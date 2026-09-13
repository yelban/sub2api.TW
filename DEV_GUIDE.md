# sub2api 專案開發指南

> 本文件記錄專案環境配置、常見坑點和注意事項，供 Claude Code 和團隊成員參考。

## 一、專案基本資訊

| 專案 | 說明 |
|------|------|
| **上游倉庫** | Wei-Shaw/sub2api |
| **Fork 倉庫** | bayma888/sub2api-bmai |
| **技術棧** | Go 後端 (Ent ORM + Gin) + Vue3 前端 (pnpm) |
| **資料庫** | PostgreSQL 16 + Redis |
| **包管理** | 後端: go modules, 前端: **pnpm**（不是 npm） |

## 二、本地環境配置

### PostgreSQL 16 (Windows 服務)

| 配置項 | 值 |
|--------|-----|
| 埠 | 5432 |
| psql 路徑 | `C:\Program Files\PostgreSQL\16\bin\psql.exe` |
| pg_hba.conf | `C:\Program Files\PostgreSQL\16\data\pg_hba.conf` |
| 資料庫憑據 | user=`sub2api`, password=`sub2api`, dbname=`sub2api` |
| 超級使用者 | user=`postgres`, password=`postgres` |

### Redis

| 配置項 | 值 |
|--------|-----|
| 埠 | 6379 |
| 密碼 | 無 |

### 開發工具

```bash
# golangci-lint（CI 用 v2.13，本地建議裝同一版以免版本差異帶來的噪音）
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.13

# pnpm (前端包管理)
npm install -g pnpm
```

## 三、CI/CD 流水線

### GitHub Actions Workflows

| Workflow | 觸發條件 | 檢查內容 |
|----------|----------|----------|
| **backend-ci.yml** | push, pull_request | 單元測試 + 整合測試 + golangci-lint v2.13 |
| **security-scan.yml** | push, pull_request, 每週一 | govulncheck + gosec + pnpm audit |
| **release.yml** | tag `v*` | 構建釋出（PR 不觸發） |

### CI 要求

- Go 版本必須是 **1.27.0**：三個 workflow 都用 `go-version-file: backend/go.mod` 取版本，隨後硬斷言 `go version | grep -q 'go1.27.0'`。升級 Go 時要同時改 `backend/go.mod`、`backend-ci.yml`（兩處）、`release.yml`、`security-scan.yml` 裡的這句斷言，**以及三個 Dockerfile 裡的 Go 構建映象**（`Dockerfile` / `deploy/Dockerfile` 的 `ARG GOLANG_IMAGE`、`backend/Dockerfile` 的 `FROM golang:`）。前者漏了 CI 會在版本校驗步驟直接失敗；**後者漏了 CI 不會報，而是等到有人用這些 Dockerfile 構建時才失敗**（`go.mod requires go >= X (running Y; GOTOOLCHAIN=local)`）。
- 前端使用 `pnpm install --frozen-lockfile`，必須提交 `pnpm-lock.yaml`

### 本地測試命令

```bash
# 後端單元測試
cd backend && go test -tags=unit ./...

# 後端整合測試
cd backend && go test -tags=integration ./...

# 程式碼質量檢查
cd backend && golangci-lint run ./...

# 前端依賴安裝（必須用 pnpm）
cd frontend && pnpm install
```

## 四、常見坑點 & 解決方案

### 坑 1：pnpm-lock.yaml 必須同步提交

**問題**：`package.json` 新增依賴後，CI 的 `pnpm install --frozen-lockfile` 失敗。

**原因**：上游 CI 使用 pnpm，lock 檔案不同步會報錯。

**解決**：
```bash
cd frontend
pnpm install  # 更新 pnpm-lock.yaml
git add pnpm-lock.yaml
git commit -m "chore: update pnpm-lock.yaml"
```

---

### 坑 2：npm 和 pnpm 的 node_modules 衝突

