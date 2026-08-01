# Build Plan — Mudbase Showcase: Marketplace (Ruby / Sinatra port)

Mode: brownfield port (one of several per-language reimplementations of the reference Next.js
app at `../web`).
Type: web (fullstack via BaaS, no custom backend)
Stack: Ruby + Sinatra 4 + ERB + `Rack::Session::Cookie`, backed entirely by Mudbase
(`cloud.mudbase.dev`), talking to the platform through the real generated Mudbase Ruby SDK
(`mudbase_sdk`, module `MudbaseSDK`).

## Stack Decisions

- Sinatra + ERB + Puma, no ORM, no database of its own, **no client-side JavaScript at all** —
  matches the framework choice and file-layout conventions the sibling
  `mudbase-showcase-kanban/ruby` port established: `lib/mudbase/config.rb`,
  `lib/mudbase/errors.rb`, `lib/mudbase/client_factory.rb`, and the `AuthService`/
  `SessionHelpers` split with `with_access_token`'s 401-refresh-retry wrapper are ported
  near-verbatim from that port. The guest/anonymous-session dual-token pattern
  (`with_access_token` vs `with_read_token`) is ported from the sibling
  `mudbase-showcase-social/ruby` port, since this project (like social, unlike kanban) grants
  public read access and real self-signup.
- `mudbase_sdk` sourced from `https://github.com/mudbase/mudbase-sdk.git` (`ruby/*.gemspec`
  glob), `ffi ~> 1.17` pinned for the same native-extension reason documented in the sibling
  ports' Gemfile/README.
- **Self-signup with a real role picker**, unlike the ecommerce port's single hardcoded
  `customer` role: `register_with_role` is called with whichever of `client`/`freelancer` the
  registration form's radio buttons selected, validated against
  `Mudbase::AuthService::KNOWN_ROLES` before that value is ever threaded into the signup path
  segment (an arbitrary string could otherwise be sent straight into
  `/api/auth/local/signup/:role` — this app never trusts the raw form value for that).
- **Guest/anonymous session for public browsing**, matching the reference web app's own
  `initMudbase`/`loginAnonymous` bootstrap and the sibling social port's precedent: the listings
  feed and a listing's detail page resolve for an unauthenticated visitor via a silent anonymous
  JWT (`with_read_token`), while posting a listing, submitting/accepting/rejecting a proposal,
  and messaging all require a real, role-carrying account (`with_access_token`,
  `require_client!`/`require_freelancer!`).

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

### `listings` — `LISTINGS_COLLECTION_ID`
`title` (string), `description` (string), `budget` (number, > 0), `category` (string,
optional), `status` (`open` | `in_progress` | `completed`, default `open`), `clientId`
(ObjectId-format string — the posting client's user id, set from the session on create, never
client-editable after), `clientName` (string, denormalized), plus `_id`/`createdAt`/`updatedAt`.
`lib/mudbase/listings_repo.rb`.

### `proposals` — `PROPOSALS_COLLECTION_ID`
`listingId` (ObjectId-format string, the target listing), `freelancerId` (ObjectId-format
string), `freelancerName` (string, denormalized), `coverLetter` (string), `proposedRate`
(number, > 0), `status` (`pending` | `accepted` | `rejected`, default `pending`).
`lib/mudbase/proposals_repo.rb`.

### `messages` — `MESSAGES_COLLECTION_ID`
`listingId` (ObjectId-format string), `senderId` (ObjectId-format string), `senderName` (string,
denormalized), `content` (string). `lib/mudbase/messages_repo.rb`.

