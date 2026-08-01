# Mudbase Showcase — Marketplace (Python)

Server-rendered FastAPI + Jinja2 port of the freelance marketplace showcase. Same Mudbase
project, data model, and RBAC as the reference Next.js app in `../web` — see
`plan/build-plan.md` for the full architecture writeup.

## Stack

- FastAPI + Jinja2, Python 3.12+
- Real Mudbase Python SDK (`mudbase-sdk`, installed from GitHub — see `requirements.txt`)
- Starlette `SessionMiddleware` — the Mudbase JWT lives only in a signed, httpOnly session
  cookie, never sent to browser JS
- mypy `--strict` clean

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# Generate a session secret:
python -c "import secrets; print(secrets.token_urlsafe(48))"
# paste it into SESSION_SECRET_KEY in .env

uvicorn app.main:app --reload
```

Visit `http://127.0.0.1:8000`.

## Demo accounts

Two already-provisioned accounts on the shared Mudbase project (see `.env.example` for the
exact values, or use the "Demo client" / "Demo freelancer" quick sign-in buttons on `/login`):

| Role | Email | Password |
|---|---|---|
| Client | `market.client.demo@gmail.com` | `DemoTest123!` |
| Freelancer | `market.freelancer.demo@gmail.com` | `DemoTest123!` |

## Feature set

- Browse listings — keyword search, category filter, budget range, pagination
- Listing detail — full description, proposal submission (freelancer), proposal review with
  accept/reject (owning client), per-listing messaging (client + accepted freelancer)
- Post / edit a listing (client)
- "My listings" (client) and "My proposals" (freelancer) views

## Type checking

```bash
mypy app
```

## Project layout

```
app/
├── main.py              FastAPI application factory
├── config.py             Environment settings (pydantic-settings)
├── mudbase_client.py      Thin sync wrapper over the real mudbase_sdk
├── session.py             Server-side session, refresh, anonymous-session bootstrap
├── context.py             Per-request Jinja template context (current user, flash, RBAC flags)
├── rbac.py                Server-side RBAC mirror of ../web/plan/build-plan.md's matrix
├── templates_env.py       Shared Jinja2Templates instance + filters
├── utils.py               Formatting helpers (currency, relative time, ObjectId check)
├── routers/               auth.py, listings.py, proposals.py, messages.py
├── schemas/               Pydantic models mirroring ../web/src/types/*.ts
├── services/              Business logic + Mudbase collection calls
├── static/css/            Stylesheet
└── templates/             Jinja2 templates + partials/
```
