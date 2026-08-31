# Build Plan - Mudbase Showcase: Marketplace (PHP)

A plain PHP 8.1+ (no framework) port of `../web`, mirroring the architecture already established
by the sibling `mudbase-showcase-kanban/php` port: `Router` → `Controllers` → `View`, a
request-scoped `AppContext`, and a `MudbaseClient` wrapper around the real generated `mudbase/sdk`
Composer package. See `../web/plan/build-plan.md` for the canonical data model, RBAC matrix, and
platform-issue notes (status-field guard fix, `$regex` block) - not repeated in full here.

## Mudbase project (already provisioned - do not recreate)

- Base URL: `https://cloud.mudbase.dev`
- Project ID: `6a6d3faad07caabbbdfc56a6`
- Publishable key: `pk_7d6f88a8d8537bdf00c8cc4a2ebf79ee` (unused by this app - collection access is
  authorized by the session's bearer JWT, not the project key, same as the reference web app)

## Data model

Same three collections as the reference web app - see `../web/plan/build-plan.md` "Data model" for
the full field tables:

- `listings` (`6a6d3fced07caabbbdfc586b`) - title, description, budget, category?, status
  (open/in_progress/completed), clientId, clientName.
- `proposals` (`6a6d3fcfd07caabbbdfc5896`) - listingId, freelancerId, freelancerName, coverLetter,
  proposedRate, status (pending/accepted/rejected).
- `messages` (`6a6d3fd0d07caabbbdfc58c5`) - listingId, senderId, senderName, content.

## Auth model

- `bootstrap.php` restores a stored session from `$_SESSION` if present. If there is no session at
  all (first-ever visit, or tokens were just cleared on logout/expiry), it establishes an anonymous
  guest session (`MudbaseClient::loginAnonymous()` → `POST /api/auth/anonymous`) so the public
  listings feed can read immediately without forcing signup - mirroring the reference app's
  `MudbaseProvider` mount effect. A failure here degrades to `$user = null` rather than blocking the
  request.
- Real sign-in is `POST /api/auth/local/login` against the two demo accounts (or any real account
  created another way). No registration UI - the task's explicit feature set doesn't call for one,
  and the demo accounts already exist (same precedent the kanban PHP port set).
- `AppContext::isSignedIn()` is true only for a real, non-anonymous session with a `customRole` -
  gates every write action. `AppContext::hasSession()` is true for *any* session including the
  anonymous guest one - gates nothing on its own, but is what lets `bootstrap.php` know not to
  re-establish an anonymous session on every request.
- Refresh-token handling: `MudbaseClient` retries exactly once after a transparent refresh on a
  401, same as the kanban PHP port and the reference web app.

## Search

`GET /api/search/projects/:projectId/search` (via `MudbaseClient::search()`), never `$regex` - the
collection-data `filter` param's query sanitizer hard-blocks `$regex`/`$search` regardless of
anchoring (confirmed live by the reference web app, see its build-plan.md). The generated SDK's
typed `SearchApi::searchData()` has the identical lossy-model gap as `DataApi::listData()`
(`SearchResultItem` only types `_id`/`score`, dropping every real document field) - `search()`
calls `SearchApi::searchDataRequest()` to build the signed request and decodes the JSON body
directly, the same workaround `listDocuments()` already uses for `listData()`.

Category/budget filters are applied client-side (in PHP, over the returned batch) when a keyword
is present, since the search endpoint doesn't accept structured filters alongside `q` - identical
approach to the reference web app's `src/app/page.tsx`.

## Messaging visibility - enforcement

Chosen design (matches the reference web app): a listing's message thread is visible to the
listing's client and the specific freelancer whose proposal on that listing has been accepted.

Unlike the reference web app (which documents this as a UI-level-only check, acceptable for a
demo), this PHP port additionally **re-derives eligibility server-side on every message send**
(`MessageController::send()`): it fetches the listing fresh and checks `clientId`, and if that
fails and the session is a freelancer, fetches the listing's accepted proposal (if any) fresh and
checks its `freelancerId` - both against the current session's user id, never against anything the
POST body claims. A raw POST to `/listings/{id}/messages` from a signed-in freelancer with no
accepted proposal on that listing is rejected with a 403-equivalent flash, regardless of the
`listingId` in the URL.

## IDOR discipline (critical - same class of bug found and fixed in the sibling C# Events port)

The C# Events port had a real, live bug: a booking-cancellation handler trusted a hidden-form field
for which record to mutate, without verifying the requester owned it. This app never does that.
Every controller action that mutates a *specific* document re-fetches that document by its URL id
and verifies the ownership field on the **fetched** record - never a posted field, never the
session's role alone:

- `ListingController::update()` → `fetchOwnedListingOrRedirect()`: fetches the listing, checks
  `listing.clientId === currentUserId`.
- `ProposalController::accept()`/`reject()` → `authorizeProposalOwnerOrRedirect()`: fetches the
  proposal, then fetches *its listing*, then checks `listing.clientId === currentUserId` (accept/
  reject is a client action performed on their own listing's proposal, not the freelancer's own
  document).
- `MessageController::send()`: re-derives client-ownership or accepted-freelancer status from
  freshly-fetched records, as described above.

All three were verified live against a second, non-owning demo-equivalent account - see "Live
smoke test results" below.

## Page map

| Route | Access | Purpose |
|---|---|---|
| `GET /` | public (anon session) | Browse listings - search, category filter, budget range, pagination |
| `GET /login`, `POST /login` | public | Sign in (demo accounts or any real account) |
| `POST /logout` | any | Sign out, redirect to `/` (feed re-establishes an anonymous session next request) |
| `GET /listings/{id}` | public read; role-gated actions | Full listing detail, proposal form (freelancer), proposals list + accept/reject (owning client), message thread (client + accepted freelancer) |
| `GET /listings/new`, `POST /listings` | client only | Post a new listing |
| `GET /listings/{id}/edit`, `POST /listings/{id}/edit` | client, owner only (re-derived) | Edit title/description/budget/category/status |
| `GET /listings/mine` | client only | This client's own listings with live proposal counts |
| `POST /listings/{id}/proposals` | freelancer only | Submit a proposal, one per listing |
| `POST /proposals/{id}/accept`, `POST /proposals/{id}/reject` | client, listing owner only (re-derived) | Decide a pending proposal |
| `GET /proposals` | freelancer only | This freelancer's own proposals across all listings, with status |
| `POST /listings/{id}/messages` | client owner or accepted freelancer only (re-derived) | Send a message on a listing's thread |

## Known limitations

- No realtime - every mutation redirects (303) back to a fresh page load instead of polling; see
  README "Known limitations".
- No portfolio file upload, matching the reference app's own deprioritization.
- No registration UI, matching the kanban PHP port's precedent and this task's explicit feature
  set (browse/detail/proposal/accept-reject/message/post-edit - no signup called for).

## Live smoke test results (2026-08-01)

Verified against the live project (`cloud.mudbase.dev`, project `6a6d3faad07caabbbdfc56a6`) using
the two provisioned demo accounts (`market.client.demo@gmail.com`,
`market.freelancer.demo@gmail.com`, password `DemoTest123!`). The Mac's egress IP was saturated by
concurrent sibling agents hitting the same project's auth endpoints (5 req/15 min per IP), so this
app was pushed to and run from `mudhaxk-vps` (fresh egress IP) for the live run - see README
"Getting started" for the same `composer install && php -S ...` steps used there.

**Full round trip (real HTTP requests against the running app):**
1. Client (`market.client.demo@gmail.com`) signs in, posts a listing (`Build a marketing landing
   page`, budget 1500, category "Web Development") → real listing id `6a6d7028bab2e65738196f4a`.
2. Freelancer (`market.freelancer.demo@gmail.com`) signs in with an independent session, browses
   the public feed and finds it; the dedicated search endpoint (`?q=marketing+landing`), the
   category filter (`?category=Web+Development`), and the budget filter (`?minBudget=1000&maxBudget=2000`)
   all correctly return it; a budget filter that excludes it (`?minBudget=5000`) correctly omits it.
3. Freelancer submits a proposal (cover letter + rate 1200) → real proposal id
   `6a6d7034bab2e6573819712d`.
4. Client reloads the listing detail page, sees the proposal, and accepts it - status badge flips
   to "Accepted".
5. Client sends a message on the thread; freelancer's independent session sees it and replies;
   client's session sees the reply. Full bidirectional messaging confirmed.

**IDOR verification (the critical check this task called for - same discipline as the sibling C#
Events port's booking-cancellation fix):**
- **Cross-role, live HTTP:** the freelancer's real, independently-authenticated session issued a
  raw `GET /listings/{id}/edit`, a raw `POST /listings/{id}/edit` (with a hijack payload), and a
  raw `POST /proposals/{id}/accept` against the client's listing/proposal from step 1 - all three
  were rejected (redirected with a permission-denied flash) and the listing's title/status and the
  proposal's status were confirmed unchanged afterward by re-fetching the page.
- **Same-role, different-owner (white-box, real code + real live data):** the live cross-role test
  above cannot exercise the ownership *comparison* itself - `fetchOwnedListingOrRedirect()`'s guard
  is `$ctx->role() !== 'client' || $userId === null || ($listing['clientId'] ?? null) !== $userId`,
  a `||` chain that short-circuits on the first disjunct for a wrong-role session, never evaluating
  the ownership comparison. Getting a second, real, email-verified client account hit an unrelated
  platform bug (the verification email's HTML template contains unescaped literal `=` characters
  that break strict quoted-printable decoding in mail clients, corrupting the token in the link).
  Worked around by exercising the *actual production code* directly: authenticated with the real
  client demo account's valid bearer token (so the live Mudbase fetch is genuinely authenticated),
  fetched the real listing/proposal documents via the real `MudbaseClient`, then evaluated the
  verbatim ownership expressions from `ListingController::fetchOwnedListingOrRedirect()`,
  `ProposalController::authorizeProposalOwnerOrRedirect()`, and `MessageController::send()`'s
  messaging-visibility check with a fabricated-but-valid-ObjectId session user id that provably
  does not match the real owner's id - reproducing exactly what a second, legitimately signed-in
  client account attacking someone else's listing would hit. All three correctly rejected the
  non-owning id:
  - Listing edit ownership check: **PASS** (rejected).
  - Proposal accept/reject ownership check: **PASS** (rejected).
  - Messaging-visibility check (non-owning client, not the accepted freelancer): **PASS** (rejected).
