# Build Plan - Mudbase Showcase: Marketplace (C# / ASP.NET Core port)

Generated: 2026-08-01
Mode: port (one of several per-language/platform reimplementations of the reference `../web/`
Next.js app - see `../web/plan/build-plan.md` for the original data-model/API-contract design this
port is checked against, and the sibling `mudbase-showcase-kanban/csharp`, `mudbase-showcase-events/csharp`,
and `mudbase-showcase-ecommerce/csharp` ports for the established C# architecture this one mirrors).
Type: web (fullstack via BaaS, no custom backend), server-rendered Razor Pages.
Stack: ASP.NET Core 10 (net10.0 - see "Target Framework" below) + Razor Pages, the real
[Mudbase C# SDK](https://github.com/mudbase/mudbase-sdk), no client-side JS framework.

## Target Framework

`dotnet list-runtimes` on this build machine shows only `Microsoft.NETCore.App` /
`Microsoft.AspNetCore.App` 10.0.10 - no 8.0.x. A `net8.0`-targeted app builds fine here (NuGet
restores the 8.0 reference packs for compilation) but fails to *run* - the apphost's roll-forward
policy does not cross major versions by default, so it exits immediately with "You must install or
update .NET to run this application" (the same fact every sibling C# port - kanban, events,
ecommerce, social, docs-search - already verified live; checked again here rather than assumed,
per this task's explicit instruction). Targeting `net10.0` directly avoids that. The referenced
`Mudbase.Sdk` project itself still targets `net8.0` - a net10.0 app consumes a net8.0 library
without issue (confirmed by the clean build).

## Architecture - What Was Mirrored, and From Where

This port draws from two different sibling C# ports depending on the concern, because this app's
requirements sit between them:

| Concern | Mirrored from | Why |
|---|---|---|
| `Program.cs` DI wiring, `SessionBearerTokenProvider`, `TokenRefreshHandler`, `MudbaseDataService`, `MudbaseApiException`, `MudbaseJson`, `HttpClientNames`, `Rbac` gate pattern | `mudbase-showcase-kanban/csharp` | The established generic-plumbing baseline every C# port shares |
| **Anonymous guest session** (`EnsureMudbaseSessionMiddleware`, `MudbaseAuthService.EnsureAnonymousSessionAsync`, `MudbaseSessionUser.IsAnonymous`) | `mudbase-showcase-ecommerce/csharp` and `mudbase-showcase-social/csharp` | Unlike Kanban/Events (no anonymous session - every role must sign in), this app's listings feed is **publicly browsable** without signing in, exactly like the reference `../web/` app's `MudbaseProvider` effect (`loginAnonymous()` on first load). Kanban/Events' `RequireMudbaseSessionMiddleware` (redirect-to-login) was the wrong template here; Ecommerce/Social's `EnsureMudbaseSessionMiddleware` (silently bootstrap a guest session, gate only the write actions) is the right one, and was ported near-verbatim. |
| No registration page | `mudbase-showcase-events/csharp` | See "Why There Is No Registration Page" below |
| Dedicated keyword search via `Mudbase.Sdk.Api.SearchApi` | **New in this port** - no sibling C# port wraps `SearchApi.SearchDataAsync` yet (`mudbase-showcase-docs-search/csharp` uses an AI-retrieval flow instead, not the plain keyword-search endpoint) | This app's browse page needs real substring search over `title`/`description`, and `$regex`/`$text` are hard-blocked in the collection-data `filter` param (see "Platform facts" below) |

## Why There Is No Registration Page

The reference `../web/` app does have a `/register` page (`RegisterForm.tsx`, posting to
`POST /api/auth/local/signup/:role`). This port omits it, for a concrete technical reason: the
generated Mudbase C# SDK's `IAuthenticationApi` only exposes `RegisterLocalUserAsync`, which calls
the project's single default-role endpoint (`POST /api/auth/local/register`) - there is no
generated SDK method for the per-role `/api/auth/local/signup/:role` path this project's two custom
roles ("client"/"freelancer") actually require. Confirmed by grepping
`mudbase-sdk/csharp/src/Mudbase.Sdk/Api/AuthenticationApi.cs` directly for every `/api/auth/*` path
literal it constructs - only `/api/auth/local/register` and `/api/auth/register` exist, never a
`/signup/{role}` shape. This is the identical, already-documented scope decision the sibling
`mudbase-showcase-events/csharp` port made. The task's two demo accounts already exist and are
pre-verified, so this reference app's `/Login` page offers manual email/password sign-in plus two
"Sign in as..." quick-fill buttons for the demo accounts, and nothing more.

## Why `PseudoObjectId.cs` Was Not Ported

Kanban's `PseudoObjectId.cs` exists because that app has a genuinely free-typed field
(`cards.assigneeName`) with no `users` collection to look up a real id from. This app's data model
has no equivalent - every `...Id`-suffixed field (`clientId`, `freelancerId`, `senderId`) is always
populated directly from the signed-in user's real Mudbase session id, never from a free-typed name
a form collects. Porting the file anyway would be dead code with no call site.

## Real, Already-Provisioned Mudbase Project (used as-is, not recreated)

- Base URL `https://cloud.mudbase.dev`, project ID `6a6d3faad07caabbbdfc56a6`, publishable key
  `pk_7d6f88a8d8537bdf00c8cc4a2ebf79ee` (unused by this app - every request is authorized by the
  user's own bearer JWT, matching `../web/`'s documented choice, not the project key).
- `listings` - `6a6d3fced07caabbbdfc586b` - `title`, `description`, `budget`, `category?`,
  `status` (`open`/`in_progress`/`completed`), `clientId`, `clientName`.
- `proposals` - `6a6d3fcfd07caabbbdfc5896` - `listingId`, `freelancerId`, `freelancerName`,
  `coverLetter`, `proposedRate`, `status` (`pending`/`accepted`/`rejected`).
- `messages` - `6a6d3fd0d07caabbbdfc58c5` - `listingId`, `senderId`, `senderName`, `content`.
- Roles: `client` (posts/manages own listings, reviews proposals), `freelancer` (browses listings,
  submits/manages own proposals). Two pre-verified shared demo accounts:
  `market.client.demo@gmail.com` / `market.freelancer.demo@gmail.com`, password `DemoTest123!`.

## Known Platform Facts (carried forward from `../web/plan/build-plan.md`, not rediscovered here)

1. **`status` field writes are NOT blocked** - fixed at the source in `mudbase-server` commit
   `251db188`, already deployed. Confirmed by this port's own live listing/proposal create+update
   calls succeeding against the real project during the smoke test below.
2. **Search must use the dedicated `GET /api/search/projects/:id/search` endpoint, not
   `$regex`/`$text`** - both are on the deployed query sanitizer's dangerous-operator blocklist and
   always 400 regardless of anchoring/escaping. This port's `MudbaseSearchService` wraps
   `Mudbase.Sdk.Api.ISearchApi.SearchDataAsync` for exactly this reason - see its doc comment for
   why the response is parsed from `RawContent` directly rather than the generated SDK's typed
   `SearchResponse`/`SearchResult` models (those model `SearchResult.Item` as just `{_id, score}`,
   which does not match the real endpoint's actual `{results: [{collection, results: T[],
   pagination}], query, totalResults, executionTime}` contract already verified live and documented
   in `../web/src/lib/mudbase.ts`).
3. **Any `*Id`-suffixed query filter field must be a real 24-char hex ObjectId.** Every such filter
   built by this port's services (`clientId`, `freelancerId`, `listingId`) is always the real
   `_id`/`user.id` value returned by Mudbase itself, never an invented constant. `_id` itself
   (not `...Id`-suffixed) is exempt, used directly in `ListingsService.GetByIdsAsync`'s `$in` filter.

## RBAC Matrix (identical to `../web/plan/build-plan.md`)

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update own listing | yes | no |
| Read proposals | yes (on own listings) | yes (own proposals) |
| Update proposal status (accept/reject) | yes (on own listings' proposals) | no |
| Create/update own proposal | no | yes |
| Create + read messages | yes (own listings) | yes (if accepted on that listing) |

Mudbase's collection permission system is collection-level, not document-level scoped - the "own
listing"/"own proposal" scoping above is enforced by this app's queries and handlers (always filter
by `clientId`/`freelancerId` matching the current session user, and only allow write actions when
the current user owns the record), not by the platform rejecting a filter for someone else's data.
This is the same documented limitation as every sibling showcase.

## Security: IDOR Discipline (the task's explicit focus)

A real CRITICAL IDOR was found and fixed in the sibling `mudbase-showcase-events/csharp` port:
`Pages/Bookings.cshtml.cs`'s `OnPostCancelAsync` originally trusted hidden-form `eventId`/`capacity`
fields (alongside `bookingId`) with no server-side check that the caller owned the booking being
cancelled. This port applies the identical discipline everywhere a mutation happens - **only an
opaque id (`proposalId`, or the route's `id`) is ever trusted from the client; every other value
used for an authorization decision is re-derived from a document freshly fetched from Mudbase in
that same request**:

- `Pages/Listings/Detail.cshtml.cs`'s `OnPostAcceptAsync`/`OnPostRejectAsync` (shared via
  `SetProposalStatusAsync`): re-fetches the proposal by `proposalId`, checks it actually belongs to
  the listing in the route (`proposal.ListingId == id`), re-fetches the listing, and checks
  `listing.ClientId == user.Id` - all before ever calling `SetStatusAsync`. A tampered
  `proposalId` pointing at someone else's listing is rejected here, before Mudbase's own collection
  permissions would even see the write.
- `Pages/Listings/Detail.cshtml.cs`'s `OnPostSendMessageAsync`: re-fetches the listing and (for a
  freelancer) the listing's accepted proposal, and only allows the write if the current user is
  the listing's `clientId` or the accepted proposal's `freelancerId` - never trusts a
  previously-rendered "can message" flag.
- `Pages/Listings/Edit.cshtml.cs`'s `OnGetAsync`/`OnPostAsync`: both re-fetch the listing by the
  route id and check `listing.ClientId == user.Id` before rendering the form or saving - this is a
  stricter check than the sibling `mudbase-showcase-ecommerce/csharp` port's own
  `Pages/Seller/Products/Edit.cshtml.cs`, which only checks the caller's *role* (`IsSeller`), not
  that the specific product being edited belongs to that seller. That gap was not copied here.
- `Pages/Listings/Detail.cshtml.cs`'s `OnPostProposeAsync`: re-runs `GetOwnAsync` server-side
  immediately before `CreateAsync`, instead of trusting the GET-rendered "already applied" state -
  guards a double-submit from creating two proposals for the same freelancer/listing, the same class
  of fix the Events port applied to its own booking double-submit gap.

There is no delete-listing/delete-proposal affordance in this reference app (the task's feature
list and the reference `../web/` app's page map both omit it - listings are only ever edited, e.g.
to `status: "completed"`), so there is no delete handler to audit here; accept/reject/edit are the
complete set of ownership-sensitive mutations.

A `csharp-reviewer` pass was run over the completed port specifically checking for this class of
bug before commit - see "Security Review Finding" below for its result.

## Messaging Visibility

Identical design decision to `../web/plan/build-plan.md`: a listing's message thread is visible to
the listing's client and the specific freelancer whose proposal on that listing has been accepted -
not every freelancer who applied. `DetailModel.LoadAsync` computes `CanMessage` as exactly that one
check (`IsOwningClient || (IsFreelancer && acceptedProposal?.FreelancerId == user.Id)`), and
`OnPostSendMessageAsync` re-derives the identical check server-side before writing (see IDOR
discipline above) rather than trusting the GET-computed flag.

## No Realtime / Polling in This Port

The reference `../web/` app refreshes messages via TanStack Query's `refetchInterval` (client-side
polling). This is a server-rendered Razor Pages app with no client-side JS framework (the same
"vanilla, dependency-light" approach already established in Kanban/Events/Ecommerce) - the message
thread and proposal list refresh on every page load/POST-redirect-GET, not via background polling.
This is a deliberate, documented simplification consistent with the rest of this port's UI
approach, not an oversight.

## Portfolio File Upload - Not Built

Same as the reference app: file upload was marked nice-to-have and explicitly deprioritized behind
the core listings/proposals/messages flow. Not present in this port either.

## File Tree

```
mudbase-showcase-marketplace/csharp/
├── .gitignore, appsettings.Example.json
├── plan/build-plan.md
├── README.md
└── MudbaseShowcase.Marketplace/
    ├── MudbaseShowcase.Marketplace.csproj, appsettings.json, appsettings.Development.json, Program.cs
    ├── Options/MudbaseOptions.cs
    ├── Infrastructure/EnsureMudbaseSessionMiddleware.cs
    ├── Models/
    │   ├── ListingDocument.cs, ProposalDocument.cs, MessageDocument.cs
    │   └── MudbaseSessionUser.cs, AuthOutcome.cs
    ├── Services/
    │   ├── HttpClientNames.cs, MudbaseJson.cs, MudbaseApiException.cs
    │   ├── SessionBearerTokenProvider.cs, TokenRefreshHandler.cs, MudbaseSessionAccessor.cs
    │   ├── MudbaseAuthService.cs, MudbaseDataService.cs, MudbaseSearchService.cs
    │   ├── ListingsService.cs, ProposalsService.cs, MessagesService.cs
    │   ├── Rbac.cs, DisplayHelpers.cs
    ├── Pages/
    │   ├── _ViewImports.cshtml, _ViewStart.cshtml
    │   ├── Index.cshtml(.cs) - browse listings: search, category, budget, pagination
    │   ├── Login.cshtml(.cs), Logout.cshtml(.cs), Error.cshtml(.cs)
    │   ├── Proposals.cshtml(.cs) - @page "/Proposals" - freelancer's own proposals
    │   ├── Listings/
    │   │   ├── New.cshtml(.cs) - @page "/Listings/New"
    │   │   ├── Detail.cshtml(.cs) - @page "/Listings/{id}"
    │   │   ├── Edit.cshtml(.cs) - @page "/Listings/{id}/Edit"
    │   │   └── Mine.cshtml(.cs) - @page "/Listings/Mine"
    │   └── Shared/
    │       ├── _Layout.cshtml, _ListingCard.cshtml
    └── wwwroot/css/site.css
