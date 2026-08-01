"""Mirrors ../../web/src/types/proposal.ts and
../../web/src/components/proposals/ProposalForm.tsx."""

from datetime import datetime
from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, field_validator

ProposalStatus = Literal["pending", "accepted", "rejected"]
PROPOSAL_STATUSES: tuple[ProposalStatus, ...] = get_args(ProposalStatus)

_STATUS_LABELS: dict[str, str] = {"pending": "Pending", "accepted": "Accepted", "rejected": "Rejected"}


def proposal_status_label(status: str) -> str:
    return _STATUS_LABELS.get(status, status)


class Proposal(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    listing_id: str = Field(alias="listingId")
    freelancer_id: str = Field(alias="freelancerId")
    freelancer_name: str = Field(alias="freelancerName")
    cover_letter: str = Field(alias="coverLetter")
    proposed_rate: float = Field(alias="proposedRate")
    status: ProposalStatus = "pending"
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class ProposalFormValues(BaseModel):
    """Mirrors the zod schema in
    ../../web/src/components/proposals/ProposalForm.tsx: 20+ char cover
    letter, positive proposed rate."""

    cover_letter: str = Field(min_length=20)
    proposed_rate: float = Field(gt=0)

    @field_validator("cover_letter")
    @classmethod
    def _strip_cover_letter(cls, value: str) -> str:
        stripped = value.strip()
        if len(stripped) < 20:
            raise ValueError("Cover letter must be at least 20 characters")
        return stripped
