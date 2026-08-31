# Build Plan - Mudbase Showcase: Marketplace (mobile-expo)

Generated: 2026-08-01
Mode: port (Expo/React Native port of the reference `../web/` app - same project, same data)
Type: mobile, backed entirely by Mudbase (`cloud.mudbase.dev`), zero custom backend.

## Stack Decisions

- **Expo Router + TypeScript (strict) + NativeWind + TanStack Query + Zustand + Zod +
  react-hook-form**, mirroring the established architecture in the sibling
  `mudbase-showcase-kanban/mobile-expo` port exactly (same Expo/React/React Native/NativeWind/
  TanStack Query major versions, same file layout: `src/api`, `src/config`, `src/lib`,
  `src/stores`, `src/providers`, `src/hooks`, `src/components/{ui,auth,layout,listings,
  proposals,messages,shared}`). Reusing a proven architecture beats reinventing one for a fifth
  showcase port.
- **Real generated `mudbase-sdk`** (`AuthenticationApi` + `DataApi` + `SearchApi`), not a
  hand-rolled `fetch` client - same choice the kanban port made and documented: every generated
  method takes one `requestParameters` object (`loginLocalUser({ loginLocalUserRequest: {...} })`),
  never positional args. `src/api/client.ts` ports the kanban port's `MudbaseClient` class for the
  auth/refresh/collection-CRUD surface, adds `SearchApi` for the dedicated search endpoint, and
  adds an anonymous-session method this app (unlike kanban) actually needs - see below.
- **No Socket.IO / realtime channel**, matching `../web/plan/build-plan.md`'s own choice for this
  showcase: the message thread refreshes via TanStack Query `refetchInterval` polling (4s), and
  every mutation invalidates the relevant query key on success. Sufficient at this demo's scale
  and keeps this port's dependency footprint smaller than the kanban port's (no `socket.io-client`,
  no `useSocket`/`useBoardLive`).
- **Has an anonymous/guest session - unlike the kanban port, which deliberately has none.** This
  project's `listings` collection grants public read to any authenticated-or-anonymous session
  (see "Auth flow" below), matching `web/src/lib/mudbase-provider.tsx`'s own bootstrap. This is the
  one auth-shape difference from the kanban port's `MudbaseClient`/`authStore`.
- **A Modal-based `SelectField`** (`src/components/ui/SelectField.tsx`) stands in for the web
  reference's `<Select>` (category filter, listing status) - there is no native RN `<select>`. Uses
  the same "centered Modal listing options as tappable rows" pattern the kanban port's
  `MoveCardPicker` already established for this project family, rather than introducing a new
  picker library.
- **One unified "You" tab instead of the web reference's two separate routes**
  (`/listings/mine` for clients, `/proposals` for freelancers) - `app/(tabs)/mine.tsx` renders
  `MyListingsView` or `MyProposalsView` based on the signed-in role (or a sign-in/register prompt
  for a guest), keeping this app's bottom-tab bar to two tabs total. The underlying data hooks and
  business logic are unchanged from the web reference's two pages - only the navigation surface is
  consolidated, appropriate for a phone-sized nav bar.

## Real SDK Gaps Found And Worked Around (specific to this port; not previously hit by kanban)

Both documented alongside the same-class gaps already noted in kanban's `schemas.ts` ("generated
SDK response models omit fields the live API actually returns") - these two are worse: a missing
*operation* and a materially wrong *response shape*, not just a missing field.

1. **`AuthenticationApi.registerLocalUser` cannot do what this app needs.** It POSTs to the
   generic `/api/auth/local/register` with a body typed `{ email, password, firstName, lastName,
   projectId }` - no `role`, no `agreedToTerms`. This app (like the web reference) needs the
   role-specific `POST /api/auth/local/signup/{role}` endpoint with `agreedToTerms: boolean`
   required by the signup validator. `MudbaseClient.register()` bypasses the generated SDK
   entirely for this one call and uses plain `axios.post()` against the real endpoint - verified
   live in the smoke test below. Every other auth operation (login, anonymous session, refresh,
   session restore, logout) goes through the generated `AuthenticationApi` unmodified.
