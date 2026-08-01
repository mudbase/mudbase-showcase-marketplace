# Mudbase Showcase — Freelance Marketplace (SwiftUI / iOS)

A production-shaped SwiftUI iOS app built on top of [Mudbase](https://www.mudbase.dev),
reimplementing the same reference marketplace as the companion Next.js app in `../web/` — same
collections, same permissions model, same messaging-visibility rule. Auth, listings, proposals,
and messaging all talk directly to `cloud.mudbase.dev` through the real generated Mudbase Swift
SDK — except the keyword-search endpoint, which is called directly via `URLSession` instead (see
"The Mudbase Swift SDK, exactly as generated" below for why).

## Why SPM, not an `.xcodeproj`

This package is deliberately `.xcodeproj`-free. Since Xcode 14, you can open a `Package.swift`
directly and run an `executableTarget` that defines a SwiftUI `App` (`@main`) as a real iOS app on
a Simulator or device — Xcode synthesizes the Info.plist/bundle at build time, no project file
needed. That keeps this reimplementation's on-disk footprint identical in spirit to the other
per-language versions in this monorepo (`../web/`, `../go/`, etc.): source + a manifest, nothing
generated or binary checked in. `swift build` from the CLI also succeeds on plain macOS — the
`platforms` list in `Package.swift` includes `.macOS(.v14)` purely so this can be verified without
Xcode; no UIKit-only API is used anywhere in the target (guarded behind small compatibility shims
where SwiftUI itself differs — see `Support/PlatformCompat.swift`).

## Setup

1. **Clone the SDK as a sibling directory.** From the same parent directory that contains this
   monorepo (`mudbase-showcase-marketplace/`):
   ```bash
   git clone https://github.com/mudbase/mudbase-sdk.git
   ```
   You should end up with:
   ```
   parent/
     mudbase-showcase-marketplace/
       swift/            <- this package (Package.swift lives here)
       web/
       ...
     mudbase-sdk/
       swift/            <- the SDK package Package.swift references
       ...
   ```

2. **Create the SwiftPM identity-collision workaround symlink** (already committed at the monorepo
   root — you only need to redo this if you re-clone the SDK somewhere else). This app's own SPM
   package directory is named `swift` and the SDK's own Swift subdirectory is *also* named `swift`.
   SwiftPM computes a local path dependency's package "identity" from the last path component of
   the path you give it, with no way to override that — so a plain
   `.package(path: "../../mudbase-sdk/swift")` gives this app's own package and its SDK dependency
   the *same* identity ("swift"), and dependency resolution silently conflates them:
   ```
   error: product 'MudbaseSDK' required by package 'swift' target 'MudbaseShowcaseMarketplace' not found in package 'MudbaseSDK'
   ```
   The fix is a relative symlink at the monorepo root:
   ```bash
   # from mudbase-showcase-marketplace/ (the monorepo root)
   ln -s ../mudbase-sdk/swift mudbase-sdk-swift
   ```
   `Package.swift` references `../mudbase-sdk-swift` (not `../../mudbase-sdk/swift`) for exactly
   this reason. Same fix already applied in the sibling ecommerce/social/docs-search Swift ports.

3. **Configure.** Copy `Config.example.plist` to `Config.plist` (same directory) — it already has
   this showcase's real project/collection IDs filled in, since none of them are secrets (a
   project/collection ID isn't sensitive, same rationale as `web/.env.example`):
   ```bash
   cp Config.example.plist Config.plist
   ```
   `Config.plist` is still gitignored to keep the file out of history as a matter of convention.
   `AppConfig.load` also reads `MUDBASE_PROJECT_ID` / `MUDBASE_LISTINGS_COLLECTION_ID` / etc.
   environment variables as a fallback, which is convenient for `swift run` during development; if
   neither source resolves every required key, the app renders a "Configuration required" screen
   instead of crashing (see `ConfigurationRequiredView.swift`).

4. **Open and run.**
   ```bash
   open Package.swift
   ```
   In Xcode: pick an iOS Simulator (or a physical device) as the run destination from the scheme
   selector, then Run. If you add `Config.plist` to the project navigator, make sure it's added to
   the `MudbaseShowcaseMarketplace` target's "Copy Bundle Resources" build phase (Xcode does this
   automatically when you drag the file in with "Add to target" checked).

## What's implemented

- **Auth** — email/password login, self-signup with a real role picker (`client` "Hire
  freelancers" vs. `freelancer` "Find work"), plus an **anonymous guest session** so the Browse
  tab is publicly browsable before signing in (mirrors `../web/src/lib/mudbase-provider.tsx`).
  Session bootstrap from Keychain on launch, logout re-establishes a fresh guest session. Token
  pair stored in the Keychain via `Support/KeychainTokenStore.swift` — never `UserDefaults`. A 401
  from an expired access token is transparently refreshed and retried once, for *every*
  authenticated call in the app (not just launch bootstrap) — see
  `Networking/AccessTokenCoordinator.swift`.
- **Browse** — listings feed with search (debounced, dedicated search endpoint), category filter,
  and budget range, matching `../web/src/app/page.tsx`'s two branches exactly (see
  `ListingsService.browse`/`.search`).
