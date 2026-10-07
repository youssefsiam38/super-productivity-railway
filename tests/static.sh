#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Static validation: syntax, shellcheck, compose, image pins and front-door posture. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "syntax"
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done
if sh -n images/app/entrypoint.sh 2>/dev/null; then pass "parses (POSIX sh): images/app/entrypoint.sh"; else fail "syntax error: images/app/entrypoint.sh"; fi
if command -v node >/dev/null; then
  if node --check tests/browser/sync_e2e.js; then pass "parses: tests/browser/sync_e2e.js"; else fail "syntax error: tests/browser/sync_e2e.js"; fi
fi

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh && shellcheck -s sh images/app/entrypoint.sh; then pass "shellcheck"; else fail "shellcheck"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "services" "app" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "the front door binds to loopback" "127.0.0.1" "$(jq -r '[.services.app.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the front door listens on 8080" "8080" "$(jq -r '[.services.app.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "only the front door is published" "1" "$(jq -r '[.services.app.ports[]?] | length' <<<"$cfg")"
assert_eq "the /data volume is mounted" "/data" "$(jq -r '[.services.app.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_contains "the compose owner password is a placeholder" 'localTestOnly' "$(jq -r '.services.app.environment.OWNER_PASSWORD' <<<"$cfg")"

section "image pins"
df=$(cat images/app/Dockerfile)
assert_contains "the web app comes from the official image, pinned by digest" \
  '^ARG SP_IMAGE=johannesjo/super-productivity:v[0-9.]*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG SP_IMAGE=' images/app/Dockerfile)"
assert_contains "WebDAV is pinned by digest" '^ARG WEBDAV_IMAGE=hacdias/webdav:v[0-9.]*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG WEBDAV_IMAGE=' images/app/Dockerfile)"
assert_contains "Caddy is pinned by digest" '^ARG CADDY_IMAGE=caddy:[^@]*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG CADDY_IMAGE=' images/app/Dockerfile)"
assert_contains "the static app is copied unmodified from the official image" 'COPY --from=sp /usr/share/nginx/html /srv/app' "$df"
assert_eq "the browser test pins Playwright exactly" "1" "$(jq -r '.dependencies.playwright' tests/browser/package.json | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')"

section "front door posture"
cf=$(cat images/app/Caddyfile)
assert_contains "everything is behind basic auth" 'basic_auth {' "$cf"
assert_contains "the Caddyfile uses a hash, never the plaintext" 'CADDY_PASSWORD_HASH' "$cf"
assert_eq "the plaintext password is not referenced by Caddy" "0" "$(grep -c 'OWNER_PASSWORD}' images/app/Caddyfile || true)"
assert_eq "only /healthz is outside the gate" "1" "$(grep -c '^	handle /healthz' images/app/Caddyfile)"
assert_contains "the proxy reports https upstream" 'X-Forwarded-Proto {$FORWARD_PROTO:https}' "$cf"
ep=$(cat images/app/entrypoint.sh)
assert_contains "the password is hashed via stdin, not argv" "printf '%s\\\\n' \"\$OWNER_PASSWORD\" | caddy hash-password" "$ep"
assert_contains "a short password is refused" 'too short' "$ep"
wd=$(cat images/app/webdav.yml)
assert_contains "WebDAV listens on loopback only" '^address: 127.0.0.1' "$wd"
assert_contains "WebDAV serves under /webdav/" '^prefix: /webdav/' "$wd"
assert_contains "WebDAV stores data on the volume" '^directory: /data/webdav' "$wd"
assert_contains "WebDAV also checks the owner credential" "{env}OWNER_PASSWORD" "$wd"
assert_contains "WebDAV CORS stays off (no cross-site use of cached credentials)" 'enabled: false' "$wd"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path '*/node_modules/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
