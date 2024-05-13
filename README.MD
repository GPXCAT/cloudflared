# build
```bash
docker build -t jscat/cloudflared .
```

# build multi platform
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t jscat/cloudflared:2024.4.1 -t jscat/cloudflared:latest --push .
```

# vim ~/.ssh/config
```bash
Host ssh.example.com
ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

# run ssh
```bash
docker run --rm -it \
    -v ./root_ssh/:/root/.ssh/ \
    jscat/cloudflared \
    ssh ssh.example.com -l user
```

# run rsync
```bash
docker run --rm -it \
    -v ./root_ssh/:/root/.ssh/ \
    -v ./data:/data \
    jscat/cloudflared \
    rsync -avhP --delete "/data/foo/" "user@ssh.example.com:/volume1/foo/"
```

# install docker
https://docs.docker.com/engine/install/ubuntu/
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```
