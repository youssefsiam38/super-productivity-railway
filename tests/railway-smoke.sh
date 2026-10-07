#!/usr/bin/env bash
# shellcheck disable=SC2015
# Live e2e against a deployed template over HTTPS.
#
#   OWNER_PASSWORD_FILE=/path/to/pw tests/railway-smoke.sh https://<domain>
#
# Set BROWSER_E2E=1 to also run the real-browser two-device sync test (tests/browser).
# Set VERIFY_ONLY=1 with SYNC_FOLDER and SYNC_MARKER to only re-check data after a redeploy.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
APP_URL=${1:?usage: railway-smoke.sh https://<domain>}; export APP_URL
: "${OWNER_PASSWORD_FILE:?set OWNER_PASSWORD_FILE to a file containing the owner password}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "edge"
wait_for_code "$APP_URL/healthz" 200 120 && pass "health over HTTPS" || die "not healthy"
assert_eq "the edge is HTTPS" "https" "${APP_URL%%://*}"

section "front door"
check_front_door

section "web app"
check_app

if [ "${VERIFY_ONLY:-0}" = 1 ]; then
  section "data survived"
  : "${SYNC_FOLDER:?}" "${SYNC_MARKER:?}"
  check_sync_kept "$SYNC_FOLDER" "$SYNC_MARKER"
else
  section "sync (WebDAV)"
  folder="live-$(date +%s)"; marker="live-marker-$RANDOM$RANDOM"
  check_sync "$folder" "$marker"
  printf 'SYNC_FOLDER=%s SYNC_MARKER=%s\n' "$folder" "$marker"

  section "real browser, two devices"
  run_browser_e2e
fi

summary
