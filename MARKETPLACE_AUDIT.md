# Marketplace audit — Super Productivity

## Identity

| Item | Value |
|---|---|
| Upstream | https://github.com/johannesjo/super-productivity (22k★, active; latest release `v19.1.0`) |
| Licence | MIT (`LICENSE`: "Permission is hereby granted, free of charge…"), verified from the file |
| Image | `johannesjo/super-productivity:v19.1.0@sha256:6177a565…77c9e4` (amd64 + arm64), static build reused |
| Sync backend | `hacdias/webdav:v5.17.0` (MIT), the server upstream uses in its own compose and E2E tests |
| Marketplace gap | `gapscan.py super-productivity superproductivity "super productivity"` → GAP (no template) |
| Brand | Own generic icon; "not affiliated" disclaimer in README and OVERVIEW |

## Architecture findings

- The web image is nginx serving a static Angular SPA (port 80). Data is in browser storage; sync is client-side to a
  provider (SuperSync, Dropbox, Nextcloud, WebDAV, local file).
- SuperSync (`packages/super-sync-server`, Postgres + Node) authenticates only through emailed magic links or
  passkeys confirmed by email. It needs SMTP and a reachable mailbox to create the first account, so it is not a
  self-contained one-click bundle and its primary flow cannot be verified without a real mail provider. **Rejected
  for this template.**
- WebDAV works with every client. Upstream's nginx can proxy `/webdav/` to a backend, but the web app has no auth.

## Security review

| Risk | Severity | Mitigation |
|---|---|---|
| Web app has no login; a public URL is open to anyone | High | Caddy basic auth on everything except `GET /healthz` |
| A WebDAV store holds all user data | High | Same front-door gate, WebDAV on loopback re-checks the credential |
| Cached basic auth + permissive CORS = cross-site data access | High | WebDAV CORS disabled; app is same-origin |
| Password leaking via argv/config/logs | Medium | Hashed via stdin at start; smoke test greps logs for it |
| Concurrent overwrites (`hacdias/webdav` ignores `If-Match`) | Low | Upstream client pre-checks the etag; single-user use |

## Tests

| Suite | Assertions | What |
|---|---|---|
| `tests/static.sh` | 33 | syntax, shellcheck, compose shape, three digest pins, front-door/WebDAV posture, secret scan |
| `tests/smoke.sh` | 36 (+5 browser sub-checks) | front door, app shell/assets/SPA fallback, WebDAV round-trip, browser two-device sync, password not logged, data on volume, misconfig refused |
| `tests/persistence.sh` | 27 | sync data and login survive a container recreate |
| `tests/railway-smoke.sh` | live HTTPS | front door, app, WebDAV round-trip, browser two-device sync; `VERIFY_ONLY=1` after a redeploy |

## Deploy-time inputs

None required. Generated: `OWNER_PASSWORD`. Defaults: `OWNER_USERNAME=owner`, `PORT=8080`.

## Live verification

Published as https://railway.com/deploy/super-productivity. A clean-room deploy of the published template passed
`tests/railway-smoke.sh` over HTTPS (33 checks, including the real-browser two-device sync), then the service was
redeployed and the sync data (curl round-trip and browser-synced task) was still there. No password in the deploy
logs.

## Verdict

**SHIPPABLE** as a wrapper template (web app + WebDAV + Caddy front door in one service, volume `/data`).
