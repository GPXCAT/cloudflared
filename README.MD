# cloudflared + SSH 自動建置

這份方案使用 GitHub Actions 的 Linux runner，每小時檢查 Cloudflare 官方 cloudflared 最新正式版。若 Docker Hub 還沒有對應版本，便自動建置並推送 `jscat/cloudflared:YYYY.M.P`，成功後再更新 `jscat/cloudflared:latest`，最後通知 Discord。無新版本則不建置、不通知。

## 設定

1. 在 Docker Hub 建立或確認 `jscat/cloudflared` repository。
2. 建立 GitHub repository，把此目錄的內容放在 repository 根目錄；必須包含 `.github/workflows/cloudflared.yml` 隱藏目錄。不要多包一層 cloudflared-autobuild。
3. GitHub repository → Settings → Secrets and variables → Actions → New repository secret，新增：

| Secret | 值 |
| --- | --- |
| DOCKERHUB_USERNAME | jscat |
| DOCKERHUB_TOKEN | Docker Hub 建立的 access token，需有此 repository 的 Read & Write 權限 |
| DISCORD_WEBHOOK_URL | Discord 頻道的 incoming webhook 完整網址；可省略而不通知 |

不要把 access token 或 webhook 寫入程式、Dockerfile 或 Git。

4. 把檔案提交到預設分支（通常 main），開啟 GitHub Actions。
5. Actions → Publish cloudflared SSH image → Run workflow，首次先手動執行。若 Docker Hub 尚無當下最新版本，會立即建置。

排程每小時第 17 分執行，時間採 UTC，但每小時在台灣也是第 17 分。GitHub 排程可能延遲，並非即時觸發；公開 repository 若 60 天沒有活動，排程可能被自動停用，需重新啟用。

## Dockerfile 與版本參數

Dockerfile 用 `CLOUDFLARED_VERSION` 指定上游 image，讓版本標籤與實際 cloudflared binary 對應一致。以下保留 `2024.4.1` 作為版本範例，請依需求替換成實際存在的版本。

## Build：單一平台

建置目前主機的平台，並標記為 `jscat/cloudflared:latest`：

```bash
VERSION=2024.4.1

docker build \
  --build-arg CLOUDFLARED_VERSION="$VERSION" \
  -t jscat/cloudflared .
```

此指令只建置到本機，不會推送 Docker Hub。

## Build：多平台並推送 Docker Hub

先登入 Docker Hub：

```bash
docker login
```

需要支援多平台的 Buildx builder。若尚未設定，可先建立：

```bash
docker buildx create --name cloudflared-builder --driver docker-container --use
docker buildx inspect --bootstrap
```

已有可用的 builder 時可略過建立步驟；同名 builder 已存在時，可用 `docker buildx use cloudflared-builder` 選取。Linux 主機若缺少跨架構執行支援，需先配置 QEMU/binfmt；GitHub Actions 已包含 QEMU 設定步驟。

同時建置 `linux/amd64` 與 `linux/arm64`，並推送版本標籤與 `latest`：

```bash
VERSION=2024.4.1

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CLOUDFLARED_VERSION="$VERSION" \
  -t "jscat/cloudflared:$VERSION" \
  -t jscat/cloudflared:latest \
  --push .
```

| 使用環境 | 平台 |
| --- | --- |
| 一般 Intel／AMD x86-64 Linux、Intel Mac 的 Docker Linux 容器 | `linux/amd64` |
| Apple Silicon Mac、ARM64 Linux 的 Docker Linux 容器 | `linux/arm64` |

兩種架構共用相同 image 標籤，Docker 會依主機架構選用。`--push` 直接推送 registry，不會將兩種架構的 image 載入本機 image store。32 位元 Raspberry Pi OS 不在這兩種平台中。

GitHub Actions 同樣預設建置這兩個平台。若只需要 x86-64，可把 workflow 的 `platforms` 改為 `linux/amd64`，並移除 QEMU 步驟。

## SSH 設定

以下容器指令把目前目錄的 `./root_ssh/` 掛載成容器內的 `/root/.ssh/`，因此設定檔應建立在 `./root_ssh/config`：

