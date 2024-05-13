# build
```bash
docker build -t jscat/cloudflared .
```

# build multi platform
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t jscat/cloudflared:2024.4.1 -t jscat/cloudflared:latest --push .
```

# run
```bash
docker run --rm -it \
    -v /vol/user/root_ssh/:/root/.ssh/ \
    -v /volume1:/volume1 \
    jscat/cloudflared \
    bash
```

# install docker
https://docs.docker.com/engine/install/ubuntu/
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

cloudflared documentation: https://github.com/cloudflared/cloudflared