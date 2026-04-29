# datamanagementd 部署說明（資料管理）

本文說明如何在宿主機部署 `datamanagementd`，並與主程序聯動開啟“資料管理”功能。

## 1. 關鍵約束

- 主程序固定探測路徑：`/tmp/sub2api-datamanagement.sock`
- 僅當該 Unix Socket 可連通且 `Health` 成功時，後臺“資料管理”才會啟用
- `datamanagementd` 使用 SQLite 持久化後設資料，不依賴主庫

## 2. 宿主機構建與執行

```bash
cd /opt/sub2api-src/datamanagement
go build -o /opt/sub2api/datamanagementd ./cmd/datamanagementd

mkdir -p /var/lib/sub2api/datamanagement
chown -R sub2api:sub2api /var/lib/sub2api/datamanagement
```

手動啟動示例：

```bash
/opt/sub2api/datamanagementd \
  -socket-path /tmp/sub2api-datamanagement.sock \
  -sqlite-path /var/lib/sub2api/datamanagement/datamanagementd.db \
  -version 1.0.0
```

## 3. systemd 託管（推薦）

倉庫已提供示例服務檔案：`deploy/sub2api-datamanagementd.service`

```bash
sudo cp deploy/sub2api-datamanagementd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sub2api-datamanagementd
sudo systemctl status sub2api-datamanagementd
```

檢視日誌：

```bash
sudo journalctl -u sub2api-datamanagementd -f
```

也可以使用一鍵安裝指令碼（自動安裝二進位制 + 註冊 systemd）：

```bash
# 方式一：使用現成二進位制
sudo ./deploy/install-datamanagementd.sh --binary /path/to/datamanagementd

# 方式二：從原始碼構建後安裝
sudo ./deploy/install-datamanagementd.sh --source /path/to/sub2api
```

## 4. Docker 部署聯動

若 `sub2api` 執行在 Docker 容器中，需要將宿主機 Socket 掛載到容器同路徑：

```yaml
services:
  sub2api:
    volumes:
      - /tmp/sub2api-datamanagement.sock:/tmp/sub2api-datamanagement.sock
```

建議在 `docker-compose.override.yml` 中維護該掛載，避免覆蓋主 compose 檔案。

## 5. 依賴檢查

`datamanagementd` 執行備份時依賴以下工具：

- `pg_dump`
- `redis-cli`
- `docker`（僅 `source_mode=docker_exec` 時）

缺失依賴會導致對應任務失敗，並在任務詳情中體現錯誤資訊。
