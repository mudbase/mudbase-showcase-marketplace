"""Thin synchronous wrapper around the real `mudbase_sdk` (urllib3-based, no
asyncio variant is published), plus small `asyncio.to_thread` adapters so
FastAPI's async handlers never block the event loop on a blocking HTTP call.

Ported from the sibling `mudbase-showcase-social`/`mudbase-showcase-ecommerce`
Python ports (same SDK version, same platform quirks) — see those projects'
`app/mudbase_client.py` docstrings for the full history of why two of the
functions below bypass their generated typed wrapper methods in favor of the
SDK's own public low-level building blocks (`ApiClient.param_serialize` +
`ApiClient.call_api`), which every generated method uses internally:

- `login_sync`: the generated response's nested user model
  (`LoginLocalUser200ResponseUser`) has no `customRole` field, even though
  the real Multi-Role feature returns one. This app needs `customRole` on
  every login (it's how client/freelancer is told apart), so the raw
  response is parsed directly instead of trusting the incomplete typed
  model.
- `search_sync`: the generated `SearchApi.search_data()` method's typed
  response model (`SearchResult.item` -> `SearchResultItem`) only declares
  `_id`/`score` on each matched item — it discards every actual document
  field (title, description, budget, clientName, ...), which is the entire
  point of a search result for this app's listings feed. The generated
  model's top-level shape (`{success, data: {results: [...]}}`) also
  doesn't match the flatter `{results: [{collection, results, pagination}],
  query, totalResults, executionTime}` shape the reference web app's own
  `MudbaseClient.search()` documents and was verified live against
  (../web/src/lib/mudbase.ts, ../web/plan/build-plan.md point 2). That raw
  REST contract is what's actually verified working, so `search_sync`
  bypasses the typed wrapper and parses the raw JSON body directly, exactly
  like `login_sync` above.

`register_with_role_sync` uses the typed `MultiRoleFeatureApi.register_with_role`
method directly — this SDK version's `RegisterWithRoleRequest` has a required
`agreed_to_terms` field and the operation returns a fully-typed
`RegisterWithRole201Response` with `token`/`refreshToken`/`user` (including
`customRole`), so no raw-JSON workaround is needed there. Both `client` and
`freelancer` are self-signup roles in this app (see ../web/plan/build-plan.md
"Auth flow") — `role` is a plain parameter, not hardcoded, so one function
serves both.
"""

import json
from typing import Any

import mudbase_sdk
from mudbase_sdk.rest import ApiException  # type: ignore[attr-defined]  # matches the SDK's own generated doc examples

from app.config import get_settings


