"""Browse, detail, post, edit, and "my listings". Mirrors
../../web/src/app/page.tsx, /listings/[id]/page.tsx, /listings/new/page.tsx,
/listings/[id]/edit/page.tsx and /listings/mine/page.tsx.

No realtime subscription here (unlike the reference SPA's TanStack Query
polling on the message thread — see routers/messages.py for where polling's
server-rendered equivalent, a page reload, applies) — matching the sibling
mudbase-showcase-social/mudbase-showcase-kanban Python ports' own precedent:
this is plain request/response HTML.
"""

import logging
from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app import rbac
from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.listing import LISTING_STATUSES, Listing, ListingFormValues, ListingStatus, listing_status_label
from app.schemas.message import Message
from app.schemas.pagination import PaginationMeta
from app.schemas.proposal import Proposal
from app.services import listings as listings_service
from app.services import messages as messages_service
from app.services import proposals as proposals_service
from app.session import call_with_reauth, ensure_anonymous_session, get_valid_access_token, require_login, set_flash
from app.templates_env import templates
from app.utils import is_object_id

router = APIRouter()
logger = logging.getLogger(__name__)

_PAGE_SIZE = 12


def _matches_filters(listing: Listing, *, category: str, min_budget: float | None, max_budget: float | None) -> bool:
    """Client-side application of the category/budget filters over a search
    result batch - needed because the dedicated search endpoint only takes a
    keyword and doesn't accept additional structured filters alongside it.
    Mirrors ../../web/src/app/page.tsx's `matchesFilters`."""
    if category and listing.category != category:
        return False
    if min_budget is not None and listing.budget < min_budget:
        return False
    if max_budget is not None and listing.budget > max_budget:
        return False
    return True


def _parse_budget_query(raw: str | None) -> float | None:
    if raw is None or raw.strip() == "":
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _parse_form_budget(raw: str) -> float:
    """Any unparsable input becomes -1, which then fails `ListingFormValues`'s
    `gt=0` validation with a normal field error instead of raising a second,
    differently-shaped exception type at this call site."""
    try:
        return float(raw)
    except ValueError:
        return -1.0


def _field_errors(exc: ValidationError) -> dict[str, str]:
    errors: dict[str, str] = {}
    for error in exc.errors():
        field = str(error["loc"][0]) if error["loc"] else "form"
        errors[field] = error["msg"]
    return errors