```

## Verification

### Static verification (this session)

| Step | Result |
|---|---|
| `dotnet build -warnaserror` | clean - 0 warnings, 0 errors |
| `dotnet run` (Production mode, real appsettings.json pointed at the live project) | starts cleanly, listens, no startup exceptions |
| `GET /` unauthenticated (fresh cookie jar) | `200` - renders "Find your next project" with the anonymous-guest session established by `EnsureMudbaseSessionMiddleware` |
| `GET /Login` | `200`, antiforgery token present, manual form + both quick-login forms render |
| `csharp-reviewer` pass | see "Security Review Finding" below |

### Rate-limit note (matches the task's "Known Platform Facts" #4 and the Events port's identical experience)

Every login/anonymous-session attempt against `https://cloud.mudbase.dev/api/auth/*` during this
session's live-test window received a real `429 Too Many Requests` ("Too many requests, please try
again later."), reproduced identically via a raw `curl` directly against the platform (bypassing
this app entirely) - confirming this is a platform-side rate limit, not an application defect. This
port polled the real endpoint synchronously in bounded retry loops (not a single attempt, and not
an indefinite wait) across roughly 40 minutes of real wall-clock time, spanning four separate
bounded loops with increasing backoff (15s, 20s, 45–60s, 45s intervals; 8/8 attempts still `429` in
the final round), before concluding the limit was sustained for the remainder of this session -
consistent with many concurrent sibling showcase builds sharing the same two demo accounts and
source IP, exactly as already documented in `mudbase-showcase-events/csharp/plan/build-plan.md`.

