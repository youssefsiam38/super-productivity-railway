#!/bin/sh
# Combined entrypoint for the Super Productivity Railway template.
#
# 1. Validates the owner credential (the front-door login, also the WebDAV sync login).
# 2. Hashes the password for Caddy via stdin (the plaintext never reaches argv or the Caddyfile).
# 3. Starts the WebDAV server on loopback and Caddy on the public $PORT. If either process exits,
#    the container exits so Railway restarts it. Secrets are never printed.
set -eu

log() { printf '[super-productivity-railway] %s\n' "$*"; }
die() { printf '[super-productivity-railway] ERROR: %s\n' "$*" >&2; exit 1; }

OWNER_USERNAME="${OWNER_USERNAME:-owner}"
export OWNER_USERNAME
[ -n "${OWNER_PASSWORD:-}" ] || die "OWNER_PASSWORD is not set. It is the login for the app and for WebDAV sync (user: ${OWNER_USERNAME})."
[ "${#OWNER_PASSWORD}" -ge 12 ] || die "OWNER_PASSWORD is too short; use at least 12 characters."
case "$OWNER_USERNAME" in
  *[!A-Za-z0-9._-]*) die "OWNER_USERNAME may only contain letters, digits, '.', '_' and '-'." ;;
esac

# Sync data lives on the volume.
DATA_DIR=/data/webdav
mkdir -p "$DATA_DIR"

CADDY_PASSWORD_HASH="$(printf '%s\n' "$OWNER_PASSWORD" | caddy hash-password)"
[ -n "$CADDY_PASSWORD_HASH" ] || die "could not hash OWNER_PASSWORD"
export CADDY_PASSWORD_HASH

log "starting WebDAV sync store on 127.0.0.1:6065 (data: ${DATA_DIR})"
webdav --config /etc/webdav/config.yml &
WEBDAV_PID=$!

log "front door starting on :${PORT:-8080} (basic auth, user: ${OWNER_USERNAME})"
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

shutdown() { kill -TERM "$WEBDAV_PID" "$CADDY_PID" 2>/dev/null || true; }
trap 'shutdown; wait; exit 0' TERM INT

# Exit as soon as either process stops, taking the other down with it.
while kill -0 "$WEBDAV_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done
log "a process exited; stopping"
shutdown
wait || true
exit 1
