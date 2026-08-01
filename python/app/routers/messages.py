"""Per-listing message thread — sending a message. Mirrors
../../web/src/components/messages/MessageThread.tsx.

No client-side polling here (unlike the reference SPA's `refetchInterval` on
the message thread query) — matching this port's plain request/response
model: a page reload is how a visitor sees a new message from the other
side. Reading the thread happens inline in routers/listings.py's
`listing_detail` (the thread is part of the listing detail page, not its own
route) — this router only owns the write.
"""

import logging
from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import RedirectResponse
from pydantic import ValidationError

from app import rbac
from app.mudbase_client import MudbaseApiError
from app.schemas.listing import Listing
from app.schemas.message import MessageFormValues
from app.services import listings as listings_service
from app.services import messages as messages_service
from app.services import proposals as proposals_service
from app.session import call_with_reauth, require_login, set_flash
from app.utils import is_object_id

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/listings/{listing_id}/messages", response_model=None)
async def send_message(request: Request, listing_id: str, content: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_login(request)
    if gate is None:
        return RedirectResponse(f"/login?next=/listings/{listing_id}", status_code=303)
    user, token = gate

    if not is_object_id(listing_id):
        return RedirectResponse("/", status_code=303)

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

    listing_client_id: str = listing.client_id
    accepted_freelancer_id: str | None
    try:
        accepted_freelancer_id, token = await call_with_reauth(
            request, token, lambda t: proposals_service.get_accepted_freelancer_id(listing_id, access_token=t)
        )
    except MudbaseApiError:
        accepted_freelancer_id = None

    if not rbac.can_message(
        user.custom_role,
        listing_client_id=listing_client_id,
        current_user_id=user.id,
        accepted_freelancer_id=accepted_freelancer_id,
    ):
        set_flash(request, "You don't have access to this conversation.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    try:
        values = MessageFormValues(content=content)
    except ValidationError:
        set_flash(request, "Write a message before sending.", "error")
        return RedirectResponse(f"/listings/{listing_id}", status_code=303)

    try:
        await call_with_reauth(
            request,
            token,
            lambda t: messages_service.create_message(
                values, listing_id=listing_id, sender_id=user.id, sender_name=user.display_name, access_token=t
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't send that message: {exc.message}", "error")

    return RedirectResponse(f"/listings/{listing_id}", status_code=303)
