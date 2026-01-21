# Sub2API

<div align="center">

[![Go](https://img.shields.io/badge/Go-1.25.5-00ADD8.svg)](https://golang.org/)
[![Vue](https://img.shields.io/badge/Vue-3.4+-4FC08D.svg)](https://vuejs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7+-DC382D.svg)](https://redis.io/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

**AI API 閘道器平臺 - 訂閱配額分發管理**

[English](README.md) | 中文

</div>

---

## 線上體驗

體驗地址：**https://v2.pincc.ai/**

演示帳號（共享演示環境；自建部署不會自動建立該帳號）：

| 郵箱 | 密碼 |
|------|------|
| admin@sub2api.com | admin123 |

## 專案概述

Sub2API 是一個 AI API 閘道器平臺，用於分發和管理 AI 產品訂閱（如 Claude Code $200/月）的 API 配額。使用者透過平臺生成的 API Key 呼叫上游 AI 服務，平臺負責鑑權、計費、負載均衡和請求轉發。

## 核心功能

- **多帳號管理** - 支援多種上游帳號型別（OAuth、API Key）
- **API Key 分發** - 為使用者生成和管理 API Key
- **精確計費** - Token 級別的用量追蹤和成本計算
- **智慧排程** - 智慧帳號選擇，支援粘性會話
- **併發控制** - 使用者級和帳號級併發限制
- **速率限制** - 可配置的請求和 Token 速率限制
- **管理後臺** - Web 介面進行監控和管理

## 技術棧

| 元件 | 技術 |
|------|------|
| 後端 | Go 1.25.5, Gin, Ent |
| 前端 | Vue 3.4+, Vite 5+, TailwindCSS |
| 資料庫 | PostgreSQL 15+ |
| 快取/佇列 | Redis 7+ |

---

## 文件

- 依賴安全：`docs/dependency-security.md`

---

## OpenAI Responses 相容注意事項

- 當請求包含 `function_call_output` 時，需要攜帶 `previous_response_id`，或在 `input` 中包含帶 `call_id` 的 `tool_call`/`function_call`，或帶非空 `id` 且與 `function_call_output.call_id` 匹配的 `item_reference`。
- 若依賴上游歷史記錄，閘道器會強制 `store=true` 並需要複用 `previous_response_id`，以避免出現 “No tool call found for function call output” 錯誤。

---

## 部署方式

### 方式一：指令碼安裝（推薦）

一鍵安裝指令碼，自動從 GitHub Releases 下載預編譯的二進位制檔案。

#### 前置條件

- Linux 伺服器（amd64 或 arm64）
- PostgreSQL 15+（已安裝並執行）
- Redis 7+（已安裝並執行）
- Root 許可權

#### 安裝步驟

```bash
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/install.sh | sudo bash
```

指令碼會自動：
1. 檢測系統架構
2. 下載最新版本
3. 安裝二進位制檔案到 `/opt/sub2api`
4. 建立 systemd 服務
5. 配置系統使用者和許可權

#### 安裝後配置

```bash
# 1. 啟動服務
sudo systemctl start sub2api

# 2. 設定開機自啟
sudo systemctl enable sub2api

# 3. 在瀏覽器中開啟設定嚮導
# http://你的伺服器IP:8080
```

設定嚮導將引導你完成：
- 資料庫配置
- Redis 配置
- 管理員帳號建立

#### 升級

可以直接在 **管理後臺** 左上角點選 **檢測更新** 按鈕進行線上升級。

網頁升級功能支援：
- 自動檢測新版本
- 一鍵下載並應用更新
- 支援回滾

#### 常用命令

```bash
# 檢視狀態
sudo systemctl status sub2api

# 檢視日誌
sudo journalctl -u sub2api -f

# 重啟服務
sudo systemctl restart sub2api

# 解除安裝
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/install.sh | sudo bash -s -- uninstall -y
```

---

### 方式二：Docker Compose

使用 Docker Compose 部署，包含 PostgreSQL 和 Redis 容器。

#### 前置條件

- Docker 20.10+
- Docker Compose v2+

#### 安裝步驟

```bash
# 1. 克隆倉庫
git clone https://github.com/Wei-Shaw/sub2api.git
cd sub2api

# 2. 進入 deploy 目錄
cd deploy

# 3. 複製環境配置檔案
cp .env.example .env

# 4. 編輯配置（設定密碼等）
nano .env
```

**`.env` 必須配置項：**

```bash
# PostgreSQL 密碼（必須修改！）
POSTGRES_PASSWORD=your_secure_password_here

# 可選：管理員帳號
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=your_admin_password

# 可選：自定義埠
SERVER_PORT=8080

# 可選：安全配置
# 啟用 URL 白名單驗證（false 則跳過白名單檢查，僅做基本格式校驗）
SECURITY_URL_ALLOWLIST_ENABLED=false

# 關閉白名單時，是否允許 http:// URL（預設 false，只允許 https://）
# ⚠️ 警告：允許 HTTP 會暴露 API 金鑰（明文傳輸）
#          僅建議在以下場景使用：
#          - 開發/測試環境
#          - 內部可信網路
#          - 本地測試伺服器（http://localhost）
# 生產環境：保持 false 或僅使用 HTTPS URL
SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false

# 是否允許私有 IP 地址用於上游/定價/CRS（內網部署時使用）
SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false
```

```bash
# 5. 啟動所有服務
docker-compose up -d

# 6. 檢視狀態
docker-compose ps

# 7. 檢視日誌
docker-compose logs -f sub2api
```

#### 訪問

在瀏覽器中開啟 `http://你的伺服器IP:8080`

#### 升級

```bash
# 拉取最新映象並重建容器
docker-compose pull
docker-compose up -d
```

#### 常用命令

```bash
# 停止所有服務
docker-compose down

# 重啟
docker-compose restart

# 檢視所有日誌
docker-compose logs -f
```

---

### 方式三：原始碼編譯

從原始碼編譯安裝，適合開發或定製需求。

#### 前置條件

- Go 1.21+
- Node.js 18+
- PostgreSQL 15+
- Redis 7+

#### 編譯步驟

```bash
# 1. 克隆倉庫
git clone https://github.com/Wei-Shaw/sub2api.git
cd sub2api

# 2. 安裝 pnpm（如果還沒有安裝）
npm install -g pnpm

# 3. 編譯前端
cd frontend
pnpm install
pnpm run build
# 構建產物輸出到 ../backend/internal/web/dist/

# 4. 編譯後端（嵌入前端）
cd ../backend
go build -tags embed -o sub2api ./cmd/server

# 5. 建立配置檔案
cp ../deploy/config.example.yaml ./config.yaml

# 6. 編輯配置
nano config.yaml
```

> **注意：** `-tags embed` 引數會將前端嵌入到二進位制檔案中。不使用此引數編譯的程式將不包含前端介面。

**`config.yaml` 關鍵配置：**

```yaml
server:
  host: "0.0.0.0"
  port: 8080
  mode: "release"

database:
  host: "localhost"
  port: 5432
  user: "postgres"
  password: "your_password"
  dbname: "sub2api"

redis:
  host: "localhost"
  port: 6379
  password: ""

jwt:
  secret: "change-this-to-a-secure-random-string"
  expire_hour: 24

default:
  user_concurrency: 5
  user_balance: 0
  api_key_prefix: "sk-"
  rate_multiplier: 1.0
```

`config.yaml` 還支援以下安全相關配置：

- `cors.allowed_origins` 配置 CORS 白名單
- `security.url_allowlist` 配置上游/價格資料/CRS 主機白名單
- `security.url_allowlist.enabled` 可關閉 URL 校驗（慎用）
- `security.url_allowlist.allow_insecure_http` 關閉校驗時允許 HTTP URL
- `security.url_allowlist.allow_private_hosts` 允許私有/本地 IP 地址
- `security.response_headers.enabled` 可啟用可配置響應頭過濾（關閉時使用預設白名單）
- `security.csp` 配置 Content-Security-Policy
- `billing.circuit_breaker` 計費異常時 fail-closed
- `server.trusted_proxies` 啟用可信代理解析 X-Forwarded-For
- `turnstile.required` 在 release 模式強制啟用 Turnstile

**⚠️ 安全警告：HTTP URL 配置**

當 `security.url_allowlist.enabled=false` 時，系統預設執行最小 URL 校驗，**拒絕 HTTP URL**，僅允許 HTTPS。要允許 HTTP URL（例如用於開發或內網測試），必須顯式設定：

```yaml
security:
  url_allowlist:
    enabled: false                # 停用白名單檢查
    allow_insecure_http: true     # 允許 HTTP URL（⚠️ 不安全）
```

**或透過環境變數：**

```bash
SECURITY_URL_ALLOWLIST_ENABLED=false
SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=true
```

**允許 HTTP 的風險：**
- API 金鑰和資料以**明文傳輸**（可被截獲）
- 易受**中間人攻擊 (MITM)**
- **不適合生產環境**

**適用場景：**
- ✅ 開發/測試環境的本地伺服器（http://localhost）
- ✅ 內網可信端點
- ✅ 獲取 HTTPS 前測試帳號連通性
- ❌ 生產環境（僅使用 HTTPS）

**未設定此項時的錯誤示例：**
```
Invalid base URL: invalid url scheme: http
```

如關閉 URL 校驗或響應頭過濾，請加強網路層防護：
- 出站訪問白名單限制上游域名/IP
- 阻斷私網/迴環/鏈路本地地址
- 強制僅允許 TLS 出站
- 在反向代理層移除敏感響應頭

```bash
# 6. 執行應用
./sub2api
```

#### 開發模式

```bash
# 後端（支援熱過載）
cd backend
go run ./cmd/server

# 前端（支援熱過載）
cd frontend
pnpm run dev
```

#### 程式碼生成

修改 `backend/ent/schema` 後，需要重新生成 Ent + Wire：

```bash
cd backend
go generate ./ent
go generate ./cmd/server
```

---

## 簡易模式

簡易模式適合個人開發者或內部團隊快速使用，不依賴完整 SaaS 功能。

- 啟用方式：設定環境變數 `RUN_MODE=simple`
- 功能差異：隱藏 SaaS 相關功能，跳過計費流程
- 安全注意事項：生產環境需同時設定 `SIMPLE_MODE_CONFIRM=true` 才允許啟動

---

## Antigravity 使用說明

Sub2API 支援 [Antigravity](https://antigravity.so/) 帳戶，授權後可透過專用端點訪問 Claude 和 Gemini 模型。

### 專用端點

| 端點 | 模型 |
|------|------|
| `/antigravity/v1/messages` | Claude 模型 |
| `/antigravity/v1beta/` | Gemini 模型 |

### Claude Code 配置示例

```bash
export ANTHROPIC_BASE_URL="http://localhost:8080/antigravity"
export ANTHROPIC_AUTH_TOKEN="sk-xxx"
```

### 混合排程模式

Antigravity 帳戶支援可選的**混合排程**功能。開啟後，通用端點 `/v1/messages` 和 `/v1beta/` 也會排程該帳戶。

> **⚠️ 注意**：Anthropic Claude 和 Antigravity Claude **不能在同一上下文中混合使用**，請透過分組功能做好隔離。


### 已知問題
在 Claude Code 中，無法自動退出Plan Mode。（正常使用原生Claude Api時，Plan 完成後，Claude Code會彈出彈出選項讓使用者同意或拒絕Plan。） 
解決辦法：shift + Tab，手動退出Plan mode，然後輸入內容 告訴 Claude Code 同意或拒絕 Plan
---

## 專案結構

```
sub2api/
├── backend/                  # Go 後端服務
│   ├── cmd/server/           # 應用入口
│   ├── internal/             # 內部模組
│   │   ├── config/           # 配置管理
│   │   ├── model/            # 資料模型
│   │   ├── service/          # 業務邏輯
│   │   ├── handler/          # HTTP 處理器
│   │   └── gateway/          # API 閘道器核心
│   └── resources/            # 靜態資源
│
├── frontend/                 # Vue 3 前端
│   └── src/
│       ├── api/              # API 呼叫
│       ├── stores/           # 狀態管理
│       ├── views/            # 頁面元件
│       └── components/       # 通用元件
│
└── deploy/                   # 部署檔案
    ├── docker-compose.yml    # Docker Compose 配置
    ├── .env.example          # Docker Compose 環境變數
    ├── config.example.yaml   # 二進位制部署完整配置檔案
    └── install.sh            # 一鍵安裝指令碼
```

## 許可證

MIT License

---

<div align="center">

**如果覺得有用，請給個 Star 支援一下！**

</div>