**問題**：之前用 npm 裝過 `node_modules`，pnpm install 報 `EPERM` 錯誤。

**解決**：
```bash
cd frontend
rm -rf node_modules  # 或 PowerShell: Remove-Item -Recurse -Force node_modules
pnpm install
```

---

### 坑 3：PowerShell 中 bcrypt hash 的 `$` 被轉義

**問題**：bcrypt hash 格式如 `$2a$10$xxx...`，PowerShell 把 `$2a` 當變數解析，導致資料丟失。

**解決**：將 SQL 寫入檔案，用 `psql -f` 執行：
```bash
# 錯誤示範（PowerShell 會吃掉 $）
psql -c "INSERT INTO users ... VALUES ('$2a$10$...')"

# 正確做法
echo "INSERT INTO users ... VALUES ('\$2a\$10\$...')" > temp.sql
psql -U sub2api -h 127.0.0.1 -d sub2api -f temp.sql
```

---

### 坑 4：psql 不支援中文路徑

**問題**：`psql -f "D:\中文路徑\file.sql"` 報錯找不到檔案。

**解決**：複製到純英文路徑再執行：
```bash
cp "D:\中文路徑\file.sql" "C:\temp.sql"
psql -f "C:\temp.sql"
```

---

### 坑 5：PostgreSQL 密碼重置流程

**場景**：忘記 PostgreSQL 密碼。

**步驟**：
1. 修改 `C:\Program Files\PostgreSQL\16\data\pg_hba.conf`
   ```
   # 將 scram-sha-256 改為 trust
   host    all    all    127.0.0.1/32    trust
   ```
2. 重啟 PostgreSQL 服務
   ```powershell
   Restart-Service postgresql-x64-16
   ```
3. 無密碼登入並重置
   ```bash
   psql -U postgres -h 127.0.0.1
   ALTER USER sub2api WITH PASSWORD 'sub2api';
   ALTER USER postgres WITH PASSWORD 'postgres';
   ```
4. 改回 `scram-sha-256` 並重啟

---

### 坑 6：Go interface 新增方法後 test stub 必須補全

**問題**：給 interface 新增方法後，編譯報錯 `does not implement interface (missing method XXX)`。

**原因**：所有測試檔案中實現該 interface 的 stub/mock 都必須補上新方法。

**解決**：
```bash
# 搜尋所有實現該 interface 的 struct
cd backend
grep -r "type.*Stub.*struct" internal/
grep -r "type.*Mock.*struct" internal/

# 逐一補全新方法
```

---

### 坑 7：Windows 上 psql 連 localhost 的 IPv6 問題

**問題**：psql 連 `localhost` 先嚐試 IPv6 (::1)，可能報錯後再回退 IPv4。

**建議**：直接用 `127.0.0.1` 代替 `localhost`。

---

### 坑 8：Windows 沒有 make 命令

**問題**：CI 裡用 `make test-unit`，本地 Windows 沒有 make。

**解決**：直接用 Makefile 裡的原始命令：
```bash
# 代替 make test-unit
go test -tags=unit ./...

# 代替 make test-integration
go test -tags=integration ./...
```

---

### 坑 9：Ent Schema 修改後必須重新生成

**問題**：修改 `ent/schema/*.go` 後，程式碼不生效。

**解決**：
```bash
cd backend
go generate ./ent  # 重新生成 ent 程式碼（json.RawMessage 欄位會生成為同類型的 jsontext.Value，屬預期）
git add ent/       # 生成的檔案也要提交
```

---

### 坑 10：前端測試看似正常，但後端呼叫失敗（模型對映被批次誤改）

**典型現象**：
- 前端按鈕點測看起來正常；
- 實際通過 API/客戶端呼叫時返回 `Service temporarily unavailable` 或提示無可用帳號；
- 常見於 OpenAI 帳號（例如 Codex 模型）在批次修改後突然不可用。

