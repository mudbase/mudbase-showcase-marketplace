"""Mirrors the `PaginationMeta` shape in ../../web/src/lib/mudbase.ts (the
Mudbase `DataApi.list_data` response's `pagination` object)."""

from pydantic import BaseModel, ConfigDict, Field


class PaginationMeta(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    page: int = 1
    limit: int = 20
    total: int = 0
    total_pages: int = Field(default=0, alias="totalPages")
    has_more: bool = Field(default=False, alias="hasMore")
