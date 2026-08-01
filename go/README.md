# Mudbase Showcase — Marketplace (Go)

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database,
and role-based access control — with **zero custom backend**, reimplemented as a server-rendered
Go application. This is a sibling port of the reference Next.js app in `../web` (see that project
for the canonical data model and API contract) and of `mudbase-showcase-kanban/go` /
`mudbase-showcase-social/go`, whose framework (`net/http` + `chi/v5` + `html/template`,
cookie-based session, the 401 → refresh → retry pattern) this app follows exactly — see
`plan/build-plan.md` "Stack Decisions".

## Stack

Go 1.26 + `net/http` + `chi/v5` + `html/template` + `gorilla/sessions`, talking directly to
`cloud.mudbase.dev` via `github.com/mudbase/mudbase-sdk/go`. Every page is server-rendered; there
is no client-side JavaScript framework and no API route of any kind that isn't Mudbase itself — the
Mudbase JWT lives only in an encrypted, httpOnly session cookie. The only JavaScript in this app is
one small poll-refresh `<script>` block on the listing detail page — this app's stand-in for the
reference web app's TanStack Query `refetchInterval` polling, since there is no official Mudbase Go
realtime client.

Like the sibling social port (and unlike kanban's every-role-must-sign-in model), this app
establishes an anonymous guest session on first visit so the public listings feed is browsable
without signup — mirroring the reference web app's own anonymous-browse bootstrap.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Two-role auth (client / freelancer) + anonymous guest browsing | Multi-Role login, `POST /api/auth/anonymous` | `internal/mbase/auth.go`, `internal/server/middleware.go` |
| Listings browse with search/category/budget filters + pagination | Collection filter/sort/page + dedicated search endpoint | `internal/store/listings.go`, `internal/mbase/search.go` |
| Post / edit a listing (owner-only, re-derived server-side) | Collection CRUD, `listings` | `internal/server/handlers_listings.go` |
| Submit a proposal (freelancer), one per listing | Collection CRUD, `proposals` | `internal/server/handlers_proposals.go` |
| Review proposals + accept/reject (owning client only, re-derived) | `PATCH` `proposals.status` | `internal/server/handlers_proposals.go`'s `resolveOwnedProposal` |
| Per-listing messaging, client + accepted freelancer only (re-derived) | Collection CRUD, `messages` | `internal/server/handlers_messages.go`, `canMessageListing` |
| Poll-based "live" proposals/messages | Repeated `GET .../data` on an interval (no official Go realtime client) | `internal/server/handlers_listings.go`'s fragment handler + inline script in `listing_detail.html` |
| 401 → refresh → retry | `POST /api/auth/refresh`, wired through every collection/search call via request context | `internal/mbase/refresh.go`, `internal/server/middleware.go` |

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | Yes (incl. anonymous guests) | Yes (incl. anonymous guests) |
| Create/update own listing | Yes | No |
| Read proposals | Yes (on own listings) | Yes (own proposals) |
| Accept/reject a proposal | Yes (on own listings' proposals) | No |
| Submit a proposal | No | Yes |
| Send/read messages on a listing | Yes (if the listing is theirs) | Yes (if their proposal on it was accepted) |

Mudbase's collection permissions are **collection-level, not document-level** — a client's write
permission on `listings` doesn't by itself stop them from editing *someone else's* listing, and the
same is true for proposal accept/reject and messaging. Every route above that targets a specific
document therefore **re-fetches that document from Mudbase and verifies the ownership field on the
fetched record** (`listing.clientId`, or the accepted proposal's `freelancerId`) against the
current session's user id *before* writing anything — never trusting the session's role alone, and
never trusting any value a request claims about who owns what. This is the same IDOR discipline the
sibling C# Events port's booking-cancellation fix established after a hidden-form value was found
being trusted for ownership instead of the fetched record. `internal/rbac` only hides/disables
controls a role cannot use in the rendered HTML — it is not the security boundary.

## Getting started

```bash
go build ./...
go vet ./...
cp .env.example .env   # fill in SESSION_SECRET (openssl rand -base64 32); collection IDs already
                        # point at the shared demo project
set -a; source .env; set +a
go run ./cmd/server
# → http://localhost:8080
```

The feed loads immediately for anyone (anonymous guest session). Sign in with one of the two demo
accounts on the login page (one-click forms, or type credentials manually) to post listings,
propose, accept/reject, or message — see `plan/build-plan.md` for account details.

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with the Multi-Role feature, two role slugs: `client`, `freelancer`.
2. Three collections — `listings`, `proposals`, `messages` — with the field shapes documented in
   `plan/build-plan.md`.

## Live smoke test

See `plan/build-plan.md` → "Live smoke test results" for the full flow verification against the
real project: client posts a listing, freelancer browses/searches and proposes, client accepts,
both parties message — plus a raw request from the *non-owning* freelancer account proving the
accept/reject/edit/message ownership re-derivation rejects it server-side, not just a hidden UI
control, and that the targeted listing/proposal were left unmodified by the rejected attempts.

## Known limitations (real platform/architecture constraints, not bugs)

- **No portfolio file upload** — matches the reference app, which deprioritized it behind the core
  listings/proposals/messages flow.
- **No document-level RBAC enforcement by the platform** — Mudbase's collection permissions are
  collection-level only; every ownership check in this app's RBAC matrix above is enforced by this
  app's own handlers, not by Mudbase. Do not treat this reference app's access control as
  production-grade multi-tenant isolation beyond what's explicitly re-derived in each handler.
- **Polling instead of a push realtime subscription** — no official Mudbase Go realtime (Socket.IO)
  client exists.
- A real platform quirk found while building this port: the wire response's `expiresIn` field
  (`86400`) does not match the JWT's actual `exp` claim (`iat + 1800`, i.e. 30 minutes) — see
  `plan/build-plan.md` "A real platform quirk" for the decoded-token evidence. Harmless here since
  this app's refresh is 401-triggered, never based on a client-side expiry timer.

## Design choices carried over from the reference web app

- **Server-side keyword search via the dedicated search endpoint**, never a `filter`-param
  `$regex` (hard-blocked by the platform's query sanitizer) — see `plan/build-plan.md` "Search".
- **Category/budget filters applied client-side over the search batch** when a keyword is present,
  since the search endpoint doesn't accept structured filters alongside `q` — matches the
  reference web app's `src/app/page.tsx`.
- **Messaging visibility: client + the one accepted freelancer, never every applicant** — matches
  the reference web app's documented design decision.

See `plan/build-plan.md` for the full rationale and the live smoke test transcript.

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only real secret (signs/encrypts the session cookie);
every Mudbase ID is a plain, non-secret identifier.
