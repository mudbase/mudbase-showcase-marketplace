# Mudbase Showcase — Marketplace (PHP)

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database,
and role-based access control — with **zero custom backend**, reimplemented as a plain,
server-rendered PHP application. This is a port of the reference Next.js app in `../web`; see that
project for the canonical data model and API contract.

## Stack

Plain PHP 8.1+ (no framework — no Laravel/Symfony), PHP's built-in dev server for local
development, and the real generated `mudbase/sdk` Composer package. Architecture mirrors the
sibling `mudbase-showcase-kanban/php` port: `Router` → `Controllers` → `View` + plain `.php` view
files, a request-scoped `AppContext`, and a `MudbaseClient` wrapper around the SDK.

Auth is session-based: the Mudbase JWT pair lives in native PHP `$_SESSION`, not `localStorage` —
there is no client-side JavaScript auth flow, and in fact **no client-side JavaScript at all** in
this app. Every interaction — sign in, post/edit a listing, submit a proposal, accept/reject, send
a message — is a plain HTML `<form>` POST.

Unlike the kanban PHP port (every role requires a real login, no guest mode at all), this app's
listings feed is **publicly browsable**: `bootstrap.php` establishes an anonymous guest session
(`POST /api/auth/anonymous`) whenever a request arrives with no session at all, mirroring the
reference Next.js app's `MudbaseProvider` mount effect. Posting a listing, submitting a proposal,
accepting/rejecting, and messaging all still require a real, role-carrying `client`/`freelancer`
account.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Two-role auth (client / freelancer) | Multi-Role login (`POST /api/auth/local/login`, `user.customRole`) | `src/Controllers/AuthController.php`, `src/Http/AppContext.php` |
| Public anonymous browsing | `POST /api/auth/anonymous` | `src/bootstrap.php` |
| Listings browse with search/category/budget filters + pagination | Collection filter/sort/page + dedicated search endpoint | `src/Controllers/ListingController::index`, `src/Mudbase/MudbaseClient::search` |
| Post / edit a listing (owner-only) | Collection CRUD, `listings` | `src/Controllers/ListingController::create/update` |
| Submit a proposal (freelancer), one per listing | Collection CRUD, `proposals` | `src/Controllers/ProposalController::create` |
| Review proposals + accept/reject (owning client only) | `PATCH` `proposals.status` | `src/Controllers/ProposalController::accept/reject` |
| Per-listing messaging, client + accepted freelancer only | Collection CRUD, `messages` | `src/Controllers/MessageController::send` |

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | ✅ (incl. anonymous guests) | ✅ (incl. anonymous guests) |
| Create/update own listing | ✅ | ❌ |
| Read proposals | ✅ (on own listings) | ✅ (own proposals) |
| Accept/reject a proposal | ✅ (on own listings' proposals) | ❌ |
| Submit a proposal | ❌ | ✅ |
| Send/read messages on a listing | ✅ (if the listing is theirs) | ✅ (if their proposal on it was accepted) |

Mudbase's collection permissions are **collection-level, not document-level** — a client's write
permission on `listings` doesn't by itself stop them from editing *someone else's* listing, and the
same is true for proposal accept/reject and messaging. Every action above that targets a specific
document (`ListingController::update`, `ProposalController::accept/reject`,
`MessageController::send`) therefore **re-fetches that document from Mudbase and verifies the
ownership field on the fetched record** (`listing.clientId`, or the accepted proposal's
`freelancerId`) against the current session's user id *before* writing anything — never trusting
the session's role alone, and never trusting any value a request claims about who owns what. This
is the same IDOR discipline the sibling C# Events port's booking-cancellation fix established
after a hidden-form value was found being trusted for ownership instead of the fetched record.
`src/Support/Rbac.php` only hides/disables controls a role cannot use in the rendered HTML — it is
not the security boundary.

## Getting started

This app expects a Mudbase project already provisioned with:

1. Local auth enabled with the Multi-Role feature, two role slugs: `client`, `freelancer`.
2. Three collections — `listings`, `proposals`, `messages` — with the field shapes documented in
   `plan/build-plan.md`.

```bash
composer install
cp .env.example .env   # fill in your own provisioned project's IDs
php -S localhost:8080 -t public public/router.php
```

Then visit `http://localhost:8080`. The feed loads immediately for anyone (anonymous guest
session). Sign in with one of the two demo accounts on the login page (one-click forms, or type
credentials manually) to post listings, propose, accept/reject, or message.

## Live smoke test

See `plan/build-plan.md` → "Live smoke test results" for the full flow verification against the
real project: client posts a listing, freelancer browses/searches and proposes, client accepts,
both parties message — plus a raw authenticated request from a *non-owning* second account proving
the accept/reject/edit/message ownership re-derivation rejects it server-side, not just a hidden UI
form.

## Known limitations (real platform/architecture constraints, not bugs)

- **No realtime.** The reference Next.js app polls `messages` via TanStack Query
  (`refetchInterval`). This server-rendered app has no persistent connection to attach a poll to —
  every mutation already redirects (`303`) back to a fresh page load, which shows the latest state,
  and the message thread itself reflects whatever was in Mudbase at the time of that render.
- **No portfolio file upload** — matches the reference app, which deprioritized it behind the core
  listings/proposals/messages flow.
- **No registration UI** — the task's two demo accounts already exist on the live project, and the
  explicit feature set for this port doesn't call for a signup flow; this app only signs in, it
  never signs up (any account created another way can still sign in here).
- **Document-level RBAC is enforced by this app's controllers, not by Mudbase's collection
  permissions** (see "RBAC matrix" above) — do not treat this reference app's access control as
  production-grade multi-tenant isolation beyond what's explicitly re-derived in each controller.

## Security

- CSRF token on every state-changing form, verified before any controller logic runs.
- Open-redirect guard (`Response::redirectToSafe()`) on the login `redirectTo` value.
- Session id regenerated on login/logout (privilege boundary crossing).
- All dynamic output escaped via `View::escape()` — no raw interpolation of user content anywhere.
- **Ownership re-derivation on every document-targeted mutation** — see "RBAC matrix" above. This
  is enforced in this app's controllers (`ListingController::fetchOwnedListingOrRedirect()`,
  `ProposalController::authorizeProposalOwnerOrRedirect()`, `MessageController::send()`), not by
  Mudbase's own collection permissions, which are collection-level only.

## Environment Variables

See `.env.example`.