class MudbaseApiError(Exception):
    """Raised for any non-2xx Mudbase response, typed or raw."""

    def __init__(self, message: str, status_code: int, code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.code = code


def _build_api_client(access_token: str | None = None) -> mudbase_sdk.ApiClient:
    settings = get_settings()
    configuration = mudbase_sdk.Configuration(host=settings.mudbase_url)
    if access_token:
        configuration.access_token = access_token
    return mudbase_sdk.ApiClient(configuration)


def _raw_json_call(
    api_client: mudbase_sdk.ApiClient,
    method: str,
    resource_path: str,
    path_params: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
    query_params: list[tuple[str, str]] | None = None,
) -> dict[str, Any]:
    """Issues a request via the SDK's own public serialize/call primitives and
    parses the JSON body ourselves. See module docstring for why.

    `auth_settings=[]` below means the generated `param_serialize` attaches
    no Authorization header on its own - that mechanism only fires for a
    named security scheme (e.g. `search_data`'s generated method passes
    `auth_settings=['OrgBearerAuth', 'ProjectBearerAuth']`), and reproducing
    that per-endpoint scheme name here would just be another thing to keep in
    sync with the SDK's generated code. Attaching the bearer token directly
    from the configured `access_token` sidesteps that entirely and works
    identically for every endpoint this function is used for, authenticated
    or not (no token configured -> no header, exactly like an unauthenticated
    call needs). Confirmed live: omitting this produced a silent
    "Authentication required" 401 from `search_sync` even with a valid
    `access_token` configured, since nothing had ever put it on the wire.
    """
    header_params: dict[str, str] = {"Content-Type": "application/json", "Accept": "application/json"}
    if api_client.configuration.access_token:
        header_params["Authorization"] = f"Bearer {api_client.configuration.access_token}"

    serialized = api_client.param_serialize(
        method=method,
        resource_path=resource_path,
        path_params=path_params or {},
        query_params=query_params or [],
        header_params=header_params,
        body=body,
        post_params=[],
        files={},
        auth_settings=[],
        collection_formats={},
    )
    response = api_client.call_api(*serialized)
    response.read()  # type: ignore[no-untyped-call]  # mudbase_sdk.rest.RESTResponse.read() ships without a type stub
    raw_text = response.data.decode("utf-8") if response.data else ""
    parsed: dict[str, Any] = json.loads(raw_text) if raw_text else {}

    if not (200 <= response.status < 300):
        message = parsed.get("error") or parsed.get("message") or f"Request failed ({response.status})"
        raise MudbaseApiError(message, response.status, parsed.get("code"))

    return parsed


def _wrap_api_exception(exc: ApiException) -> MudbaseApiError:
    body: dict[str, Any] = {}
    if exc.body:
        try:
            body = json.loads(exc.body)
        except (ValueError, TypeError):
            body = {}
    message = body.get("error") or body.get("message") or exc.reason or "Mudbase request failed"
    return MudbaseApiError(message, exc.status or 500, body.get("code"))


# ─── Auth ───────────────────────────────────────────────────────────────────


def register_with_role_sync(
    role: str,
    email: str,
    password: str,
    first_name: str,
    last_name: str,
    agreed_to_terms: bool,
) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client() as client:
        api = mudbase_sdk.MultiRoleFeatureApi(client)
        try:
            response = api.register_with_role(
                role,
                mudbase_sdk.RegisterWithRoleRequest(
                    email=email,
                    password=password,
                    firstName=first_name,
                    lastName=last_name,
                    projectId=settings.mudbase_project_id,
                    agreedToTerms=agreed_to_terms,
                ),
            )
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.to_dict()


def login_sync(email: str, password: str) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client() as client:
        return _raw_json_call(
            client,
            "POST",
            "/api/auth/local/login",
            body={"email": email, "password": password, "projectId": settings.mudbase_project_id},
        )


def create_anonymous_session_sync() -> dict[str, Any]:
    """Guest browsing session (POST /api/auth/anonymous) — its JWT satisfies
    the `listings`/`proposals`/`messages` collections' public read rule for a
    visitor who hasn't registered yet. `CreateAnonymousSession200Response` is
    a complete typed model for what we need (token/refreshToken/expiresIn; no
    customRole to lose since a guest never has one), so the generated typed
    method is used directly here."""
    settings = get_settings()
    with _build_api_client() as client:
        auth_api = mudbase_sdk.AuthenticationApi(client)
        try:
            response = auth_api.create_anonymous_session(
                create_anonymous_session_request=mudbase_sdk.CreateAnonymousSessionRequest(
                    projectId=settings.mudbase_project_id
                )
            )
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.to_dict()


def refresh_sync(refresh_token: str) -> dict[str, Any]:
    with _build_api_client() as client:
        return _raw_json_call(
            client,
            "POST",
            "/api/auth/refresh",
            body={"refreshToken": refresh_token},
        )


def logout_sync(access_token: str) -> None:
    with _build_api_client(access_token) as client:
        auth_api = mudbase_sdk.AuthenticationApi(client)
        try:
            auth_api.logout_local_user()
        except ApiException:
            # Best-effort: the caller always clears the local session cookie
            # regardless, so a dead/expired token on logout is not fatal.
            return


# ─── Collections (listings / proposals / messages) ─────────────────────────


def list_data_sync(
    collection_id: str,
    *,
    filter_dict: dict[str, Any] | None = None,
    sort: str | None = None,
    page: int = 1,
    limit: int = 20,
    access_token: str | None = None,
) -> dict[str, Any]:
    """Note: unlike the reference web app's direct REST `getDocuments()`
    (../../web/src/lib/mudbase.ts), this SDK version's generated
    `DataApi.list_data` has no `fields` (projection) parameter at all - one
    more generated-client-vs-REST-contract gap in the same family as the
    `login_sync`/`search_sync` bypasses documented in this module's
    docstring. Rather than bypass the typed wrapper for a bandwidth
    optimization, callers that only need one field (category sampling,
    proposal-count batching, accepted-freelancer lookup) just fetch full
    documents and read the field they need off the parsed model."""
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        filter_str = json.dumps(filter_dict) if filter_dict else None
        try:
            response = api.list_data(
                settings.mudbase_project_id,
                collection_id,
                page=page,
                limit=limit,
                sort=sort,
                filter=filter_str,
            )
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        items = [item.to_dict() for item in (response.data or [])]
        pagination = response.pagination.to_dict() if response.pagination else None
        return {"data": items, "pagination": pagination}


def get_data_sync(collection_id: str, document_id: str, *, access_token: str | None = None) -> dict[str, Any] | None:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.get_data(settings.mudbase_project_id, collection_id, document_id)
        except ApiException as exc:
            if exc.status == 404:
                return None
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def create_data_sync(collection_id: str, body: dict[str, Any], *, access_token: str) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.create_data(settings.mudbase_project_id, collection_id, body)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def update_data_sync(
    collection_id: str,
    document_id: str,
    body: dict[str, Any],
    *,
    access_token: str,
) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.update_data(settings.mudbase_project_id, collection_id, document_id, body)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def delete_data_sync(collection_id: str, document_id: str, *, access_token: str) -> None:
    """Kept for generic collection-CRUD parity with `create_data_sync`/
    `update_data_sync`/`get_data_sync`/`list_data_sync` above, mirroring
    ../../web/src/lib/mudbase.ts::deleteDocument() - the reference web app
    defines the same method on its client but never calls it from any page
    either (this feature set has no delete UI for listings/proposals/
    messages, only post/edit; see plan/build-plan.md)."""
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            api.delete_data(settings.mudbase_project_id, collection_id, document_id)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc


# ─── Search ─────────────────────────────────────────────────────────────────


def search_sync(
    q: str,
    *,
    collections: str,
    limit: int = 50,
    page: int = 1,
    access_token: str,
) -> dict[str, Any]:
    """Server-side keyword search across a collection's string fields
    (title/description/name/content/email). This is the real substring-search
    surface for this app — the collection-data `filter` param cannot do it:
    `$regex` (and `$text`'s `$search`) are on the deployed query sanitizer's
    dangerous-operator blocklist and always 400 regardless of anchoring or
    escaping (confirmed live, see ../web/plan/build-plan.md point 2). This
    endpoint builds its own regex server-side (not from raw client input
    passed through the sanitizer), so it isn't subject to that block.

    `collections` is the collection's slug (e.g. "listings"), not its _id —
    see app.config.Settings.listings_collection_slug. Bypasses the generated
    typed `SearchApi` wrapper; see module docstring for why."""
    settings = get_settings()
    with _build_api_client(access_token) as client:
        query_params = [
            ("q", q),
            ("collections", collections),
            ("limit", str(limit)),
            ("page", str(page)),
        ]
        return _raw_json_call(
            client,
            "GET",
            f"/api/search/projects/{settings.mudbase_project_id}/search",
            query_params=query_params,
        )
