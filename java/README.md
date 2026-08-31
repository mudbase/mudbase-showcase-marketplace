# Mudbase Showcase - Marketplace (Java / Spring Boot edition)

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** - auth, database,
role-based access control, no custom backend of any kind - reimplemented in **Spring Boot +
Thymeleaf** (server-rendered, no client-side JS framework). This is a companion to the reference
Next.js app at `../web`: same Mudbase project, same three collections
(`listings`/`proposals`/`messages`), same RBAC matrix and business rules; see
`../web/plan/build-plan.md` for the reference data model and what deliberately differs here.

## Stack

Java 17, Spring Boot 3.3 (Web MVC, not WebFlux), Thymeleaf, Bean Validation. The only outbound
HTTP this app makes is the real Mudbase Java SDK (plus a few raw calls that bypass known SDK
deserialization quirks - see `MudbaseAuthClient`/`MudbaseDataClient` javadoc) against
`cloud.mudbase.dev` - no other services, no database of its own.

## Setup

### 1. Install the Mudbase SDK to your local Maven repository (one-time, mandatory)

The SDK is **not published to Maven Central** - it lives at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), subdirectory `java/`.
Clone it as a **sibling** of this repo, then install it into `~/.m2`:

```bash
git clone https://github.com/mudbase/mudbase-sdk.git
cd mudbase-sdk/java && mvn install
```

This installs `dev.mudbase:mudbase-sdk:2.0.0` into your local repo - already done on any machine
that previously set up the sibling `mudbase-showcase-kanban/java`, `mudbase-showcase-social/java`,
or `mudbase-showcase-ecommerce/java` ports, since it's the exact same artifact.

### 2. Configure environment variables

```bash
cp .env.example .env
# fill in your provisioned project's IDs (or just use the already-provisioned showcase project -
# application.properties already defaults to it)
set -a && source .env && set +a
```

See `.env.example` for the full list. You need a Mudbase project already provisioned with local
auth, the Multi-Role feature's two role slugs (`client`/`freelancer`), and the three collections
(`listings`, `proposals`, `messages`) shaped as documented in `../web/plan/build-plan.md` with the
RBAC matrix below - this app assumes that provisioning already exists, exactly like the reference
web app does. Two demo accounts are already provisioned: `market.client.demo@gmail.com` /
`market.freelancer.demo@gmail.com`, password `DemoTest123!`.

### 3. Build and run

```bash
cd mudbase-showcase-marketplace/java
mvn clean install   # verify it builds clean
mvn spring-boot:run
```

Visit `http://localhost:8080` and sign in with one of the two demo accounts (the login page ships
one-click "Sign in as Client/Freelancer" buttons for fast demoing).

## What's implemented

| Page | Route | Notes |
|---|---|---|
| Browse listings | `GET /` | Search (`q`), category, min/max budget filters, pagination; auth-gated for every role |
| Post a listing | `GET/POST /listings/new`, `POST /listings` | Client-only; title 3-120 chars, description 20+, budget > 0, optional category |
| Listing detail | `GET /listings/{id}` | Full detail; proposal form (freelancer) or own-proposal status + withdraw (freelancer); proposals-received + accept/reject (owning client); message thread (client + accepted freelancer) |
| Edit listing | `GET/POST /listings/{id}/edit` | Client, owner-only - ownership re-derived server-side from the fetched document, never a hidden field |
| Delete listing | `POST /listings/{id}/delete` | Client, owner-only - same re-derived ownership check |
| My listings | `GET /listings/mine` | Client-only; own listings with live proposal counts (batched query, no N+1) |
| Submit proposal | `POST /listings/{id}/proposals` | Freelancer-only; refuses a second proposal on the same listing |
| Accept / reject proposal | `POST /proposals/{id}/accept`, `POST /proposals/{id}/reject` | Client-only, and only on the caller's OWN listing - ownership re-derived by fetching the proposal, then fetching that listing, then comparing `clientId` to the caller; see "Security notes" below |
| Withdraw proposal | `POST /proposals/{id}/withdraw` | Freelancer, owner-only - ownership re-derived from the fetched proposal's `freelancerId` |
| My proposals | `GET /proposals/mine` | Freelancer-only; own proposals across all listings, with listing titles (batched query) |
| Send message | `POST /listings/{id}/messages` | Client or the listing's accepted freelancer only - re-derived server-side on every send, not just hidden in the UI |
| Login / Logout | `GET/POST /login`, `POST /logout` | Email + password, plus two quick-fill demo buttons - no registration UI, see "What deliberately differs" |

