#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: write sync data, recreate the container keeping the volume, verify it survived.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

cleanup() {
  local rc=$?
  [ "$rc" -eq 0 ] || compose logs --no-color --tail 150 || true
  compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

section "seed"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d --quiet-pull
wait_for_code "$APP_URL/healthz" 200 || die "never became healthy"
check_sync "persist" "persist-marker-$$"

section "recreate the container (volume kept)"
compose down --remove-orphans
compose up -d
wait_for_code "$APP_URL/healthz" 200 && pass "healthy after recreate" || die "never came back"

section "verify"
check_sync_kept "persist" "persist-marker-$$"
check_front_door
assert_eq "the owner still signs in" "200" "$(acode "$APP_URL/")"

summary