**根因**：
- OpenAI 帳號編輯頁預設不顯式展示對映規則，容易讓人誤以為“沒對映也沒關係”；
- 但在**批次修改同時選中不同平臺帳號**（OpenAI + Antigravity/Gemini）時，模型白名單/對映可能被跨平臺策略覆蓋；
- 結果是 OpenAI 帳號的關鍵模型對映丟失或被改壞，後端選不到可用帳號。

**修復方案（按優先順序）**：
1. **快速修復（推薦）**：在批次修改中補回正確的透傳對映（例如 `gpt-5.3-codex -> gpt-5.3-codex-spark`）。
2. **徹底重建**：刪除並重新新增全部相關帳號（最穩但成本高）。

**關鍵經驗**：
- 如果某模型已被軟體內建預設對映覆蓋，通常不需要額外再加透傳；
- 但當上遊模型更新快於本倉庫預設對映時，**手動批次新增透傳對映**是最簡單、最低風險的臨時兜底方案；
- 批次操作前儘量按平臺分組，不要混選不同平臺帳號。

---

### 坑 11：PR 提交前檢查清單

提交 PR 前務必本地驗證：

- [ ] `go test -tags=unit ./...` 通過
- [ ] `go test -tags=integration ./...` 通過
- [ ] `golangci-lint run ./...` 無新增問題
- [ ] `pnpm-lock.yaml` 已同步（如果改了 package.json）
- [ ] 所有 test stub 補全新介面方法（如果改了 interface）
- [ ] Ent 生成的程式碼已提交（如果改了 schema）

## 五、常用命令速查

### 資料庫操作

```bash
# 連線資料庫
psql -U sub2api -h 127.0.0.1 -d sub2api

# 檢視所有使用者
psql -U postgres -h 127.0.0.1 -c "\du"

# 檢視所有資料庫
psql -U postgres -h 127.0.0.1 -c "\l"

# 執行 SQL 檔案
psql -U sub2api -h 127.0.0.1 -d sub2api -f migration.sql
```

### Git 操作

```bash
# 同步上游
git fetch upstream
git checkout main
git merge upstream/main
git push origin main

# 建立功能分支
git checkout -b feature/xxx

# Rebase 到最新 main
git fetch upstream
git rebase upstream/main
```

### 前端操作

```bash
# 安裝依賴（必須用 pnpm）
cd frontend
pnpm install

# 開發伺服器
pnpm dev

# 構建
pnpm build
```

### 後端操作

```bash
# 執行伺服器
cd backend
go run ./cmd/server/

# 生成 Ent 程式碼
go generate ./ent

# 執行測試
go test -tags=unit ./...
go test -tags=integration ./...

# Lint 檢查
golangci-lint run ./...
```

## 六、專案結構速覽

```
sub2api-bmai/
├── backend/
│   ├── cmd/server/          # 主程式入口
│   ├── ent/                 # Ent ORM 生成程式碼
│   │   └── schema/          # 資料庫 Schema 定義
│   ├── internal/
│   │   ├── handler/         # HTTP 處理器
│   │   ├── service/         # 業務邏輯
│   │   ├── repository/      # 資料訪問層
│   │   └── server/          # 伺服器配置
│   ├── migrations/          # 資料庫遷移指令碼
│   └── config.yaml          # 配置檔案
├── frontend/
│   ├── src/
│   │   ├── api/             # API 呼叫
│   │   ├── components/      # Vue 元件
│   │   ├── views/           # 頁面檢視
│   │   ├── types/           # TypeScript 型別
│   │   └── i18n/            # 國際化
│   ├── package.json         # 依賴配置
│   └── pnpm-lock.yaml       # pnpm 鎖檔案（必須提交）
└── .claude/
    └── CLAUDE.md            # 本文件
```

## 七、參考資源

- [上游倉庫](https://github.com/Wei-Shaw/sub2api)
- [Ent 文件](https://entgo.io/docs/getting-started)
- [Vue3 文件](https://vuejs.org/)
- [pnpm 文件](https://pnpm.io/)
