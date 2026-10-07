#!/usr/bin/env bash
# shellcheck disable=SC2015
# Local smoke test: build/run the combined image, then exercise the front door, the app and sync.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

cleanup() {
  local rc=$?
  if [ "$rc" -ne 0 ] || [ "${SHOW_LOGS:-0}" = 1 ]; then compose logs --no-color --tail 150 || true; fi
  [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

section "start"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d --quiet-pull
wait_for_code "$APP_URL/healthz" 200 && pass "front door is up" || die "never became healthy"

section "front door"
check_front_door

section "web app"
check_app

section "sync (WebDAV)"
check_sync "smoke-$$" "smoke-marker-$$"

section "real browser, two devices"
run_browser_e2e

section "container posture"
logs=$(compose logs --no-color app 2>&1)
if grep -qF -- "$_OWNER_PASSWORD" <<<"$logs"; then fail "the owner password appears in the logs"; else pass "the owner password never appears in the logs"; fi
assert_eq "sync data is on the volume" "yes" "$(compose exec -T app sh -c '[ -d /data/webdav/smoke-'"$$"' ] && echo yes || echo no')"

section "misconfiguration is refused"
out=$(docker run --rm -e OWNER_PASSWORD=short "${SP_RAILWAY_IMAGE:-super-productivity-railway:local}" 2>&1 || true)
assert_contains "a short password stops the container" "too short" "$out"
out=$(docker run --rm "${SP_RAILWAY_IMAGE:-super-productivity-railway:local}" 2>&1 || true)
assert_contains "a missing password stops the container" "OWNER_PASSWORD is not set" "$out"

summary