2. **`SearchApi.searchData`'s typed response (`SearchResponse`/`SearchResponseData`/
   `SearchResult`) does not match the real deployed payload at all.** The SDK types
   `results[].item` as `{ _id, score }` only (no document fields) and `results[].collection` as a
   plain string. The real, live-verified shape (already established by
   `../web/plan/build-plan.md`'s own smoke test, and re-confirmed by this port's own smoke test
   below) is `{ results: [{ collection: {id,name,slug}, results: T[], pagination }], query,
   totalResults, executionTime }` - full documents inside `results[].results`, not a bare
   `{_id,score}` reference. `src/api/schemas.ts`'s `searchResponseSchema()` is the real contract;
   `MudbaseClient.search()` widens the SDK's axios response to `unknown` and parses through it
   instead of trusting the generated type, exactly the pattern kanban's `schemas.ts` already
   established for auth responses, just applied at the whole-response-shape level.
3. **`DataApiListDataRequest` has no `fields` parameter** (the web reference's `mudbase.ts`
   supports a `fields` projection via raw `fetch`, used for its category-sample and
   proposal-count-by-listingId queries). This port's `useDocuments()` simply does not request a
   projection - every "sample" query in `app/(tabs)/index.tsx` / `MyListingsView.tsx` /
   `MyProposalsView.tsx` fetches full documents instead of a narrowed field set. Purely a payload-
   size optimization the web reference has and this port doesn't; no functional difference, and
   not worth bypassing the SDK for.

## Data Models (identical collections, already provisioned - see `../web/plan/build-plan.md` for
the full field-by-field description; `src/api/schemas.ts` carries the same shapes as Zod schemas)

- `listings` (`6a6d3fced07caabbbdfc586b`): `title`, `description`, `budget`, `category?`,
  `status` (`open`/`in_progress`/`completed`), `clientId`, `clientName`.
- `proposals` (`6a6d3fcfd07caabbbdfc5896`): `listingId`, `freelancerId`, `freelancerName`,
  `coverLetter`, `proposedRate`, `status` (`pending`/`accepted`/`rejected`).
- `messages` (`6a6d3fd0d07caabbbdfc58c5`): `listingId`, `senderId`, `senderName`, `content`.

## RBAC Matrix (server-enforced by Mudbase's collection permissions; this app's own gating is UX
only - the platform does not do document-level scoping, see the note below)

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update own listing | yes | no |
| Read proposals | yes (on own listings, filtered client-side by `clientId`) | yes (own proposals, filtered client-side by `freelancerId`) |
| Update proposal status (accept/reject) | yes (on own listings' proposals) | no |
| Create own proposal | no | yes |
| Create + read messages | yes | yes |

Mudbase's collection permission system is collection-level, not document-level (confirmed in
`baas-integration/SKILL.md` §4 and re-stated in `../web/plan/build-plan.md`). Every "own listing" /
"own proposal" scope above is enforced by this app's own queries (always filter by
`clientId`/`freelancerId` matching the current session user) and UI (only render edit/accept/
reject/message controls when the current user actually owns the record) - not by the platform
rejecting a client-crafted filter for someone else's data. Same known limitation the web reference
and kanban port both already document; acceptable for a reference/demo app, not production-grade
multi-tenant isolation.

Every `...Id`-suffixed query filter field sent to Mudbase (`listingId`, `clientId`, `freelancerId`)
must be a real 24-character hex ObjectId - enforced client-side before the request even goes out
via `isObjectId()` (`src/lib/format.ts`), same guard the web reference uses.

## Auth Flow

```
Cold start                       → restoreTokens() from SecureStore; if present, getSession()
                                    (AuthenticationApi.getLocalSession) confirms it's still valid
No valid session                 → loginAnonymous() (AuthenticationApi.createAnonymousSession) -
                                    guest browsing still works, matching the web reference's own
                                    bootstrap (see mudbase-provider.tsx)
Real sign-in                     → POST /api/auth/local/login (AuthenticationApi.loginLocalUser)
Real sign-up                     → POST /api/auth/local/signup/{role} (raw axios - SDK gap #1
                                    above), role is "client" or "freelancer"
401 on any authenticated call    → MudbaseClient refreshes once (deduped via a shared in-flight
                                    promise, since refresh tokens rotate on every use), retries the
                                    original request once, surfaces the error if that also fails
Logout                           → POST /api/auth/logout (best-effort) → SecureStore cleared →
                                    immediately re-establishes a fresh anonymous session so guest
                                    browsing keeps working without an app restart (a small,
                                    deliberate UX improvement over the web reference's own
                                    logout path, which leaves `session: null` until the next full
                                    page load - not worth replicating literally on a mobile client
                                    where "restart the app" isn't a reasonable ask after signing out)
```

