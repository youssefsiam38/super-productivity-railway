# syntax=docker/dockerfile:1
#
# Combined image for the Super Productivity Railway template:
#   - the Super Productivity web app (the static build from the official image, unmodified),
#   - a WebDAV server (hacdias/webdav) that stores the sync data on the /data volume,
#   - a Caddy front door: the only public listener, HTTP basic auth on everything except /healthz.
# One origin serves both the app and its sync backend, so the browser app syncs same-origin
# (no CORS) and every other device syncs to https://<domain>/webdav/ with the same credentials.
ARG SP_IMAGE=johannesjo/super-productivity:v19.1.0@sha256:6177a56563e855ad613782860955c61ed256afb68e1d0bfdaa4df98aad77c9e4
ARG WEBDAV_IMAGE=hacdias/webdav:v5.17.0@sha256:8b8a39de046fd04a2615f51c245883ea40547efba4ad0b4646e1b7a0d5daf23a
ARG CADDY_IMAGE=caddy:2.11.7-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f

FROM ${SP_IMAGE} AS sp
FROM ${WEBDAV_IMAGE} AS webdav

FROM ${CADDY_IMAGE}
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown

# Static web app exactly as upstream ships it (minus source maps, which are only for debugging).
COPY --from=sp /usr/share/nginx/html /srv/app
RUN find /srv/app -name '*.map' -delete
COPY --from=webdav /bin/webdav /usr/local/bin/webdav
COPY images/app/Caddyfile /etc/caddy/Caddyfile
COPY images/app/webdav.yml /etc/webdav/config.yml
COPY --chmod=0755 images/app/entrypoint.sh /usr/local/bin/sp-railway-entrypoint

ENV PORT=8080 \
    XDG_DATA_HOME=/var/lib/caddy \
    XDG_CONFIG_HOME=/var/lib/caddy/config \
    OWNER_USERNAME=owner

LABEL org.opencontainers.image.title="super-productivity-railway" \
      org.opencontainers.image.description="Super Productivity web app + WebDAV sync behind a Caddy basic-auth front door, for the Railway template. Not affiliated with the Super Productivity project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/super-productivity-railway" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

EXPOSE 8080
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ["sh", "-c", "wget -q -O /dev/null http://127.0.0.1:${PORT:-8080}/healthz || exit 1"]

ENTRYPOINT ["/usr/local/bin/sp-railway-entrypoint"]
