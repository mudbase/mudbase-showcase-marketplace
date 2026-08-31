# Build Plan - Mudbase Showcase: Marketplace (web)

This is the **reference implementation** for the marketplace showcase - the other 9 ports
(mobile-expo, mobile-flutter, python, go, ruby, java, csharp, php, swift) are built to match this
data model and API contract exactly.

## Stack

- Next.js 15 (App Router), TypeScript strict, no `any`
- Tailwind CSS + shadcn/ui-style components (Radix primitives + `class-variance-authority` + `tailwind-merge`)
- TanStack Query v5 for all server state (listings, proposals, messages)
- `react-hook-form` + `zod` for every form
- Zero custom backend - every read/write goes straight to `cloud.mudbase.dev` from the browser

No Socket.IO / realtime channel is used in this version (unlike the social/ecommerce showcases).
The messages thread and proposal-status updates refresh via TanStack Query polling
(`refetchInterval`) and cache invalidation on mutation - sufficient for the demo's scale and
keeps this reference implementation simpler for the other 9 ports to mirror without needing a
WebSocket client per language.

## Mudbase project (already provisioned - do not recreate)

- Base URL: `https://cloud.mudbase.dev`
- Project ID: `6a6d3faad07caabbbdfc56a6`
- Publishable key: `pk_7d6f88a8d8537bdf00c8cc4a2ebf79ee` (safe client-side; currently unused by any
  request - collection reads/writes are authorized by the user's bearer JWT, not the project key,
  mirroring the pattern already verified live in the social/ecommerce showcases)

## Data model

### `listings` (`6a6d3fced07caabbbdfc586b`)

| Field | Type | Notes |
|---|---|---|
| `title` | string | required |
| `description` | string | required |
| `budget` | number | required, > 0 |
| `category` | string | optional |
| `status` | string | `open` \| `in_progress` \| `completed`, default `open` |
| `clientId` | string | the posting client's user id - set from the session on create, never client-editable after |
| `clientName` | string | denormalized display name, set on create |

### `proposals` (`6a6d3fcfd07caabbbdfc5896`)

| Field | Type | Notes |
|---|---|---|
| `listingId` | string | real 24-hex ObjectId of the target listing |
| `freelancerId` | string | the submitting freelancer's user id |
| `freelancerName` | string | denormalized display name |
| `coverLetter` | string | required |
| `proposedRate` | number | required, > 0 |
| `status` | string | `pending` \| `accepted` \| `rejected`, default `pending` |

### `messages` (`6a6d3fd0d07caabbbdfc58c5`)

| Field | Type | Notes |
|---|---|---|
| `listingId` | string | real 24-hex ObjectId of the listing the thread belongs to |
| `senderId` | string | current user's id |
| `senderName` | string | denormalized display name |
| `content` | string | required |

