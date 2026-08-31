# Build Plan - Mudbase Showcase: Marketplace (Flutter)

Flutter/Dart port of the freelance Marketplace showcase, built to match the reference
implementation's (`../web`) data model, RBAC, and messaging-visibility rule exactly. Architecture
mirrors the sibling `mudbase-showcase-kanban/mobile-flutter` port: Riverpod (`flutter_riverpod`, no
code generation), `go_router`, `flutter_secure_storage`, and the real generated Mudbase Dart SDK
(`mudbase_sdk`) resolved as a sibling-checkout path dependency.

## Stack

- Flutter + Dart, `flutter_riverpod` (plain `AsyncNotifier`/`FamilyAsyncNotifier`, no
  `riverpod_generator`/`freezed`) for state, `go_router` for navigation.
- `dio` (via `MudbaseSdk().dio`) for HTTP, bypassing the SDK's generated `*Api` wrapper classes for
  auth/data/search - see `core/auth_service.dart` header for why (the generated response models
  silently drop `customRole` and every field this app actually needs beyond `_id`/`createdAt`/
  `updatedAt`).
- `flutter_secure_storage` for the auth token (Keychain/EncryptedSharedPreferences) - never
  `SharedPreferences`.
- No Socket.IO / realtime channel, matching the reference web app's own stack decision - the
  message thread polls every 4s (`MessageThreadController`) and every mutation invalidates/refetches
  its own provider, same as the web app's TanStack Query `refetchInterval` + cache invalidation.

## Mudbase project (already provisioned - do not recreate)

- Base URL: `https://cloud.mudbase.dev`
- Project ID: `6a6d3faad07caabbbdfc56a6`
- `listings` (`6a6d3fced07caabbbdfc586b`), `proposals` (`6a6d3fcfd07caabbbdfc5896`), `messages`
  (`6a6d3fd0d07caabbbdfc58c5`) - full field schema in `../web/plan/build-plan.md`, mirrored exactly
  by `lib/models/listing.dart` / `proposal.dart` / `message.dart`.

## Auth model - the one deliberate divergence from the sibling kanban/social/ecommerce ports

Unlike those ports (no anonymous session, every screen behind a login wall), this app has a real
guest/anonymous session, because its own web reference explicitly documents guest browsing as a
feature: `MudbaseProvider` establishes an anonymous session on mount so the public listings feed
reads without forcing signup. `AuthController.build()` mirrors this - restores a stored real
session if one exists, otherwise (or on failure) establishes a fresh anonymous one via
`POST /api/auth/anonymous`. `state.valueOrNull` is therefore *never* `null` once bootstrapped;
screens gate write actions on `user.isAuthenticated` (a real, role-carrying account: not anonymous
AND has a `customRole`), not on session-presence.

One improvement over strictly mirroring the web app: `AuthController.logout()` immediately
re-establishes a fresh anonymous session afterward, rather than leaving the session `null` the way
the web app's `MudbaseProvider` does post-logout (its own `useEffect` that calls
`loginAnonymous()` only runs once, on mount - a real gap in the reference implementation that a
page reload papers over on web, but a mobile app has no equivalent "reload" affordance for). See
`lib/features/auth/auth_controller.dart` class doc for the full rationale.

## Router

`go_router`'s `redirect` allows guest browsing everywhere except a small explicit set of
role-gated routes (`/listings/new`, `/listings/mine`, `/proposals/mine`, and any `/listings/:id/edit`)
- mirrors the web app's own per-page `isAuthenticated`/`role` guards rather than a single blanket
auth wall (contrast with the kanban port, which has no guest session at all and gates every route).
Role *mismatch* (e.g. a freelancer opening `/listings/new`) is handled in-screen with a message, not
by the router - same as the reference web app's own pages.

## Messaging visibility

Exactly the reference web app's rule: a listing's message thread is visible to the listing's client
and the specific freelancer whose proposal on that listing has been accepted - enforced in
`ListingDetailScreen.canMessage` (client OR (freelancer AND `acceptedFreelancerId == user.id`)) and
mirrored into `lib/features/messages/`. `ProposalReviewController.setStatus` invalidates the
surrounding `ListingDetailController` family instance after every accept/reject so message-thread
visibility updates live the moment a proposal is accepted, without a manual screen refresh.

## Platform facts carried over from the reference web app (already fixed / already true - not
rediscovered here)

1. `status` field writes on `listings`/`proposals` are **not** blocked (fixed in `mudbase-server`
   commit `251db188`, already deployed) - verified again live in this build's own smoke test
   (listing create with `status: "open"`, proposal accept via `status: "accepted"` both succeed).
2. Search **must** use `GET /api/search/projects/:id/search`, never `$regex`/`$text` - both are
   hard-blocked by the query sanitizer's DoS guard. `MudbaseSearchService` is the only place this
   app builds a search request; `ListingRepository.search()` is the only caller.
3. Every `...Id`-suffixed filter field sent to Mudbase must be a real 24-char hex ObjectId -
   `core/formatters.dart#isObjectId` guards every repository call that builds one
   (`clientId`/`freelancerId`/`listingId` filters), matching the web app's `isObjectId()`.

## Testing Note (environment constraint)

This build environment has no Flutter SDK installed - confirmed with `which flutter` before
writing any code. `test/core/` and `test/models/` therefore depend on nothing but `dart:core`,
`dio`, and this app's own pure-Dart files (never `package:flutter`), so they run with plain
`dart test`, independent of Flutter, via a throwaway "scratch package" (copy the Flutter-free
subset of `lib/` - `core/`, `models/`, `data/repositories/`, `config/` - into a package with a
`flutter`-free `pubspec.yaml` that still resolves the real `mudbase_sdk` path dependency).
**48/48 tests passed** this way, and `dart analyze` on that same scratch package reported
**no issues**.

