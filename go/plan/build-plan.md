# Build Plan - Mudbase Showcase: Marketplace (Go)

A server-rendered Go port of `../web` (the reference Next.js implementation), mirroring the
architecture already established by the sibling `mudbase-showcase-kanban/go` and
`mudbase-showcase-social/go` ports exactly: `net/http` + `chi/v5` routing, `html/template`
server-rendered pages, a `gorilla/sessions` encrypted cookie holding the Mudbase JWT (there is no
client-side JS framework, so the cookie is the only place a token can live), and the same
`internal/mbase` package shape (`Client`, generic `List`/`Get`/`Create`/`Update`/`Delete`, a
`TokenRefresher`-carrying context wired through `internal/server/middleware.go`). This app follows
social's auth model (anonymous/guest browsing session, not kanban's every-role-must-sign-in
model), since the reference web app's public listings feed is meant to be readable without
signup. See `../web/plan/build-plan.md` for the canonical data model, RBAC matrix, and
platform-issue notes (the `status`-field guard fix, the `$regex` block) - restated only briefly
below.

## Mudbase project (already provisioned - do not recreate)

- Base URL: `https://cloud.mudbase.dev`
- Project ID: `6a6d3faad07caabbbdfc56a6`
- `listings` (`6a6d3fced07caabbbdfc586b`), `proposals` (`6a6d3fcfd07caabbbdfc5896`),
  `messages` (`6a6d3fd0d07caabbbdfc58c5`) - same field shapes as `../web/plan/build-plan.md`.

## Auth model

- `sessionMiddleware` (`internal/server/middleware.go`) establishes a Mudbase anonymous session
  (`POST /api/auth/anonymous`) on any request with no access token yet, so the public listings
  feed resolves without forcing sign-in - every collection read on this backend requires *some*
  authentication.