@router.get("/", response_class=HTMLResponse, response_model=None)
async def browse_listings(
    request: Request,
    q: str = "",
    category: str = "",
    min_budget: str | None = None,
    max_budget: str | None = None,
    page: int = 1,
) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)
    safe_page = max(1, page)
    keyword = q.strip()
    min_value = _parse_budget_query(min_budget)
    max_value = _parse_budget_query(max_budget)

    listings: list[Listing] = []
    total = 0
    total_pages = 1
    load_error: str | None = None
    try:
        if keyword and token:
            all_matches = await listings_service.search_listings(keyword, access_token=token)
            filtered = [
                listing
                for listing in all_matches
                if _matches_filters(listing, category=category, min_budget=min_value, max_budget=max_value)
            ]
            total = len(filtered)
            total_pages = max(1, -(-total // _PAGE_SIZE))
            start = (safe_page - 1) * _PAGE_SIZE
            listings = filtered[start : start + _PAGE_SIZE]
        elif not keyword:
            listings, pagination = await listings_service.list_listings(
                category=category or None,
                min_budget=min_value,
                max_budget=max_value,
                page=safe_page,
                access_token=token,
            )
            total = pagination.total
            total_pages = max(1, pagination.total_pages)
    except MudbaseApiError as exc:
        load_error = f"Couldn't load listings right now: {exc.message}"

    categories: list[str]
    try:
        categories = await listings_service.list_categories(access_token=token)
    except MudbaseApiError:
        categories = []

    context = await build_base_context(request)
    context.update(
        {
            "listings": listings,
            "categories": categories,
            "search": keyword,
            "category": category,
            "min_budget": min_budget or "",
            "max_budget": max_budget or "",
            "page": safe_page,
            "total": total,
            "total_pages": total_pages,
            "load_error": load_error,
        }
    )
    return templates.TemplateResponse(request=request, name="index.html", context=context)


@router.get("/listings/new", response_class=HTMLResponse, response_model=None)
async def new_listing_page(request: Request) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse("/login?next=/listings/new", status_code=303)
    user, _token = gate
    if not rbac.can_post_listing(user.custom_role):
        # Redirecting to /login here (instead of /) would loop forever: this visitor already
        # has a real session, so login_page's own already-authenticated check immediately
        # bounces back to `next` - this is a wrong-role block, not a missing-session one.
        set_flash(request, "Sign in with a client account to post a listing.", "error")
        return RedirectResponse("/", status_code=303)

    context = await build_base_context(request)
    context.update({"errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="listing_new.html", context=context)


@router.post("/listings", response_model=None)
async def create_listing_submit(
    request: Request,
    title: Annotated[str, Form()],
    description: Annotated[str, Form()],
    budget: Annotated[str, Form()],
    category: Annotated[str, Form()] = "",
) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse("/login?next=/listings/new", status_code=303)
    user, token = gate
    if not rbac.can_post_listing(user.custom_role):
        set_flash(request, "Sign in with a client account to post a listing.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        values = ListingFormValues(
            title=title, description=description, budget=_parse_form_budget(budget), category=category
        )
    except ValidationError as exc:
        context = await build_base_context(request)
        context.update({"errors": _field_errors(exc), "form_error": None})
        return templates.TemplateResponse(request=request, name="listing_new.html", context=context, status_code=422)

    try:
        created, _token = await call_with_reauth(
            request,
            token,
            lambda t: listings_service.create_listing(
                values, client_id=user.id, client_name=user.display_name, access_token=t
            ),
        )
    except MudbaseApiError as exc:
        context = await build_base_context(request)
        context.update({"errors": {}, "form_error": f"Couldn't post that listing: {exc.message}"})
        return templates.TemplateResponse(request=request, name="listing_new.html", context=context, status_code=400)

    set_flash(request, "Listing posted.", "success")
    return RedirectResponse(f"/listings/{created.id}", status_code=303)


@router.get("/listings/mine", response_class=HTMLResponse, response_model=None)
async def my_listings_page(request: Request, page: int = 1) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse("/login?next=/listings/mine", status_code=303)
    user, token = gate
    if not rbac.can_post_listing(user.custom_role):
        set_flash(request, "Sign in with a client account to view your listings.", "error")
        return RedirectResponse("/", status_code=303)

    safe_page = max(1, page)
    listings: list[Listing]
    pagination: PaginationMeta
    proposal_counts: dict[str, int]
    load_error: str | None
    try:
        (listings, pagination), token = await call_with_reauth(
            request, token, lambda t: listings_service.list_listings_by_client(user.id, page=safe_page, access_token=t)
        )
        listing_ids = [listing.id for listing in listings]
        proposal_counts, _token = await call_with_reauth(
            request, token, lambda t: proposals_service.count_proposals_by_listing_ids(listing_ids, access_token=t)
        )
        load_error = None
    except MudbaseApiError as exc:
        listings, pagination, proposal_counts = [], PaginationMeta(), {}
        load_error = f"Couldn't load your listings: {exc.message}"

    context = await build_base_context(request)
    context.update(
        {
            "listings": listings,
            "proposal_counts": proposal_counts,
            "pagination": pagination,
            "load_error": load_error,
        }
    )
    return templates.TemplateResponse(request=request, name="listings_mine.html", context=context)


@router.get("/listings/{listing_id}", response_class=HTMLResponse, response_model=None)
async def listing_detail(request: Request, listing_id: str) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)

    if not is_object_id(listing_id):
        context = await build_base_context(request)
        context.update({"listing": None})
        return templates.TemplateResponse(request=request, name="listing_detail.html", context=context, status_code=404)

    listing: Listing | None
    try:
        listing = await listings_service.get_listing(listing_id, access_token=token)
    except MudbaseApiError:
        listing = None

    context = await build_base_context(request)
    if listing is None:
        context.update({"listing": None})
        return templates.TemplateResponse(request=request, name="listing_detail.html", context=context, status_code=404)

    role: str | None = context["role"]
    current_user = context["current_user"]
    current_user_id: str | None = current_user.id if current_user and current_user.is_real_account else None
    is_owning_client = rbac.can_edit_listing(role, listing_client_id=listing.client_id, current_user_id=current_user_id)
    is_freelancer = role == "freelancer" and current_user_id is not None

    own_proposal: Proposal | None = None
    if role == "freelancer" and current_user_id is not None and token:
        freelancer_id: str = current_user_id
        try:
            own_proposal, token = await call_with_reauth(
                request, token, lambda t: proposals_service.get_own_proposal(listing_id, freelancer_id, access_token=t)
            )
        except MudbaseApiError:
            own_proposal = None

    proposals: list[Proposal] = []
    if is_owning_client and token:
        try:
            proposals, token = await call_with_reauth(
                request, token, lambda t: proposals_service.list_proposals_for_listing(listing_id, access_token=t)
            )
        except MudbaseApiError:
            proposals = []

    accepted_freelancer_id: str | None = None
    if context["is_authenticated"] and token:
        try:
            accepted_freelancer_id, token = await call_with_reauth(
                request, token, lambda t: proposals_service.get_accepted_freelancer_id(listing_id, access_token=t)
            )
        except MudbaseApiError:
            accepted_freelancer_id = None

    can_message = rbac.can_message(
        role,
        listing_client_id=listing.client_id,
        current_user_id=current_user_id,
        accepted_freelancer_id=accepted_freelancer_id,
    )

    messages: list[Message] = []
    if can_message and token:
        try:
            messages, token = await call_with_reauth(
                request, token, lambda t: messages_service.list_messages(listing_id, access_token=t)
            )
        except MudbaseApiError:
            messages = []

    context.update(
        {
            "listing": listing,
            "listing_status_label": listing_status_label(listing.status),
            "is_owning_client": is_owning_client,
            "is_freelancer": is_freelancer,
            "own_proposal": own_proposal,
            "proposals": proposals,
            "can_message": can_message,
            "messages": messages,
            "errors": {},
        }
    )
    return templates.TemplateResponse(request=request, name="listing_detail.html", context=context)


@router.get("/listings/{listing_id}/edit", response_class=HTMLResponse, response_model=None)
async def edit_listing_page(request: Request, listing_id: str) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse(f"/login?next=/listings/{listing_id}/edit", status_code=303)
    user, token = gate

    if not is_object_id(listing_id):
        return RedirectResponse("/", status_code=303)

    listing: Listing | None
    try:
        listing, _token = await call_with_reauth(
            request, token, lambda t: listings_service.get_listing(listing_id, access_token=t)
        )
    except MudbaseApiError:
        listing = None
    if listing is None:
        set_flash(request, "That listing no longer exists.", "error")
        return RedirectResponse("/", status_code=303)

    if not rbac.can_edit_listing(user.custom_role, listing_client_id=listing.client_id, current_user_id=user.id):
        set_flash(request, "Only the client who posted this listing can edit it.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    context = await build_base_context(request)
    context.update({"listing": listing, "errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="listing_edit.html", context=context)


@router.post("/listings/{listing_id}/edit", response_model=None)
async def update_listing_submit(
    request: Request,
    listing_id: str,
    title: Annotated[str, Form()],
    description: Annotated[str, Form()],
    budget: Annotated[str, Form()],
    status: Annotated[str, Form()],
    category: Annotated[str, Form()] = "",
) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse(f"/login?next=/listings/{listing_id}/edit", status_code=303)
    user, token = gate

    listing: Listing | None
    try:
        listing, token = await call_with_reauth(
            request, token, lambda t: listings_service.get_listing(listing_id, access_token=t)
        )
    except MudbaseApiError:
        listing = None
    if listing is None:
        set_flash(request, "That listing no longer exists.", "error")
        return RedirectResponse("/", status_code=303)

    if not rbac.can_edit_listing(user.custom_role, listing_client_id=listing.client_id, current_user_id=user.id):
        set_flash(request, "Only the client who posted this listing can edit it.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    if status not in LISTING_STATUSES:
        set_flash(request, "Invalid status.", "error")
        return RedirectResponse(f"/listings/{listing_id}/edit", status_code=303)
    status_to_set: ListingStatus = status

    try:
        values = ListingFormValues(
            title=title, description=description, budget=_parse_form_budget(budget), category=category
        )
    except ValidationError as exc:
        context = await build_base_context(request)
        context.update({"listing": listing, "errors": _field_errors(exc), "form_error": None})
        return templates.TemplateResponse(request=request, name="listing_edit.html", context=context, status_code=422)

    listing_to_update = listing
    try:
        await call_with_reauth(
            request,
            token,
            lambda t: listings_service.update_listing(listing_to_update, values, status=status_to_set, access_token=t),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that listing: {exc.message}", "error")
        return RedirectResponse(f"/listings/{listing_id}/edit", status_code=303)

    set_flash(request, "Listing updated.", "success")
    return RedirectResponse(f"/listings/{listing_id}", status_code=303)