`tool/manual_test.dart` is a standalone live smoke-test script exercising this exact layer against
the real, live project - run the same way. See "Live Smoke Test Results" below.

Full `flutter analyze`/`flutter test` (covering the widget/riverpod/go_router layer this
Flutter-free scratch package can't reach) was run separately with a real Flutter SDK installed on
the project's VPS (`mudhaxk-vps` - see the builder root `CLAUDE.md` "VPS Offload"), since installing
a multi-hundred-MB SDK locally for a single verification pass isn't worth the disk/bandwidth cost
on this machine.

## Live Smoke Test Results

Full flow exercised end-to-end against the real, live project (`dart run tool/manual_test.dart`)
using the two pre-provisioned demo accounts (`market.client.demo@gmail.com` /
`market.freelancer.demo@gmail.com`, password `DemoTest123!`). **Result: 17/17 steps passed.**

```
Mudbase Showcase Marketplace (Flutter) - live manual smoke test
Base URL: https://cloud.mudbase.dev
Project:  6a6d3faad07caabbbdfc56a6

- login as Client ... PASS
- login as Freelancer ... PASS
- Client posts a new listing ... PASS
- Freelancer browses listings and finds the new one (server-side filter) ... PASS
- Freelancer searches for the listing by keyword (dedicated search endpoint, not $regex) ... PASS
- Freelancer submits a proposal on the listing ... PASS
- Client reads proposals received on the listing and finds it pending ... PASS
- Client accepts the proposal (status field write - previously blocked, fixed in mudbase-server commit 251db188) ... PASS
- acceptedFreelancerId now resolves to the freelancer (drives message thread visibility) ... PASS
- Client sends a message on the listing thread ... PASS
- Freelancer (now accepted) reads the thread and sees the client's message ... PASS
- Freelancer replies on the thread ... PASS
- Client reads the thread and sees the freelancer's reply ... PASS
- Freelancer's own proposal now reads back as accepted ... PASS
- POST /api/auth/refresh returns a new, distinct, usable token pair ... PASS
- An invalid access token is rejected with a real 401 ... PASS
- Sign out (best-effort server-side revoke) ... PASS

Passed: 17, Failed: 0
```

This project's `/api/auth/local/login` endpoint is rate-limited to 5 requests / 15 minutes per IP
and is shared across every language/platform port's own smoke test on this project, often run
concurrently by several build sessions at once - a `429` here is a real, expected platform control,
not a bug. Observed live during this build: a run from one egress IP 429'd on the client login while
the freelancer login on that same run succeeded moments later, and a fresh attempt right after (same
process, same IP) then passed both logins cleanly - contention is a shared, per-window resource
across every concurrent smoke test on this project, not a fixed per-caller quota. The test script
waits out a 429 with a bounded retry (`_withRateLimitRetry`, 3 attempts / 90s backoff) rather than
failing outright, and only ever spends exactly two login calls per full run (client once, freelancer
once - the refresh-token test reuses the freelancer's already-captured refresh token instead of a
third login).

## Code review fixes (applied before this app was considered done)

A `flutter-reviewer` pass over the finished app (after `flutter analyze`/`flutter test` were already
clean) found three real issues, all fixed:

1. **HIGH - `MessageThreadController`'s 4-second poll timer never stopped when the user navigated
   away.** `messageThreadControllerProvider` (and `listingDetailControllerProvider`,
   `proposalReviewControllerProvider`) were plain (non-`autoDispose`) `AsyncNotifierProvider.family`
   instances - Riverpod kept every family instance (and, for the message thread, its live
   `Timer.periodic`) alive for the whole app session even after the last widget listener unmounted.
   Fixed by converting all three to `AsyncNotifierProvider.autoDispose.family` /
   `AutoDisposeFamilyAsyncNotifier`, so each listing's detail/proposal-review/message-thread state
   (and the message thread's polling timer) is torn down once its screen is no longer watched.
2. **MEDIUM - a race in the 401 → refresh-fails → anonymous-fallback path.** `_refreshAccessToken()`
   already deduped concurrent refresh attempts via an in-flight future, but the anonymous-session
   fallback it falls through to on refresh failure did not - two concurrent `callAuthorized` calls
   hitting this path at once could each clear storage and re-log-in anonymously independently. Fixed
   by giving `_fallBackToAnonymous()` the same in-flight-future dedup pattern.
3. **LOW - signing out briefly flashed the splash screen.** `AuthController.logout()` set
   `state = const AsyncLoading()` while re-establishing the post-logout anonymous session, and the
   router's `_AuthRefreshNotifier` sends any non-`/splash` location to `/splash` while auth state is
   loading - so "Sign out" briefly bounced the UI to splash and back. Fixed by not emitting an
   intermediate loading state during logout; the previous (signed-in) user's data simply stays on
   screen until the new anonymous session lands.

Also caught during this pass (not by the reviewer, by a manual route audit): `RegisterScreen`
navigated a newly-registered freelancer to `/proposals`, a route that doesn't exist (the real route
is `/proposals/mine`) - would have 404'd into the router's `errorBuilder` immediately after every
freelancer signup. Fixed.

## Known limitations

- No listing delete flow - matches the reference web app exactly (its own RBAC matrix documents
  "delete own listing" as a client permission, but no page or component ever calls it; kept out of
  this port too rather than adding a feature branch the web reference itself doesn't exercise).
- Document-level RBAC ("own listing"/"own proposal" scoping) is enforced by this app's own
  queries/UI, not by the platform rejecting a filter for someone else's data - same documented
  limitation as the web app and every other showcase port.
- Portfolio file upload was not built, matching the web app's own "Known limitations" (deprioritized
  behind the core listings/proposals/messages flow).