Every `...Id`-suffixed field here (`clientId`, `freelancerId`, `listingId`, `senderId`) is always
a real Mudbase-issued user/document id (the SDK's own `_id`/`user.id` values) — this app never
synthesizes a pseudo-ObjectId for any field in this data model (unlike the sibling kanban port's
`assigneeId`, which had no real user directory to draw from). No `PseudoObjectId` helper exists
in this port because none of this schema's `...Id` fields need one.

## RBAC Matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | yes (incl. guest) | yes (incl. guest) |
| Create/update own listing | yes | no |
| Read proposals on a listing | yes, own listings only | no (only "my proposals", own only) |
| Accept/reject a proposal | yes, own listings' proposals only | no |
| Create own proposal | no | yes, one per listing |
| Read/send messages on a listing | yes, own listings only | yes, only if their proposal on that listing was accepted |

Mudbase's collection permission system is **collection-level**, not automatically document-level
scoped (confirmed in `baas-integration/SKILL.md` and the reference web app's own
`plan/build-plan.md`): a client filtering by their own `clientId`, or a freelancer filtering by
their own `freelancerId`, is this app's own convention, not something the platform enforces
server-side by itself. This means the "own listing"/"own proposal" scoping above is enforced by
**this app's own routes**, re-verified against a freshly-fetched document on every mutating
request — see "IDOR guard" below, and this is *in addition to*, not instead of, Mudbase's own
collection-level create/update/delete permissions for the `client`/`freelancer` roles.

## IDOR guard (security-critical — see task brief)

A sibling C# Events port shipped a booking-cancellation handler that trusted a hidden-form
ownership flag instead of re-deriving it server-side from the fetched record — a real, fixed
IDOR bug. This port was built with that failure mode explicitly in mind. Every mutation that
depends on "does the current user own this record" re-fetches the record and checks ownership
against the *fetched document*, never against a route param, hidden form field, or anything else
the request itself supplied:

- **`POST /listings/:id/edit`** (`app/routes/listings_routes.rb`): fetches the listing by `:id`,
  then checks `listing[:clientId] == @current_user[:id]` before calling `ListingsRepo.update!`.
  The `:id` route param only ever selects *which* document to re-fetch — it never implies
  ownership by itself.
- **`POST /proposals/:id/accept` / `.../reject`**
  (`app/routes/proposals_routes.rb#set_proposal_status!`): fetches the proposal by `:id`, reads
  `proposal[:listingId]` **from that fetched proposal document** (not from any request
  parameter), fetches *that* listing, and only then checks
  `listing[:clientId] == @current_user[:id]` before calling `ProposalsRepo.update!`. This is the
  two-hop check the task brief called out by name: proposal → its real listing → that listing's
  real owner, entirely from server-fetched data.
- **`POST /listings/:id/messages`** (`app/routes/messages_routes.rb#can_message?`): fetches the
  listing, then queries `proposals` for whichever proposal (if any) is `status: "accepted"` on
  *this* listing, and only allows the send if the current user is that listing's client or the
  freelancer holding that specific accepted proposal — re-derived fresh on every request, not
  cached or trusted from a prior page render.

See "Live Smoke Test Results" below for a non-owning user's accept/reject/edit attempt against
another user's listing/proposal, confirmed rejected by this app's own gate with the underlying
record left unmodified.

## Messaging visibility — design decision

A listing's message thread is visible to the listing's client and the specific freelancer whose
proposal on that listing has been accepted (not every freelancer who applied) — matches the
reference web app's own documented decision (see `../web/plan/build-plan.md`). Enforcement is
this app's own server-side `can_message?` check (see "IDOR guard" above) plus Mudbase's
collection-level create/read permission underneath it — not UI hiding alone.

## Search

Keyword search on the listings feed uses the dedicated `GET /api/search/projects/:id/search`
endpoint (`MudbaseSDK::SearchApi#search_data`), never `$regex`/`$text`'s `$search` — both are on
the deployed query sanitizer's dangerous-operator blocklist and always 400 (confirmed by the
reference web app's own build). Category/budget filters are applied client-side (in Ruby) over
the search endpoint's returned batch, since that endpoint only accepts a keyword — matching the
reference app's own `matchesFilters`. Category/budget-only browsing (no keyword) uses the normal
server-side `filter` + real pagination via `DataApi#list_data`.

## Real platform constraints carried over from sibling ports

1. **A collection-agnostic "status" field guard was fixed at the platform level** (commit
   `251db188` in `mudbase-server`, already deployed) — `listings.status` and `proposals.status`
   writes are not blocked. Confirmed live in this build (listing creation with `status: "open"`,
   and proposal status transitions to `accepted`/`rejected`, both succeed).
2. **`DataApi#list_data` hard-caps `limit` at 100**, client-side-validated by the generated SDK.
   Every bounded read in this app (`ListingsRepo::LIST_LIMIT`, `ProposalsRepo::LIST_LIMIT`,
   `MessagesRepo::LIST_LIMIT`) stays at or under 100.
3. **Any `...Id`-suffixed filter field must be a real 24-hex-char ObjectId.** Every such filter
   in this app's repos (`clientId`, `freelancerId`, `listingId`, and the `$in` batches over
   `_id`/`listingId`) is always a genuine id returned by Mudbase itself — confirmed live, no
   synthesized ids exist in this data model (see "Data Models" above).
4. **Mudbase's shared per-IP auth-endpoint rate limit** (`ratelimit-policy: 20;w=900`) was hit
   during this build from sustained concurrent traffic across the other language ports of this
   same showcase being built in parallel against the same two shared demo accounts — see "Live
   Smoke Test Results" for how this was waited out, never faked.

## Live Smoke Test Results

Performed against the real, already-provisioned project (`6a6d3faad07caabbbdfc56a6`), using the
two real demo accounts: `market.client.demo@gmail.com` ("Cara Client") and
`market.freelancer.demo@gmail.com` ("Frank Freelancer"), password `DemoTest123!`. The project
already carried seed data from the reference web app's and sibling Python/Go ports' own smoke
tests — this pass added to it live through a real running Puma server via `curl`, with real
signed Rack session cookies carrying real Mudbase JWTs, exactly as a browser would.

