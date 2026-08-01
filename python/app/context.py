"""Per-request template context shared across every page: current user (if
any, including the anonymous guest), a one-shot flash message, and small
RBAC helpers so templates can gate nav links/write controls without
importing app.rbac themselves.
"""

from typing import Any

from fastapi import Request

from app import rbac
from app.session import get_session_user, pop_flash


async def build_base_context(request: Request) -> dict[str, Any]:
    user = get_session_user(request)
    is_authenticated = user is not None and user.is_real_account
    role = user.custom_role if user is not None and is_authenticated else None
    return {
        "current_user": user,
        "is_authenticated": is_authenticated,
        "role": role,
        "role_label": rbac.role_label(role),
        "flash": pop_flash(request),
        "can_post_listing": rbac.can_post_listing(role),
    }
