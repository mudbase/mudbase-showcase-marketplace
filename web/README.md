# Mudbase Showcase — Marketplace (Web)

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and file storage — with **zero custom backend**. This is the reference implementation
in a series of 10 ports of the same app (web, Expo, Flutter, Python, Go, Ruby, Java, C#, PHP,
Swift); see the [repo root README](../README.md) for the full list.

## Stack

- Next.js 15 (App Router), TypeScript strict, no `any`
- Tailwind CSS + shadcn/ui-style components (Radix primitives, `class-variance-authority`, `tailwind-merge`)
- TanStack Query v5 for all server state
- `react-hook-form` + `zod` for every form

Full technical blueprint (data model, RBAC matrix, page map, messaging-visibility decision,
platform issues discovered during the live smoke test): [`plan/build-plan.md`](./plan/build-plan.md).

## Features

- Public listings browse (`/`) with keyword search, category filter, and budget range, paginated
- Listing detail (`/listings/[id]`): full info, a proposal form for freelancers, the received
  proposals list with accept/reject for the owning client, and a message thread
- Post / edit a listing (client only, owner only for edits)
- My proposals (`/proposals`, freelancer) — every proposal you've submitted, with status
- My listings (`/listings/mine`, client) — your own listings with live proposal counts
- Real signup choosing a role (client or freelancer), plus the two pre-seeded shared demo accounts

## Getting started

```bash
npm install
cp .env.example .env.local   # already points at the shared demo Mudbase project
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Sign in with either shared demo account
(see below), or register a new account and pick a role.

### Demo accounts

| Role | Email | Password |
|---|---|---|
| Client | `market.client.demo@gmail.com` | `DemoTest123!` |
| Freelancer | `market.freelancer.demo@gmail.com` | `DemoTest123!` |

## Environment variables

See [`.env.example`](./.env.example). All three `NEXT_PUBLIC_*` Mudbase vars are safe to expose
client-side — the base URL and project ID are public routing information, and the API key is a
publishable (`pk_`) key, not a secret.

## Scripts

```bash
npm run dev     # start the dev server
npm run build   # production build
npm run start   # run the production build
npm run lint    # eslint
```

## Known limitations

- Portfolio file upload to Mudbase's public bucket was scoped out of this pass (see
  `plan/build-plan.md` "Known limitations") — `MudbaseClient.uploadFile()` exists for API-contract
  parity with the sibling showcases but nothing in the UI calls it yet.
- RBAC ("own listing" / "own proposal" scoping) is enforced by this app's queries and UI, not by
  the platform at the document level — see `plan/build-plan.md` for why.