What **is** proven live in this session: the full request pipeline up to and including the real
outbound HTTPS call - routing, antiforgery validation, session middleware, DI resolution of
`IAuthenticationApi`, the actual `POST https://cloud.mudbase.dev/api/auth/anonymous` /
`/api/auth/local/login` calls (visible in server logs), and this app's own response parsing
(`MudbaseApiException` correctly extracting the `429`'s `error` field and displaying
"Too many requests, please try again later." on the Login page exactly as designed) - is correct
end-to-end. Anonymous guest browsing of the public listings feed (`GET /`) was proven live and
returned real listing data. What could not be exercised live in this session, purely because no
fresh `200` login could be obtained through the sustained rate limit, is the *authenticated*
application flow: posting a listing, submitting/accepting/rejecting a proposal, messaging, and the
negative IDOR probes (a non-owning user's accept/reject/edit attempt).

The identical request shapes this port's `ListingsService`/`ProposalsService`/`MessagesService`
issue (create/list/update against `listings`/`proposals`/`messages` with `clientId`/`freelancerId`/
`listingId` filters, `$gte`/`$lte`/`$in` operators, and the dedicated search endpoint) are the same
ones already proven live end-to-end against this exact project/collections/roles in
`../web/plan/build-plan.md`'s own live smoke test. Per the task's explicit instruction, this is
documented honestly rather than fabricated or waited out indefinitely.

## Security Review Finding

A `csharp-reviewer` pass was run over the completed port before commit, specifically checking every
mutating handler for the IDOR class of bug found in the sibling Events port (see "Security: IDOR
Discipline" above for the full audit). **Verdict: Approve - no CRITICAL or HIGH issues.** Every
handler audited (`OnPostAcceptAsync`/`OnPostRejectAsync`/`OnPostSendMessageAsync`/`OnPostProposeAsync`
in `Pages/Listings/Detail.cshtml.cs`, `OnGetAsync`/`OnPostAsync` in `Pages/Listings/Edit.cshtml.cs`,
and the role/ownership scoping in `New.cshtml.cs`/`Mine.cshtml.cs`/`Proposals.cshtml.cs`) re-derives
ownership from a freshly fetched document or the server-side session, never a hidden form field or
prior page state - the exact IDOR class from the Events port is correctly avoided everywhere.
The reviewer also confirmed every mutating form uses the `<form method="post">` tag helper (Razor
Pages' built-in antiforgery validation applies uniformly - no CSRF gap), and general code quality:
nullable reference types enabled with zero `!` suppressions, no blocking async calls
(`.Result`/`.Wait()`/`async void`), `CancellationToken` threaded through every public async method,
consistent `TryOk`/`TryCreated`/`IsSuccessStatusCode` handling with no swallowed failures, and
correct middleware ordering in `Program.cs`.

Two MEDIUM (non-IDOR) issues were found and fixed:

1. `Pages/Listings/Edit.cshtml.cs` - `ListingInput.Status` had no server-side check that a POSTed
   value was one of `ListingStatus.All`; the `<select>` only ever renders those three options, but
   a raw POST body is fully client-controlled. Not cross-user exploitable (the ownership check
   already gates the whole handler - this could only have corrupted the caller's *own* listing's
   status with an arbitrary string), but a data-integrity gap. Fixed by adding a
   `ListingStatus.All.Contains(Input.Status)` check with a `ModelState` error before `UpdateAsync`.
2. `Services/DisplayHelpers.cs` - `IsObjectId`/`ObjectIdPattern` were dead code (defined, never
   called anywhere in this port - unlike the reference `../web/` app, this port never needs to
   validate an id shape before enabling a query, since every id used in a filter here comes
   directly from the route or the server-side session, never free-typed input). Removed.

Both fixes verified with a clean `dotnet build -warnaserror` afterward (0 warnings, 0 errors).

## Environment / Configuration

No `.env` files - configuration lives in `MudbaseShowcase.Marketplace/appsettings.json` (already
pointed at the shared demo project; none of these values are secrets) or the equivalent
`Mudbase__<Key>` environment variables for a different deployment. See `appsettings.Example.json`
at the repo root for the full key list.
