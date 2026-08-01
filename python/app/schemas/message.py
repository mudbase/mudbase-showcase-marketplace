"""Mirrors ../../web/src/types/message.ts and
../../web/src/components/messages/MessageThread.tsx."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

_MAX_CONTENT_LENGTH = 4000


class Message(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    listing_id: str = Field(alias="listingId")
    sender_id: str = Field(alias="senderId")
    sender_name: str = Field(alias="senderName")
    content: str
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class MessageFormValues(BaseModel):
    content: str = Field(min_length=1, max_length=_MAX_CONTENT_LENGTH)

    @field_validator("content")
    @classmethod
    def _strip_content(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Write a message before sending.")
        return stripped
