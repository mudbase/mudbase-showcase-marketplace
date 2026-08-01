# Mudbase Showcase — Marketplace (mobile-expo)

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database,
role-based access control, and search — with **zero custom backend**. This is the Expo/React
Native port of the reference [`../web`](../web) app: same Mudbase project, same three collections,
same RBAC matrix, same data model, same messaging-visibility rule.

## Stack

Expo Router (SDK 57) + TypeScript (strict) + NativeWind + TanStack Query + Zustand + Zod +
react-hook-form, talking directly to `cloud.mudbase.dev` via the real generated
[`mudbase-sdk`](https://github.com/mudbase/mudbase-sdk) (`AuthenticationApi` + `DataApi` +
`SearchApi`) — no hand-rolled REST client (except one documented SDK gap, see below), no custom
backend of any kind. Every request is made with the signed-in user's own JWT, or an anonymous
guest session's for public browsing; there is no server-side code and no privileged credential
anywhere in this app.

Architecture mirrors the sibling [`mudbase-showcase-kanban/mobile-expo`](../../mudbase-showcase-kanban/mobile-expo)
port: same file layout (`src/api`, `src/config`, `src/lib`, `src/stores`, `src/providers`,
`src/hooks`, `src/components/{ui,auth,layout,listings,proposals,messages,shared}`), same
secure-token pattern. No Socket.IO here — this showcase polls instead (see `plan/build-plan.md`).

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Two-role auth (client / freelancer) **plus a guest/anonymous session** for public browsing | `POST /api/auth/anonymous`, `POST /api/auth/local/login`, `POST /api/auth/local/signup/{role}` | `src/api/client.ts`, `src/stores/authStore.ts` |
| Listings CRUD (client-owned) | Collection CRUD, `listings` | `src/hooks/useCollection.ts`, `src/components/listings/*` |
| Server-side keyword search | Dedicated `GET /api/search/projects/:id/search` endpoint (never `$regex`) | `src/api/client.ts`'s `search()`, `app/(tabs)/index.tsx` |
| Proposals (submit, accept/reject) | Collection CRUD, `proposals` | `src/components/proposals/*` |
| Per-listing messaging, client + accepted freelancer only | Collection CRUD, `messages`, polled via TanStack Query | `src/components/messages/MessageThread.tsx` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `src/hooks/useAuth.ts`, `src/components/layout/AppHeader.tsx` |

## RBAC matrix

| Action | client | freelancer |
|---|---|---|
| Read listings | Yes | Yes |
| Create/update own listing | Yes | No |
| Read proposals (own listings / own proposals) | Yes | Yes |
| Accept/reject proposals (on own listings) | Yes | No |
| Submit own proposal | No | Yes |
| Send/read messages (client + accepted freelancer only) | Yes | Yes |

Mudbase's own collection permissions are the real server-side enforcement boundary; this app's
UI-level gating only decides what renders, never what the platform allows — see
`plan/build-plan.md` for the live verification notes and the known document-level-scoping
limitation shared with the web reference.

## Getting started

```bash
npm install
cp .env.example .env   # already points at the shared demo project below; edit if you provision your own
npm run start           # or: npm run ios / npm run android / npm run web
```

Sign in with one of the two demo accounts on the login screen's quick-fill buttons (or type
credentials manually) — see `plan/build-plan.md` for account details and the live smoke-test notes.

## Provisioning (already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with two role slugs: `client`, `freelancer`, plus anonymous sessions enabled
   for public listing reads.
2. Three collections — `listings`, `proposals`, `messages` — with the field shapes documented in
   `plan/build-plan.md`, each role granted the permissions in the RBAC matrix above.

`.env.example` lists every id this app needs — all values are `EXPO_PUBLIC_*` since none of them
are secret (every request authenticates with a JWT, real or anonymous, never a static key).

## Live smoke test

See `plan/build-plan.md` → "Live Smoke Test Results" for the full request-by-request verification
against the real project: client posts a listing → freelancer browses/searches/proposes → client
accepts → both message → freelancer sees the accepted status, plus a confirmation that `$regex`
is still correctly blocked and the `status`-field platform fix holds on both create and update.

## Known limitations (real platform constraints, not bugs — carried forward from the web reference)

- **Document-level RBAC is enforced client-side**, not by the platform — Mudbase's collection
  permissions are collection-level, not per-document. This app's own queries and UI are the "own
  listing" / "own proposal" scoping boundary, same limitation the web reference documents.
- **No file/portfolio upload** — out of scope for this pass, same choice the web reference made.
- **No `fields` projection** — the generated `mudbase-sdk`'s `DataApi.listData` has no `fields`
  parameter, so the two dashboard "sample" queries (category picker, proposal counts) fetch full
  documents instead of a narrowed field set. No functional difference, just a slightly larger
  payload than the web reference's equivalent raw-`fetch` calls.
