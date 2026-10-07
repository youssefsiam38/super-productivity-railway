# Super Productivity on Railway

One-click [Railway](https://railway.com) template for [Super Productivity](https://github.com/johannesjo/super-productivity),
the open-source to-do list and time tracker, **bundled with its own private WebDAV sync store** behind a login.

> Community-maintained. Not affiliated with, endorsed by, or an official offering of the Super Productivity project.
> The template uses its own generic icon, not the Super Productivity logo.

## What you get

- The official Super Productivity web app (`johannesjo/super-productivity`, MIT), served unmodified.
- A WebDAV sync store (`hacdias/webdav`, MIT) at `https://<domain>/webdav/`, with data on a Railway volume.
- A Caddy front door: HTTP basic auth on everything (app and WebDAV) except `GET /healthz`.
- One credential for everything: `OWNER_USERNAME` (default `owner`) and a generated `OWNER_PASSWORD`.
- Images pinned by digest; a wrapper image built and tested in CI and published to
  `ghcr.io/youssefsiam38/super-productivity-railway`.

## Deploy

1. Deploy the template. Nothing needs to be filled in.
2. Copy `OWNER_PASSWORD` from the service's **Variables** tab.
3. Open the public domain and sign in as `owner` with that password.
4. Turn on sync: **Settings → Sync & Backup** (or the sync icon, or "Set up sync" on first launch) → provider
   **WebDAV**, then:
   - Base URL: `https://<your-domain>/webdav/`
   - Username / password: the same owner credential
   - Sync folder path: any name, e.g. `super-productivity`
5. Use the same values on every other device (another browser, the Android/iOS app).

Super Productivity labels generic WebDAV as "not recommended / no support" because WebDAV servers vary. The template
pins and tests one specific server, and a real browser syncs a task between two devices against it in CI and on a
live deployment.

## Security

Super Productivity has no login of its own, so the front door is the only gate. It covers both the app and the WebDAV
store. The password is hashed at start-up (never written to a config file or printed). WebDAV listens only on
loopback and checks the credential again. CORS is off, so other websites cannot use a browser's saved login to read
your data. Optional end-to-end encryption is available in the app's sync settings. See [SECURITY.md](SECURITY.md).

## Repository layout

| Path | Purpose |
|---|---|
| `images/app/` | Wrapper image: `Dockerfile`, `Caddyfile`, `webdav.yml`, `entrypoint.sh` |
| `compose.yaml` | Local test topology (mirrors the single Railway service) |
| `tests/static.sh` | Syntax, shellcheck, compose shape, digest pins, front-door posture, secret scan |
| `tests/smoke.sh` | Builds and runs the image: front door, app, WebDAV round-trip, browser two-device sync |
| `tests/persistence.sh` | Writes sync data, recreates the container, verifies it survived |
| `tests/railway-smoke.sh` | The same flows over HTTPS against a live deployment |
| `tests/browser/` | Playwright test: a task synced from one browser profile to another |
| `marketplace/OVERVIEW.md` | Railway Marketplace description |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration |

## Local development

```bash
tests/static.sh
docker compose build
BROWSER_E2E=1 tests/smoke.sh     # BROWSER_E2E needs Node; it runs npm ci in tests/browser
tests/persistence.sh
```

The local stack listens on `http://127.0.0.1:18190` (user `owner`, password `localTestOnlyOwnerPw1`).

## License

The template's own files are MIT ([LICENSE](LICENSE)). Super Productivity, hacdias/webdav and Caddy keep their own
licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `licenses/`.
