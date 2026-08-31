# Mudbase Showcase - Marketplace (Flutter)

A Flutter reimplementation of the [Mudbase Showcase Marketplace](../web) - a freelance job board
with client/freelancer RBAC, listings, proposals, and per-listing messaging - talking directly to
`cloud.mudbase.dev` through the real, generated **Mudbase Dart SDK** (`mudbase_sdk`,
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), `dart/` subdirectory),
with **zero custom backend**.

## Stack

Flutter + Dart, Riverpod (`flutter_riverpod`, no code generation) for state, `go_router` for
navigation, `flutter_secure_storage` for the auth token. Same architecture as the sibling
`mudbase-showcase-kanban` Flutter port - see `plan/build-plan.md` "Auth model" for the one
deliberate divergence (this app has a real guest/anonymous browsing session; kanban does not).

## Setup

The Mudbase Dart SDK is **not published to pub.dev** - `pubspec.yaml` references it as a relative
path dependency assuming a sibling-clone layout:

```yaml
mudbase_sdk:
  path: ../../mudbase-sdk/dart
```

`mobile-flutter/` sits one level inside the `mudbase-showcase-marketplace` repo, so reaching a flat
sibling of that repo takes exactly two `../` segments (`mobile-flutter/` → `mudbase-showcase-marketplace/`
→ parent → `mudbase-sdk/dart`).

Before anything else, clone `mudbase-sdk` as a sibling of `mudbase-showcase-marketplace` itself
(same parent directory):

```bash
# from the directory that contains mudbase-showcase-marketplace/
git clone https://github.com/mudbase/mudbase-sdk.git
```

Then:

```bash
cd mobile-flutter

# First time only (or after upgrading Flutter) - generates/refreshes the
# android/, ios/, etc. platform folders. Safe to re-run.
flutter create .

flutter pub get

cp dart_define.example.json dart_define.json
# dart_define.example.json already contains this showcase's real,
# already-provisioned project/collection ids (they're public, not secrets -
# see "Security" below). Override only if pointing at your own project.

flutter run --dart-define-from-file=dart_define.json
```

### Config (`--dart-define-from-file`, this project's Flutter convention)

Never a runtime `.env` file - every value is read via `String.fromEnvironment` in
`lib/config/env_config.dart`, which defaults every key to this showcase's real, already-provisioned
project. `dart_define.example.json` documents every key:

| Key | Notes |
|---|---|
| `MUDBASE_PROJECT_ID` | Not a secret - same as the web app's `NEXT_PUBLIC_MUDBASE_PROJECT_ID`. |
| `LISTINGS_COLLECTION_ID` | |
| `PROPOSALS_COLLECTION_ID` | |
| `MESSAGES_COLLECTION_ID` | |
| `MUDBASE_BASE_URL` | Defaults to `https://cloud.mudbase.dev`. |

`main()` calls `EnvConfig.assertConfigured()` before `runApp` and fails fast with a clear message
if any required key is somehow left empty.

There is **no secret of any kind in this app** - every value above is safe to ship in a mobile
bundle.

## Demo accounts

Sign in from the login screen's quick-fill buttons, or type the credentials manually:

| Role | Email | Password |
|---|---|---|
| Client | `market.client.demo@gmail.com` | `DemoTest123!` |
| Freelancer | `market.freelancer.demo@gmail.com` | `DemoTest123!` |

Real signup is also available (`/register`) - choose client or freelancer.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing (anonymous session) + real client/freelancer accounts | `POST /api/auth/anonymous`, `POST /api/auth/local/login`, `POST /api/auth/local/signup/:role` | `lib/features/auth/` |
| Browse listings - search, category, budget range, pagination | Collection read (`filter`+pagination) + dedicated search endpoint | `lib/features/listings/listings_controller.dart`, `lib/core/mudbase_search_service.dart` |
| Listing detail + proposal submission | Collection CRUD, `proposals` | `lib/features/listings/listing_detail_controller.dart`, `lib/features/proposals/widgets/proposal_submit_form.dart` |
| Proposals review + accept/reject | Collection CRUD, `PATCH status` | `lib/features/proposals/proposal_review_controller.dart` |
| Post/edit listing | Collection CRUD, `listings` | `lib/features/listings/listing_form_screen.dart` |
| Per-listing messaging (client + accepted freelancer only) | Collection CRUD, `messages`, 4s poll | `lib/features/messages/` |
| My listings / my proposals | Collection read, batched proposal-count / listing-title lookups | `lib/features/listings/my_listings_*`, `lib/features/proposals/my_proposals_*` |

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | yes | yes |
| Create/update own listing | yes | no |
| Read proposals | yes (on own listings) | yes (own proposals) |
| Accept/reject proposal | yes (on own listings' proposals) | no |
| Create own proposal | no | yes |
| Create + read messages | yes (own listings) | yes (accepted proposal only) |

The UI hides write controls a role cannot use; document-level scoping ("own listing"/"own
proposal") is enforced by this app's own queries - see `plan/build-plan.md` "Known limitations" for
why this isn't platform-enforced document-level RBAC.

## Design choice: no realtime channel

Unlike the sibling `mudbase-showcase-kanban`/`mudbase-showcase-social` Flutter ports, this app has
no Socket.IO subscription. The reference web app's own `plan/build-plan.md` documents this as a
deliberate stack decision (polling + cache invalidation is sufficient at this demo's scale and
keeps every port of this showcase simpler to mirror) - this port follows the same call.
`MessageThreadController` polls every 4 seconds while its screen is open.

## Known limitations (real platform constraints and reference-app parity choices, not bugs)

See `plan/build-plan.md` → "Known limitations" - no listing delete flow (the web reference never
built one either), document-level RBAC is UI/query-enforced rather than platform-enforced, and
this project's login endpoint is rate-limited (5 requests / 15 minutes per IP) and shared across
every language/platform port's own smoke test.

## Architecture decisions

- **Riverpod without code generation**, same reason as the sibling kanban/social/ecommerce ports:
  this environment has no Flutter SDK installed to iteratively verify `build_runner` output
  locally - every provider and model here is verifiable by `dart analyze` alone (and, for the
  Flutter-free layer, actually was - see `plan/build-plan.md` "Testing Note").
- **A real guest/anonymous session** (unlike the sibling ports) - see `plan/build-plan.md` "Auth
  model" for the full rationale; this app's own web reference explicitly documents guest browsing
  as a feature.
- **`FamilyAsyncNotifier` per listing/proposal-list/message-thread** rather than one giant
  screen-wide controller - a listing detail screen, its proposal review list, and its message
  thread each have independent loading/error/mutation lifecycles, and keeping them as separate
  family-keyed providers means navigating to a different listing never carries over stale state
  from the previous one.

## Testing

`test/models/` and `test/core/` use plain `package:test` (not `flutter_test`) specifically so they
run with **plain `dart test`, independent of the Flutter SDK** - and they were: **48/48 passed**
in this build (see `plan/build-plan.md` "Testing Note" for exactly how).

```bash
dart test test/core test/models   # runs today, no Flutter SDK needed
flutter test                      # once Flutter is installed
```

`tool/manual_test.dart` is a standalone live smoke-test script against the real project - see
`plan/build-plan.md` → "Live Smoke Test Results"; it was executed for real during this build via
the scratch-package technique documented there.

## Verification

```bash
dart format --set-exit-if-changed .
dart analyze     # requires `flutter pub get` first once Flutter is installed
flutter test
```

## License

MIT - see the repo root [LICENSE](../LICENSE).