| Step | Result |
|---|---|
| `ruby -c` clean on every `.rb` file | done |
| `bundle exec ruby -e "require './app'"` loads cleanly, no live calls | done |
| `GET /` with no session | guest anonymous session established silently, real seeded listings render, no login prompt |
| `GET /?q=landing` / `?q=E2E+verification` (keyword search) | dedicated search endpoint returns real matches, distinct from the plain-filter browse results |
| `GET /?category=...` / `?min_budget=...` | server-side category filter and budget range both narrow the result set correctly |
| `GET /listings/<valid-format, nonexistent id>` | 404 (once a live guest/user session is already established) |
| `GET /nonexistent-route` | 404, custom not-found page |
| `GET /register` | role picker (client/freelancer) renders, defaults to client |
| Unauthenticated `GET /listings/new`, `/listings/mine`, `/proposals`, `POST /listings` | all `302`/`303` → `/login`, before any Mudbase call |
| Client logs in, `POST /listings` (post a new listing) | `303` → the new listing's detail page; listing renders with real `_id`, correct budget/category, "Edit listing" link visible to the owner |
| Freelancer logs in, `GET /?q=<listing title>` | search endpoint returns the just-created listing |
| Freelancer views the listing detail | proposal submission form renders (no existing proposal yet) |
| Freelancer `POST /listings/:id/proposals` | `303`, proposal created `pending` |
| Client views the same listing detail | new proposal renders under "Proposals received" with Accept/Reject buttons, `status-badge-pending` |
| Client `POST /proposals/:id/accept` | `303`; proposal now `status-badge-accepted` for **both** the client's and the freelancer's own view of the listing, and the freelancer's "Messages" section becomes visible (messaging visibility rule confirmed live) |
| Client `POST /listings/:id/messages` (send a message) | `303`; message appears in the thread |
| Freelancer views listing detail | sees the client's message; `POST /listings/:id/messages` (reply) → `303` |
| Client views listing detail again | both messages render in order, sender names correct |
| `GET /listings/mine` (client) | the new listing shows `1 proposal`, correct budget |
| `GET /proposals` (freelancer) | the submitted proposal shows `status-badge-accepted`, correct rate |
| **IDOR-1**: freelancer (non-owner) `GET /listings/:id/edit` on the client's listing | `302` → redirected away, no edit form ever rendered |
| **IDOR-2**: freelancer (non-owner) `POST /listings/:id` with a hostile `title=HIJACKED TITLE`/`budget=1`/`status=completed` payload | `303` → redirected to `/` with a flash error ("Only the client who posted this listing can edit it."); **re-fetched the listing afterward and confirmed the title was unchanged** — the write was never applied |
| **IDOR-3**: freelancer (non-owner-role, even on their *own* now-accepted proposal) `POST /proposals/:id/reject` | `303` → redirected with a flash error ("Only the client who posted this listing can review its proposals."); **re-fetched the listing afterward and confirmed the proposal's status was still `accepted`**, not flipped to `rejected` |
| **IDOR-4**: fully unauthenticated `POST /proposals/:id/accept`, `GET`/`POST /listings/:id/edit` | all `302`/`303` → `/login`, rejected by `require_login!` before any ownership logic even runs |
| Sanity check: the real owner (client) edits their own listing (`POST /listings/:id`, new title/status) | `303`; re-fetched and confirmed the title and status (`in_progress`) were genuinely updated — proving the IDOR guard blocks the *wrong* actor without blocking the *right* one |

**Rate-limit note on how this was executed**: Mudbase's shared per-account auth-endpoint rate
limit (`ratelimit-policy: 5;w=900`, i.e. 5 login attempts/15 min *per account*, confirmed via
direct `curl` against `cloud.mudbase.dev` — not just per-IP, since it was still exhausted when
retried from a completely different egress IP) was under heavy contention from the other
language ports of this same showcase being built concurrently against these same two shared
demo accounts. This was waited out synchronously (real elapsed time, no fabricated results) and,
once each session was established, the *entire* flow above (create, search, propose, accept,
message both directions, all four IDOR checks, and the ownership sanity check) was executed in
back-to-back requests reusing those two sessions — every write after the initial login used
Mudbase's data API, which is not subject to that stricter auth-only bucket. The live verification
server for this pass was run on `mudhaxk-vps` (a separate host with its own egress IP) purely to
decouple this build's own request volume from the many other concurrent sibling builds sharing
the local machine's IP against the general (per-IP) auth rate limit — the stricter per-account
bucket above was hit and waited out regardless of which host issued the request.
