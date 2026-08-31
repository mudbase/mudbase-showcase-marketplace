# Build Plan - Mudbase Showcase: Marketplace (Python port)

Server-rendered FastAPI + Jinja2 reimplementation of `../web` (the Next.js reference
implementation). Same Mudbase project, same collections, same RBAC matrix, same messaging
visibility rule. Architecture mirrors the sibling `mudbase-showcase-kanban/python` and
`mudbase-showcase-social/python` ports exactly (same module layout, same session/refresh
strategy, same `MudbaseApiError`/`call_with_reauth` pattern).

## Stack

- FastAPI + Jinja2 (server-rendered, no client-side JS framework)
- Real Mudbase Python SDK (`mudbase-sdk`, git+https, same version as the sibling ports)
- Starlette `SessionMiddleware` (signed, httpOnly cookie) holds the Mudbase JWT server-side -
  never sent to browser JS, unlike the reference SPA which necessarily holds its token in
  `localStorage` for direct browser-to-Mudbase calls
- mypy `--strict` clean

## Mudbase project (already provisioned - do not recreate)

- Base URL: `https://cloud.mudbase.dev`
- Project ID: `6a6d3faad07caabbbdfc56a6`
- `listings` (`6a6d3fced07caabbbdfc586b`), `proposals` (`6a6d3fcfd07caabbbdfc5896`),
  `messages` (`6a6d3fd0d07caabbbdfc58c5`) - see `../web/plan/build-plan.md` for the full field
  schema, RBAC matrix, and known platform issues (both already fixed/documented there).

## Auth model

Same as `../web` and the sibling `mudbase-showcase-social/python` port:

- Anonymous guest session (`POST /api/auth/anonymous`) established on first request so public
  listing browsing works without signup (`app.session.ensure_anonymous_session`).
- Real sign-in is `POST /api/auth/local/login` (shared demo accounts, or any real account created
  via `POST /api/auth/local/signup/client` or `/signup/freelancer` - both are self-signup roles
  here, unlike the ecommerce showcase's hidden-role customer-only signup).
- `app.session.require_login` is this app's write-gate: returns `None` (redirect to `/login`)
  unless the session holds a real, role-carrying account - distinct from the always-present
  anonymous session.
- Refresh-token handling ported verbatim from the sibling ports: `call_with_reauth` retries a
  Mudbase call exactly once after a transparent refresh on a 401; `get_valid_access_token`
  proactively refreshes within a 60s expiry margin.

## RBAC

Server-side mirror of `../web/plan/build-plan.md`'s RBAC matrix, in `app/rbac.py`. Document-level
scoping ("own listing", "own proposal", messaging visibility) is enforced by this app's queries
and routers - Mudbase's collection permissions are collection-level, not automatically
document-level scoped (same known limitation documented in the reference web app and every
sibling Python port).

**Messaging visibility**: a listing's message thread is visible to the listing's client and the
specific freelancer whose proposal on that listing has been accepted - one boolean check
(`app.rbac.can_message`), not a dynamic applicant-list membership check. Enforced by
`routers/listings.py`'s `listing_detail` (thread render) and `routers/messages.py`'s `send_message`
(write gate).

## Page map

| Route | Access | Purpose |
|---|---|---|
| `GET /` | public (anon session) | Browse listings - search, category filter, budget range, pagination |
| `GET /login`, `POST /login` | public | Sign in (shared demo accounts or any real account) + quick demo sign-in buttons |
| `GET /register`, `POST /register` | public | Real signup with a role selector (client / freelancer) |
| `GET /listings/{id}` | public read; role-gated actions | Full listing detail, proposal form (freelancer), proposals list + accept/reject (owning client), message thread (client + accepted freelancer) |
| `GET /listings/new`, `POST /listings` | client only | Post a new listing |
| `GET /listings/{id}/edit`, `POST /listings/{id}/edit` | client, owner only | Edit title/description/budget/category/status |
| `GET /listings/mine` | client only | This client's own listings with live proposal counts |
| `POST /listings/{id}/proposals` | freelancer only | Submit a proposal |
| `POST /proposals/{id}/accept`, `POST /proposals/{id}/reject` | client, owner of the listing only | Review a proposal |
| `GET /proposals` | freelancer only | This freelancer's own proposals across all listings, with status |
| `POST /listings/{id}/messages` | client + accepted freelancer only | Send a message on a listing's thread |

No realtime channel or polling here (unlike the reference SPA's TanStack Query `refetchInterval`
on the message thread) - matching the sibling ports' own precedent: this is plain
request/response HTML, a page reload is how a visitor sees another user's change.

## Search

`GET /` uses the dedicated `GET /api/search/projects/:projectId/search?q=...&collections=listings`
endpoint when a keyword is present (never `$regex`/`$text` - both are hard-blocked on the
collection-data `filter` param's dangerous-operator blocklist, confirmed live and documented in
`../web/plan/build-plan.md`). Category/budget filters are applied client-side (server-side, in
this app's case) over the search result batch, matching the reference web app's own precedent -
the search endpoint doesn't accept structured filters alongside `q`.

## SDK-vs-REST gaps discovered building this port

Two more instances of the same class of issue already documented in the sibling ports (the
generated Python SDK's typed models sometimes don't match, or don't fully expose, what the raw
REST contract the reference web app already verified live actually returns):

1. **`SearchApi.search_data()`'s typed response model is unusable for this app.**
   `SearchResultItem` (the per-match model) only declares `_id`/`score` - it discards every real
   document field (title, description, budget, clientName, ...), and the typed envelope shape
   (`{success, data: {results: [...]}}`) doesn't match the flatter
   `{results: [{collection, results, pagination}], query, totalResults, executionTime}` shape
   `../web/src/lib/mudbase.ts`'s `search()` documents and was verified live against. Fixed the
   same way the sibling ports fixed the analogous `login_sync`/`customRole` gap:
   `mudbase_client.search_sync()` bypasses the typed wrapper and calls the SDK's own public
   `param_serialize`/`call_api` primitives directly, parsing the raw JSON body.
2. **`DataApi.list_data()` has no `fields` (projection) parameter at all** in this SDK version,
   unlike the reference web app's direct REST `getDocuments()` which accepts one. Rather than add
   a second raw-REST bypass for a bandwidth optimization, callers that only needed one field
   (category sampling for the filter dropdown, proposal-count batching, accepted-freelancer
   lookup) were rewritten to fetch full documents and read the one field they need off the parsed
   model - functionally equivalent, just slightly more data transferred per call.

## Known limitations

- Document-level RBAC (see above) is enforced application-side, not by the platform. Do not treat
  this reference app's access control as production-grade multi-tenant isolation.
- No portfolio/file upload - out of scope for this pass, matching the reference web app.
