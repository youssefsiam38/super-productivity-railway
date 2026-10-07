# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | Super Productivity |
| Code | `super-productivity` |
| Template id | `38a0fe6e-6ba2-4234-b575-a91125e72006` |
| Deploy URL | https://railway.com/deploy/super-productivity |
| Category | Other |
| Card description | Self-hosted to-do list and time tracker with private WebDAV sync |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. The image is referenced by tag and digest; `UPSTREAM.md`
records the upstream digests.

## Services

### `app`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/super-productivity-railway:1.0.0@sha256:f024df37c6300bccb900ca546e2516f76a11989f742b08ca93ee406cc05a122b` |
| Public domain | target port 8080 |
| Volume | `/data` |
| Healthcheck | `/healthz`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `PORT` | `8080` |
| `OWNER_USERNAME` | `owner` |
| `OWNER_PASSWORD` | generated, alnum32 |
| `FORWARD_PROTO` | `https` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `120` |

## Notes

- One service: the official Super Productivity static build + hacdias/webdav + Caddy, as the wrapper image
  `ghcr.io/youssefsiam38/super-productivity-railway` (built and tested by CI, public on GHCR, pinned by digest).
- Caddy basic auth gates everything except `GET /healthz`; WebDAV (loopback :6065, prefix `/webdav/`) re-checks the same
  owner credential and stores files under `/data/webdav`. WebDAV CORS is off on purpose.
- WebDAV instead of upstream's SuperSync: SuperSync signs users in only by emailed magic link / passkey confirmed by
  email, which needs SMTP and a mailbox — not a self-contained one-click bundle.
- Sync setup is manual in the app (Settings → Sync → WebDAV, `https://<domain>/webdav/`, owner user/password); the
  upstream `sync-config-default-override.json` pre-fill is ignored by the v19.1 sync dialog, so it is not used.
- Live e2e (published template, clean-room): front door 401s (incl. WebDAV PROPFIND/PUT), app shell, WebDAV round-trip,
  real-browser two-device task sync, and data surviving a redeploy.
