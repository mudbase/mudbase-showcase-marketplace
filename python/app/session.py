"""Server-side session: the Mudbase JWT lives only in the signed, httpOnly
Starlette session cookie set up in main.py — it is never sent to browser JS,
matching the reference web app's own note that this is a deliberate
difference for a server-rendered port (the reference SPA necessarily holds
its token in `localStorage` for direct browser-to-Mudbase calls).

This app has a guest/anonymous session for public listing browsing (see
`ensure_anonymous_session` below), same precedent as the sibling
mudbase-showcase-social/mudbase-showcase-ecommerce Python ports. Refresh
strategy (proactive margin-based refresh in `get_valid_access_token`,
reactive retry-once in `call_with_reauth`) is ported verbatim from those
ports' own `app/session.py`.
"""

import asyncio
import logging
import time
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

from fastapi import Request
from pydantic import BaseModel

from app.mudbase_client import MudbaseApiError, create_anonymous_session_sync, refresh_sync

logger = logging.getLogger(__name__)

T = TypeVar("T")

_USER_KEY = "user"
_TOKEN_KEY = "token"
_REFRESH_KEY = "refresh_token"
_EXPIRES_KEY = "expires_at"
_FLASH_KEY = "flash"

_REFRESH_MARGIN_SECONDS: float = 60.0
_DEFAULT_EXPIRES_IN_SECONDS: float = 3600.0


class SessionUser(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    custom_role: str | None = None
    is_anonymous: bool = False

    @property
    def display_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip() or self.email

    @property
    def is_real_account(self) -> bool:
        """A real, role-carrying account - distinct from the always-present
        anonymous guest session. Mirrors ../web/src/hooks/useAuth.ts's
        `isAuthenticated`."""
        return not self.is_anonymous and self.custom_role is not None


def store_session(
    request: Request,
    *,
    user: dict[str, Any],
    token: str,
    refresh_token: str,
    expires_in: float | None,
) -> None:
    request.session[_USER_KEY] = {
        "id": user.get("id") or user.get("_id"),
        "email": user.get("email"),
        "first_name": user.get("firstName"),
        "last_name": user.get("lastName"),
        "custom_role": user.get("customRole"),
        "is_anonymous": bool(user.get("isAnonymous", False)),
    }
    request.session[_TOKEN_KEY] = token
    request.session[_REFRESH_KEY] = refresh_token
    request.session[_EXPIRES_KEY] = time.time() + float(expires_in or _DEFAULT_EXPIRES_IN_SECONDS)


def clear_session(request: Request) -> None:
    request.session.clear()


def get_session_user(request: Request) -> SessionUser | None:
    data = request.session.get(_USER_KEY)
    if not data or not data.get("id"):
        return None
    return SessionUser(**data)


async def force_refresh_access_token(request: Request) -> str | None:
    """Unconditionally exchanges the session's stored refresh token for a new
    access/refresh pair, bypassing the expiry-margin check `get_valid_access_
    token` uses. Persists the new pair into the session on success. Clears
    the session and returns None if there is no refresh token to use, or the
    refresh call itself fails (refresh token expired/revoked too)."""
    refresh_token = request.session.get(_REFRESH_KEY)
    if not refresh_token:
        clear_session(request)
        return None

    try:
        result = await asyncio.to_thread(refresh_sync, refresh_token)
    except MudbaseApiError as exc:
        logger.info("Session refresh failed, signing the visitor out: %s", exc.message)
        clear_session(request)
        return None

    new_token: str | None = result.get("token")
    new_refresh: str | None = result.get("refreshToken")
    if not new_token or not new_refresh:
        clear_session(request)
        return None

    request.session[_TOKEN_KEY] = new_token
    request.session[_REFRESH_KEY] = new_refresh
    request.session[_EXPIRES_KEY] = time.time() + float(result.get("expiresIn") or _DEFAULT_EXPIRES_IN_SECONDS)
    return new_token


async def get_valid_access_token(request: Request) -> str | None:
    """Returns a live access token for the current session, refreshing it
    first if it is within `_REFRESH_MARGIN_SECONDS` of expiry. Clears the
    session and returns None if there is no session or refresh fails."""
    token: str | None = request.session.get(_TOKEN_KEY)
    if not token:
        return None

    expires_at = request.session.get(_EXPIRES_KEY, 0.0)
    if expires_at - _REFRESH_MARGIN_SECONDS > time.time():
        return token

    return await force_refresh_access_token(request)


async def call_with_reauth(
    request: Request,
    token: str,
    operation: Callable[[str], Awaitable[T]],
) -> tuple[T, str]:
    """Runs `operation(token)`. If it raises a `MudbaseApiError` with a 401
    status — the server rejected a token our local expiry bookkeeping thought
    was still good — forces a refresh via the stored refresh token and retries
    `operation` exactly once with the new token, instead of letting the 401
    surface to the caller. Returns the result alongside whichever token ended
    up succeeding, so callers threading a token across several calls in the
    same request can keep using the refreshed one. Any non-401 error, or a
    401 that persists after a successful refresh, propagates unchanged."""
    try:
        result = await operation(token)
    except MudbaseApiError as exc:
        if exc.status_code != 401:
            raise
        new_token = await force_refresh_access_token(request)
        if not new_token:
            raise
        result = await operation(new_token)
        return result, new_token
    return result, token


async def ensure_anonymous_session(request: Request) -> None:
    """Establishes a lightweight anonymous Mudbase session for listing
    browsing if the visitor has no session (real or anonymous) yet. Mirrors
    the reference SPA's `POST /api/auth/anonymous` on first load — the JWT it
    grants satisfies the collections' authenticated-read rule without
    requiring registration.

    Best-effort: if the call fails, pages render with an empty/error state
    rather than raising, since a page that fails to load anything is worse
    than one that fails to load without a session.
    """
    if request.session.get(_TOKEN_KEY):
        return
    try:
        result = await asyncio.to_thread(create_anonymous_session_sync)
    except MudbaseApiError as exc:
        logger.warning("Anonymous session creation failed; reads will run unauthenticated: %s", exc.message)
        return

    token = result.get("token")
    refresh_token = result.get("refreshToken") or result.get("refresh_token")
    if not token or not refresh_token:
        return

    request.session[_TOKEN_KEY] = token
    request.session[_REFRESH_KEY] = refresh_token
    request.session[_EXPIRES_KEY] = time.time() + float(
        result.get("expiresIn") or result.get("expires_in") or _DEFAULT_EXPIRES_IN_SECONDS
    )


async def require_login(request: Request) -> tuple[SessionUser, str] | None:
    """This app's write-gate: unlike `get_valid_access_token`/anonymous
    browsing, posting a listing, submitting a proposal, editing, or viewing
    "my listings"/"my proposals" all require a **real**, role-carrying
    account — not the always-present anonymous guest session. Returns
    `(user, token)` on success, or `None` if the visitor must be redirected
    to /login (no real session, or a refresh attempt failed and the session
    was cleared)."""
    user = get_session_user(request)
    if user is None or not user.is_real_account:
        return None
    token = await get_valid_access_token(request)
    if token is None:
        return None
    return user, token


def set_flash(request: Request, message: str, category: str = "info") -> None:
    request.session[_FLASH_KEY] = {"message": message, "category": category}


def pop_flash(request: Request) -> dict[str, str] | None:
    flash: dict[str, str] | None = request.session.pop(_FLASH_KEY, None)
    return flash
