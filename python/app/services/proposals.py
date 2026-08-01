"""proposals collection: read granted to clients (on their own listings) and
freelancers (their own proposals); create/update restricted by this app's
routers to the submitting freelancer / owning client respectively (re-checked
via app.rbac before ever calling this module — the real enforcement boundary
is Mudbase's own collection permissions, see
../../web/plan/build-plan.md "RBAC matrix").
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.mudbase_client import create_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.pagination import PaginationMeta
from app.schemas.proposal import Proposal, ProposalFormValues, ProposalStatus

_LIST_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 client-side.
_PAGE_SIZE = 10


async def list_proposals_for_listing(listing_id: str, *, access_token: str) -> list[Proposal]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.proposals_collection_id,
        filter_dict={"listingId": listing_id},
        sort="-createdAt",
        limit=_LIST_LIMIT,
        access_token=access_token,
    )
    return [Proposal.model_validate(doc) for doc in result["data"]]


async def get_own_proposal(listing_id: str, freelancer_id: str, *, access_token: str) -> Proposal | None:
    """A freelancer's own proposal on a given listing, if any - determines
    whether the listing detail page shows the submission form or the
    freelancer's existing status. Mirrors
    ../../web/src/app/listings/[id]/page.tsx's `ownProposal` query."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.proposals_collection_id,
        filter_dict={"listingId": listing_id, "freelancerId": freelancer_id},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Proposal.model_validate(docs[0]) if docs else None


async def get_accepted_freelancer_id(listing_id: str, *, access_token: str) -> str | None:
    """Whichever proposal (if any) has been accepted on this listing -
    decides who besides the client can see and use the message thread. See
    ../../web/plan/build-plan.md "Messaging visibility"."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.proposals_collection_id,
        filter_dict={"listingId": listing_id, "status": "accepted"},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    if not docs:
        return None
    freelancer_id = docs[0].get("freelancerId")
    return str(freelancer_id) if freelancer_id else None


async def create_proposal(
    values: ProposalFormValues,
    *,
    listing_id: str,
    freelancer_id: str,
    freelancer_name: str,
    access_token: str,
) -> Proposal:
    settings = get_settings()
    body: dict[str, Any] = {
        "listingId": listing_id,
        "freelancerId": freelancer_id,
        "freelancerName": freelancer_name,
        "coverLetter": values.cover_letter,
        "proposedRate": values.proposed_rate,
        "status": "pending",
    }
    doc = await asyncio.to_thread(create_data_sync, settings.proposals_collection_id, body, access_token=access_token)
    return Proposal.model_validate(doc)


async def get_proposal(proposal_id: str, *, access_token: str) -> Proposal | None:
    settings = get_settings()
    doc = await asyncio.to_thread(
        get_data_sync, settings.proposals_collection_id, proposal_id, access_token=access_token
    )
    return Proposal.model_validate(doc) if doc else None


async def set_proposal_status(proposal_id: str, status: ProposalStatus, *, access_token: str) -> Proposal:
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.proposals_collection_id,
        proposal_id,
        {"status": status},
        access_token=access_token,
    )
    return Proposal.model_validate(doc)


async def list_proposals_by_freelancer(
    freelancer_id: str, *, page: int = 1, access_token: str
) -> tuple[list[Proposal], PaginationMeta]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.proposals_collection_id,
        filter_dict={"freelancerId": freelancer_id},
        sort="-createdAt",
        page=page,
        limit=_PAGE_SIZE,
        access_token=access_token,
    )
    proposals = [Proposal.model_validate(doc) for doc in result["data"]]
    pagination = PaginationMeta.model_validate(result["pagination"]) if result["pagination"] else PaginationMeta()
    return proposals, pagination


async def count_proposals_by_listing_ids(listing_ids: list[str], *, access_token: str) -> dict[str, int]:
    """One batched query for proposal counts across every listing on a page,
    instead of an N+1 query per listing. Mirrors
    ../../web/src/app/listings/mine/page.tsx's `proposalCounts`."""
    if not listing_ids:
        return {}
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.proposals_collection_id,
        filter_dict={"listingId": {"$in": listing_ids}},
        limit=_LIST_LIMIT,
        access_token=access_token,
    )
    counts: dict[str, int] = {}
    for doc in result["data"]:
        listing_id = doc.get("listingId")
        if listing_id:
            counts[str(listing_id)] = counts.get(str(listing_id), 0) + 1
    return counts