All three collections also carry Mudbase's standard `_id`, `createdAt`, `updatedAt`.

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update/delete own listing | yes | no |
| Read proposals | yes (on own listings) | yes (own proposals) |
| Update proposal status (accept/reject) | yes (on own listings' proposals) | no |
| Create/update/delete own proposal | no | yes |
| Create + read messages | yes | yes |

Mudbase's collection permission system is **collection-level**, not automatically document-level
scoped (confirmed in `baas-integration/SKILL.md` §4: permission conditions like `$userId` are only
auto-populated on `create`, not enforced as a read/update filter). This means:

- The "own listing" / "own proposal" scoping above is enforced by **this app's queries and UI**
  (always filter by `clientId`/`freelancerId` matching the current session user, and only render
  edit/accept/reject controls when the current user owns the record) - not by the platform
  rejecting a client filter for someone else's data. This is a known limitation acceptable for a
  reference/demo app, and is the same class of limitation already documented in the sibling
  ecommerce/social showcases' `mudbase.ts`.
- Every `...Id` filter sent to Mudbase (`listingId`, `clientId`, `freelancerId`) must be a real
  24-character hex ObjectId - Mudbase's query sanitizer rejects (and security-alerts on) any
  top-level filter field ending in `Id` that isn't. All such values here are the real `_id`/`user.id`
  values returned by Mudbase itself, never invented constants.

## Auth flow

- `MudbaseProvider` establishes a session on mount: if a stored token exists, restore it via
  `GET /api/auth/session`; otherwise log in anonymously (`POST /api/auth/anonymous`) so the public
  listings feed can read without forcing signup (same "authenticated-role read" pattern as the
  ecommerce/social showcases - an anonymous session still carries the platform's baseline
  "authenticated" read permission).
- Real sign-in is `POST /api/auth/local/login` (shared demo accounts, or any real account created
  via `POST /api/auth/local/signup/client` or `/signup/freelancer`).
- `useAuth().isAuthenticated` is true only for a real, non-anonymous session with a `customRole` -
  gates every write action (post listing, submit proposal, send message, accept/reject).
- Refresh-token handling: `MudbaseClient` stores both access + refresh tokens, uses a
  `refreshInFlight` promise to dedupe concurrent refreshes (refresh tokens are single-use/rotating),
  and `request()` retries exactly once after a transparent refresh on a 401. Ported directly from
  `mudbase-showcase-social/web/src/lib/mudbase.ts`.

## Messaging visibility - design decision

Chosen: **a listing's message thread is visible to the listing's client and the specific
freelancer whose proposal on that listing has been accepted** (not every freelancer who applied).
Rationale: this reads as "you're hired, now let's coordinate," is simple to reason about and test
(exactly one freelancer ever has thread access per listing), and keeps the reference contract the
9 other ports need to replicate small - one boolean check (`am I the client, or do I have an
accepted proposal on this listing`) rather than a dynamic applicant-list membership check.

Enforcement is UI-level (message composer + thread view only render for the client or the accepted
freelancer) plus the platform's collection-level create/read permission - see the known-limitation
note above regarding document-level scoping.

## Page map

| Route | Access | Purpose |
|---|---|---|
| `/` | public (anon session) | Browse listings - search, category filter, budget range, pagination |
| `/login` | public | Sign in (shared demo accounts or any real account) |
| `/register` | public | Real signup, choose role (client / freelancer) |
| `/listings/[id]` | public read; role-gated actions | Full listing detail, proposal form (freelancer), proposals list + accept/reject (owning client), message thread (client + accepted freelancer) |
| `/listings/new` | client only | Post a new listing |
| `/listings/[id]/edit` | client, owner only | Edit title/description/budget/category/status |
| `/listings/mine` | client only | This client's own listings with live proposal counts |
| `/proposals` | freelancer only | This freelancer's own proposals across all listings, with status |

## Platform issues discovered during the live smoke test (2026-08-01)

Two real, reproducible constraints of the deployed Mudbase backend (`mudbase-server`, this
project's own platform) surfaced while wiring this app up against the live project. Documented
here so the other 9 ports don't have to rediscover them from scratch.

1. **A collection-agnostic "status" field guard blocked this schema outright, and was fixed.**
   `POST`/`PATCH` on `/api/data/projects/:id/collections/:id/data` ran a blanket
   `enforceServerRoleAssignment(Update)` check treating any field literally named `status`
   (along with `role`, `customRole`, `permissions`, etc.) as a protected role/account field,
   unconditionally, on every project data collection - not just auth-adjacent ones. Since the
   `listings`/`proposals` collections both declare `status` as a required ordinary workflow
   field, this meant no non-admin end user could ever create or update a document in either
   collection: creation was rejected with `403 Cannot set protected role fields` if `status` was
   present, and rejected with `400 Field 'status' is required` if it was omitted - a hard
   deadlock. Root-caused to `middleware/enforceServerRoleAssignment.js` and
   `middleware/fieldProtection.js` in the `mudbase-server` repo, confirmed the platform already
   ships a purpose-built, narrower mechanism for exactly this
   (`Collection.stateMachine` + `middleware/stateMachineValidation.js`, which enforces
   role-gated `from -> to` transitions when configured and is a deliberate no-op otherwise).
   **Fixed at the source** (commit `251db188` in `mudbase-server`, deployed to
   `mudbase-server.fly.dev` / `cloud.mudbase.dev` same day): removed `status` from both
   blanket-blocked field lists. Every genuinely identity/access-controlling field (`role`,
   `customRole`, `permissions`, `hierarchy`, `isAdmin`, `userType`, `vendorId`, `verifiedAt`,
   `verifiedBy`, `isVerified`, `approvalStatus`) is untouched and still fully blocked for
   non-admins. Verified live post-deploy: listing/proposal create and status update both work
   end-to-end now.
2. **`$regex` (and `$text`'s `$search`) are hard-blocked in the collection-data `filter` param -
   this is intentional, not a bug, and was NOT changed.** `utils/querySanitizer.js` has `$regex`
   on its `dangerousOperators` blocklist (DoS risk from unanchored/attacker-supplied patterns)
   and `$search` isn't in the operator allowlist either, so both always 400 regardless of
   anchoring or escaping. The `baas-integration` skill previously suggested `$regex` as the
   substring-search workaround - that guidance was stale and has been corrected in this session.
   The real mechanism is the dedicated `GET /api/search/projects/:projectId/search?q=...&
   collections=<slug>` endpoint (`routes/search.js` / `services/searchService.js`), which builds
   its own server-side regex across `title`/`description`/`name`/`content`/`email` and isn't
   subject to the client-filter sanitizer. This app's listings search (`/`) uses that endpoint
   (`MudbaseClient.search()` / `useSearch()`) when a keyword is present, and applies the
   category/budget filters client-side over the returned batch since the search endpoint doesn't
   accept additional structured filters alongside `q`. Category/budget-only browsing (no
   keyword) still uses the normal server-side `filter` + real pagination.

## Known limitations

- Portfolio file upload to the public bucket was **not built** in this pass - the spec marked it
  nice-to-have and explicitly said to prioritize the core listings/proposals/messages flow first.
  The `uploadFile()` method still exists on `MudbaseClient` for API-contract completeness (mirrors
  the ecommerce/social showcases) but nothing in the UI calls it yet.
- Document-level RBAC (see above) is enforced client-side, not by the platform. Do not treat this
  reference app's access control as production-grade multi-tenant isolation.