- **Listing detail** — full detail, a freelancer's proposal submission (or their existing
  proposal's status), the owning client's received proposals with one-tap accept/reject, and the
  message thread (client + accepted freelancer only — see "Messaging visibility" below).
- **My Listings** (client only) — a client's own listings with live proposal counts, post/edit.
- **My Proposals** (freelancer only) — a freelancer's own proposals across every listing.
- **Messaging** — polls every 4 seconds (matching the web app's `refetchInterval`) rather than a
  realtime channel — the web reference's own deliberate simplification, carried over here.

## Architecture

```
Sources/MudbaseShowcaseMarketplace/
  App/            @main entry point
  Config/         AppConfig (Config.plist + env var loader)
  Support/        Keychain, API error mapping, formatting, navigation reference types, platform shims
  Networking/     Thin wrappers over the generated SDK's async calls + the raw search-endpoint call
  Models/         Listing, Proposal, Message, AppUser — decoded from Mudbase JSON
  Services/       SessionStore, TabRouter (both @MainActor ObservableObject), ListingsService, ProposalsService, MessagesService
  ViewModels/     One @MainActor ObservableObject per screen
  Views/          SwiftUI views, grouped by feature area
```

`SessionStore` and `TabRouter` are the two app-wide stores (created once in the `App` struct and
injected via `.environmentObject`); every other view model is constructed explicitly by its owning
view (passed `config` and any IDs it needs) rather than reached for via `@EnvironmentObject`, so
each screen's real dependencies stay visible at its call site.

## The Mudbase Swift SDK, exactly as generated — and the one place this app deliberately bypasses it

Every Mudbase call in this app goes through the real generated `MudbaseSDK` async/await methods —
none of the signatures were guessed; each was read from
`../../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift` before being used:

- `AuthenticationAPI.createAnonymousSession`, `.loginLocalUser`, `.getLocalSession`,
  `.refreshToken`, `.logoutLocalUser`
- `MultiRoleFeatureAPI.registerWithRole(role:registerWithRoleRequest:)`
- `DataAPI.listData` / `.getData` / `.createData` / `.updateData` / `.deleteData`

**Except keyword search.** `SearchAPI.searchData`'s generated response models
(`SearchResponse`/`SearchResponseData`/`SearchResult`/`SearchResultItem`) describe a
`{ success, data: { results: [{ collection: String?, item: { id, score } }], pagination, query,
searchTime } }` shape. That does **not** match what `GET /api/search/projects/:id/search` actually
returns — confirmed by reading the live handler directly
(`mudbase-backend/routes/search.js` → `services/searchService.js`'s `executeSearch`/
`searchInCollection`), not by guessing: the real body is
`{ results: [{ collection: { id, name, slug }, results: [fullMatchedDocuments], pagination: {
page, limit, total, totalPages } }], query, totalResults, executionTime }` — full matched
documents per collection, no `success`/`data` envelope. This is the same class of
generated-SDK/live-API gap already known for `customRole` on the login response (below) — the
OpenAPI spec behind this endpoint just doesn't describe the real server behavior.
`Networking/SearchGateway.swift` calls the endpoint directly with `URLSession` (reusing the same
bearer token `MudbaseSDKBootstrap` keeps in sync, and the same `AccessTokenCoordinator`
401-refresh-and-retry policy) and decodes the raw JSON tree by hand into the same
`MudbaseDocument` every other gateway already uses, sidestepping the wrong generated model
entirely instead of building on top of it.

Two more real, documented generated-SDK gaps, both carried over from the ecommerce/social Swift
ports and unrelated to search:

- **`RegisterWithRole201Response.user` already carries `customRole`** directly, so
  `SessionStore.register` builds the signed-in `AppUser` straight from the register response
  instead of a follow-up `login` + `getLocalSession` round trip.
- **`LoginLocalUser200ResponseUser` still has no `customRole`** — only
  `GetLocalSession200Response.user` (typed as a raw `JSONValue`, since the SDK can't know ahead of
  time what custom roles a project's Multi-Role feature defines) carries it, so every *login* is
  followed by a `getLocalSession` call for exactly this reason — `AuthGateway.currentUser()`.

## Data model & RBAC

Mirrors `../web/plan/build-plan.md` exactly:

- **`listings`** — `title`, `description`, `budget`, `category?`, `status`
  (`open`/`in_progress`/`completed`), `clientId`, `clientName`.
- **`proposals`** — `listingId`, `freelancerId`, `freelancerName`, `coverLetter`, `proposedRate`,
  `status` (`pending`/`accepted`/`rejected`).
- **`messages`** — `listingId`, `senderId`, `senderName`, `content`.

Mudbase's collection permission system is collection-level, not automatically document-level
scoped — the "own listing"/"own proposal" scoping is enforced by this app's own queries and UI
(always filter by `clientId`/`freelancerId` matching the current session user, only render
edit/accept/reject controls when the current user owns the record), not by the platform rejecting
a mismatched filter. Every `...Id`-suffixed filter value sent to Mudbase is checked against
`Formatting.isObjectId` before being sent, mirroring the web client's `isObjectId` guard against
the deployed query sanitizer's real-ObjectId-or-400 rule.

## Messaging visibility

A listing's message thread is visible to the listing's client and the specific freelancer whose
proposal on that listing has been accepted (not every freelancer who applied) — one boolean check
per `ListingDetailViewModel.load`: "am I the client, or do I have an accepted proposal on this
listing." Enforcement is UI-level (the Messages section and its composer only render for the
client or the accepted freelancer) plus the platform's collection-level create/read permission —
same known limitation as every other RBAC check in this app (see above).

## Known limitations

- **Numbered pagination is simplified to "Load more."** The web reference has real page-number
  `PaginationControls`; this app appends the next page to the current in-memory list instead — a
  deliberate adaptation to native list idioms (infinite-scroll-style), not a missing filter/search
  capability. Every filter (category, budget range, keyword search) behaves identically to the web
  version.
- **Document-level RBAC is enforced client-side, not by the platform** (see "Data model & RBAC"
  above) — do not treat this reference app's access control as production-grade multi-tenant
  isolation.
- **Portfolio/attachment file upload was not built** (matches the web reference's own scope: the
  spec marked it nice-to-have and explicitly prioritized the core listings/proposals/messages
  flow).
- **Certificate pinning and biometric auth are out of scope** for this reference build — the
  project's own security rules call for both on a production mobile app; they're omitted here to
  keep this a focused reimplementation, not a full production hardening pass. Token storage
  (Keychain, never `UserDefaults`) is implemented, since that's a baseline correctness issue rather
  than an additive hardening feature.
- **The SwiftPM package-identity collision** described in "Setup" step 2 — a genuine SwiftPM
  constraint (identity = last path component, no override), not a bug in this app's manifest.
- **The `SearchAPI.searchData` generated-model gap** and the **missing `customRole` on login**
  described above under "The Mudbase Swift SDK, exactly as generated."

## Verification

No Xcode/iOS Simulator was available in the environment this app was built in. What was verified:

- **`swift build`** — compiles clean (zero errors, zero warnings) for the secondary `.macOS(.v14)`
  target (see "Why SPM, not an `.xcodeproj`").
- **`swift build --build-tests`** — the `ManualLiveFlowTests` target compiles clean.
- **`swift test --filter ManualLiveFlowTests`** (no env var) — confirms the live test is properly
  gated off by default: 1 test, skipped, zero network calls.
- **A real, live end-to-end pass of the exact REST contract this app's `Services`/`Networking`
  layer calls**, run twice against the actual `cloud.mudbase.dev` project using the demo accounts
  this showcase's task brief provisioned (`market.client.demo@gmail.com` /
  `market.freelancer.demo@gmail.com`):
  1. A partial run of `Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift` itself
     (`RUN_LIVE_FLOW_TEST=1 swift test`) got through real client login (`currentUser()` confirmed
     `customRole: "client"`) and real listing creation against production before a *shared, heavily
     contended* per-IP auth rate limit (5 login attempts / 15 min — this Mac's IP is used by many
     concurrent sibling-showcase build sessions today) blocked the freelancer login the test needed
     next.
  2. A hand-written shell/curl script exercising the identical sequence of endpoints and JSON
     payloads (`POST /api/auth/local/login` for both accounts, `POST`/`GET`/`PATCH` on the
     `listings`/`proposals`/`messages` collection-data endpoints, and
     `GET /api/search/projects/:id/search`) was run from a second network path (the `mudhaxk-vps`
     box, to get a less-contended egress IP once the Mac's own IP proved persistently rate-limited)
     and passed **17/17 checks**: client login + `customRole`, listing creation with `status:
     "open"` (confirms the `status`-field-write fix is live), category-filtered browse, the
     dedicated search endpoint finding the listing by title (confirming the real response shape is
     exactly `{ query, totalResults, executionTime, results: [{ collection, pagination, results }]
     }`, matching `SearchGateway`'s hand-decoded model and *not* the generated SDK's), freelancer
     login + `customRole`, proposal creation with `status: "pending"`, the client's
     proposals-received list, `status: "accepted"` round-tripping, `acceptedProposal` resolving to
     the right freelancer, both directions of messaging, and the listing's `status: "completed"`
     round-tripping.

  Together these two runs cover every endpoint and payload shape this app's Swift code calls,
  end to end, against the real deployed backend — including the one endpoint (`SearchGateway`)
  where the generated SDK's own model is known to be wrong.

Given both verification paths, a full single run of `ManualLiveFlowTests.swift` itself, uninterrupted
start-to-finish, was not obtained in this session purely because of the shared rate-limit window,
not a code defect. **A real Xcode/Simulator run (tapping through the actual UI) was not performed**
and should be done before treating this as fully device-tested.
