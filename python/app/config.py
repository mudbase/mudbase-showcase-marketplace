"""Environment configuration.

Mirrors ../web/src/lib/config.ts and the sibling mudbase-showcase-social/
mudbase-showcase-ecommerce Python ports' app/config.py: fail fast at startup
if a required collection/project ID is missing, rather than surfacing a
confusing error deep inside a request handler later.
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mudbase_url: str = Field(default="https://cloud.mudbase.dev", alias="MUDBASE_URL")
    mudbase_project_id: str = Field(alias="MUDBASE_PROJECT_ID")
    listings_collection_id: str = Field(alias="LISTINGS_COLLECTION_ID")
    proposals_collection_id: str = Field(alias="PROPOSALS_COLLECTION_ID")
    messages_collection_id: str = Field(alias="MESSAGES_COLLECTION_ID")

    # The collection's slug, distinct from its _id above - the search endpoint's `collections`
    # query param matches on slug, not _id (see mudbase_client.search_sync()).
    listings_collection_slug: str = Field(default="listings", alias="LISTINGS_COLLECTION_SLUG")

    session_secret_key: str = Field(alias="SESSION_SECRET_KEY")
    session_cookie_name: str = Field(default="mudbase_showcase_marketplace_session", alias="SESSION_COOKIE_NAME")
    session_https_only: bool = Field(default=False, alias="SESSION_HTTPS_ONLY")

    # Quick sign-in demo accounts for the /login page. Not a production secret: this whole app is
    # a public showcase and these credentials are already published in this project's own
    # README/build-plan. Override via .env for a private deployment.
    demo_client_email: str = Field(default="market.client.demo@gmail.com", alias="DEMO_CLIENT_EMAIL")
    demo_freelancer_email: str = Field(default="market.freelancer.demo@gmail.com", alias="DEMO_FREELANCER_EMAIL")
    demo_password: str = Field(default="DemoTest123!", alias="DEMO_PASSWORD")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached so env parsing/validation happens once per process, not per request."""
    return Settings()  # type: ignore[call-arg]  # values come from the environment/.env file
