# Mudbase Showcase - Marketplace

A freelance marketplace built **entirely on [Mudbase](https://www.mudbase.dev)** - auth, database,
realtime, and file storage - with **zero custom backend**. The same app, reimplemented once per
official Mudbase SDK, so every supported language has a real, runnable reference app rather than a
toy snippet.

Every version talks to the same Mudbase project shape (see `web/plan/build-plan.md` for the
collection/permission schema) and demonstrates the same feature set: two-sided RBAC (client /
freelancer), job listings with search & filtering, proposals, and in-app messaging.

## Versions in this repo

| Directory | Platform | SDK |
|---|---|---|
| [`web/`](./web) | Next.js 15 (App Router) web app | JavaScript/TypeScript |
| [`mobile-expo/`](./mobile-expo) | Expo / React Native mobile app | JavaScript/TypeScript |
| [`mobile-flutter/`](./mobile-flutter) | Flutter mobile app | Dart |
| [`python/`](./python) | Server-rendered web app | Python |
| [`go/`](./go) | Server-rendered web app | Go |
| [`ruby/`](./ruby) | Server-rendered web app | Ruby |
| [`java/`](./java) | Server-rendered web app (Spring Boot) | Java |
| [`csharp/`](./csharp) | Server-rendered web app (ASP.NET Core) | C# |
| [`php/`](./php) | Server-rendered web app | PHP |
| [`swift/`](./swift) | iOS app (SwiftUI) | Swift |

Each directory is self-contained with its own README, dependency manifest, and `.env.example` -
clone this repo and only set up the language you care about.

## Prerequisite: clone the SDK repo as a sibling

Most versions here (everything except `python/`, `go/`, and `ruby/`, whose package managers can
install straight from a git subdirectory) reference the [mudbase-sdk](https://github.com/mudbase/mudbase-sdk)
repo by relative path, since none of the 9 SDKs are published to a public registry yet. Clone it
next to this repo, at the same parent directory level, before building any version besides `web/`:

```
some-folder/
├── mudbase-sdk/                      # git clone https://github.com/mudbase/mudbase-sdk
└── mudbase-showcase-marketplace/     # this repo
```

## Data model & roles

- **listings** - `title`, `description`, `budget`, `category?`, `status` (`open`/`in_progress`/
  `completed`), `clientId`, `clientName`
- **proposals** - `listingId`, `freelancerId`, `freelancerName`, `coverLetter`, `proposedRate`,
  `status` (`pending`/`accepted`/`rejected`)
- **messages** - `listingId`, `senderId`, `senderName`, `content`

Roles: **client** (posts/manages own listings, reviews proposals), **freelancer** (browses
listings, submits/manages own proposals). Both roles can message on a listing. Auth, users,
realtime, and file storage (for portfolio uploads) are all native Mudbase features.

## License

MIT - see [LICENSE](./LICENSE).
