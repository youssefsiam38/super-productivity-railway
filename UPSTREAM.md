# Upstream

| Component | Image | Pinned tag | Digest (multi-arch index) |
|---|---|---|---|
| Super Productivity | `johannesjo/super-productivity` | `v19.1.0` | `sha256:6177a56563e855ad613782860955c61ed256afb68e1d0bfdaa4df98aad77c9e4` |
| webdav | `hacdias/webdav` | `v5.17.0` | `sha256:8b8a39de046fd04a2615f51c245883ea40547efba4ad0b4646e1b7a0d5daf23a` |
| Caddy | `caddy` | `2.11.7-alpine` | `sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f` |

Upstream project: https://github.com/johannesjo/super-productivity (MIT). The pins are the `ARG …_IMAGE=` lines in
`images/app/Dockerfile`.

## Wrapper image

`ghcr.io/youssefsiam38/super-productivity-railway`, built by `.github/workflows/publish-image.yml` on a `vX.Y.Z` tag.
The template pins it by digest:

`ghcr.io/youssefsiam38/super-productivity-railway:1.0.0@sha256:f024df37c6300bccb900ca546e2516f76a11989f742b08ca93ee406cc05a122b`

## Refreshing a digest

```bash
curl -s "https://hub.docker.com/v2/repositories/johannesjo/super-productivity/tags/v19.1.0/" | jq -r .digest
curl -s "https://hub.docker.com/v2/repositories/hacdias/webdav/tags/v5.17.0/" | jq -r .digest
curl -s "https://hub.docker.com/v2/repositories/library/caddy/tags/2.11.7-alpine/" | jq -r .digest
```
