# Mudbase Showcase - Marketplace (C# / ASP.NET Core)

A freelance job marketplace, server-rendered with **ASP.NET Core 10 Razor Pages**, built **entirely
on [Mudbase](https://www.mudbase.dev)** - auth, database, and role-based access control - with
**zero custom backend**. This is the C# port of the reference implementation in `../web/`
(Next.js): same data model, same API contract, same RBAC matrix, against the same live project.

## Stack

ASP.NET Core 10, Razor Pages, the real [Mudbase C# SDK](https://github.com/mudbase/mudbase-sdk)
(generated client, `mudbase-sdk/csharp`), talking directly to `cloud.mudbase.dev`. There is no
database, no ORM, and no custom API of any kind in this app - every listing/proposal/message read
or write goes straight to Mudbase's REST API through the generated SDK, authenticated with the
signed-in user's own JWT (held server-side in ASP.NET Core session state, never exposed to client
JS) - or, for anonymous browsing, a guest session bootstrapped the same way.

No client-side JS framework. Forms use plain HTML `<form method="post">` with ASP.NET Core's
Razor Pages handler pattern (`asp-page-handler`) and antiforgery tokens; the message thread and
proposal list refresh on every page load/POST-redirect-GET rather than via background polling (the
reference Next.js app polls client-side with TanStack Query - see `plan/build-plan.md` for why this
port doesn't need an equivalent).

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Anonymous guest browsing + real client/freelancer auth | `POST /api/auth/anonymous`, `POST /api/auth/local/login`, `GET /api/auth/local/session` | `Services/MudbaseAuthService.cs`, `Infrastructure/EnsureMudbaseSessionMiddleware.cs` |
| Listings browse: search, category, budget, pagination | Collection filter/pagination + dedicated search endpoint | `Services/ListingsService.cs`, `Services/MudbaseSearchService.cs`, `Pages/Index.cshtml(.cs)` |
| Listing detail, post, edit | Collection CRUD, `listings` | `Pages/Listings/Detail.cshtml(.cs)`, `Pages/Listings/New.cshtml(.cs)`, `Pages/Listings/Edit.cshtml(.cs)` |
| Proposal submission, review, accept/reject | Collection CRUD, `proposals` | `Services/ProposalsService.cs`, `Pages/Listings/Detail.cshtml.cs` |
| Per-listing messaging (client + accepted freelancer only) | Collection CRUD, `messages` | `Services/MessagesService.cs`, `Pages/Listings/Detail.cshtml.cs` |
| Role-aware UI, server-enforced with ownership re-derivation | Mudbase's own per-role collection permissions + this app's own IDOR-safe handler checks | `Services/Rbac.cs`, every mutating handler in `Pages/Listings/Detail.cshtml.cs`/`Edit.cshtml.cs` |
| Automatic token refresh | `POST /api/auth/refresh`, single-use rotating refresh tokens | `Services/TokenRefreshHandler.cs` |

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update own listing | yes | no |
| Read proposals | yes (on own listings) | yes (own proposals) |
| Accept/reject a proposal | yes (on own listings' proposals) | no |
| Create/update own proposal | no | yes |
| Create + read messages | yes (own listings) | yes (if accepted on that listing) |

The UI hides write controls a role/ownership combination cannot use, and every mutating Razor Page
handler re-checks both the role **and** ownership of the specific document being mutated server-side
via a fresh fetch from Mudbase - see `plan/build-plan.md`'s "Security: IDOR Discipline" section for
the full audit and why this matters (a sibling port had a real IDOR here before being fixed).
Neither of those is the ultimate enforcement boundary, though - Mudbase's own collection permissions
are.

## Getting started

This repo assumes a sibling clone of the Mudbase C# SDK (not published on NuGet):

```bash
cd ..                                             # parent directory of this repo
git clone https://github.com/mudbase/mudbase-sdk.git
cd mudbase-showcase-marketplace/csharp/MudbaseShowcase.Marketplace
dotnet run
```

Then open `http://localhost:5000` (or whatever port `dotnet run` reports). Browse listings without
signing in, or sign in with one of the two demo accounts via the login page's quick-fill buttons
(or type credentials manually) - see `plan/build-plan.md` for account details and the RBAC/IDOR
verification notes.

> **.NET version note**: this project targets `net10.0`. If your machine only has an older SDK
> installed, either install the .NET 10 SDK or see `MudbaseShowcase.Marketplace.csproj`'s comment
> for why an older `TargetFramework` builds but will not run without a matching runtime installed.

## Configuration

No `.env` files - configuration lives in `MudbaseShowcase.Marketplace/appsettings.json` (already
pointed at the shared demo project; none of these values are secrets - a project/collection id is
not sensitive) or the equivalent `Mudbase__<Key>` environment variables for a different deployment.
See `appsettings.Example.json` at the repo root for the full key list with descriptions.

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

- A project with two custom Multi-Roles: `client` and `freelancer`.
- Collections: `listings` (`title`, `description`, `budget`, `category?`, `status`, `clientId`,
  `clientName`), `proposals` (`listingId`, `freelancerId`, `freelancerName`, `coverLetter`,
  `proposedRate`, `status`), `messages` (`listingId`, `senderId`, `senderName`, `content`).
- Two pre-verified demo accounts: `market.client.demo@gmail.com` / `market.freelancer.demo@gmail.com`,
  password `DemoTest123!`.

See `plan/build-plan.md` for the exact provisioned IDs already wired into `appsettings.json`.
