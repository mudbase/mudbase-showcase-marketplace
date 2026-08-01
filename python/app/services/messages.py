"""messages collection: create + read granted to any authenticated user, but
only rendered by this app's routers/templates for the listing's client and
its accepted freelancer (see app.rbac.can_message and
../../web/plan/build-plan.md "Messaging visibility") — a document-level
scope Mudbase's collection permissions don't enforce server-side (see
../../web/plan/build-plan.md "RBAC matrix").
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.mudbase_client import create_data_sync, list_data_sync
from app.schemas.message import Message, MessageFormValues

_THREAD_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 client-side.


async def list_messages(listing_id: str, *, access_token: str) -> list[Message]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.messages_collection_id,
        filter_dict={"listingId": listing_id},
        sort="createdAt",
        limit=_THREAD_LIMIT,
        access_token=access_token,
    )
    return [Message.model_validate(doc) for doc in result["data"]]


async def create_message(
    values: MessageFormValues,
    *,
    listing_id: str,
    sender_id: str,
    sender_name: str,
    access_token: str,
) -> Message:
    settings = get_settings()
    body: dict[str, Any] = {
        "listingId": listing_id,
        "senderId": sender_id,
        "senderName": sender_name,
        "content": values.content,
    }
    doc = await asyncio.to_thread(create_data_sync, settings.messages_collection_id, body, access_token=access_token)
    return Message.model_validate(doc)
