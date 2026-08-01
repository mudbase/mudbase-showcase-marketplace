"""listings collection: public (authenticated, including the anonymous guest
session) read, `client`-role-only create; update restricted by this app's
routers to the owning client (re-checked via app.rbac before ever calling
this module — the real enforcement boundary is Mudbase's own collection
permissions, see ../../web/plan/build-plan.md "RBAC matrix").
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.mudbase_client import create_data_sync, get_data_sync, list_data_sync, search_sync, update_data_sync
from app.schemas.listing import Listing, ListingFormValues, ListingStatus
from app.schemas.pagination import PaginationMeta

_PAGE_SIZE = 12
_CATEGORY_SAMPLE_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 client-side.
_SEARCH_LIMIT = 50


async def list_listings(
    *,
    category: str | None = None,
    min_budget: float | None = None,
    max_budget: float | None = None,
    page: int = 1,
    access_token: str | None,
) -> tuple[list[Listing], PaginationMeta]:
    """Server-side filter + real pagination — used when no search keyword is
    present. Mirrors ../../web/src/app/page.tsx's "Branch 1"."""
    settings = get_settings()
    filter_dict: dict[str, Any] = {}
    if category:
        filter_dict["category"] = category
    budget_filter: dict[str, Any] = {}
    if min_budget is not None:
        budget_filter["$gte"] = min_budget
    if max_budget is not None:
        budget_filter["$lte"] = max_budget
    if budget_filter:
        filter_dict["budget"] = budget_filter

    result = await asyncio.to_thread(
        list_data_sync,
        settings.listings_collection_id,
        filter_dict=filter_dict or None,
        sort="-createdAt",
        page=page,
        limit=_PAGE_SIZE,
        access_token=access_token,
    )
    listings = [Listing.model_validate(doc) for doc in result["data"]]
    pagination = PaginationMeta.model_validate(result["pagination"]) if result["pagination"] else PaginationMeta()
    return listings, pagination


async def search_listings(q: str, *, access_token: str) -> list[Listing]:
    """Keyword search via the dedicated search endpoint (see
    mudbase_client.search_sync() for why the collection-data `filter` param
    can't do this) — used when a search keyword is present. Mirrors
    ../../web/src/app/page.tsx's "Branch 2". Category/budget filters and
    pagination are applied by the caller over this batch, matching the
    reference web app's own client-side post-filtering (the search endpoint
    doesn't accept structured filters alongside `q`)."""
    settings = get_settings()
    result = await asyncio.to_thread(
        search_sync,
        q,
        collections=settings.listings_collection_slug,
        limit=_SEARCH_LIMIT,
        access_token=access_token,
    )
    collection_results = result.get("results") or []
    first = collection_results[0] if collection_results else {}
    raw_listings = first.get("results") or []
    return [Listing.model_validate(doc) for doc in raw_listings]


async def list_categories(*, access_token: str | None) -> list[str]:
    """A lightweight, unfiltered sample used only to populate the category
    filter dropdown - avoids a dedicated "distinct categories" endpoint that
    Mudbase's data API doesn't expose. Mirrors
    ../../web/src/app/page.tsx's `categorySample` query."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.listings_collection_id,
        limit=_CATEGORY_SAMPLE_LIMIT,
        access_token=access_token,
    )
    seen: set[str] = set()
    for doc in result["data"]:
        category = doc.get("category")
        if category:
            seen.add(str(category))
    return sorted(seen)


async def list_listings_by_client(client_id: str, *, page: int = 1, access_token: str) -> tuple[list[Listing], PaginationMeta]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.listings_collection_id,
        filter_dict={"clientId": client_id},
        sort="-createdAt",
        page=page,
        limit=_PAGE_SIZE,
        access_token=access_token,
    )
    listings = [Listing.model_validate(doc) for doc in result["data"]]
    pagination = PaginationMeta.model_validate(result["pagination"]) if result["pagination"] else PaginationMeta()
    return listings, pagination


async def get_listing(listing_id: str, *, access_token: str | None) -> Listing | None:
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.listings_collection_id, listing_id, access_token=access_token)
    return Listing.model_validate(doc) if doc else None


async def create_listing(
    values: ListingFormValues,
    *,
    client_id: str,
    client_name: str,
    access_token: str,
) -> Listing:
    settings = get_settings()
    body: dict[str, Any] = {
        "title": values.title,
        "description": values.description,
        "budget": values.budget,
        "status": "open",
        "clientId": client_id,
        "clientName": client_name,
    }
    if values.category:
        body["category"] = values.category
    doc = await asyncio.to_thread(create_data_sync, settings.listings_collection_id, body, access_token=access_token)
    return Listing.model_validate(doc)


async def update_listing(
    listing: Listing,
    values: ListingFormValues,
    *,
    status: ListingStatus,
    access_token: str,
) -> Listing:
    settings = get_settings()
    body: dict[str, Any] = {
        "title": values.title,
        "description": values.description,
        "budget": values.budget,
        "category": values.category or None,
        "status": status,
    }
    doc = await asyncio.to_thread(
        update_data_sync, settings.listings_collection_id, listing.id, body, access_token=access_token
    )
    return Listing.model_validate(doc)


async def list_listings_by_ids(listing_ids: list[str], *, access_token: str) -> dict[str, Listing]:
    """One batched query for the listing titles referenced on a page, instead
    of an N+1 query per proposal. Mirrors
    ../../web/src/app/proposals/page.tsx's `listingsById`."""
    if not listing_ids:
        return {}
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.listings_collection_id,
        filter_dict={"_id": {"$in": listing_ids}},
        limit=_CATEGORY_SAMPLE_LIMIT,
        access_token=access_token,
    )
    return {doc["_id"]: Listing.model_validate(doc) for doc in result["data"]}
