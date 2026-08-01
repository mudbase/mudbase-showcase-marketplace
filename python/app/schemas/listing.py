"""Mirrors ../../web/src/types/listing.ts and
../../web/src/components/listings/ListingForm.tsx. Field aliases match the
raw Mudbase document shape (camelCase, `_id`) so `Listing.model_validate(doc)`
works directly off a `DataApi` response dict — no separate mapping layer.
"""

from datetime import datetime
from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, field_validator

ListingStatus = Literal["open", "in_progress", "completed"]
LISTING_STATUSES: tuple[ListingStatus, ...] = get_args(ListingStatus)

_STATUS_LABELS: dict[str, str] = {"open": "Open", "in_progress": "In progress", "completed": "Completed"}

_MAX_TITLE_LENGTH = 120
_MAX_CATEGORY_LENGTH = 60


def listing_status_label(status: str) -> str:
    return _STATUS_LABELS.get(status, status)


class Listing(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    title: str
    description: str
    budget: float
    category: str | None = None
    status: ListingStatus = "open"
    client_id: str = Field(alias="clientId")
    client_name: str = Field(alias="clientName")
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class ListingFormValues(BaseModel):
    """Validated shape of the listing composer/edit form. Mirrors the zod
    schema in ../../web/src/components/listings/ListingForm.tsx: 3-120 char
    title, 20+ char description, positive budget, optional category capped
    at 60 chars."""

    title: str = Field(min_length=3, max_length=_MAX_TITLE_LENGTH)
    description: str = Field(min_length=20)
    budget: float = Field(gt=0)
    category: str = Field(default="", max_length=_MAX_CATEGORY_LENGTH)

    @field_validator("title", "description")
    @classmethod
    def _strip_required(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("This field is required.")
        return stripped

    @field_validator("category")
    @classmethod
    def _strip_category(cls, value: str) -> str:
        return value.strip()