- Real sign-in is `POST /api/auth/local/login`; real sign-up is
  `POST /api/auth/local/signup/{client|freelancer}` (`internal/mbase/auth.go`'s `Register`), using
  the vendored SDK's typed `RegisterWithRole` method directly - unlike the sibling ecommerce Go
  port, this SDK build's `RegisterWithRoleRequest` model already declares `agreedToTerms`, so no
  raw-HTTP workaround was needed for the request; the response is still re-decoded from the raw
  body the same uniform way every other auth call in this package is, since `LoginLocalUser`'s and
  `CreateAnonymousSession`'s response models still omit `customRole`/`isAnonymous` (see the "Known
  SDK gap" doc comment on `auth.go`'s `AuthUser`).
- `session.Data.IsSignedIn()` is true only for a real, non-anonymous session with a `customRole` -
  gates every write route via `requireSignedIn`; `requireClient`/`requireFreelancer` additionally
  gate role-specific routes (post listing, submit proposal).
- 401 → refresh → retry is wired through every collection call via request context
  (`internal/mbase/refresh.go`'s `callWithRefresh`), exactly like kanban/social.

## Search - the real reason this port needed a new `internal/mbase` file

Neither kanban nor social needed full-text search. This app's browse/search feature does, and two
things had to be worked around:

1. **`$regex`/`$text` are hard-blocked** in the collection-data `filter` param's query sanitizer
   (dangerous-operator blocklist), confirmed live and documented in `../web/plan/build-plan.md`.
   The real mechanism is `GET /api/search/projects/:id/search`.
2. **The vendored SDK's generated `SearchAPI` response models are lossy in a way distinct from the
   already-documented auth-response gap**: `SearchResultItem` (the innermost matched-document type)
   declares only `_id` and `score` - every actual document field (title, description, budget, ...)
   is silently dropped by the generated model, and it has no `AdditionalProperties` map to fall
   back on either (unlike `DataListResponseDataInner`, which kanban/social's `mbase.List` already
   relies on merging). Worse, the generated model's nesting
   (`SearchResponse → SearchResponseData → []SearchResult{collection, item, highlight}`) doesn't
   even match the wire shape the reference web app's own `MudbaseClient.search()` was built and
   verified against live: a flat
   `{ results: [{ collection: {id,name,slug}, results: T[], pagination }], query, totalResults,
   executionTime }`, one entry per requested collection, each carrying the *full* matched documents
   in its own `results` array. `internal/mbase/search.go`'s `Search[T]` follows this package's
   established pattern for this class of gap (see `auth.go`'s `decodeAuthBody` workaround): it
   still executes through the real generated `SearchAPI.SearchData` method for request
   construction, query-param encoding, and auth/error handling, then re-decodes the *raw* response
   body against the shape confirmed by the reference web app instead of trusting the incomplete
   generated model.

Category/budget filters are applied client-side (in Go, over the returned batch) when a keyword is
present, matching the reference web app's `src/app/page.tsx` - the search endpoint doesn't accept
structured filters alongside `q`.

## Messaging visibility - enforcement

Chosen design (matches the reference web app, `../web/plan/build-plan.md` "Messaging visibility"):
a listing's message thread is visible to the listing's client and the specific freelancer whose
proposal on that listing has been accepted - never any other applicant.

`internal/server/handlers_listings.go`'s `canMessageListing` is the single, shared implementation
of this rule, called both by the listing detail page/fragment (read) and by
`handlers_messages.go`'s `handleMessageCreate` (write), so the two can never drift apart. It is
derived entirely from server-fetched documents on every call - the listing's own `clientId`, and a
fresh query for the accepted proposal's `freelancerId` - never from anything the request itself
claims (no `role` or `listingId` trusted from a hidden field).

## IDOR discipline (critical - same class of bug found and fixed in the sibling C# Events port)

The C# Events port had a real, live bug: a booking-cancellation handler trusted hidden-form fields
(`eventId`/`capacity`) for which record to mutate and what its capacity was, without verifying the
requester owned it. This app never does that. Every handler that mutates a *specific* document
re-fetches that document by its URL `{id}` and verifies the ownership field on the **fetched**
record - never a posted field, never the session's role alone:

- `handleListingEditShow`/`handleListingEditSubmit` (`handlers_listings.go`): fetch the listing by
  its URL id, check `listing.IsOwnedBy(currentUserID)` (`models.Listing.ClientID == userID`).
  Neither route is gated by `requireClient` - only `requireSignedIn` - precisely so the ownership
  comparison itself is what rejects a wrong-role *or* right-role-wrong-owner request; there is no
  short-circuiting role check upstream of it that a cross-role live test could fail to exercise.
- `resolveOwnedProposal` (`handlers_proposals.go`), used by both `handleProposalAccept` and
  `handleProposalReject`: fetches the proposal by its URL id, then fetches *that proposal's own*
  `listingId` (never a posted `listingId`), then checks the listing's `clientId` against the
  current session user. Same "not gated by role upstream" property as the listing edit handlers.
- `handleMessageCreate` (`handlers_messages.go`): re-derives client-ownership or accepted-freelancer
  status via `canMessageListing`, described above - never from a posted field.

## Page map

| Route | Access | Purpose |
|---|---|---|
| `GET /` | public (anon session) | Browse listings - search, category filter, budget range, pagination |
| `GET /login`, `POST /login` | public | Sign in (demo accounts or any real account) |
| `GET /register`, `POST /register` | public | Real signup, choose role (client / freelancer) |
| `POST /logout` | any | Sign out; feed re-establishes an anonymous session next request |
| `GET /listings/{id}`, `GET /listings/{id}/fragment` | public read; role-gated actions | Full listing detail (poll-refreshed proposals panel + message thread), proposal form (freelancer), proposals list + accept/reject (owning client), message thread (client + accepted freelancer) |
| `GET /listings/new`, `POST /listings/new` | client only | Post a new listing |
| `GET /listings/{id}/edit`, `POST /listings/{id}/edit` | signed-in; owner re-derived | Edit title/description/budget/category/status |
| `GET /listings/mine` | client only | This client's own listings with live proposal counts |
| `POST /listings/{id}/proposals` | freelancer only | Submit a proposal, one per listing |
| `POST /proposals/{id}/accept`, `POST /proposals/{id}/reject` | signed-in; listing owner re-derived | Decide a pending proposal |
| `GET /proposals/mine` | freelancer only | This freelancer's own proposals across all listings, with status |
| `POST /listings/{id}/messages` | signed-in; visibility re-derived | Send a message on a listing's thread |

## Realtime

No official Mudbase Go realtime (Socket.IO) client exists - same gap kanban/social document. The
listing detail page polls `GET /listings/{id}/fragment` every 4s via a small inline script,
replacing the proposals-panel + message-thread `<div>` only; the proposal-submission and
message-composer forms live outside that polled div so an in-progress typed cover letter or
message is never wiped mid-keystroke by a poll tick.

## A real platform quirk found while building this port: access-token lifetime

The wire response's `expiresIn` field on every auth call reports `86400` (24h), but the JWT's own
`exp` claim is actually `iat + 1800` (30 minutes) - confirmed by decoding a real issued token
during this build's live smoke test (`iat: 03:21:39 UTC`, `exp: 03:51:39 UTC`). Callers relying on
the wire `expiresIn` field to decide when to refresh proactively would be wrong by a factor of 48x;
this app never does that - every collection call's 401 is what triggers a refresh
(`internal/mbase/refresh.go`'s `callWithRefresh`), never a client-side timer, so this quirk is
harmless here. Documented for whichever future port next assumes the wire `expiresIn` is accurate.

## Known limitations

- No portfolio file upload, matching the reference app's own deprioritization.
- Document-level RBAC is enforced by this app's own handlers (see "IDOR discipline" above), not by
  Mudbase's collection permissions, which are collection-level only - same documented limitation
  as every sibling port and the reference web app itself.
- Polling instead of a push realtime subscription (see "Realtime" above).

## Live smoke test results (2026-08-01)

Verified against the live project (`cloud.mudbase.dev`, project `6a6d3faad07caabbbdfc56a6`) using
the two provisioned demo accounts (`market.client.demo@gmail.com`,
`market.freelancer.demo@gmail.com`, password `DemoTest123!`). The auth endpoints' rate limit
(shared across every concurrently-running sibling port hitting the same demo project this
session) was exhausted repeatedly during this build from the Mac's own egress IP; a direct raw
`curl` test proved the block was **not** IP-scoped (it also 429'd from `mudhaxk-vps`'s distinct
IP), so this app was ultimately verified by waiting out the shared window (bounded synchronous
sleep+retry against the raw login endpoint, never a background timer) and then running the app
itself from `mudhaxk-vps` for the actual test traffic, to keep the Mac's own request history out of
the shared bucket for the remainder of the run.

**Full round trip (real HTTP requests against the running app):**
1. Client signs in, posts a listing (`Build a marketing landing page`, budget 1500, category
   "Web Development") → real listing id `6a6d766ebab2e657381990eb`.
2. Freelancer signs in with an independent session, searches `?q=landing` via the dedicated search
   endpoint - the listing is correctly returned among the results.
3. Freelancer submits a proposal (cover letter + rate 1200) → real proposal id
   `6a6d7678bab2e657381991c7`.
4. Client reloads the listing detail page, sees the proposal under "Proposals received", and
   accepts it - status badge flips from "Pending" to "Accepted".
5. Client sends a message on the thread; freelancer's independent session sees it and replies;
   client's session sees the reply. Full bidirectional messaging confirmed, including via the
   poll-refresh fragment endpoint (`GET /listings/{id}/fragment`).

**IDOR verification (the critical check this task called for):**
- The freelancer's real, independently-authenticated session issued: a raw `POST
  /proposals/{id}/accept` against the client's proposal from step 3, a raw `GET
  /listings/{id}/edit`, and a raw `POST /listings/{id}/edit` (hijack payload: title
  "HIJACKED TITLE", status "completed", budget 1) against the client's listing from step 1 - all
  three were rejected server-side with a permission-denied flash redirect, and the listing's
  title/status were confirmed unchanged by re-fetching the page afterward (still "Build a
  marketing landing page", still "Open"; the proposal remained "Accepted", not reset or altered).
  Neither the listing-edit routes nor the proposal-accept/reject routes are gated by a role
  middleware upstream of the ownership check (only `requireSignedIn` is), so this live cross-role
  test genuinely exercises the real `models.Listing.IsOwnedBy` comparison - there is no
  short-circuiting role gate that could hide a same-role-different-owner bug from a cross-role-only
  test the way there would be if edits were also gated to `requireClient` before the ownership
  check ran.
- **Role-gate verification** (distinct from ownership): the freelancer's session posting to
  `/listings/new` was rejected by `requireClient` ("Only client accounts can do that.") before any
  Mudbase call; the client's session posting to `/listings/{id}/proposals` was rejected by
  `requireFreelancer` ("Only freelancer accounts can do that.") the same way.
- **Messaging-visibility verification**: the client posted a *second*, fresh listing with no
  proposals and no accepted freelancer at all; the freelancer's session (real proposal-submitting
  freelancer on the *other* listing, but not accepted anywhere on this one) attempting `POST
  /listings/{second-id}/messages` was rejected ("You don't have access to this listing's
  messages.") - confirming `canMessageListing` re-derives eligibility per-listing from fresh data,
  not from any prior success elsewhere in the same session.

All three of the above ran against `mudhaxk-vps` (see above); the app itself was left unmodified
by these tests beyond the intended data - no listing or proposal state was corrupted by any of the
rejected attempts.