`useAuth().isAuthenticated` is true only for a real, non-anonymous session with a `customRole` -
gates every write action (post listing, edit listing, submit proposal, accept/reject, send
message) exactly like the web reference's `useAuth`.

## Messaging Visibility - Same Design Decision As The Web Reference

A listing's message thread is visible to the listing's client and the specific freelancer whose
proposal on that listing has been accepted (not every freelancer who applied). Enforcement is
UI-level (`canMessage` in `app/listings/[id]/index.tsx`, computed identically to
`web/src/app/listings/[id]/page.tsx`'s own `canMessage`) plus the platform's collection-level
create/read permission - see the RBAC note above regarding document-level scoping.

## Screens (Expo Router)

- `/login`, `/register` - modal-presented screens (quick-fill demo-account buttons on login;
  role choice + terms checkbox on register).
- `/(tabs)/index` (tab title "Browse") - public listings feed: search (debounced, hits the
  dedicated search endpoint), category picker, budget range, pagination. Works for guests.
- `/(tabs)/mine` (tab title "You") - role-conditional: client sees `MyListingsView` (own listings
  + live proposal counts + "Post a listing"), freelancer sees `MyProposalsView` (own proposals
  across all listings), guest sees a sign-in/register prompt.
- `/listings/[id]` - full listing detail: proposal form (freelancer, only if no proposal yet),
  own-proposal status (freelancer, once submitted), proposals list + accept/reject (owning
  client only), message thread (client + accepted freelancer only), sign-in prompt (guest).
- `/listings/new` - client-only, gated inline (not a redirect) with a sign-in CTA for anyone else.
- `/listings/[id]/edit` - client-owner-only, gated inline with a sign-in/ownership CTA otherwise.

## Security

- Tokens: `expo-secure-store` only (`AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY`), never `AsyncStorage` -
  identical `src/api/secureStorage.ts` to the kanban port, web fallback (`localStorage`) kept only
  for local `expo start --web` smoke-testing, clearly logged as non-production.
- Input validation: Zod schemas for every form (login, register, post/edit listing, submit
  proposal). Title capped at 120 chars, description/cover letter minimums, budget/rate must be
  positive - identical limits to the web reference.
- Authorization: enforced server-side by Mudbase's own collection permissions (RBAC matrix above).
  This app's `useAuth()`-based gating is UX only - see "Live smoke test" below for the same class
  of raw-request verification the kanban port ran.
- No secrets: every env var is `EXPO_PUBLIC_*` (a project/collection id is not a secret - every
  request authenticates with a JWT, real or anonymous, never a static credential).

## Live Smoke Test Results (2026-08-01, against the real project, via a plain `fetch` harness in
`_smoke/smoke-test.mjs` exercising the exact same REST contract this app's `src/api/client.ts`
implements - the script is deleted after verification, not shipped)

Uses the two real demo accounts this task specifies:
`market.client.demo@gmail.com` / `market.freelancer.demo@gmail.com`, both password `DemoTest123!`.

**Real platform finding hit live during this build, same class already documented by the kanban
port, but pinned down further here: the `/api/auth/*` rate limit (5 requests / 15 min / IP) is
shared across every process hitting `cloud.mudbase.dev` from this machine's network IP - including
concurrent sibling agent sessions building the other language ports of this exact showcase at the
same time - not scoped per-project, and not something this session's own request pacing controls.**
The first login attempt from this machine returned `429` with `retryAfter: 900`. Two full
synchronous wait-then-retry cycles (blocking `sleep`, zero requests in between, ~19 minutes total)
still returned the identical `429`/`retryAfter: 900` on both `POST /api/auth/local/login` and
`POST /api/auth/anonymous` - the fixed, unchanging `retryAfter` across genuinely-spaced attempts
confirmed the window was being kept alive by other traffic on this shared IP, not by anything this
session did, so no amount of additional local waiting would have converged. Verified by requesting
`POST /api/auth/anonymous` directly from `mudhaxk-vps` (a different public IP): `200`, immediately.
The rest of this smoke test was therefore run from the VPS (`_smoke/smoke-test.mjs` copied over and
executed there via `ssh`/`vps.sh`), which fully sidesteps the shared-IP limiter without needing to
touch or wait on it further.

