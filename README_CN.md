# Sub2API

<div align="center">

[![Go](https://img.shields.io/badge/Go-1.25.7-00ADD8.svg)](https://golang.org/)
[![Vue](https://img.shields.io/badge/Vue-3.4+-4FC08D.svg)](https://vuejs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7+-DC382D.svg)](https://redis.io/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

<a href="https://trendshift.io/repositories/21823" target="_blank"><img src="https://trendshift.io/api/badge/repositories/21823" alt="Wei-Shaw%2Fsub2api | Trendshift" width="250" height="55"/></a>

**AI API 閘道器平臺 - 訂閱配額分發管理**

[English](README.md) | 中文 | [日本語](README_JA.md)

</div>

> **Sub2API 官方僅使用  `sub2api.org` 與 `pincc.ai` 兩個域名。其他使用 Sub2API 名義的網站可能為第三方部署或服務，與本專案無關，請自行甄別。**
---

## 線上體驗

體驗地址：**[https://demo.sub2api.org/](https://demo.sub2api.org/)**

演示帳號（共享演示環境；自建部署不會自動建立該帳號）：

| 郵箱 | 密碼 |
|------|------|
| admin@sub2api.org | admin123 |

## 專案概述

Sub2API 是一個 AI API 閘道器平臺，用於分發和管理 AI 產品訂閱的 API 配額。使用者透過平臺生成的 API Key 呼叫上游 AI 服務，平臺負責鑑權、計費、負載均衡和請求轉發。

## 核心功能

- **多帳號管理** - 支援多種上游帳號型別（OAuth、API Key）
- **API Key 分發** - 為使用者生成和管理 API Key
- **精確計費** - Token 級別的用量追蹤和成本計算
- **智慧排程** - 智慧帳號選擇，支援粘性會話
- **併發控制** - 使用者級和帳號級併發限制
- **速率限制** - 可配置的請求和 Token 速率限制
- **內建支付系統** - 支援 EasyPay 易支付、支付寶官方、微信官方、Stripe，使用者自助充值，無需獨立部署支付服務（[配置指南](docs/PAYMENT_CN.md)）
- **管理後臺** - Web 介面進行監控和管理
- **外部系統整合** - 支援透過 iframe 嵌入外部系統（如工單等），擴充套件管理後臺功能

## ❤️ 贊助商

> [想出現在這裡？](mailto:support@pincc.ai)

<table>
<tr>
<td width="180" align="center" valign="middle"><a href="https://shop.pincc.ai/"><img src="assets/partners/logos/pincc-logo.png" alt="pincc" width="150"></a></td>
<td valign="middle"><b><a href="https://shop.pincc.ai/">PinCC</a></b> 是基於 Sub2API 搭建的官方中轉服務，提供 Claude Code、Codex、Gemini 等主流模型的穩定中轉，開箱即用，免去自建部署與運維煩惱。</td>
</tr>

<tr>
<td width="180"><a href="https://www.packyapi.com/register?aff=sub2api"><img src="assets/partners/logos/packycode.png" alt="PackyCode" width="150"></a></td>
<td>感謝 PackyCode 贊助了本專案！PackyCode 是一家穩定、高效的API中轉服務商，提供 Claude Code、Codex、Gemini 等多種中轉服務。PackyCode 為本軟體的使用者提供了特別優惠，使用<a href="https://www.packyapi.com/register?aff=sub2api">此連結</a>註冊並在充值時填寫"sub2api"優惠碼，首次充值可以享受9折優惠！</td>
</tr>

<tr>
<td width="180"><a href="https://ctok.ai"><img src="assets/partners/logos/ctok.png" alt="CTok" width="150"></a></td>
<td>感謝 CTok.ai 贊助了本專案！CTok.ai 致力於打造一站式 AI 程式設計工具服務平臺。我們提供 Claude Code 專業套餐及技術社群服務，同時支援 Google Gemini 和 OpenAI Codex。透過精心設計的套餐方案和專業的技術社群，為開發者提供穩定的服務保障和持續的技術支援，讓 AI 輔助程式設計真正成為開發者的生產力工具。點選<a href="https://ctok.ai">這裡</a>註冊！</td>
</tr>

<tr>
<td width="180"><a href="https://aigocode.com/invite/SUB2API"><img src="assets/partners/logos/aigocode.png" alt="AIGoCode" width="150"></a></td>
<td>感謝 AIGoCode 贊助了本專案！AIGoCode 是一站式整合 Claude Code、Codex 以及最新 Gemini 模型的綜合平臺，為您提供穩定、高效、高性價比的 AI 程式設計服務。平臺提供靈活的訂閱方案，零封號風險，免 VPN 直連，響應極速。AIGoCode 為 sub2api 使用者準備了專屬福利：透過<a href="https://aigocode.com/invite/SUB2API">此連結</a>註冊，首次充值可額外獲得 10% 贈送額度！</td>
</tr>

<tr>
<td width="180"><a href="https://apikey.fun/register?aff=SUB2API"><img src="assets/partners/logos/apikey-fun.png" alt="APIKEY.FUN" width="150"></a></td>
<td>感謝 APIKEY.FUN 贊助了本專案！<a href="https://apikey.fun/register?aff=SUB2API">APIKEY.FUN</a> 是 sub2api 開源專案的核心貢獻者之一，致力於提供開放、穩定、高性價比的 AI API 接入服務。平臺支援 Claude、OpenAI、Gemini 等熱門模型的 API 中轉服務，價格低至官方原價的 7%。透過專屬連結 <a href="https://apikey.fun/register?aff=SUB2API">APIKEY</a> 註冊，可享受所有充值永久 95 折優惠。</td>
</tr>

<tr>
<td width="180"><a href="https://code.silkapi.com/register?aff=SUB2API"><img src="assets/partners/logos/silkapi.png" alt="silkapi" width="150"></a></td>
<td>感謝 絲綢API 贊助了本專案！ <a href="https://code.silkapi.com/register?aff=SUB2API">絲綢API</a> 是基於 Sub2API 搭建的中轉服務，專注於提供 Codex 高速穩定API中轉。</td>
</tr>

<tr>
<td width="180"><a href="https://ylscode.com/"><img src="assets/partners/logos/ylscode.png" alt="ylscode" width="150"></a></td>
<td>感謝 伊莉思Code 贊助了本專案！ <a href="https://ylscode.com/">伊莉思Code</a> 致力於構建安全的企業級Coding Agent生產力服務，提供穩定快速的 Codex / Claude / Gemini 訂閱服務與即用即付API多種方案靈活選擇，限時註冊贈送 3 天 Codex 試用福利！</td>
</tr>

<tr>
<td width="180"><a href="https://www.aicodemirror.com/register?invitecode=KMVZQM"><img src="assets/partners/logos/AICodeMirror.jpg" alt="AICodeMirror" width="150"></a></td>
<td>感謝 AICodeMirror 贊助了本專案！AICodeMirror 提供 Claude Code / Codex / Gemini CLI 官方高穩定性中轉服務，企業級併發、快速開票、7×24 小時專屬技術支援。Claude Code / Codex / Gemini 官方通道低至原價 38% / 2% / 9%，充值更享額外折扣！AICodeMirror 為 sub2api 使用者提供專屬福利：透過<a href="https://www.aicodemirror.com/register?invitecode=KMVZQM">此連結</a>註冊，首次充值立享 8 折優惠，企業客戶最高可享 75 折！</td>
</tr>

<tr>
<td width="180"><a href="https://shop.bmoplus.com/?utm_source=github"><img src="assets/partners/logos/bmoplus.jpg" alt="bmoplus" width="150"></a></td>
<td>感謝 BmoPlus 贊助了本專案！BmoPlus 是一家專為AI訂閱重度使用者打造的可靠 AI 帳號代充服務商，提供穩定的 ChatGPT Plus / ChatGPT Pro(全程質保) / Claude Pro / Super Grok / Gemini Pro 的官方代充&成品帳號。 透過<a href="https://shop.bmoplus.com/?utm_source=github">BmoPlus AI成品號專賣/代充</a>註冊下單的使用者，可享GPT 官網訂閱一折 的震撼價格！</td>
</tr>

<tr>
<td width="180"><a href="https://bestproxy.com/?keyword=a2e8iuol"><img src="assets/partners/logos/bestproxy.png" alt="bestproxy" width="150"></a></td>
<td>感謝 Bestproxy 贊助了本專案！<a href="https://bestproxy.com/?keyword=a2e8iuol">Bestproxy</a> 是一家提供高純度住宅IP，支援一號一IP獨享，結合真實家庭網路與指紋隔離，可實現鏈路環境隔離，降低關聯風控機率。</td>
</tr>

<tr>
<td width="180"><a href="https://pateway.ai/?ch=1tsfr51"><img src="assets/partners/logos/pateway.png" alt="pateway" width="150"></a></td>
<td>感謝 PatewayAI 贊助了本專案！PatewayAI 是一家面向重度 AI 開發者、專注官方直連的高品質模型 API 中轉服務商。提供 Claude 全系列與 Codex 系列模型，100% 官方源直供，不摻假不注水，歡迎檢驗。計費透明，Token 級帳單可逐筆核驗。
同時支援企業級高併發，併為企業客戶提供了專業的管理平臺，企業客戶可簽訂正式合同並開具發票，更多詳情進入官網獲取聯絡方式。
現在透過 <a href="https://pateway.ai/?ch=1tsfr51">此連結</a> 註冊即送 $3 試用額度，使用者充值低至 6 折，邀請好友雙向贈送，邀請獎勵可達 $150。</td>
</tr>

<tr>
<td width="180"><a href="https://api.pptoken.org/register?promo=SUB2API"><img src="assets/partners/logos/pptoken.png" alt="pptoken" width="150"></a></td>
<td>感謝 PPToken.org 贊助本專案！ <a href="https://api.pptoken.org/register?promo=SUB2API">PPToken.org</a> 主打 GPT 系列模型 API 中轉服務，支援 Codex、Claude Code、OpenAI 相容客戶端及 Gemini CLI 等工具接入。充值 1:1，1 元=1 美元額度；GPT 模型最低 0.16 倍倍率，綜合成本約為官方價格的 0.22 折，最快首字 Token 約 1 秒，適合開發者低成本、高響應速度接入 GPT 模型能力。技術支援： 7×24 小時真人響應（不是機器人），群內@技術，10 分鐘內有回覆 。贊助商福利：前 200 名使用者透過 <a href="https://api.pptoken.org/register?promo=SUB2API">[專屬註冊連結]</a> 註冊，輸入優惠碼 `SUB2API`，可領取 Codex / Claude Code 免費試用額度，無門檻、不綁卡。
</td>
</tr>
</table>

## 生態專案

圍繞 Sub2API 的社群擴充套件與整合專案：

| 專案 | 說明 | 功能 |
|------|------|------|
| ~~[Sub2ApiPay](https://github.com/touwaeriol/sub2apipay)~~ | ~~自助支付系統~~ | **已內建** — 支付功能已整合到 Sub2API 中，無需獨立部署。詳見 [支付配置指南](docs/PAYMENT_CN.md) |
| [sub2api-mobile](https://github.com/ckken/sub2api-mobile) | 移動端管理控制台 | 跨平臺應用（iOS/Android/Web），支援使用者管理、帳號管理、監控看板、多後端切換；基於 Expo + React Native 構建 |

## 技術棧

| 元件 | 技術 |
|------|------|
| 後端 | Go 1.25.7, Gin, Ent |
| 前端 | Vue 3.4+, Vite 5+, TailwindCSS |
| 資料庫 | PostgreSQL 15+ |
| 快取/佇列 | Redis 7+ |

---

## Nginx 反向代理注意事項

透過 Nginx 反向代理 Sub2API（或 CRS 服務）並搭配 Codex CLI 使用時，需要在 Nginx 配置的 `http` 塊中新增：

```nginx
underscores_in_headers on;
```

Nginx 預設會丟棄名稱中含下劃線的請求頭（如 `session_id`），這會導致多帳號環境下的粘性會話功能失效。

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

### 方式二：Docker Compose（推薦）

使用 Docker Compose 部署，包含 PostgreSQL 和 Redis 容器。

#### 前置條件

- Docker 20.10+
- Docker Compose v2+

#### 快速開始（一鍵部署）

使用自動化部署指令碼快速搭建：

```bash
# 建立部署目錄
mkdir -p sub2api-deploy && cd sub2api-deploy

# 下載並執行部署準備指令碼
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-deploy.sh | bash

# 啟動服務
docker compose up -d

# 檢視日誌
docker compose logs -f sub2api
```

**指令碼功能：**
- 下載 `docker-compose.local.yml`（本地儲存為 `docker-compose.yml`）和 `.env.example`
- 自動生成安全憑證（JWT_SECRET、TOTP_ENCRYPTION_KEY、POSTGRES_PASSWORD）
- 建立 `.env` 檔案並填充自動生成的金鑰
- 建立資料目錄（使用本地目錄，便於備份和遷移）
- 顯示生成的憑證供你記錄

#### 手動部署

如果你希望手動配置：

```bash
# 1. 克隆倉庫
git clone https://github.com/Wei-Shaw/sub2api.git
cd sub2api/deploy

# 2. 複製環境配置檔案
cp .env.example .env

# 3. 編輯配置（生成安全密碼）
nano .env
```

**`.env` 必須配置項：**

```bash
# PostgreSQL 密碼（必需）
POSTGRES_PASSWORD=your_secure_password_here

# JWT 金鑰（推薦 - 重啟後保持使用者登入狀態）
JWT_SECRET=your_jwt_secret_here

# TOTP 加密金鑰（推薦 - 重啟後保留雙因素認證）
TOTP_ENCRYPTION_KEY=your_totp_key_here

# 可選：管理員帳號
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=your_admin_password

# 可選：自定義埠
SERVER_PORT=8080
```

**生成安全金鑰：**
```bash
# 生成 JWT_SECRET
openssl rand -hex 32

# 生成 TOTP_ENCRYPTION_KEY
openssl rand -hex 32

# 生成 POSTGRES_PASSWORD
openssl rand -hex 32
```

```bash
# 4. 建立資料目錄（本地版）
mkdir -p data postgres_data redis_data

# 5. 啟動所有服務
# 選項 A：本地目錄版（推薦 - 易於遷移）
docker compose -f docker-compose.local.yml up -d

# 選項 B：命名卷版（簡單設定）
docker compose up -d

# 6. 檢視狀態
docker compose -f docker-compose.local.yml ps

# 7. 檢視日誌
docker compose -f docker-compose.local.yml logs -f sub2api
```

#### 部署版本對比

| 版本 | 資料儲存 | 遷移便利性 | 適用場景 |
|------|---------|-----------|---------|
| **docker-compose.local.yml** | 本地目錄 | ✅ 簡單（打包整個目錄） | 生產環境、頻繁備份 |
| **docker-compose.yml** | 命名卷 | ⚠️ 需要 docker 命令 | 簡單設定 |

**推薦：** 使用 `docker-compose.local.yml`（指令碼部署）以便更輕鬆地管理資料。

#### 啟用“資料管理”功能（datamanagementd）

如需啟用管理後臺“資料管理”，需要額外部署宿主機資料管理程序 `datamanagementd`。

關鍵點：

- 主程序固定探測：`/tmp/sub2api-datamanagement.sock`
- 只有該 Socket 可連通時，資料管理功能才會開啟
- Docker 場景需將宿主機 Socket 掛載到容器同路徑

詳細部署步驟見：`deploy/DATAMANAGEMENTD_CN.md`

#### 訪問

在瀏覽器中開啟 `http://你的伺服器IP:8080`

如果管理員密碼是自動生成的，在日誌中查詢：
```bash
docker compose -f docker-compose.local.yml logs sub2api | grep "admin password"
```

#### 升級

```bash
# 拉取最新映象並重建容器
docker compose -f docker-compose.local.yml pull
docker compose -f docker-compose.local.yml up -d
```

#### 輕鬆遷移（本地目錄版）

使用 `docker-compose.local.yml` 時，可以輕鬆遷移到新伺服器：

```bash
# 源伺服器
docker compose -f docker-compose.local.yml down
cd ..
tar czf sub2api-complete.tar.gz sub2api-deploy/

# 傳輸到新伺服器
scp sub2api-complete.tar.gz user@new-server:/path/

# 新伺服器
tar xzf sub2api-complete.tar.gz
cd sub2api-deploy/
docker compose -f docker-compose.local.yml up -d
```

#### 常用命令

```bash
# 停止所有服務
docker compose -f docker-compose.local.yml down

# 重啟
docker compose -f docker-compose.local.yml restart

# 檢視所有日誌
docker compose -f docker-compose.local.yml logs -f

# 刪除所有資料（謹慎！）
docker compose -f docker-compose.local.yml down
rm -rf data/ postgres_data/ redis_data/
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

### Sora 功能狀態（暫不可用）

> ⚠️ 當前 Sora 相關功能因上游接入與媒體鏈路存在技術問題，暫時不可用。
> 現階段請勿在生產環境依賴 Sora 能力。
> 文件中的 `gateway.sora_*` 配置僅作預留，待技術問題修復後再恢復可用。

### Sora 媒體簽名 URL（功能恢復後可選）

當配置 `gateway.sora_media_signing_key` 且 `gateway.sora_media_signed_url_ttl_seconds > 0` 時，閘道器會將 Sora 輸出的媒體地址改寫為臨時簽名 URL（`/sora/media-signed/...`）。這樣無需 API Key 即可在瀏覽器中直接訪問，且具備過期控制與防篡改能力（簽名包含 path + query）。

```yaml
gateway:
  # /sora/media 是否強制要求 API Key（預設 false）
  sora_media_require_api_key: false
  # 媒體臨時簽名金鑰（為空則停用簽名）
  sora_media_signing_key: "your-signing-key"
  # 臨時簽名 URL 有效期（秒）
  sora_media_signed_url_ttl_seconds: 900
```

> 若未配置簽名金鑰，`/sora/media-signed` 將返回 503。  
> 如需更嚴格的訪問控制，可將 `sora_media_require_api_key` 設為 true，僅允許攜帶 API Key 的 `/sora/media` 訪問。

訪問策略說明：
- `/sora/media`：內部呼叫或客戶端攜帶 API Key 才能下載
- `/sora/media-signed`：外部可訪問，但有簽名 + 過期控制

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

**閘道器防禦縱深建議（重點）**

- `gateway.upstream_response_read_max_bytes`：限制非流式上游響應讀取大小（預設 `8MB`），用於防止異常響應導致記憶體放大。
- `gateway.proxy_probe_response_read_max_bytes`：限制代理探測響應讀取大小（預設 `1MB`）。
- `gateway.gemini_debug_response_headers`：預設 `false`，僅在排障時短時開啟，避免高頻請求日誌開銷。
- `/auth/register`、`/auth/login`、`/auth/login/2fa`、`/auth/send-verify-code` 已提供服務端兜底限流（Redis 故障時 fail-close）。
- 推薦將 WAF/CDN 作為第一層防護，服務端限流與響應讀取上限作為第二層兜底；兩層同時保留，避免旁路流量與誤配置風險。

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

#### HTTP/2 (h2c) 與 HTTP/1.1 回退

後端明文埠預設支援 h2c，並保留 HTTP/1.1 回退用於 WebSocket 與舊客戶端。瀏覽器通常不支援 h2c，效能收益主要在反向代理或內網鏈路。

**反向代理示例（Caddy）：**

```caddyfile
transport http {
	versions h2c h1
}
```

**驗證：**

```bash
# h2c prior knowledge
curl --http2-prior-knowledge -I http://localhost:8080/health
# HTTP/1.1 回退
curl --http1.1 -I http://localhost:8080/health
# WebSocket 回退驗證（需管理員 token）
websocat -H="Sec-WebSocket-Protocol: sub2api-admin, jwt.<ADMIN_TOKEN>" ws://localhost:8080/api/v1/admin/ops/ws/qps
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

## 免責宣告

> **使用本專案前請仔細閱讀：**
>
> :rotating_light: **服務條款風險**: 使用本專案可能違反 Anthropic 的服務條款。請在使用前仔細閱讀 Anthropic 的使用者協議，使用本專案的一切風險由使用者自行承擔。
>
> :book: **免責宣告**: 本專案僅供技術學習和研究使用，作者不對因使用本專案導致的帳戶封禁、服務中斷或其他損失承擔任何責任。

---

## Star History

<a href="https://star-history.com/#Wei-Shaw/sub2api&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Wei-Shaw/sub2api&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Wei-Shaw/sub2api&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Wei-Shaw/sub2api&type=Date" />
 </picture>
</a>

---

## 許可證

本專案基於 [GNU 寬通用公共許可證 v3.0](LICENSE)（或更高版本）授權。

Copyright (c) 2026 Wesley Liddick

---

<div align="center">

**如果覺得有用，請給個 Star 支援一下！**

</div>
