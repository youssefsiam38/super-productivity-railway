#!/usr/bin/env bash
# shellcheck disable=SC2015
# Shared helpers for super-productivity-railway tests. Source this file; do not execute it.
#
# The front door is HTTP basic auth (OWNER_USERNAME / OWNER_PASSWORD); the same credential is the
# WebDAV sync login. The password is read from a file or a test-only env var and never echoed: it is
# written to a mode-600 curl config under $TEST_TMP and passed with --config, never on argv.

: "${APP_URL:=http://127.0.0.1:${SP_TEST_PORT:-18190}}"
: "${TEST_TIMEOUT:=180}"
: "${OWNER_USERNAME:=owner}"
# Deliberately NOT inherited from a generic $OWNER_PASSWORD / $ADMIN_PASSWORD in the caller's env.
if [ -n "${OWNER_PASSWORD_FILE:-}" ]; then
  _OWNER_PASSWORD=$(<"$OWNER_PASSWORD_FILE")
else
  _OWNER_PASSWORD=${SP_TEST_OWNER_PASSWORD:-localTestOnlyOwnerPw1}
fi

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
chmod 700 "$TEST_TMP"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 2
  done
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

# auth_cfg USER PASSWORD -> path of a mode-600 curl config holding the basic-auth credential.
auth_cfg() {
  local f="$TEST_TMP/auth-$RANDOM.cfg"
  (umask 077; printf 'user = "%s:%s"\n' "$1" "$2" >"$f")
  printf '%s' "$f"
}
OWNER_CFG=""
owner_cfg() { [ -n "$OWNER_CFG" ] || OWNER_CFG=$(auth_cfg "$OWNER_USERNAME" "$_OWNER_PASSWORD"); printf '%s' "$OWNER_CFG"; }

# Authenticated requests as the owner.
acurl() { curl -s --max-time 60 --config "$(owner_cfg)" "$@"; }
acode() { curl -s -o /dev/null -w '%{http_code}' --max-time 60 --config "$(owner_cfg)" "$@" || true; }

# The front-door gate: everything but /healthz needs the owner credential.
check_front_door() {
  local p
  assert_eq "health check answers without auth" "200" "$(http_code "$APP_URL/healthz")"
  assert_eq "health check refuses POST" "405" "$(http_code -X POST "$APP_URL/healthz")"
  for p in / /index.html /assets/i18n/en.json /webdav/ /webdav /some/spa/route; do
    assert_eq "anonymous GET $p is refused" "401" "$(http_code "$APP_URL$p")"
  done
  assert_eq "anonymous PROPFIND /webdav/ is refused" "401" "$(http_code -X PROPFIND -H 'Depth: 1' "$APP_URL/webdav/")"
  assert_eq "anonymous PUT into /webdav/ is refused" "401" "$(http_code -X PUT --data x "$APP_URL/webdav/pwn.txt")"
  assert_eq "the wrong password is refused" "401" "$(http_code --config "$(auth_cfg "$OWNER_USERNAME" "wrong-password-123")" "$APP_URL/")"
  assert_eq "the wrong user is refused" "401" "$(http_code --config "$(auth_cfg "intruder" "$_OWNER_PASSWORD")" "$APP_URL/")"
  assert_eq "the WebDAV server is not published on its own" "000" "$(http_code --max-time 3 "${APP_URL%:*}:6065/")"
}

# The web app behind the front door.
check_app() {
  local html
  html=$(acurl "$APP_URL/")
  assert_contains "the owner gets the Super Productivity app shell" '<app-root' "$html"
  assert_contains "the app shell is Super Productivity" 'Super Productivity' "$html"
  assert_eq "deep links fall back to the SPA" "200" "$(acode "$APP_URL/tag/TODAY/tasks")"
  assert_eq "app assets are served" "200" "$(acode "$APP_URL/assets/i18n/en.json")"
  assert_eq "the service-worker manifest is served" "200" "$(acode "$APP_URL/ngsw.json")"
  assert_eq "the app shell is revalidated" "no-cache" "$(acurl -D - -o /dev/null "$APP_URL/" | tr -d '\r' | awk -F': ' 'tolower($1)=="cache-control"{print $2}')"
}

