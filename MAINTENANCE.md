# Maintenance

## Updating Super Productivity (or webdav / Caddy)

1. **Bump the pin.** Resolve the new digest (see `UPSTREAM.md`) and update the `ARG …_IMAGE=` line in
   `images/app/Dockerfile` (and `UPSTREAM.md`).
2. **Run the tests locally.**
   ```bash
   tests/static.sh
   docker compose build
   BROWSER_E2E=1 tests/smoke.sh
   tests/persistence.sh
   ```
   If the browser test breaks, upstream probably changed the sync dialog; adjust `tests/browser/sync_e2e.js`.
3. **Cut a release tag** (`git tag -a v1.0.1 -m v1.0.1 && git push origin v1.0.1`). `publish-image.yml` re-runs the
   tests, then pushes `ghcr.io/youssefsiam38/super-productivity-railway:{1.0.1,1.0,latest}`.
4. **Re-point the template** at the new wrapper digest (`_audit/spec_super_productivity.py` → `patch_template`), run
   a clean-room deploy and `tests/railway-smoke.sh`, then publish the update.

## Rebuilding the Railway template from scratch

The exact configuration is in `RAILWAY_TEMPLATE.md`. The generator spec is `_audit/spec_super_productivity.py`, and
the kit in `_audit/` (`tplkit.py`) builds a skeleton, patches the template and runs a clean-room deploy. Only
`skeleton()` sets volumes, domains and health checks, so changing any of those means rebuilding from a skeleton.

## Gotchas worth remembering

- **SuperSync needs SMTP.** Upstream's SuperSync server only signs users in through emailed magic links or passkeys
  confirmed by email. That is why the template ships WebDAV.
- **`hacdias/webdav` ignores `If-Match`.** It overwrites unconditionally. Super Productivity knows this (it is
  upstream's own E2E server) and does a PROPFIND etag pre-check before each upload.
- **Do not strip `/webdav` in Caddy.** The WebDAV server runs with `prefix: /webdav/` so PROPFIND hrefs carry the
  prefix the client asked for. Caddy rewrites absolute `Destination` headers (COPY/MOVE) to a path.
- **Keep WebDAV CORS off.** With basic auth cached by the browser, a permissive CORS policy would let any site make
  credentialed requests. The same-origin web app does not need CORS.
- **Upstream's sync pre-fill is ineffective in v19.1.** The stock image writes `sync-config-default-override.json`
  from `WEBDAV_*` env vars, but the sync dialog ignores it, so the wrapper does not reproduce it.
- **Caddy's storage dir.** The official Caddy image puts its data in `/data`; the wrapper moves it to
  `/var/lib/caddy` so the volume holds only sync data.
- **Local tests: no generic env inheritance.** `tests/lib.sh` reads `SP_TEST_OWNER_PASSWORD` or
  `OWNER_PASSWORD_FILE`, never a generic `OWNER_PASSWORD` from the caller's environment.
