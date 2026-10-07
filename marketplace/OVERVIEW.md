# Deploy and Host Super Productivity on Railway

Super Productivity is an open-source to-do list and time tracker with timeboxing, Pomodoro and focus modes, projects,
tags, notes, repeatable tasks and work-log reports. It runs as a web app that keeps its data in the browser and syncs
between devices through a sync backend. This template deploys the Super Productivity web app together with its own
private WebDAV sync store on one HTTPS domain, behind a login with a generated password. It is a community-maintained
template based on Super Productivity. It is not affiliated with, endorsed by, or an official offering of the Super
Productivity project, and it does not use its logo.

## About Hosting Super Productivity

The Super Productivity web app is a static single-page app: tasks live in the browser's storage until you turn on
sync. On its own it has no login, and a WebDAV share open to the internet would expose all of your data. This
template bundles both halves in one container: the official web app (unmodified), a WebDAV server that stores the
sync data on a Railway volume, and a Caddy front door that puts everything behind HTTP basic auth. The same owner
credential signs you in to the app and is the WebDAV sync login, so every browser, phone and desktop that uses this
deployment syncs to the same place.

## Common Use Cases

- A private, self-hosted task manager and time tracker you can open from any browser.
- Syncing Super Productivity between your laptop, phone and work machine without a third-party cloud.
- Keeping time-tracking and work-log data for billing on infrastructure you control.

## Dependencies for Super Productivity Hosting

- Nothing external is required: the WebDAV sync store is built in and keeps its files on the volume.
- No email server, database or API key is needed.

### Deployment Dependencies

- Super Productivity: https://github.com/johannesjo/super-productivity (MIT)
- WebDAV server (hacdias/webdav): https://github.com/hacdias/webdav (MIT)
- Template repository and tests: https://github.com/youssefsiam38/super-productivity-railway

### Implementation Details

One service runs a small wrapper image: the static build from the official `johannesjo/super-productivity` image,
the `hacdias/webdav` server and Caddy, each pinned by digest. Caddy is the only public listener. It answers
`/healthz` for Railway's health check and requires `OWNER_USERNAME` (default `owner`) and a generated
`OWNER_PASSWORD` for everything else. It serves the app at `/` and forwards `/webdav/` to the WebDAV server on
loopback, which checks the same credential again and stores files under `/data/webdav` on the volume. The password
is hashed at start-up and never written to a config file or printed. Cross-origin (CORS) access to WebDAV is off on
purpose, so other websites cannot reuse a browser's saved login.

Tested in CI and on a live deployment of this template: the health check is open but everything else returns `401`
without the credential (including WebDAV `PROPFIND` and `PUT`); a wrong user or password is refused; the app loads;
and the WebDAV sync round-trip (create folder, upload, list, read back, overwrite, copy, move, delete) works. A real
browser creates a task and syncs it, and a second fresh browser receives it. The sync data survives a redeploy.

After deploying, copy `OWNER_PASSWORD` from the service's variables and open the public domain (user `owner`). To
sync, open Sync settings, pick WebDAV and enter `https://<your-domain>/webdav/`, the same user and password, and a
folder name. Use the same values on your other devices.

## Why Deploy Super Productivity on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Super Productivity on Railway, you are one step closer to supporting a complete full-stack application
with minimal burden. Host your servers, databases, AI agents, and more on Railway.