# WebDAV sync round-trip: what the app's WebDAV provider does (folder, upload, list, read, move,
# overwrite, delete). Leaves FOLDER/sync-data.json holding MARKER for persistence checks.
# Usage: check_sync FOLDER MARKER
check_sync() {
  local folder=$1 marker=$2 base="$APP_URL/webdav/$1" body listing
  body="$TEST_TMP/sync-data.json"
  printf '{"version":2,"marker":"%s","state":{"task":{"ids":["t1"],"entities":{"t1":{"title":"%s"}}}}}\n' "$marker" "$marker" >"$body"

  assert_eq "WebDAV: create the sync folder" "201" "$(acode -X MKCOL "$base/")"
  assert_eq "WebDAV: upload sync data" "201" "$(acode -T "$body" "$base/sync-data.json")"
  listing=$(acurl -X PROPFIND -H 'Depth: 1' "$base/")
  assert_contains "WebDAV: PROPFIND lists the file under the /webdav/ prefix" "<D:href>/webdav/$folder/sync-data.json</D:href>" "$listing"
  assert_contains "WebDAV: read-back returns the uploaded data" "$marker" "$(acurl "$base/sync-data.json")"
  # hacdias/webdav (also upstream's own WebDAV test server) overwrites unconditionally and ignores
  # If-Match; Super Productivity compensates with a PROPFIND etag pre-check, so we only assert that
  # an overwrite succeeds and the etag changes.
  local etag1 etag2
  etag1=$(acurl -I "$base/sync-data.json" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{print $2}')
  printf '{"version":2,"marker":"%s","rev":2}\n' "$marker" >"$body.2"
  assert_eq "WebDAV: overwrite existing sync data" "201" "$(acode -T "$body.2" "$base/sync-data.json")"
  etag2=$(acurl -I "$base/sync-data.json" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{print $2}')
  if [ -n "$etag1" ] && [ "$etag1" != "$etag2" ]; then pass "WebDAV: the etag changes on overwrite"; else fail "WebDAV: etag did not change"; fi
  assert_eq "WebDAV: copy with an absolute Destination URL" "201" \
    "$(acode -X COPY -H "Destination: $base/sync-data.copy.json" "$base/sync-data.json")"
  assert_eq "WebDAV: move with an absolute Destination URL" "201" \
    "$(acode -X MOVE -H "Destination: $base/sync-data.moved.json" "$base/sync-data.copy.json")"
  assert_eq "WebDAV: delete" "204" "$(acode -X DELETE "$base/sync-data.moved.json")"
  assert_eq "WebDAV: deleted file is gone" "404" "$(acode "$base/sync-data.moved.json")"
  if acurl --path-as-is "$APP_URL/webdav/../../etc/passwd" | grep -q 'root:'; then
    fail "WebDAV: path traversal escaped the store"
  else
    pass "WebDAV: path traversal stays inside the store"
  fi
}

# Persistence check: FOLDER/sync-data.json still holds MARKER.
check_sync_kept() {
  assert_contains "sync data survived ($1)" "$2" "$(acurl "$APP_URL/webdav/$1/sync-data.json")"
}

# Optional real-browser cross-device sync test (tests/browser). Runs when BROWSER_E2E=1.
run_browser_e2e() {
  [ "${BROWSER_E2E:-0}" = 1 ] || { echo "  SKIP  browser e2e (set BROWSER_E2E=1)"; return 0; }
  local dir="$REPO_ROOT/tests/browser" pwf="$TEST_TMP/owner.pw"
  [ -d "$dir/node_modules/playwright" ] || (cd "$dir" && npm ci --silent >/dev/null) || { fail "browser e2e: npm ci"; return 0; }
  (umask 077; printf '%s' "$_OWNER_PASSWORD" >"$pwf")
  local out
  if out=$(APP_URL="$APP_URL" OWNER_USERNAME="$OWNER_USERNAME" OWNER_PASSWORD_FILE="$pwf" node "$dir/sync_e2e.js" 2>&1); then
    pass "browser e2e: web app syncs a task to WebDAV and a second device receives it"
  else
    fail "browser e2e"
  fi
  grep -E '^  (PASS|FAIL)' <<<"$out" | sed 's/^/    /'
}
