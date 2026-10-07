# Security

## What the template enforces

- **Nothing is public except `GET /healthz`.** The Caddy front door requires the owner credential for the web app,
  its assets and the WebDAV store. A wrong user or password gets `401`.
- **The sync data is behind the same credential twice.** Caddy checks it, and the WebDAV server (loopback only)
  checks it again.
- **No cross-origin access.** WebDAV CORS is off, so another website cannot use a browser's cached basic-auth login
  to read or write your data.
- **The password is generated** (`OWNER_PASSWORD`, 32 alphanumeric characters), must be at least 12 characters, is
  hashed at start-up, and is never written to a file or printed.

## What you should do

- Keep `OWNER_PASSWORD` private. Anyone with it can read and change all synced data.
- To rotate it, change `OWNER_PASSWORD` in Railway, redeploy, then update the sync settings on each device.
- For defence in depth, turn on the app's optional end-to-end encryption in the sync settings. The server then only
  stores encrypted data.
- Back up the `/data` volume (Railway volume backups). It holds every synced file.

## Notes

- Basic auth is cached by the browser for the session. Use a private window on shared computers.
- Super Productivity also stores your data in each browser's local storage. That is upstream behaviour.

## Reporting

Report template issues at https://github.com/youssefsiam38/super-productivity-railway/issues. Report Super
Productivity issues upstream at https://github.com/johannesjo/super-productivity.