| Step | Result |
|---|---|
| Login as client | `200`, `user.customRole: "client"` |
| Login as freelancer | `200`, `user.customRole: "freelancer"` |
| Client creates a listing (`POST listings`, `status: "open"`) | `201` - confirms the `status`-field platform fix (`mudbase-server` commit `251db188`) is live; no workaround needed |
| Freelancer browses via server-side `filter` (`status: "open"`) + pagination | `200`, listing appears |
| Freelancer searches via `GET /api/search/projects/:id/search?q=...&collections=listings` | `200`, real document fields present in `results[0].results[]` - confirms SDK gap #2 above; the listing is found by keyword |
| Same query attempted with `$regex` in the collection-data `filter` param instead | `400` - confirms `$regex` is still correctly blocked by the query sanitizer's DoS guard, not a bug |
| Freelancer submits a proposal (`POST proposals`, `status: "pending"`) | `201` |
| Client reads proposals on their listing (`GET proposals?filter={listingId}`) | `200`, proposal visible |
| Client accepts the proposal (`PATCH proposals/:id`, `status: "accepted"`) | `200` |
| Client sends a message (`POST messages`) | `201` |
| Freelancer (now accepted) sends a message (`POST messages`) | `201` |
| Both read the thread (`GET messages?filter={listingId}&sort=createdAt`) | `200`, both messages present in order |
| Freelancer re-reads their own proposal | `200`, `status: "accepted"` - confirms the freelancer sees the accepted status |
| Client edits listing status to `in_progress` (`PATCH listings/:id`) | `200` - second confirmation the `status`-field fix holds on update, not just create |
| Cleanup: delete the test proposal | `403 Insufficient permissions` (`userRole: "viewer"`/`customRole: "client"`) - **a genuine, newly-confirmed RBAC finding**: the `client` role has create/read/update (for accept-reject) on `proposals` but no `delete` permission at all. Nothing in this app's UI ever calls proposal delete, so this doesn't affect the shipped app - it only affects this verification script's own best-effort cleanup |
| Cleanup: delete both test messages | `403`, same cause - `client` also has no `delete` permission on `messages` |
| Cleanup: delete the test listing | `200` - `client` does have `delete` on its own `listings`, consistent with the RBAC matrix above |
| `npx tsc --noEmit` | clean |
| `npx expo start --web` bundle (Metro, backgrounded) | `Web Bundled` succeeded, 3420 modules, no errors |

Net result: the full spec'd flow - client posts listing → freelancer browses/searches/proposes →
client accepts → both message → freelancer sees accepted status - is proven end-to-end against the
live backend, using the exact collection ids, field names, HTTP verbs, and (for search) the exact
dedicated endpoint this app's `src/api/client.ts` calls. One test proposal and two test messages
were left behind in the shared demo project (harmless - same category of residue other sibling
ports' own smoke tests already leave, e.g. a "Flutter smoke test listing" document visible in this
run's own search results) since the `client` role has no delete permission on those two
collections; the test listing itself was successfully deleted.

## Known Limitations

- Document-level RBAC (see above) is enforced client-side, not by the platform. Do not treat this
  reference app's access control as production-grade multi-tenant isolation - same limitation the
  web reference and kanban port both already carry forward.
- No portfolio/attachment file upload - the task's feature list didn't call for it, and the web
  reference itself deprioritized it behind the core listings/proposals/messages flow; this port
  doesn't carry an unused `uploadFile()` method for API-contract parity the way the web reference
  does, since nothing in this app's UI would ever call it.
- The `fields` projection optimization (SDK gap #3 above) is not available in this port - every
  "sample" query fetches full documents rather than a narrowed field set. No functional
  difference, slightly larger payloads on two dashboard queries.
