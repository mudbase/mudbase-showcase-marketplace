# Mudbase Showcase - Marketplace (Ruby / Sinatra)

A server-rendered freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)**
- auth and database, with **zero custom backend** - implemented in **Sinatra + ERB**, talking to
`cloud.mudbase.dev` through the real generated **Mudbase Ruby SDK** (`mudbase_sdk`, module
`MudbaseSDK`). This is the Ruby reimplementation of the reference Next.js app (see `../web`):
same Mudbase project, same three collections (`listings`/`proposals`/`messages`), same
`client`/`freelancer` RBAC matrix, same messaging-visibility rule - different stack, following
the Sinatra structure the sibling `mudbase-showcase-kanban`/`mudbase-showcase-social` ports
established.

## Stack

Sinatra 4 + ERB + `Rack::Session::Cookie`, `mudbase_sdk` (git-sourced), Puma. No ORM, no
database of its own, no client-side JavaScript - every read/write goes to Mudbase's Collections
REST API and the dedicated search endpoint, and every interaction is a plain HTML form
GET/POST.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Self-signup with a real role picker (client/freelancer) | `POST /api/auth/local/signup/:role` (role-parameterized) | `lib/mudbase/auth_service.rb`, `app/routes/auth_routes.rb` |
| Guest browsing (anonymous session) | `POST /api/auth/anonymous` | `lib/session_helpers.rb#ensure_guest_session!` |
| Browse listings - search, category, budget filters, pagination | Dedicated `GET /api/search/projects/:id/search` for keyword search; filtered/sorted/paginated collection reads otherwise | `app/routes/listings_routes.rb`, `lib/mudbase/listings_repo.rb` |
| Post / edit a listing - **client only, ownership re-verified server-side** | Collection create/update, RBAC enforced by Mudbase + this app | `app/routes/listings_routes.rb` |
| Submit a proposal - **freelancer only**, one proposal per listing | Collection create | `app/routes/proposals_routes.rb` |
| Accept / reject a proposal - **owning client only, IDOR-guarded** | Collection update | `app/routes/proposals_routes.rb#set_proposal_status!` |
| Per-listing messaging - **client + the one accepted freelancer only** | Collection create/read | `app/routes/messages_routes.rb`, `lib/mudbase/messages_repo.rb` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled, with the Multi-Role feature configured with two self-signup role slugs:
   `client` / `freelancer`.
2. Three collections - `listings`, `proposals`, `messages` - with the field shapes documented
   in `plan/build-plan.md`.

`.env.example` lists every ID this app needs once that's done.

## Setup

```bash
bundle install
cp .env.example .env   # fill in your own provisioned project's IDs and a session secret
bundle exec puma -p 4567 config.ru
# or: bundle exec rackup config.ru
```

Open `http://localhost:4567`. Sign in with one of the two demo accounts (or use the "Sign in as
Client / Freelancer" quick-fill buttons on `/login`):

| Role | Email | Password |
|---|---|---|
| Client | `market.client.demo@gmail.com` | `DemoTest123!` |
| Freelancer | `market.freelancer.demo@gmail.com` | `DemoTest123!` |

### Native-extension (ffi) caveat

`mudbase_sdk` depends on `typhoeus` → `ethon` → `ffi` for its HTTP transport. `ffi`'s native
extension is loosely pinned by the SDK's own gemspec and can fail to compile against a newer
Xcode/Clang toolchain than the gem release expects. This Gemfile pins `ffi ~> 1.17` explicitly (a
version with prebuilt `arm64-darwin`/`x86_64-darwin`/Linux bottles, so `bundle install` typically
doesn't need to compile anything). If you still hit a build failure, run
`gem install ffi -v '~> 1.17'` on its own first to confirm a prebuilt binary is available for
your platform before touching the vendored SDK gemspec.

### Verifying the app

```bash
find . -name "*.rb" -exec ruby -c {} \;                            # every file: Syntax OK
bundle exec ruby -e "require './app'"                              # loads cleanly, no live calls
```

## Security - IDOR guard (accept/reject, edit)

A sibling C# Events port shipped a booking-cancellation handler that trusted a hidden-form
ownership flag instead of verifying it server-side - a real, fixed IDOR bug. This app applies
the same discipline everywhere a request could mutate a record it doesn't own:

- **`POST /listings/:id/edit`**: re-fetches the listing by `:id`, then checks
  `listing[:clientId] == @current_user[:id]` against that *freshly-fetched* document before
  calling `update!` - never trusts a hidden form field or the fact that the edit form happened
  to render.
- **`POST /proposals/:id/accept` / `.../reject`**: re-fetches the proposal by `:id`, re-fetches
  the *listing that proposal references* (`proposal[:listingId]`, itself read from the
  just-fetched proposal document - never a route param), then checks
  `listing[:clientId] == @current_user[:id]` before calling `update!`. See
  `app/routes/proposals_routes.rb#set_proposal_status!`.
- **`POST /listings/:id/messages`**: re-fetches the listing and re-queries `proposals` for the
  accepted freelancer's id on *this* listing before allowing a send - a freelancer whose
  proposal was never accepted (or was accepted on a *different* listing) cannot post into this
  thread no matter what the request claims. See `app/routes/messages_routes.rb#can_message?`.

Verified live against the real project: a non-owning user's edit attempt on someone else's
listing (with a hostile `title`/`budget`/`status` payload) and a non-owning user's reject attempt
on an already-accepted proposal were both rejected by this app's own gate, and the underlying
listing/proposal were re-fetched afterward and confirmed unchanged. A follow-up edit by the
*real* owner, re-fetched and confirmed applied, proves the guard blocks the wrong actor without
blocking the right one. See `plan/build-plan.md` "Live Smoke Test Results" for the full
request-by-request table.

## Known limitations (real platform/framework constraints, not bugs)

- **No realtime.** This app is entirely server-rendered with no client-side JavaScript runtime,
  and deliberately never sends the Mudbase JWT to the browser (it lives only in an httponly
  Rack session cookie). Reload the listing detail page to see a new message or proposal status
  change from the other side.
- **No portfolio/file upload.** Matches the reference web app's own scoping - out of scope for
  this pass.
- **Document-level RBAC is enforced by this app's routes, not by Mudbase's collection
  permissions alone** (which are collection-level, not automatically scoped to "my own
  listing"). See plan/build-plan.md "RBAC matrix" and the IDOR section above for how this app
  closes that gap itself.
- **`DataApi#list_data` hard-caps `limit` at 100**, client-side-enforced by the generated SDK
  (confirmed by the sibling kanban/social Ruby ports' own builds). Every bounded read in this
  app is set to exactly 100 (or the reference app's own page size) for this reason.

## Local development

```bash
bundle install
cp .env.example .env
bundle exec puma -p 4567 config.ru
```

## Deploy

Any Ruby host that runs Puma behind `config.ru` (Fly.io, Render, a bare VPS with systemd) works
unmodified. Set every variable in `.env.example` as a real environment variable -
`SESSION_SECRET` must be a long random value distinct from any other app's secret, and
`RACK_ENV=production` turns on the `secure` cookie flag (HTTPS-only session cookie).
