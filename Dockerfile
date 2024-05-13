FROM ubuntu:22.04

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive \
    && apt install --no-install-recommends --assume-yes rsync openssh-client ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=cloudflare/cloudflared:latest /usr/local/bin/cloudflared /usr/local/bin/cloudflared