Session/auth: the Mudbase-issued JWT is stored server-side in the Spring `HttpSession` - it is
never sent to the browser (pages are plain server-rendered HTML with a shared stylesheet, no
client JS at all beyond ordinary form submissions).

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update/delete own listing | yes | no |
| Read proposals | yes (on own listings) | yes (own proposals) |
| Update proposal status (accept/reject) | yes (on own listings' proposals) | no |
| Create/update/delete own proposal | no | yes |
| Create + read messages | yes | yes (only if their proposal was accepted) |

Mudbase's collection permission system is **collection-level, not document-level** (confirmed in
`baas-integration/SKILL.md` and reused verbatim from `../web/plan/build-plan.md`). This means the
"own listing"/"own proposal" scoping above is **not** enforced by the platform rejecting a filter
for someone else's data - it must be enforced by this app itself, in the service layer, on every
mutating request. See "Security notes" below for how that's done.

## Security notes - ownership re-derivation (IDOR hardening)

Every mutation that determines *which* document gets changed, or *whether the caller is allowed
to change it*, re-derives ownership from a **freshly fetched document** - never from a hidden
form field, a path variable on its own, or anything else the request merely asserts:

- **Edit/delete a listing** (`ListingService#update`/`#delete`): fetches the listing by id, then
  compares its `clientId` to the signed-in session's own user id. A request whose `id` path
  variable points at someone else's listing is rejected with `ForbiddenActionException` before any
  write is attempted, regardless of what the submitted form contains.
- **Accept/reject a proposal** (`ProposalService#decide`): fetches the *proposal* first (to learn
  its real `listingId` - never trusted from the request), then fetches *that listing* (to learn
  its real `clientId`), and only proceeds if the caller's user id matches. This two-hop
  re-derivation is the exact discipline needed to close the class of bug found and fixed in the
  sibling C# Events port, whose booking-cancellation handler trusted a hidden form field instead
  of re-deriving ownership from the fetched booking document.
- **Withdraw a proposal** (`ProposalService#withdraw`): fetches the proposal, compares its
  `freelancerId` to the caller.
- **Send a message** (`MessageService#send`/`#canAccessThread`): fetches the listing document and
  re-derives thread membership (owning client, or the freelancer with an *accepted* proposal on
  it via a live query) before allowing the write - checked on both read and write, not just hidden
  in the UI.

This was verified live: a second, freshly-registered client account (same role, different
identity) attempting to edit/delete the first client's listing or accept its proposal is rejected
server-side with a 403, even though it presents a syntactically valid request to the correct
routes.

## Platform notes (already known - not rediscovered here)

- `status` field writes are **not** blocked (fixed in `mudbase-server` commit `251db188`, already
  deployed) - `listings.status` and `proposals.status` write normally.
- Keyword search uses the dedicated `GET /api/search/projects/:id/search` endpoint, not
  `$regex`/`$text` (both are hard-blocked by the query sanitizer's dangerous-operator blocklist).
  `MudbaseDataClient#search` bypasses the generated `SearchApi` for the same reason every other
  call in that class bypasses its generated counterpart - a raw call parsed leniently avoids any
  risk of a Gson model choking on an undeclared field.
- Every `...Id`-suffixed filter field sent to Mudbase must be a real 24-character hex ObjectId.
- The generated Java SDK has documented Gson-deserialization quirks (`login`'s response `user`
  object carries both `role` and `customRole`; `listData`'s pagination carries `hasMore`) - both
  bypassed here with raw `OkHttpClient` calls parsed leniently via Jackson, the same fix already
  found and applied in the sibling kanban/social/ecommerce Java ports.

## What deliberately differs from the reference web app

- **No anonymous/guest browsing.** The reference Next.js app establishes an anonymous Mudbase
  session so guests can browse listings without signing in first. This port simplifies that away -
  every route other than `/login` requires a real client/freelancer sign-in - matching the same
  simplification the sibling kanban Java port already made for its three roles. Documented here
  rather than rediscovered as a "bug."
- **No registration UI.** Accounts are provisioned ahead of time (the two shared demo accounts).
  Same simplification as the kanban port.
- **Server-rendered filter form instead of live/debounced search.** The reference app debounces
  keystrokes and refetches via TanStack Query; this port's `/` uses a plain `GET` form - submitting
  reloads the page with the new query string. Functionally equivalent, no client JS required.
- **No message polling.** The reference app polls the thread every 4s via `refetchInterval`; this
  port renders the thread once per page load (reload to see new messages) - consistent with this
  app having no client-side JS at all.
- **Proposal withdrawal was added** (not present in the reference web app's UI) to give the
  RBAC matrix's "freelancer can delete own proposal" row an actual, testable code path - the
  reference app only ever shows an already-submitted proposal's status.

## Known limitations

- Document-level RBAC (see above) is enforced by this app's service layer, not by the platform.
  Do not treat this reference app's access control as production-grade multi-tenant isolation on
  its own - it depends on this app's own code being correct, which is why every mutation
  re-derives ownership from a fresh fetch rather than trusting the request (see "Security notes").
- No file/portfolio upload - out of scope for this pass, matching the reference web app.
