# syntax=docker/dockerfile:1
ARG CLOUDFLARED_VERSION
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} AS upstream

FROM debian:stable-slim
ARG CLOUDFLARED_VERSION
LABEL org.opencontainers.image.version="${CLOUDFLARED_VERSION}"
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --assume-yes \
       rsync openssh-client ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=upstream /usr/local/bin/cloudflared /usr/local/bin/cloudflared
CMD ["cloudflared", "--version"]
