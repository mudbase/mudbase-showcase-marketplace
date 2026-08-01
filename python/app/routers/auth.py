"""Login / register / logout. Mirrors ../../web/src/app/login, /register and
../../web/src/hooks/useAuth.ts. Self-signup exposes a real role selector
(client or freelancer) — unlike the ecommerce showcase's hidden-role
customer-only signup, both roles here are meant to be created by end users.
"""

import logging
from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app.config import get_settings
from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.auth import LoginFormValues, RegisterFormValues
from app.services import auth_service
from app.session import clear_session, get_session_user, get_valid_access_token, set_flash, store_session
from app.templates_env import templates

router = APIRouter()
logger = logging.getLogger(__name__)


def _post_login_redirect(custom_role: str | None) -> str:
    return "/listings/mine" if custom_role == "client" else "/"


def _demo_context() -> dict[str, str]:
    settings = get_settings()
    return {
        "demo_client_email": settings.demo_client_email,
        "demo_freelancer_email": settings.demo_freelancer_email,
        "demo_password": settings.demo_password,
    }


@router.get("/login", response_class=HTMLResponse, response_model=None)
async def login_page(request: Request, next: str | None = None) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is not None and user.is_real_account:
        return RedirectResponse(next or "/", status_code=303)
    context = await build_base_context(request)
    context.update({"errors": {}, "form_error": None, "next": next, **_demo_context()})
    return templates.TemplateResponse(request=request, name="login.html", context=context)


@router.post("/login", response_class=HTMLResponse, response_model=None)
async def login_submit(
    request: Request,
    email: Annotated[str, Form()],
    password: Annotated[str, Form()],
    next: Annotated[str | None, Form()] = None,
) -> HTMLResponse | RedirectResponse:
    try:
        values = LoginFormValues(email=email, password=password)
    except ValidationError as exc:
        context = await build_base_context(request)
        context.update({"errors": _field_errors(exc), "form_error": None, "next": next, **_demo_context()})
        return templates.TemplateResponse(request=request, name="login.html", context=context, status_code=422)

    try:
        result = await auth_service.login(values.email, values.password)
    except MudbaseApiError as exc:
        context = await build_base_context(request)
        context.update({"errors": {}, "form_error": exc.message, "next": next, **_demo_context()})
        return templates.TemplateResponse(request=request, name="login.html", context=context, status_code=401)

    user = result.get("user") or {}
    store_session(
        request,
        user=user,
        token=result["token"],
        refresh_token=result["refreshToken"],
        expires_in=result.get("expiresIn"),
    )
    set_flash(request, "Welcome back!", "success")
    destination = next or _post_login_redirect(user.get("customRole"))
    return RedirectResponse(destination, status_code=303)


@router.get("/register", response_class=HTMLResponse, response_model=None)
async def register_page(request: Request) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is not None and user.is_real_account:
        return RedirectResponse("/", status_code=303)
    context = await build_base_context(request)
    context.update({"errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="register.html", context=context)


@router.post("/register", response_class=HTMLResponse, response_model=None)
async def register_submit(
    request: Request,
    first_name: Annotated[str, Form()],
    last_name: Annotated[str, Form()],
    email: Annotated[str, Form()],
    password: Annotated[str, Form()],
    role: Annotated[str, Form()],
    agreed_to_terms: Annotated[bool, Form()] = False,
) -> HTMLResponse | RedirectResponse:
    try:
        values = RegisterFormValues(
            first_name=first_name,
            last_name=last_name,
            email=email,
            password=password,
            role=role,  # type: ignore[arg-type]  # pydantic's Literal validation rejects anything else
            agreed_to_terms=agreed_to_terms,
        )
    except ValidationError as exc:
        context = await build_base_context(request)
        context.update({"errors": _field_errors(exc), "form_error": None})
        return templates.TemplateResponse(request=request, name="register.html", context=context, status_code=422)

    try:
        result = await auth_service.register(
            values.role, values.email, values.password, values.first_name, values.last_name, values.agreed_to_terms
        )
    except MudbaseApiError as exc:
        context = await build_base_context(request)
        context.update({"errors": {}, "form_error": exc.message})
        return templates.TemplateResponse(request=request, name="register.html", context=context, status_code=400)

    token = result.get("token")
    if not token:
        # This project requires email verification — register() never
        # returns a session token in that case.
        set_flash(
            request,
            result.get("message") or "Check your inbox for a verification link, then sign in.",
            "info",
        )
        return RedirectResponse("/login", status_code=303)

    user = result.get("user") or {}
    store_session(
        request,
        user=user,
        token=token,
        refresh_token=result["refreshToken"],
        expires_in=result.get("expiresIn"),
    )
    set_flash(request, "Welcome to the marketplace!", "success")
    return RedirectResponse(_post_login_redirect(user.get("customRole")), status_code=303)


@router.post("/logout", response_model=None)
async def logout_submit(request: Request) -> RedirectResponse:
    token = await get_valid_access_token(request)
    if token:
        try:
            await auth_service.logout(token)
        except MudbaseApiError as exc:
            # Session is cleared locally regardless of the remote logout outcome (an
            # already-expired token, for instance, shouldn't strand the user signed in).
            logger.warning("Remote logout failed for a local session teardown: %s", exc.message)
    clear_session(request)
    return RedirectResponse("/", status_code=303)


def _field_errors(exc: ValidationError) -> dict[str, str]:
    errors: dict[str, str] = {}
    for error in exc.errors():
        field = str(error["loc"][0]) if error["loc"] else "form"
        errors[field] = error["msg"]
    return errors
