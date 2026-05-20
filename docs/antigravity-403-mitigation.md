# Antigravity 帳號 403 風控緩解指南

> 建立日期：2026-04-30
> 適用版本：sub2api v0.1.120 (upstream)
> 主題：Antigravity OAuth 帳號頻繁出現 `Validation required (403)` / 大規模封號的原因分析與緩解策略

---

## TL;DR（先看結論）

1. **TLS 指紋偽裝對 Antigravity 帳號完全無效**——sub2api 的 TLS 指紋實作在程式碼層面就排除了 Antigravity 平臺（`backend/internal/service/account.go:1390`），且即使能套用也不會有幫助（理由見[第 4 節](#4-為什麼tls-指紋對-antigravity-無效詳細糾正)）。
2. **Antigravity 大規模封號是 Google 端風控設計，所有反代專案通用**，不是 sub2api 獨有問題。社群普遍認為 [#1453](https://github.com/Wei-Shaw/sub2api/issues/1453)、[#1433](https://github.com/Wei-Shaw/sub2api/issues/1433) 屬此類，「在哪都是秒封」。
3. **真實有效的緩解只有四項**：
   - **保持 UA 版本最新**（已在 `ANTIGRAVITY_USER_AGENT_VERSION` env 處理）
   - **每帳號獨立乾淨 IP**（per-account proxy；sub2api 已支援 `account.ProxyID`）
   - **避開 Antigravity 走高風險模型路徑**（社群觀察 Opus 4.6 路由特別容易觸發）
   - **降低單帳號併發 + 失敗冷卻**（目前 sub2api 對 403 validation 是直接永久停用，沒有冷卻期）
4. **沒有真正的「徹底解決方案」**。Antigravity 客戶端會回報 IDE 行為遙測（滑鼠、鍵盤、視窗焦點），任何純 API 反代都無法偽造這些。

---

## 1. 錯誤訊息解析

### Sub2API 看到的錯誤

```
Validation required (403): Verify your account to continue. | validation_url: https://accounts.google.com/signin/continue?...
```

### Sub2API 程式碼如何分類 403

`backend/internal/service/antigravity_quota_fetcher.go:220` 的 `classifyForbiddenType()` 把 Antigravity 403 分成三類：

| 型別 | 觸發條件（response body 包含） | sub2api 處置 |
|---|---|---|
| `validation` | `validation_required` / `verify your account` / `validation_url` | **永久 SetError**，需人工去 Google 驗證後手動恢復 |
| `violation` | `terms of service` / `violation` | **永久 SetError**，視同封號，需聯絡 Google |
| `forbidden`（generic） | 其他 | **永久 SetError** |

實際處理在 `backend/internal/service/ratelimit_service.go:765-805`：

```go
func (s *RateLimitService) handleAntigravity403(...) (shouldDisable bool) {
    fbType := classifyForbiddenType(string(responseBody))
    switch fbType {
    case forbiddenTypeValidation:
        // 永久停用，需人工去 Google 驗證後手動恢復
        s.handleAuthError(ctx, account, msg)
        return true
    ...
    }
}
```

**注意：sub2api 對 Antigravity 403 全部都是「永久停用」，沒有指數退避也沒有冷卻期。** 一觸發就要人工去後臺操作。

---

## 2. 真實 Root Cause（按發生機率排序）

### 2.1 Sub2API 內部 402 / 401 被誤認為 Google 403 ⚠️ 最常被誤判

**先講結論**：sub2api 的「使用者餘額不足」**不會**回傳 `Validation required`，而是回 **`Payment required (402): insufficient balance or billing issue`**（`backend/internal/service/ratelimit_service.go:249`）。

但實務上很多使用者看到任何 4xx 錯誤都以為是 Google 風控，混淆了兩種完全不同的問題。

**典型誤判案例**：

[Issue #2076](https://github.com/Wei-Shaw/sub2api/issues/2076) 標題雖是「Antigravity 版本不支援」，但 liaoOyao 的留言：

> 「謝謝，cc 用上了。原來是我的管理員帳號沒有充值餘額，一直顯示餘額不夠」

——這位使用者其實遇到的是 **402 餘額不足**，不是 Antigravity UA 問題、也不是 Google 風控，但發在這個 issue 下被誤導。

#### 一張表分清楚

| 你看到的訊息（精確字串） | 真實原因 | 處理方向 |
|---|---|---|
| `Payment required (402): insufficient balance or billing issue` | **Sub2API 內部** — 使用者錢包餘額為 0 | 後臺充值 |
| `Credit balance exhausted (400): credit balance is too low` | **Anthropic 上游** — Anthropic API key 帳戶沒餘額 | Anthropic console 加值 |
| `Unauthorized (401)` | API key 失效 / 過期 | 重發 API key |
| `Validation required (403): ... validation_url: https://accounts.google.com/...` | **Google 真實風控** — Antigravity 帳號需驗證 | 見 §6 完整 SOP |
| `Account violation (403): ... terms of service` | **Google 封號** — 帳號被永久標記 | 該帳號報廢，聯絡 Google |
| `Access forbidden (403)`（無 validation_url、無 violation） | 通用 403 — 配額 / 設定 / 端點問題 | 看 sub2api logs |

#### 鑑別 SOP

```bash
# 1. 從 client 端看回應的精確字串（含括號裡的數字）
#    402 → 內部餘額；403 + validation_url → Google 風控

# 2. 確認 sub2api 是否真的有把請求送出去
docker compose logs sub2api --since 10m 2>&1 \
  | grep -E "cloudcode-pa|antigravity.*upstream|outbound" \
  | tail -20

#    沒看到 cloudcode-pa.googleapis.com → sub2api 內部就擋掉了，根本沒打 Google

# 3. 後臺確認使用者餘額
#    /admin/users → 找你自己 → 看「餘額」欄位
```

#### 內部 402 / 401 處理

```
1. 後臺 /admin/users → 找你自己 → 「更多」→ 「充值」
   即使你是 admin 也要充值，admin 不等於有無限額度

2. 訂閱模式：
   後臺 → 訂閱分配 → 把訂閱方案分配給你的帳號

3. 確認分組許可權：
   後臺 → 分組 → 檢查你的分組有沒有對應平臺帳號池
   /admin/api-keys → 確認 API key 綁的分組正確
```

### 2.2 客戶端版本（User-Agent）過舊 ⚡ 容易解

Antigravity 上游每 1-2 週發新版本就把舊版擋掉：

| 期間 | 最新版本 | 來源 |
|---|---|---|
| 2026-03 | v1.21.6 / v1.21.9 | [changelog](https://www.gradually.ai/en/changelogs/antigravity/) |
| 2026-04 上旬 | v1.22.2 | 同上 |
| 2026-04-16 起 | **v1.23.2** | [Antigravity Changelog](https://antigravity.google/changelog) |

**症狀**：所有請求穩定回 `This version of Antigravity is no longer supported`。

**解法**：升 UA 版本，重啟容器（`docker compose up -d`，不能用 `restart`）：

```bash
echo "ANTIGRAVITY_USER_AGENT_VERSION=1.23.2" >> .env
docker compose up -d sub2api
docker compose exec sub2api env | grep ANTIGRAVITY  # 驗證
```

`deploy/docker-compose.yml` 的 `environment:` 區段必須有：

```yaml
- ANTIGRAVITY_USER_AGENT_VERSION=${ANTIGRAVITY_USER_AGENT_VERSION:-}
```

否則 `.env` 的值不會 pass 進容器。

### 2.3 IDE 行為遙測缺失 🔴 無法解

社群核心觀點（[#1233](https://github.com/Wei-Shaw/sub2api/issues/1233)、[#1453](https://github.com/Wei-Shaw/sub2api/issues/1453)，contributor StarryKira 多次強調）：

> 「反重力有神奇遙測，會上傳使用者滑鼠點了什麼的操作日誌，sub2api 一直沒解決」
> 「目前只有那個注入反重力 js 的那個能相對穩定」

**機制推測**：
- Antigravity 是 VS Code 衍生的 Electron 桌面應用
- 它會持續回報 IDE 使用情境：滑鼠軌跡、鍵盤節奏、視窗焦點切換、檔案開關、Agent 執行狀態
- Google 端風控引擎會比對「這個帳號最近 N 分鐘有 IDE 遙測嗎？沒有→風控」
- **純 API 反代（包括 sub2api）無法偽造這些遙測**——沒有真實 IDE 在跑

**症狀**：帳號用一段時間（幾小時到幾天）就被 `VALIDATION_REQUIRED`，與請求量無關。重新去 Google 驗證後又能用，幾天後又被擋。

**緩解（不是解法）**：
- 帳號**先在真實 Antigravity IDE 跑幾次任務**，建立「人類使用」的遙測底；之後再放到 sub2api 用
- **混合使用**：每週讓帳號在真實 IDE 用一次（任意操作 5-10 分鐘）
- 不要把全新建立的 OAuth 帳號直接丟去 sub2api

### 2.4 IP 信譽不足

**症狀**：同一 VPS IP 跑 N 個 Antigravity 帳號，幾天內全部一起被風控。

- 雲端機房 IP（AWS、GCP、Linode、Hetzner、DigitalOcean 等）對 Google 而言是「資料中心」，先天信任度低
- 多帳號共用同 IP → Google 視為「異常聚合」
- 高頻併發 → 觸發行為異常

**緩解**：

1. 用 sub2api 的 per-account proxy 功能：後臺 → 帳號 → 編輯 → 設定 ProxyID
2. 優先用**住宅 ISP Proxy**（cost 高但效果最好）
3. 次選：自家寬頻 + WireGuard 出口（但要注意自家 IP 也可能被一起標記）

### 2.5 模型路由風險

[Issue #563](https://github.com/Wei-Shaw/sub2api/issues/563) 與相關討論：

> denvey：「sub2api 從升級到 opus 4.6 錯誤率太高了」
> godloveBiya：「我也是付費的 ultra 帳號，年前被封了 5 個 claude 帳號，7 個 antigravity 帳號」

**社群觀察**：把 Opus 4.6 走 Antigravity 路徑特別容易導致連鎖封號。可能與 sub2api 對 thinking 模式的 request body 處理有關（被 Google 視為異常請求）。

**緩解**：在後臺 group 設定，把 Opus 4.6 路由排除 Antigravity 帳號池，只留 Anthropic 帳號處理。

---

## 3. 程式碼證據

### 3.1 sub2api 實際對 Antigravity 做了什麼

| 機制 | 檔案 | 是否啟用 |
|---|---|---|
| User-Agent 動態版本 | `backend/internal/pkg/antigravity/oauth.go:53,70` | ✅ env 控制 |
| Per-account Proxy | `backend/internal/service/antigravity_quota_fetcher.go:208` | ✅ 帳號設定 ProxyID |
| OAuth Token Refresh | `backend/internal/service/antigravity_token_refresher.go` | ✅ 自動 |
| MODEL_CAPACITY 冷卻 | `backend/internal/service/antigravity_gateway_service.go:73,361` | ✅ 10 秒 |
| Google 配置錯誤冷卻 | `backend/internal/service/antigravity_gateway_service.go:2489` | ✅ 1 分鐘 |
| INTERNAL 500 漸進懲罰 | `backend/internal/service/antigravity_internal500_penalty.go` | ✅ |
| 隱私模式設定 | `backend/internal/service/antigravity_privacy_service.go` | ✅ 建立帳號時 |
| 模型對映（Opus 4.6→thinking） | `backend/migrations/051_*.sql` | ✅ |

### 3.2 sub2api 沒做的（已知缺口）

| 機制 | 影響 | 為何沒做 |
|---|---|---|
| **TLS 指紋偽裝** | 無 | 對 Antigravity 無意義（見 §4） |
| **403 Validation 自動冷卻** | 大 | 設計上認為需人工驗證 |
| **IDE 行為遙測偽造** | 大 | 技術上極困難 |
| **自動 UA 版本拉取** | 中 | 沒有官方 changelog API |
| **`client.go:443` IDEVersion 寫死** | 小 | LoadCodeAssist 才用 |

### 3.3 IDEVersion 寫死的潛在問題

`backend/internal/pkg/antigravity/client.go:443`：

```go
reqBody.Metadata.IDEVersion = "1.20.6"
```

這個寫死值**不受 `ANTIGRAVITY_USER_AGENT_VERSION` env 控制**。只在 `LoadCodeAssist`（帳號 onboarding 驗證）用，但若 Google 對這個值也檢查，可能成為新帳號驗證失敗的隱性原因。

**修補建議**：fork 改為讀同一個 env：

```go
reqBody.Metadata.IDEVersion = defaultUserAgentVersion  // 改成從 env 讀
```

---

## 4. 為什麼「TLS 指紋」對 Antigravity 無效（詳細糾正）

網路上常見建議「強制套用 TLS 指紋到 Antigravity 群組」是**錯誤的**。

### 4.1 程式碼層面就排除了

`backend/internal/service/account.go:1390`：

```go
func (a *Account) IsTLSFingerprintEnabled() bool {
    // 僅支援 Anthropic OAuth/SetupToken 帳號
    if !a.IsAnthropicOAuthOrSetupToken() {
        return false
    }
    ...
}

func (a *Account) IsAnthropicOAuthOrSetupToken() bool {
    return a.Platform == PlatformAnthropic && (a.Type == AccountTypeOAuth || a.Type == AccountTypeSetupToken)
}
```

`Platform == "antigravity"` 直接 return false，前端 UI 也不會顯示 TLS 指紋設定區塊。

### 4.2 機制上也無意義

sub2api 的 TLS 指紋是用 [refraction-networking/utls](https://github.com/refraction-networking/utls) 偽裝成 **Node.js 24.x Claude Code 客戶端** 的 ClientHello。但 Antigravity：

- 上游端點是 `https://cloudcode-pa.googleapis.com`（Google API），不是 Anthropic
- 真實 Antigravity 客戶端是 **VS Code 衍生的 Electron 應用**（Chromium TLS stack），不是 Node.js
- 偽裝成 Node.js 去打 Google API → 反而更可疑

### 4.3 真要做也做不到完整偽裝

要對 Antigravity 有意義，需要偽裝成 Electron/Chromium 的 TLS 指紋 + 同時偽造所有 IDE 行為遙測。前者技術上可做（utls 支援 Chrome 指紋），後者目前沒人能做。

**結論**：把資源花在 TLS 指紋是搞錯方向。

---

## 5. 實作緩解措施（依優先序）

### Tier 1：必做（成本低、效果明確）

#### 1.1 升 UA 並驗證 env 真的進到容器

```bash
# .env
ANTIGRAVITY_USER_AGENT_VERSION=1.23.2

# 必須 up -d，不是 restart（後者不重讀 env）
docker compose up -d sub2api

# 驗證
docker compose exec sub2api env | grep ANTIGRAVITY_USER_AGENT_VERSION
# 應輸出 ANTIGRAVITY_USER_AGENT_VERSION=1.23.2
```

#### 1.2 確認 docker-compose.yml 有 pass env

`deploy/docker-compose.yml` 的 sub2api `environment:` 區段必須有：

```yaml
- ANTIGRAVITY_USER_AGENT_VERSION=${ANTIGRAVITY_USER_AGENT_VERSION:-}
```

#### 1.3 設定關鍵的固定金鑰

避免容器重啟後使用者要重新登入 / TOTP 失效：

```bash
# .env
JWT_SECRET=$(openssl rand -hex 32)
TOTP_ENCRYPTION_KEY=$(openssl rand -hex 32)
```

### Tier 2：強烈建議（成本中、效果大）

#### 2.1 把 Opus 4.6 路由排除 Antigravity

後臺 → 分組管理 → 編輯分組 → 限制 Opus 4.6 只能走 Anthropic 帳號池。

#### 2.2 Per-account proxy

不要讓多個 Antigravity 帳號共用同一出口 IP。

```
後臺 → 代理管理 → 新增 Proxy（住宅 IP）
後臺 → 帳號管理 → 編輯帳號 → ProxyID 指定
```

#### 2.3 帳號預熱 SOP

新建立的 Antigravity OAuth 帳號**不要直接丟 sub2api**：

1. 用真實 Antigravity IDE 登入
2. 跑 3-5 個小任務（chat、agent run），每天分散
3. 持續 3-7 天「正常使用」
4. 之後再放到 sub2api，建議仍保留每週 1 次真實 IDE 使用

#### 2.4 降低單帳號併發

後臺 → 帳號 → 編輯 → 併發數限制（建議 Antigravity 帳號設 1-2，不要設高）。

### Tier 3：架構層改進（fork 修改）

#### 3.1 改 IDEVersion 動態化

`backend/internal/pkg/antigravity/client.go:443`：

```go
// 改前：reqBody.Metadata.IDEVersion = "1.20.6"
reqBody.Metadata.IDEVersion = defaultUserAgentVersion
```

#### 3.2 對 403 validation 加冷卻機制（不要一次永久停用）

`backend/internal/service/ratelimit_service.go:769`：

```go
case forbiddenTypeValidation:
    // 改前：直接 SetError 永久停用
    // 改後：先標記 24h cooldown，3 次內未恢復才 SetError
    s.accountRepo.SetTempUnschedulable(ctx, account.ID, time.Now().Add(24*time.Hour), msg)
    s.incrementValidationCounter(account.ID)
    if s.getValidationCount(account.ID) >= 3 {
        s.handleAuthError(ctx, account, msg)
    }
```

效益：給帳號自動恢復機會，避免一次性風波打掉所有帳號。

#### 3.3 加自動 UA 版本檢查

定期跑 cron job 抓 antigravity.google/changelog 的最新版本，自動更新 env。需要 fork 額外開發。

### Tier 4：替代方案（風險已不可控時）

| 方案 | 適合場景 | 缺點 |
|---|---|---|
| 直接用 Antigravity IDE | 個人使用 | 無 API 共用 |
| 改用 Anthropic 官方訂閱 | 主力做 Claude | 失去 Gemini 3 Pro |
| Gemini Code Assist OAuth | 主力做 Gemini | 不是 Antigravity 套餐 |
| **重用官方 ls_core 二進位（見 §5.4）** | 進階使用者、有 desktop 環境 | 需本地裝 Antigravity IDE、純雲端 server 不適用 |

### 5.4 重用官方 ls_core 二進位（最接近「徹底解決」的方案）

社群 [#1453](https://github.com/Wei-Shaw/sub2api/issues/1453) 提到「目前只有那個注入反重力 js 的那個能相對穩定」——準確的描述其實**不是注入 JS**，而是**直接啟動官方 Antigravity IDE 內附的 `ls_core` 二進位**，自己當 Extension Server 注入 OAuth token。代表專案是 [lbjlaq/Antigravity-Tools-LS](https://github.com/lbjlaq/Antigravity-Tools-LS)（Rust + Axum + Tokio）。

#### 5.4.1 為什麼這個能繞過風控（核心原理）

| 比較面向 | sub2api / 一般反代 | Antigravity-Tools-LS |
|---|---|---|
| 發出 gRPC 的程式 | 自己寫的 Go HTTP client | **官方 ls_core 二進位** |
| TLS Client Hello 指紋 | Go `net/http` 預設 | 官方 ls_core（100% 一致） |
| HTTP/2 frame settings | Go 預設 | 官方 ls_core（100% 一致） |
| Connect-Proto / gRPC headers | 手動模擬，可能漏細節 | 官方 ls_core（無法不一致） |
| OAuth 流程 | 自己重做 token refresh | 透過 Extension Server gRPC 介面注入 |
| Google 端風控引擎看到 | 「來路不明的 Go 客戶端」 | 「真實 Antigravity」 |

關鍵：Google 從**網路層**完全分不出「真實 IDE 啟動的 ls_core」與「我們程式啟動的 ls_core」——因為**就是同一個二進位**。這不是偽裝，是借殼。

#### 5.4.2 架構

```
Client（Claude Code / OpenAI SDK）
    ↓ HTTP /v1/chat/completions（OpenAI 相容）
Antigravity-Tools-LS（Rust + Axum，本地 Port 5188）
    ├─ Account Manager（多 OAuth 帳號池）
    ├─ Protocol Transcoder（OpenAI/Anthropic ↔ gRPC/Connect-Proto）
    └─ LS-Orchestrator
          ↓ Spawn / lifecycle 管理
        ls_core（官方二進位，從本地 Antigravity IDE 抽出）
          ↓ Extension Server gRPC 注入 OAuth token
          ↓ SubscribeToUnifiedStateSync
          ↓ gRPC + Connect-Proto over HTTPS
        Google cloudcode-pa.googleapis.com  ✅
```

#### 5.4.3 部署需求

- **必要：本地安裝真實 Antigravity IDE**（從 antigravity.google 下載）
  - macOS / Windows / Linux desktop 都可以
  - 純 headless server **不適用**（除非你能手動把 ls_core 二進位抽出來搬到 server，但 IDE 升級時又要重新搬）
- 本機要能跑 Rust（或用 Docker image）
- IDE 升級時要重新同步 ls_core 二進位（Antigravity-Tools-LS 有 auto sync）
- 多 OAuth 帳號透過 SQLite database-level injection 切換（修改 IDE 的 `state.vscdb`）

#### 5.4.4 安裝（節錄官方）

```bash
# 一鍵安裝
curl -fsSL https://raw.githubusercontent.com/lbjlaq/Antigravity-Tools-LS/main/install.sh | bash

# 或從原始碼跑
git clone https://github.com/lbjlaq/Antigravity-Tools-LS.git
cd Antigravity-Tools-LS
PORT=5188 RUST_LOG=info cargo run --bin cli-server

# Docker（需 mount 本地 IDE 路徑）
# 詳見 repo README
```

啟動後 `http://localhost:5188/v1/chat/completions` 即為 OpenAI 相容端點。

#### 5.4.5 與 sub2api 的兩種整合方式

**方案 A：完全取代 sub2api 對 Antigravity 的處理**

```
Claude Code → 直接指向 Antigravity-Tools-LS（http://desktop:5188）
sub2api 仍管理 Anthropic / OpenAI / Gemini 帳號
```

最乾淨。後臺移除所有 Antigravity 帳號，改在 Antigravity-Tools-LS 管理。

**方案 B：sub2api 透明轉發到 Antigravity-Tools-LS**

```
Claude Code → sub2api（保留統一管理 / 計費 / 路由）
              ├─ Anthropic 帳號 → Anthropic API 直連
              └─ Antigravity 路由 → Antigravity-Tools-LS（http://desktop:5188）
                                      → ls_core → Google
```

需要 fork sub2api 把 Antigravity 平臺的 upstream URL 從 `cloudcode-pa.googleapis.com` 改成 `http://desktop:5188`，**並停用 sub2api 自己的 protocol transformation**（不然會雙重轉換打破請求）。工程量不小，且失去 sub2api 多帳號池效益（因為帳號池實際上在 Antigravity-Tools-LS 裡）。

**結論：除非你需要 sub2api 的計費系統，否則直接用方案 A。**

#### 5.4.6 不要混淆的另一個專案

[Futureppo/antigravity_bypass](https://github.com/Futureppo/antigravity_bypass) 也叫「antigravity bypass」、也會 patch JS frontend，**但只解 MCP tool 數量限制（100 → 114514）**，**跟 403 風控完全無關**。不要被名字誤導。

#### 5.4.7 ⚠️ 重要限制（不要被 README 過度承諾誤導）

Tools-LS 的 README 寫得很漂亮，但實際上**還在 v0.0.3 / Early Experimental Stage**（2026-03-26 釋出，作者自陳）。深入看 GitHub issues 會發現幾個關鍵限制：

##### 限制 1：Thinking 流式輸出未實作 🔴 影響 Opus 4.6 核心價值

README 明文：

> 「思維鏈 (Thinking)：[核心周知] 目前版本尚未實作對 Thinking 過程的流式提取與回顯。該功能已列入路線圖。」

[Issue #17](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/17) 確認：跑 `claude-opus-4-6-thinking` 能拿到答案，但 **Claude Code 看不到思考過程**。Opus 的「extended thinking」價值被砍掉一半。

**解法**：用 [buildin1/Antigravity-Tools-LS](https://github.com/buildin1/Antigravity-Tools-LS) fork——Issue #17 留言：「我在我自己的 fork 中實現了深度思考，並且支援了 lite 模型的深度思考輸出」。

##### 限制 2：模型 ID 必須精確比對（無 alias 自動轉換）

README 明文：

> 「Model Alias forwarding feature has not yet been achieved. An exact Model ID **must be stringently used** during API requests」

| ❌ 不接受 | ✅ 必須用 |
|---|---|
| `claude-opus-4-6` | `claude-opus-4-6-thinking` |
| `claude-opus-4-6-20251101` | `claude-opus-4-6-thinking` |
| `claude-sonnet-4-6-thinking` | `claude-sonnet-4-6` |
| `claude-3-5-sonnet-20250101` | `claude-sonnet-4-6` |

支援的完整清單：
- Claude：`claude-sonnet-4-6`、`claude-opus-4-6-thinking`
- Gemini：`gemini-3.1-pro-high`、`gemini-3.1-pro-low`、`gemini-3-flash-agent`
- 其他：`gpt-oss-120b-medium`

**Claude Code 預設可能傳的 model ID 不一定匹配**，要在 CC config 裡 override。

##### 限制 3：Open issue 反映的實際問題（截至 2026-04）

| Issue | 標題 | 影響 |
|---|---|---|
| [#27](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/27) | 反代 4.6 opus 會報錯，反代 3.1 pro 正常 | **直接打 Opus 使用情境** |
| [#20](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/20) | Claude Code 經常提示：核心返回內容為空 | 穩定度問題 |
| [#18](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/18) | 不管讓它發什麼訊息都回復一個內容 | 可能 cache / state bug |
| [#21](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/21) | 圖片輸入返回空 | 多模態不能用 |
| [#23](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/23) | Same Pro account works with old switch-login, but hangs with Tools-LS v0.0.3 | 退步 bug |
| [#13](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/13) | 登入所有號都是 free + 被封禁，實際在 Antigravity 可以用 | 帳號狀態誤判（v0.0.3 部分修正）|

##### 限制 4：被封號疑慮未明確排除

理論上「重用 ls_core」應該不被封，但實測案例不夠多：

- [Issue #11](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/11) 標題就是「有人用這個被封過號嗎」——**沒有明確答案**
- [Issue #22](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/22) 標題「Does it resolve 7 day block?」——**沒回覆**

「重用 ls_core」**只解 TLS / HTTP/2 / gRPC 層的特徵問題**，但 Google 風控還可能基於：帳號活躍度、IP 信譽、IDE 行為遙測連續性等。Tools-LS 並未偽造 IDE 操作遙測。

##### 限制 5：作者更新頻率

README 明文：

> 「Due to the author's busy work schedule, project updates may not be very frequent.」

關鍵 issue（#11、#17、#22、#27）至今未解決。如果你需要長期穩定的方案，**不適合**直接 production 用。

#### 5.4.8 多帳號管理：手動切換 ≠ 自動輪替

Tools-LS 的多帳號是**「One-Click IDE Account Switching」**——人工觸發切換目前活躍帳號，**不是請求進來自動找可用帳號**的排程。

| 機制 | Tools-LS | sub2api |
|---|---|---|
| 多帳號儲存 | ✅ SQLite 帳號池 | ✅ Postgres |
| 手動 / 一鍵切換目前帳號 | ✅ 改 IDE state.vscdb | ✅ |
| **請求進來自動選可用帳號** | ❌ 沒有 | ✅ scheduler |
| **429 / 403 觸發自動切換** | ❌ 沒有 | ✅ |
| **多帳號並行排程** | ❌ 沒有 | ✅ |
| **Quota 用完自動切下一個** | ❌ 沒有 | ✅ |

如果你要真正的自動輪替，要看下面：

##### 替代 1：同作者的 [Antigravity-Manager](https://github.com/lbjlaq/Antigravity-Manager)（970+ stars）

- ✅ 「智慧帳號輪詢系統：自動負載均衡，觸發 429 或 400 錯誤時毫秒級切換到健康帳號」
- ✅ Tauri + React GUI，比 CLI 友善
- ❌ **不重用 ls_core**——用自己的 HTTP client 模擬請求
- ⚠️ 風控強度可能介於 sub2api 和 Tools-LS 中間

##### 替代 2：自己外層架分流（最穩但工程量大）

```
Claude Code
    ↓
nginx / Caddy（你自己跑，本地）
    ├─ 帳號 A 健康 → Tools-LS 例項 1（綁帳號 A）
    ├─ 帳號 B 健康 → Tools-LS 例項 2（綁帳號 B）
    └─ ...
```

需要：跑多個 Tools-LS instance 各綁不同帳號 + 外層分流邏輯。工程量大，但每個 instance 都重用 ls_core。

##### 替代 3：放棄自動輪替，配 cron 做帳號輪換

如果你只有 2-3 個帳號、用量不大：

```bash
# 每 6 小時切一次帳號
0 */6 * * * curl -X POST http://localhost:5188/v1/accounts/switch -d '{"id":"next"}'
```

Tools-LS 有切換 API，可以排程觸發。

#### 5.4.9 階段性試用 SOP（先驗證再投入）

不要一開始就 all in。建議分階段：

##### 階段 1：30 分鐘可行性驗證

```bash
# 1. 用 buildin1 fork（thinking 已實作）
git clone https://github.com/buildin1/Antigravity-Tools-LS.git
cd Antigravity-Tools-LS
PORT=5188 RUST_LOG=info cargo run --bin cli-server

# 2. 本機 Antigravity IDE 登入 1 個 Google 帳號（不是付費 Pro，先用免費的試）

# 3. Claude Code 設定
export ANTHROPIC_BASE_URL=http://localhost:5188
export ANTHROPIC_AUTH_TOKEN=test
export ANTHROPIC_MODEL=claude-sonnet-4-6   # 注意 ID 精確

# 4. 連 10 個簡單對話
claude "say hi"
claude "1+1=?"
# ...
```

**檢查清單**：

- [ ] 10 個簡單對話全部成功
- [ ] 試 `claude-opus-4-6-thinking`，確認 [#27](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/27) 是否影響你
- [ ] 試 1 個有圖片的請求（看 [#21](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/21) 是否影響）
- [ ] 試 1 個 MCP 工具呼叫
- [ ] 試 1 個 long context（>50k tokens）
- [ ] 連續 24 小時觀察是否被封號

##### 階段 2：依結果決策

| 階段 1 結果 | 推薦下一步 |
|---|---|
| 全綠 + 帳號 1-2 個 | 全切 Tools-LS，sub2api 退役 Antigravity 部分 |
| Sonnet 綠 / Opus 紅（#27） | 留在 Sonnet，Opus 改用 Anthropic 訂閱 |
| 工具呼叫紅（#20、#23） | 不適合，留在 sub2api |
| 24h 內被封 | 可能你的 IP / 帳號信譽問題，重新考慮 |

##### 階段 3：如果一定要多帳號 + 不被封

目前沒有完美方案，權衡：

| 方案 | 風控 | 多帳號自動輪 | 工程量 | 適合 |
|---|---|---|---|---|
| Tools-LS + 1 帳號 | 低 | 無 | 低 | 個人 |
| Antigravity-Manager | 中 | 有 | 低 | 小團隊 |
| 多 Tools-LS instance + nginx 分流 | 低 | 有 | 高 | 進階 |
| sub2api + 大量便宜帳號當消耗品 | 高 | 有 | 低 | 不在意封號 |

#### 5.4.10 相關 fork 與專案

| 專案 | 作者 | 與本主題關係 |
|---|---|---|
| [lbjlaq/Antigravity-Tools-LS](https://github.com/lbjlaq/Antigravity-Tools-LS) | lbjlaq | **本節主角**，重用 ls_core，但 v0.0.3 早期 |
| [buildin1/Antigravity-Tools-LS](https://github.com/buildin1/Antigravity-Tools-LS) | buildin1 | Fork，**已實作 thinking 流式輸出** |
| [lbjlaq/Antigravity-Manager](https://github.com/lbjlaq/Antigravity-Manager) | lbjlaq | 同作者另一專案，有自動輪詢但不重用 ls_core |
| [Futureppo/antigravity_bypass](https://github.com/Futureppo/antigravity_bypass) | Futureppo | **與 403 無關**，只 patch MCP tool 數量限制 |
| [yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy) | yuaotian | DLL 注入強制走 proxy（Windows）、與 403 無關 |
| [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) | router-for-me | 另一個 CLI 反代，但對 Antigravity 支援不完整（[issue #725](https://github.com/router-for-me/CLIProxyAPI/issues/725)）|

#### 5.4.11 最終適用判斷

| 你的情境 | 建議 |
|---|---|
| 只想試試看，1-2 個 Antigravity 帳號 | 試 buildin1 fork + 1 帳號 |
| 主用 Sonnet 4.6 + 帳號 < 5 + 有 desktop | Tools-LS（buildin1 fork） |
| 主用 Opus 4.6-thinking | **暫緩**，等 #27 修復或自己 patch |
| 需要圖片輸入 / 多模態 | **暫緩**，等 #21 修復 |
| 帳號 ≥ 10 + 需自動輪替 | Antigravity-Manager（接受可能被風控） |
| 純 cloud server、無 desktop | 不適用，繼續 sub2api + UA + Per-account proxy |
| 個人單人使用、帳號 1-2 個 | 直接用真實 Antigravity IDE 最省事 |
| 只在乎 Claude，Antigravity 不是必須 | 改用 Anthropic 官方訂閱 / API key |

---

## 6. 403 處置 SOP

### 6.1 真實 Validation required（403）完整解法

#### 第 0 步：先確認是真正的 Google 風控、不是內部 402

按 §2.1 對照表確認訊息字串確實是 `Validation required (403)` 而且**有附 `validation_url`**。沒有 validation_url 的 403 走 §6.2 處理。

#### 第 1 步：取出 validation_url

**位置 A：後臺 UI**

```
/admin/accounts → 找到該帳號 → 看「錯誤訊息」欄位
完整訊息長這樣：
  Validation required (403): account needs Google verification
  | upstream: Verify your account to continue.
  | validation_url: https://accounts.google.com/signin/continue?sarp=1&...
複製 validation_url 後面整段（含所有 query string）
```

**位置 B：API（如果後臺被遮罩）**

```bash
ADMIN_TOKEN="你的 admin JWT"
SUB2API_URL="http://localhost:8080"

curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$SUB2API_URL/api/v1/admin/accounts?platform=antigravity&status=error" \
  | jq -r '.data[] | select(.error_message | contains("Validation required")) | "\(.id)\t\(.name)\t\(.error_message)"'
```

**位置 C：直接撈 DB**

```bash
docker compose exec postgres \
  psql -U sub2api -d sub2api -c \
  "SELECT id, name, error_message FROM accounts
   WHERE platform='antigravity' AND error_message LIKE '%validation_url%';"
```

#### 第 2 步：準備乾淨驗證環境（最關鍵的一步）

**為什麼乾淨環境很重要**：Google 看的是「驗證當下的環境特徵 vs 帳號平常使用的環境」。如果你 OAuth 帳號當初是用臺灣 IP 註冊、平常在自家寬頻用，但你跑去美國 VPN 上做驗證——驗證會被標記為「環境異常」、即使完成驗證 24 小時內又會被風控。

| 必須做 | 為什麼 |
|---|---|
| 關掉所有 VPN / 代理 | 環境一致性 |
| 用該 Google 帳號**註冊地理位置**的家用寬頻 IP | IP 信譽 + 地理一致性 |
| 用**該帳號平常登入的瀏覽器**（含 cookies、登入狀態） | 瀏覽器指紋一致性 |
| **同一臺機器**先登入該 Google 帳號（gmail / drive） | 確認 session 健康 |
| 別開無痕模式 / 別清 cookies | 反常會更可疑 |
| 別在公司 / 學校 / 公共 Wi-Fi 做 | IP 池信譽差 |

**禁忌**：
- ❌ 跑去 sub2api 部署的雲端機器上開 SSH X11 / VNC 操作（IP 是 datacenter）
- ❌ 用 Chrome 隱身模式 + 全新設定檔
- ❌ 多帳號同時驗證（依序處理，每個帳號間隔 30 分鐘以上）

#### 第 3 步：實際驗證流程

1. 把 validation_url 貼到瀏覽器網址列開啟
2. Google 會跳出「Verify it's you」頁面，可能要求：
   - **手機簡訊驗證碼**（最常見，需要繫結手機的 Google 帳號）
   - 回答安全題
   - 驗證備用 email
   - **新帳號可能要求補綁手機號**——必須做，否則一定再被擋
3. 完成後會跳回 Antigravity 的「Authorization successful」或類似頁
4. **同時** 在另一個分頁開 https://myaccount.google.com/security
   - 看「最近的安全活動」是否顯示「Verification completed」
   - 若顯示「Suspicious activity」或「Account locked」→ 這帳號暫時別用，等 24 小時再試

#### 第 4 步：用真實 Antigravity IDE 確認帳號可用

**這步不能跳**。光在瀏覽器完成驗證，不代表 OAuth API token 已恢復——必須用真實 IDE 觸發一次 token refresh：

1. 本機下載 [Antigravity IDE](https://antigravity.google/download)
2. 開啟 → File → Sign in → 選該 Google 帳號
3. 隨便跑一個 chat：「say hi」
4. 如果**沒有**再跳「Verify your account」→ 帳號真的恢復了
5. 如果又跳 → 重做第 3 步，可能驗證沒完成

**進階：刷出新 OAuth token**

跑一次 IDE 後，原本 sub2api 裡儲存的 OAuth token 可能還是舊的（雖然 refresh token 會自動刷）。可以：

```
sub2api 後臺 → 帳號 → 編輯 → 重新 OAuth 授權 → 用同一個 Google 帳號重登
```

這樣 sub2api 拿到的就是**剛剛驗證後的全新 token**，最乾淨。

#### 第 5 步：sub2api 後臺手動恢復

```
/admin/accounts → 找該帳號 → 「啟用」
或 API:
  curl -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$SUB2API_URL/api/v1/admin/accounts/$ACCOUNT_ID/enable"
```

#### 第 6 步：保活策略（避免再次被擋）

恢復後**不要立刻丟回高頻使用**。建議：

| 時段 | 動作 |
|---|---|
| 第 1-3 天 | 每天用真實 Antigravity IDE 跑 5-10 分鐘任務（聊天、agent run、開幾個檔案） |
| 第 4-7 天 | sub2api 端用 1-2 次 / 天，每次只跑簡單請求 |
| 第 8 天起 | 進入正常 sub2api 排程，但**併發限制 1**（後臺 → 帳號 → 編輯 → 並發數） |
| 持續 | 每週至少 1 次真實 IDE 使用，建立持續行為遙測底 |

如果跳過保活直接放回高頻使用，**通常 1-3 天內又會被擋**——這就是社群「驗證完又被擋」的迴圈來源。

#### 第 7 步：失敗後的判斷

如果照上面做完還是被擋，分情況：

| 症狀 | 可能原因 | 處理 |
|---|---|---|
| 24h 內又被擋 | 該帳號信譽已標記，難救 | 報廢、開新 Google 帳號 |
| 連續 3 個帳號都救不回 | 你的 IP 段被 Google 標記 | 換 IP、換實體網路 |
| 整批帳號同時被擋 | 走 §6.3 大規模封號流程 |
| 驗證頁直接顯示「This account has been disabled」 | TOS violation 永久封號 | 該帳號報廢，無解 |

---

### 6.2 通用 403（無 validation_url）處置

通常是 sub2api 跟 Google 端配置問題，不是風控：

```bash
# 查實際上游回應
docker compose logs sub2api --since 5m 2>&1 \
  | grep -A 5 "Access forbidden" \
  | head -30
```

常見原因與處理：

- `User does not have access to project` → 帳號 Google Cloud project ID 沒設定（sub2api 後臺 → 帳號編輯 → project_id）
- `Quota exceeded` → 該帳號當日配額用完，等隔日 reset
- `Method not allowed` → sub2api 模型對映問題，回報 issue
- 沒任何 upstream log → sub2api 內部問題，看 §2.1

---

### 6.3 大規模封號（超過 30% 帳號同時掛掉）

1. **立刻** 把所有 Antigravity 帳號設為「停用」（避免連鎖風控波及剩下健康的）

   ```bash
   # 批次停用 SQL（小心執行）
   docker compose exec postgres psql -U sub2api -d sub2api -c \
     "UPDATE accounts SET status='disabled' WHERE platform='antigravity' AND status='enabled';"
   ```

2. 鑑別觸發源：

   | 檢查項 | 如何判斷 |
   |---|---|
   | UA 過舊 | 看 [Antigravity Changelog](https://antigravity.google/changelog) 最新版本 vs 你 env 設的 |
   | sub2api 升級觸發 | 對照 [Wei-Shaw/sub2api releases](https://github.com/Wei-Shaw/sub2api/releases)，看你的 v0.1.x 有無對 antigravity request body 改動 |
   | Google 端統一風控 | 上 [#1453](https://github.com/Wei-Shaw/sub2api/issues/1453) / Discord 看其他人是否同時爆 |
   | IP 段被風控 | 換 proxy / 用本機 + cloudflared tunnel 試一個帳號是否能恢復 |

3. 如果是 sub2api 升級觸發 → 回滾到上一版本 + 等修復

4. 如果是 Google 端統一風控 → 等 24-48 小時，期間用備援（Anthropic 訂閱直連、Gemini Code Assist OAuth）

5. **不要** 在大規模封號當下大量重試驗證——會被 Google 視為攻擊，連 IP 一起標記

---

### 6.4 預防勝於治療

最有效的「不被擋」就是「別讓 sub2api 跑 Antigravity」：

- 改用 §5.4 的 **Antigravity-Tools-LS 重用 ls_core 方案**（最接近徹底解決）
- 或把 Antigravity 帳號當「次要」備援，主力走 Anthropic 訂閱
- 對 Antigravity 帳號設 **Per-account proxy（住宅 IP）+ 併發限 1**，至少能撐久一點

---

## 7. 監控與健康檢查

建議加入定期監控：

```bash
# 每小時檢查一次帳號可排程數
docker compose exec sub2api wget -qO- http://localhost:8080/health

# 看最近 1 小時的 403 事件
docker compose logs sub2api --since 1h 2>&1 | grep -E "Validation required|account_violation|403"

# 看當前 Antigravity 帳號狀態（需 admin token）
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/api/v1/admin/accounts?platform=antigravity"
```

---

## 8. 已知事實 vs 常見迷思對照

| 主張 | 對/錯 | 證據 |
|---|---|---|
| 「TLS 指紋能緩解 Antigravity 403」 | ❌ 錯 | `account.go:1390` 直接排除；機制上也無意義 |
| 「sub2api 用 Go net/http 預設 TLS 指紋會被 Google 識破」 | ⚠️ 半對 | 對 Anthropic 是真的（已偽裝），對 Antigravity 影響有限 |
| 「需要套高品質住宅 Proxy」 | ✅ 對 | sub2api 已支援 per-account proxy |
| 「需要 Exponential Backoff」 | ✅ 對 | sub2api 對 403 是直接停用，無 backoff |
| 「`Validation required` 都是 Google 風控」 | ✅ 對（精確版） | 該字串只會在 Google 上游 403 + body 含 validation_required 時出現（`ratelimit_service.go:772`）|
| 「使用者餘額不足會回 `Validation required (403)`」 | ❌ 錯 | 餘額不足回 `Payment required (402)`（`ratelimit_service.go:249`），常被使用者誤認為 Google 風控 |
| 「驗證完帳號就永久恢復」 | ❌ 錯 | 不做保活，1-3 天內又會被擋（見 §6.1 第 6 步）|
| 「能用雲端 server 完成 Google 帳號驗證」 | ⚠️ 半對 | 技術上可以，但 datacenter IP 驗證會被風控標記，恢復後很快又被擋 |
| 「升 UA 就能徹底解決」 | ⚠️ 半對 | 是必要條件不是充分條件 |
| 「Antigravity 反代本身封控就厲害，跟 sub2api 無關」 | ✅ 對 | 社群 [#1433](https://github.com/Wei-Shaw/sub2api/issues/1433) 共識 |
| 「社群有人成功『注入 JS』繞過風控」 | ⚠️ 措辭錯但精神對 | 真實作法是重用官方 `ls_core` 二進位（[Antigravity-Tools-LS](https://github.com/lbjlaq/Antigravity-Tools-LS)），不是 JS 注入 |
| 「`Futureppo/antigravity_bypass` 能解 403」 | ❌ 錯 | 那專案只解 MCP tool 數量限制（100→114514），跟 403 風控無關 |
| 「Tools-LS 能完整跑 Opus 4.6-thinking」 | ⚠️ 半對 | 能拿到答案但 thinking 不會 stream（[#17](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/17)）；用 [buildin1 fork](https://github.com/buildin1/Antigravity-Tools-LS) 才完整 |
| 「Tools-LS 多帳號自動輪替」 | ❌ 錯 | 只有手動切換目前活躍帳號，不是請求層排程。要自動輪替看 Antigravity-Manager 或自架分流 |
| 「Tools-LS 已是穩定 production-ready 方案」 | ❌ 錯 | v0.0.3 / Early Experimental，多個關鍵 issue（#11、#17、#22、#27）未解 |

---

## 9. 參考資料

### Sub2API 程式碼
- `backend/internal/service/account.go:1387-1429` — `IsTLSFingerprintEnabled()` 平臺限制
- `backend/internal/service/ratelimit_service.go:699-805` — 403 處理邏輯
- `backend/internal/service/antigravity_quota_fetcher.go:219-272` — 403 分類與 URL 提取
- `backend/internal/pkg/antigravity/oauth.go:52-72` — UA 版本管理
- `backend/internal/pkg/antigravity/client.go:443` — IDEVersion 寫死處
- `backend/internal/service/antigravity_gateway_service.go:73-361` — MODEL_CAPACITY cooldown

### GitHub Issues
- [#784 anti 帳號 oauth 之後 403](https://github.com/Wei-Shaw/sub2api/issues/784) — 假 403 案例（餘額不足）
- [#1233 antigravity 封號](https://github.com/Wei-Shaw/sub2api/issues/1233) — 行為遙測討論
- [#1433 Antigravity 為什麼在這個專案裡面一用就封](https://github.com/Wei-Shaw/sub2api/issues/1433) — 反代封控本質
- [#1453 反重力拉閘了呀](https://github.com/Wei-Shaw/sub2api/issues/1453) — 同上
- [#2076 Antigravity 版本不支援](https://github.com/Wei-Shaw/sub2api/issues/2076) — UA 過舊
- [#563 Antigravity 違規封號](https://github.com/Wei-Shaw/sub2api/issues/563) — Opus 4.6 路由風險
- [#203 403 Insufficient account balance](https://github.com/Wei-Shaw/sub2api/issues/203) — 假 403 案例

### Antigravity 官方
- [Antigravity Changelog](https://antigravity.google/changelog) — 版本追蹤
- [Antigravity Releases](https://antigravity.google/releases) — 下載
- [社群 Changelog 映象](https://www.gradually.ai/en/changelogs/antigravity/) — 較完整時間線

### 社群方案（§5.4）
- [lbjlaq/Antigravity-Tools-LS](https://github.com/lbjlaq/Antigravity-Tools-LS) — **重用官方 ls_core 的核心方案**（Rust + Axum）
- [buildin1/Antigravity-Tools-LS](https://github.com/buildin1/Antigravity-Tools-LS) — fork，**補上 thinking 流式輸出**
- [lbjlaq/Antigravity-Manager](https://github.com/lbjlaq/Antigravity-Manager) — 同作者，多帳號管理 GUI（Tauri + React），有自動輪詢但不重用 ls_core
- [Futureppo/antigravity_bypass](https://github.com/Futureppo/antigravity_bypass) — patch JS 解 MCP tool 限制（**不解 403**）
- [yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy) — Windows DLL 注入強制走代理（跟 403 無關）
- [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) — 另一 CLI 反代，對 Antigravity 支援不完整
- [GitHub topic: antigravity](https://github.com/topics/antigravity) — 936+ 相關專案

### Tools-LS 關鍵 Issues
- [#11 有人用這個被封過號嗎](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/11) — 風控不確定性
- [#17 思考模型不思考](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/17) — Thinking 限制
- [#20 核心返回為空](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/20) — 穩定度問題
- [#21 圖片返回空](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/21) — 多模態限制
- [#22 7 day block](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/22) — 風控未明確
- [#27 Opus 4.6 報錯、3.1 pro 正常](https://github.com/lbjlaq/Antigravity-Tools-LS/issues/27) — Opus 不穩

### 相關技術
- [refraction-networking/utls](https://github.com/refraction-networking/utls) — sub2api TLS 指紋偽裝底層
- [Google Code Assist API](https://cloud.google.com/code-assist) — Antigravity 上游端點

---

## 10. 變更紀錄

| 日期 | 內容 |
|---|---|
| 2026-04-30 | 初版。基於 sub2api v0.1.120 程式碼 + GitHub issues 整合 |
| 2026-04-30 | 補充 §5.4「重用官方 ls_core 二進位」方案詳解（Antigravity-Tools-LS）|
| 2026-04-30 | 修正 §2.1 改寫為「402 vs 403 鑑別」、§6 重寫真實 Validation required 完整 7 步 SOP |
| 2026-04-30 | §5.4 大幅補充：5 大限制、多帳號現況、階段性試用 SOP、相關 fork 對照、最終決策表 |
