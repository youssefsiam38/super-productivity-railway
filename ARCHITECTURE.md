# Architecture

```
                 Railway edge (HTTPS)
                         │
                         ▼  :8080 ($PORT)
  ┌─────────────────────────────────────────────────────────────┐
  │ app service (ghcr.io/youssefsiam38/super-productivity-railway) │
  │                                                             │
  │  Caddy front door                                           │
  │   GET /healthz ───────────────► "ok" (no auth)              │
  │   everything else: basic auth (OWNER_USERNAME / hash)       │
  │     /webdav/* ──► hacdias/webdav 127.0.0.1:6065 ──► /data/webdav │
  │     /*        ──► /srv/app (Super Productivity static SPA)  │
  └─────────────────────────────────────────────────────────────┘
                         │
                     volume /data
```

## Service

| Item | Value |
|---|---|
| Image | `ghcr.io/youssefsiam38/super-productivity-railway:<version>@sha256:…` |
| Public port | `8080` (`PORT=8080`; the domain targets 8080) |
| Health check | `GET /healthz` (answered by Caddy, no auth) |
| Volume | `/data` (WebDAV files under `/data/webdav`) |
| Auth | Caddy basic auth on all other paths; WebDAV re-checks the same credential |

## Why this shape

- **Super Productivity is a static SPA with no server and no login.** Its data lives in the browser, and it syncs
  through a provider. A useful self-hosted bundle needs a sync backend, and the whole thing needs a gate.
- **Why WebDAV and not SuperSync.** Upstream's newer SuperSync server signs users in only with emailed magic links or
  passkeys confirmed by email, so it needs an SMTP account and a mailbox to create the first user. That cannot be a
  one-click, self-contained deploy, and it cannot be verified end to end without a real mail provider. WebDAV is a
  first-class provider in every Super Productivity client and is what upstream's own compose and E2E tests use with
  the same `hacdias/webdav` server.
- **One container, one origin.** Serving the app and `/webdav/` from the same origin means the browser app syncs
  without CORS. Keeping CORS off means no other site can make credentialed requests with the browser's cached
  basic-auth login. A single service also means a single volume and nothing on the private network.
- **The app is served by Caddy instead of upstream's nginx.** The static files are copied unmodified from the
  official image. Upstream's entrypoint only adds a `sync-config-default-override.json` pre-fill, and in v19.1 the
  sync dialog does not apply it, so it is not reproduced.
- **The password is hashed via stdin** (`caddy hash-password`) at start-up, so the plaintext never appears in argv,
  the Caddyfile or the logs. WebDAV reads it from its environment (`{env}OWNER_PASSWORD`).
- **Process supervision.** The entrypoint starts WebDAV and Caddy and exits if either stops, so Railway restarts the
  container.