```bash
mkdir -p ./root_ssh
chmod 700 ./root_ssh
vim ./root_ssh/config
```

加入：

```sshconfig
Host ssh.example.com
    ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

把 `ssh.example.com` 換成已設定 Cloudflare Access SSH 的實際主機名稱。`%h` 會代入 SSH 連線的主機名稱。

```bash
chmod 600 ./root_ssh/config
```

若需金鑰登入，把對應私鑰放在 `./root_ssh/`（例如 `id_ed25519`），並將私鑰權限設為 `600`。這個目錄也會保存 SSH 的 `known_hosts`。Cloudflare Access 驗證與遠端主機的 SSH 登入驗證仍需依你的設定完成。

若是在主機直接執行 SSH，設定檔才是 `~/.ssh/config`。單獨編輯主機的 `~/.ssh/config` 不會影響以下掛載 `./root_ssh/` 的容器。若希望沿用主機的設定與金鑰，可將掛載改為 `-v "$HOME/.ssh:/root/.ssh"`；容器也會因此存取該目錄內的金鑰。

請勿把 `root_ssh/`、私鑰或本機資料目錄提交至公開 repository；也應在自己的 `.dockerignore` 中排除它們，避免傳入建置 context。

## Run SSH

```bash
docker run --rm -it \
    -v ./root_ssh/:/root/.ssh/ \
    jscat/cloudflared \
    ssh ssh.example.com -l user
```

把 `user` 換成遠端 SSH 帳號。若要固定 image 版本，可將 `jscat/cloudflared` 改成 `jscat/cloudflared:2024.4.1`。

## Run rsync

先準備本機資料目錄：

```bash
mkdir -p ./data/foo
```

將本機 `./data/foo/` 同步到遠端 `/volume1/foo/`：

```bash
docker run --rm -it \
    -v ./root_ssh/:/root/.ssh/ \
    -v ./data:/data \
    jscat/cloudflared \
    rsync -avhP --delete "/data/foo/" "user@ssh.example.com:/volume1/foo/"
```

遠端主機也需要安裝 rsync，且 `user` 需要有目標目錄的寫入權限。rsync 會經由 SSH 使用前述 ProxyCommand。

`/data/foo/` 結尾的 `/` 表示同步此目錄內的內容。`--delete` 會刪除遠端目標目錄中、來源沒有的檔案。首次執行可先加上 `--dry-run` 檢查預計變更：

```bash
docker run --rm -it \
    -v ./root_ssh/:/root/.ssh/ \
    -v ./data:/data \
    jscat/cloudflared \
    rsync -avhP --delete --dry-run "/data/foo/" "user@ssh.example.com:/volume1/foo/"
```

## 重試與維護

- 以 Docker Hub 已存在的版本 manifest 當紀錄，不依賴 runner 本機資料。
- 先推送版本標籤，再讓 latest 指向該 manifest。若更新 latest 失敗，下次會重新同步，無須重建已成功的版本。
- Discord 失敗會讓該次 workflow 顯示失敗，但不撤回已推送的 image；沒有跨執行的通知補發佇列。
- 排程只處理當時最新正式版，不補建兩次檢查間的中間版本。
- 修改 Dockerfile 不會自動重建既有版本。手動 Run workflow 並勾選 force 可重建當前版本；這會覆寫該版本標籤與 latest。
- 如果你手動把 latest 指向其他版本，下次排程會同步回目前官方最新版本。
- 內建 concurrency 避免此 workflow 同時發佈。請勿讓其他流程同時覆寫相同 image 標籤。
- 若上游 GitHub 發佈了 Release、但相同版本的 Docker image 尚未上線，建置會失敗；下次排程會再次嘗試。
- workflow 本身不部署或更新既有容器，僅建置、發佈及通知。
- GitHub Actions 使用量與 Docker Hub 費用／額度依帳號方案而定。

## 官方參考

- https://docs.docker.com/build/ci/github-actions/
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule
- https://docs.github.com/en/rest/releases/releases#get-the-latest-release
