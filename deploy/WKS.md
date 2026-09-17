# wks 部署紀錄

本 fork 部署在 wks（Hostinger VPS），服務名 `twsub2api`。通用流程見本機 `~/.claude/guides/wks-deploy.md`。

| 項目 | 值 |
|------|----|
| 網址 | https://cp.beyondsearchai.com |
| 流量路徑 | Cloudflare 橘雲 → nginx_proxy（NPM，萬用憑證 `*.beyondsearchai.com`）→ `twsub2api:8080` |
| 程式碼 | `/home/orz99/zoo/sub2api.TW`（https clone，追蹤 `main`） |
| compose | `/home/orz99/zoo/docker-compose.yml` 的 `twsub2api` 區塊 |
| 映像 | `dado/twsub2api:v<VERSION>`，記憶體上限 512MB |
| 資料 | 共用 `postgresql_db`（資料庫 `sub2api`）與 `redis_cache`（db 3） |
| 機密 | `/home/orz99/zoo/.env` 的 `SUB2API_*` 鍵 |
| 備份 | `/home/orz99/zoo/backups/sub2api-<舊版本>-<時間>.dump` |

## 更新

本機推送 `main` 後：

```bash
ssh wks 'bash /home/orz99/zoo/sub2api.TW/deploy/wks-update.sh'
```

腳本會備份資料庫、`git pull`、在 `VERSION` 變更時同步 compose 的 `image` 與 build 參數 `VERSION`、重建映像、只重啟 `twsub2api`，最後從 nginx_proxy 檢查 `/health`。

## 回退

1. 把 compose 的 `image` 改回舊標籤（舊映像用 `docker images dado/twsub2api` 查）。
2. 若新版已跑過資料庫 migration，先用備份還原：`docker exec -i postgresql_db sh -c 'pg_restore -U "$POSTGRES_USER" -d sub2api --clean' < backups/<檔名>.dump`。
3. `docker compose up -d --no-deps twsub2api`。

## 注意事項

- Dockerfile 預設 `GOPROXY=goproxy.cn`，在 wks 下載會斷線，腳本已改用 `proxy.golang.org`。
- 資料庫備份會累積在 `backups/`，每份約 2MB，定期手動清理。
- 同機另有 CLIProxyAPI（`https://cpa.beyondsearchai.com`，服務名 `cli-proxy-api`），紀錄在該 repo 的 `deploy/WKS.md`。
