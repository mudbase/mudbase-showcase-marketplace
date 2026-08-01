"""Proposal submission (freelancer), accept/reject (owning client), and "my
proposals" (freelancer). Mirrors ../../web/src/components/proposals/
ProposalForm.tsx, ProposalList.tsx and ../../web/src/app/proposals/page.tsx.
"""

import logging
from typing import Annotated, Literal

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app import rbac
from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.listing import Listing
from app.schemas.pagination import PaginationMeta
from app.schemas.proposal import Proposal, ProposalFormValues
from app.services import listings as listings_service
from app.services import proposals as proposals_service
from app.session import call_with_reauth, require_login, set_flash
from app.templates_env import templates
from app.utils import is_object_id

router = APIRouter()
logger = logging.getLogger(__name__)

_PAGE_SIZE = 10


def _field_errors(exc: ValidationError) -> dict[str, str]:
    errors: dict[str, str] = {}
    for error in exc.errors():
        field = str(error["loc"][0]) if error["loc"] else "form"
        errors[field] = error["msg"]
    return errors


@router.post("/listings/{listing_id}/proposals", response_model=None)
async def submit_proposal(
    request: Request,
    listing_id: str,
    cover_letter: Annotated[str, Form()],
    proposed_rate: Annotated[str, Form()],
) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse(f"/login?next=/listings/{listing_id}", status_code=303)
    user, token = gate
    if not rbac.can_submit_proposal(user.custom_role):
        set_flash(request, "Sign in with a freelancer account to submit a proposal.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    try:
        rate = float(proposed_rate)
    except ValueError:
        rate = -1.0

    try:
        values = ProposalFormValues(cover_letter=cover_letter, proposed_rate=rate)
    except ValidationError:
        set_flash(request, "Give your cover letter at least 20 characters and a rate greater than 0.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    try:
        await call_with_reauth(
            request,
            token,
            lambda t: proposals_service.create_proposal(
                values,
                listing_id=listing_id,
                freelancer_id=user.id,
                freelancer_name=user.display_name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't submit that proposal: {exc.message}", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    set_flash(request, "Proposal submitted.", "success")
    return RedirectResponse(f"/listings/{listing_id}", status_code=303)


async def _set_status(request: Request, proposal_id: str, status: Literal["accepted", "rejected"]) -> RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse("/login", status_code=303)
    user, token = gate

    if not is_object_id(proposal_id):
        return RedirectResponse("/", status_code=303)

    proposal: Proposal | None
    try:
        proposal, token = await call_with_reauth(
            request, token, lambda t: proposals_service.get_proposal(proposal_id, access_token=t)
        )
    except MudbaseApiError:
        proposal = None
    if proposal is None:
        set_flash(request, "That proposal no longer exists.", "error")
        return RedirectResponse("/", status_code=303)

    target_listing_id: str = proposal.listing_id
    listing: Listing | None
    try:
        listing, token = await call_with_reauth(
            request, token, lambda t: listings_service.get_listing(target_listing_id, access_token=t)
        )
    except MudbaseApiError:
        listing = None
    if listing is None:
        set_flash(request, "That listing no longer exists.", "error")
        return RedirectResponse("/", status_code=303)

    if not rbac.can_manage_proposals(user.custom_role, listing_client_id=listing.client_id, current_user_id=user.id):
        set_flash(request, "Only the client who posted this listing can review its proposals.", "error")
        return RedirectResponse(f"/listings/{listing.id}", status_code=303)

    try:
        await call_with_reauth(
            request, token, lambda t: proposals_service.set_proposal_status(proposal_id, status, access_token=t)
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that proposal: {exc.message}", "error")
        return RedirectResponse(f"/listings/{listing.id}", status_code=303)

    set_flash(request, f"Proposal {status}.", "success")
    return RedirectResponse(f"/listings/{listing.id}", status_code=303)


@router.post("/proposals/{proposal_id}/accept", response_model=None)
async def accept_proposal(request: Request, proposal_id: str) -> RedirectResponse:
    return await _set_status(request, proposal_id, "accepted")


@router.post("/proposals/{proposal_id}/reject", response_model=None)
async def reject_proposal(request: Request, proposal_id: str) -> RedirectResponse:
    return await _set_status(request, proposal_id, "rejected")


@router.get("/proposals", response_class=HTMLResponse, response_model=None)
async def my_proposals_page(request: Request, page: int = 1) -> HTMLResponse | RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse("/login?next=/proposals", status_code=303)
    user, token = gate
    if not rbac.can_submit_proposal(user.custom_role):
        set_flash(request, "Sign in with a freelancer account to view your proposals.", "error")
        return RedirectResponse("/", status_code=303)

    safe_page = max(1, page)
    proposals: list[Proposal]
    pagination: PaginationMeta
    listings_by_id: dict[str, Listing]
    load_error: str | None
    try:
        (proposals, pagination), token = await call_with_reauth(
            request,
            token,
            lambda t: proposals_service.list_proposals_by_freelancer(user.id, page=safe_page, access_token=t),
        )
        listing_ids = sorted({proposal.listing_id for proposal in proposals})
        listings_by_id, _token = await call_with_reauth(
            request, token, lambda t: listings_service.list_listings_by_ids(listing_ids, access_token=t)
        )
        load_error = None
    except MudbaseApiError as exc:
        proposals, pagination, listings_by_id = [], PaginationMeta(), {}
        load_error = f"Couldn't load your proposals: {exc.message}"

    context = await build_base_context(request)
    context.update(
        {
            "proposals": proposals,
            "listings_by_id": listings_by_id,
            "pagination": pagination,
            "load_error": load_error,
        }
    )
    return templates.TemplateResponse(request=request, name="proposals_mine.html", context=context)
