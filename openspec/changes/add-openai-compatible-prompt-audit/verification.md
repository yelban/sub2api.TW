# 驗證與灰度手冊

## 1. 驗證原則

本檔案既是實現期驗收矩陣，也是上線前證據索引模板。所有“待實現”項必須替換為可重複執行的測試名、命令輸出、SQL 結果、日誌查詢或頁面截圖路徑；僅寫“人工驗證通過”不算證據。

驗證順序：

1. OpenSpec 結構和需求完整性。
2. 純函式、配置和核心單元測試。
3. PostgreSQL/Redis 整合與多 Worker/多例項測試。
4. Handler 協議矩陣和無副作用斷言。
5. 前端功能、憑據狀態、可訪問和原頁面迴歸。
6. 全量構建、canary 洩露檢查、async 灰度和 blocking 准入。

關鍵不變數：

- off 等於升級前行為。
- async 的任何失敗都不改變主請求結果。
- blocking 的 Block/Unavailable/Invalid 必須發生在帳號、計費和上游之前。
- 現有 Content Moderation Block 響應永遠優先且原副作用保持不變。
- PostgreSQL、日誌、管理 API、前端和錯誤響應中沒有完整 Prompt 或 Guard token。

## 2. Requirement → Evidence 追蹤矩陣

狀態詞：`待實現`、`通過`、`失敗`、`豁免（必須有批准連結）`。證據路徑建議統一放到實現 PR 的 CI artifact 或 `docs/evidence/prompt-audit/<date>/`，不要把包含真實 Prompt/token 的原始資料提交到倉庫。

### 2.1 prompt-input-audit

| ID | Requirement | 必備自動化證據 | 補充證據 | 狀態 |
| --- | --- | --- | --- | --- |
| A01 | 獨立且預設關閉 | Coordinator off 單測；預設 config 單測；現有 Moderation 迴歸 | 升級後 config/runtime 截圖 | 通過（自動化） |
| A02 | OpenAI 相容節點 | request builder golden；mock server 斷言 `/v1/chat/completions`、model/messages/temperature/max_tokens/seed | probe 脫敏結果 | 通過（自動化） |
| A03 | 憑據和出站地址安全 | 加密往返；Public DTO canary；SSRF/DNS rebinding/redirect/256 KiB 測試 | 配置 JSON 與日誌掃描 | 通過（自動化） |
| A04 | 按協議提取輸入快照 | Chat/Responses/Claude/Gemini/images/media/WS 表驅動測試；使用者名稱/郵箱/API Key 名稱分列 | 路由覆蓋清單 | 通過（自動化） |
| A05 | 資料庫快照脫敏不可恢復 | canary Prompt 入庫後全列掃描；預覽/hash 單測 | schema 禁止列 SQL | 通過（自動化+SQL） |
| A06 | 持久任務 + Redis TTL | staging→SET EX→queued；多例項佇列 admission lock；Redis/釋出失敗補償測試 | TTL 1800 秒視窗證據 | 通過（整合） |
| A07 | Worker 可靠消費 | SKIP LOCKED、claim_version fencing、retry、lease refresh/reclaim、panic、shutdown 測試 | 多 Worker 執行指標 | 通過（整合+race） |
| A08 | Qwen3Guard 嚴格歸一 | Safe/Controversial/Unsafe、九類、未知類、重複/額外/缺失欄位測試 | golden response 語料 | 通過（自動化） |
| A09 | Unicode 完整分片 | 中文/emoji/組合字元/超長文本覆蓋與順序測試；部分失敗不 Allow；逐片日誌無正文 | chunk_total 事件樣本 | 通過（自動化） |
| A10 | 獨立可關聯事件 | event transaction、store_pass_events、身份快照、FK/篩選、IssueSummary 派生測試 | 管理事件詳情截圖 | 通過（整合） |
| A11 | 真實執行態 | healthy/degraded/error、Redis/DB/Worker/節點/config version 測試 | runtime JSON 樣本 | 通過（自動化） |
| A12 | 安全查詢和刪除 | 複合篩選、分頁、單條/批次、snapshot max ID、認證 token/actor/expiry/hash、分批刪除測試 | 管理審計日誌 | 通過（整合） |

### 2.2 prompt-input-guard

| ID | Requirement | 必備自動化證據 | 補充證據 | 狀態 |
| --- | --- | --- | --- | --- |
| G01 | 顯式啟用三態 | 配置真值表和非法組合測試 | 頁面聯動截圖 | 通過（自動化） |
| G02 | 兩引擎獨立語義 | fake engines 全組合；Legacy Block 優先；兩類事件獨立 | 現有郵件/封號/Hash 迴歸 | 通過（自動化） |
| G03 | 門禁在副作用之前 | Block/Unavailable/Invalid 的 account/billing/upstream counter 均為 0 | Ops 請求鏈日誌 | 通過（矩陣） |
| G04 | 覆蓋所有協議入口 | routes 自動列舉/結構測試；HTTP/SSE/WS E2E 矩陣 | 已簽字路由清單 | 通過（矩陣） |
| G05 | 同步分片共享預算且完整 | fake clock 總 deadline；Block 早停；Allow 全片；最後片失敗測試 | p95/p99 指標 | 通過（自動化） |
| G06 | 有序 fail-closed 故障切換 | 連線/429/5xx/timeout failover；401/403/invalid 終止；bulkhead 測試 | 節點執行態 | 通過（自動化） |
| G07 | HTTP 協議相容錯誤 | OpenAI/Claude 可選 code、Gemini 數值 code/status + ErrorInfo reason golden；403/503 | curl 樣本（脫敏） | 通過（golden） |
| G08 | WS 每個 response.create 門禁 | 首輪/後續輪次 Allow/Block/Unavailable/Invalid 測試；4403/1013 | WS trace（無正文） | 通過（結構+golden） |
| G09 | 同步結果複用且不重複掃描 | Guard fake 呼叫次數=chunk 數；record failure 不改 decision；無二次呼叫 | event/job 關聯 SQL | 通過（自動化） |
| G10 | 版本化熱路徑快照 | PostgreSQL CAS 併發儲存、雙例項 invalidation、last-known-good、cold-start fail-closed、無熱路徑 DB 測試 | expected/active version 指標 | 通過（整合） |
| G11 | 可觀測且不洩密 | 穩定日誌/指標詞典測試；canary 全介質掃描 | Dashboard/runtime 截圖 | 通過（自動化+掃描） |
| G12 | 停用/回滾即時生效 | blocking→async→off 多例項測試；進行中請求邊界測試 | 回滾演練記錄 | 通過（自動化；生產演練待簽字） |

### 2.3 security-audit-console

| ID | Requirement | 必備自動化證據 | 補充證據 | 狀態 |
| --- | --- | --- | --- | --- |
| C01 | 安全審計分組和獨立頁面 | router/Sidebar/feature guard 測試；舊路由迴歸 | 側欄和雙頁面截圖 | 通過（自動化） |
| C02 | 清晰獨立工作區 | 頁面分割槽、獨立載入/錯誤、dirty/reload 測試 | 桌面頁面截圖 | 通過（Vitest） |
| C03 | 審計池和真實探測 | endpoint CRUD draft、probe 進度/結果、token preserve/replace/clear 測試 | probe 對話方塊截圖 | 通過（Vitest+API） |
| C04 | 範圍和九類風險 | all/selected、搜尋、失效 group、九類對稱展示測試 | 選擇器截圖 | 通過（Vitest） |
| C05 | blocking 風險確認 | 開啟二次確認；關閉 enabled 聯動；取消確認測試 | 確認文案截圖 | 通過（Vitest） |
| C06 | 儲存可驗證且不洩憑據 | 成功快照重新整理、409 衝突保留草稿、secret state 清理、無 storage/console 測試 | Public DTO 捕獲 | 通過（Vitest+掃描） |
| C07 | 真實執行態和 Guard 指標 | expected/active mismatch、Worker stale、Redis degraded、指標渲染測試 | 概覽截圖 | 通過（Vitest） |
| C08 | 可複核列表和詳情 | filter/page/table/detail tabs、使用者名稱/郵箱/API Key 分列複製、IssueSummary、脫敏預覽測試 | 詳情截圖 | 通過（Vitest+API） |
| C09 | 防誤刪除 | 單條/批次/preview/max ID/認證 token/篩選變化失效/時間範圍測試 | 刪除確認截圖 | 通過（整合+Vitest） |
| C10 | 管理操作審計 | config/probe/delete 成功失敗審計測試；detail allowlist | audit_logs SQL/API 樣本 | 通過（自動化） |
| C11 | 響應式/可訪問/i18n | zh/en key 對稱；鍵盤/focus/accessible name；窄屏測試 | 桌面與窄屏截圖 | 通過（Vitest+lint） |

## 3. 標準驗證命令

### 3.1 OpenSpec

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt
openspec status --change add-openai-compatible-prompt-audit
openspec validate add-openai-compatible-prompt-audit --type change --strict --no-interactive
openspec show add-openai-compatible-prompt-audit
```

### 3.2 後端快速門禁

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt/backend

go test ./internal/securityaudit/... -count=1
go test ./internal/handler/... ./internal/server/... -count=1
go test ./internal/service -run ContentModeration -count=1
go test -race ./internal/securityaudit/... -count=1
```

如果新模組採用單一 package，第一條可以寫成 `go test ./internal/securityaudit -count=1`；以最終目錄結構為準，但不能省略 race。

### 3.3 PostgreSQL/Redis 整合

專案已有基於 Testcontainers 的 integration harness。實現時把 Prompt Audit migration/Repository/Redis 場景接入同一模式：

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt/backend
go test -tags=integration ./internal/repository ./internal/securityaudit/... -run 'PromptAudit|PromptGuard' -count=1
go test -tags=integration -race ./internal/securityaudit/... -run 'MultiWorker|MultiInstance|Lease|ConfigInvalidation' -count=1
```

CI 中 Docker 不可用必須失敗；本地跳過要在證據中明確寫“未執行”，不能標為通過。

### 3.4 前端

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt
pnpm --dir frontend run lint:check
pnpm --dir frontend run typecheck
pnpm --dir frontend exec vitest run \
  src/features/prompt-audit \
  src/views/admin/__tests__/RiskControlView.spec.ts \
  src/router/__tests__/feature-access.spec.ts
pnpm --dir frontend run build
```

### 3.5 全量

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt
make test-backend
make test-frontend
make build
```

儲存命令、commit SHA、開始/結束時間、退出碼和 CI artifact URL。不要只儲存終端截圖。

## 4. 模式和協議驗收矩陣

### 4.1 執行模式

| risk_control | prompt enabled | blocking | 期望 Prompt 行為 | 主請求 |
| --- | --- | --- | --- | --- |
| false | 任意 | 任意 | off | 完全保持升級前行為 |
| true | false | false | off | 完全保持升級前行為 |
| true | false | true | 配置儲存失敗 | 無執行態變化 |
| true | true | false | async enqueue | 無論審計依賴成敗都按原流程 |
| true | true | true | blocking evaluate | Block/Unavailable/Invalid fail-closed |

### 4.2 HTTP/SSE/WS

每行都要分別驗證 benign、flag、block、Guard unavailable、invalid response；Legacy moderation 還需追加“Legacy 單獨 Block”和“兩者同時 Block”。

| 入口 | 非流式 Allow | SSE/流式 Allow | Prompt Block | Unavailable | Invalid | 必查副作用 |
| --- | --- | --- | --- | --- | --- | --- |
| OpenAI Chat Completions | 原 envelope | Guard 前 0 bytes，之後原流 | 403 `prompt_guard_blocked` | 503 `prompt_guard_unavailable` | 503 `prompt_guard_invalid_response` | account/billing/upstream |
| OpenAI Responses + aliases | 原 envelope | 同上 | 403 OpenAI-compatible | 503 | 503 | account/billing/upstream |
| Claude Messages | 原 envelope | 同上 | 403 Anthropic envelope | 503 Anthropic envelope | 503 Anthropic envelope | account/billing/upstream |
| Gemini generateContent | 原 envelope | 原流式行為 | 403 Google envelope + ErrorInfo reason | 503 + ErrorInfo reason | 503 + ErrorInfo reason | account/billing/upstream |
| Images/Grok media 文本入口 | 原 envelope | 保持原 keepalive 時序 | 403 | 503 | 503 | image slot/billing/upstream/task |
| Responses WS first turn | 正常繼續 | N/A | close 4403 blocked | close 1013 unavailable | close 1013 invalid | user/account slot、billing、dial |
| Responses WS subsequent | 本輪繼續 | N/A | close 4403，stage=subsequent_turn | close 1013 | close 1013 | 本輪 slot、billing、upstream write |

SSE 測試不能只斷言最終狀態；必須在 Guard fake 阻塞時讀取連線並證明還沒有 header/首位元組/keepalive。

WS 測試必須檢查 close code、短 reason、stage 日誌和上游幀計數；不能把所有 1013 錯誤都寫成同一內部錯誤事實。

## 5. 無帳號、無計費、無上游證明

### 5.1 測試裝置

在每類 Handler E2E 測試注入以下可計數 fake/stub：

```text
account_select_calls
user_slot_acquire_calls
account_slot_acquire_calls
subscription_or_balance_check_calls
billing_preconsume_calls
usage_write_calls
upstream_dial_calls
upstream_http_calls
upstream_ws_write_calls
async_media_task_create_calls
```

對 Prompt Block、Unavailable、Invalid 分別斷言所有適用計數為 0。若基礎鑑權必須讀取 API key/user/group，這不算“帳號選擇”；證據需區分認證主體讀取與上游 account scheduler。

### 5.2 資料庫前後快照

除 fake counter 外，測試還應記錄請求前後這些業務表/統計不變：

- usage/billing/餘額/訂閱消費記錄。
- API key/account quota 與 rate limit 計數。
- 上游請求/任務記錄。
- 圖片/媒體佔用或預扣記錄。

允許新增的只有 Prompt Audit 自己的脫敏 blocking job/event、結構化日誌和指標。現有 Content Moderation 同時命中時，它原本會產生的記錄/封號/郵件仍按既有行為執行。

### 5.3 日誌斷言

同步拒絕事件必須包含：

```text
upstream_dispatched=false
billing_preconsumed=false
stage=http|first_turn|subsequent_turn
error_code=<stable code>
```

不得僅依賴日誌證明無副作用；日誌必須與 counter 和 DB snapshot 同時通過。

## 6. PostgreSQL 驗證

### 6.1 Schema

在 migration 整合測試中驗證：

- 兩表、所有列、預設值、CHECK、索引和 FK 刪除行為。
- username/email/API Key name 快照分別落在顯式列，API 分列返回；`issue_summaries` 從事件事實派生而非重複落列。
- migration 從空庫和當前生產前一版本都能應用。
- 不改 `content_moderation_logs` 定義和資料。
- 關鍵索引被典型篩選/claim 查詢使用；對代表性資料執行 `EXPLAIN`。

禁止列檢查示例：

```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_name IN ('prompt_audit_jobs', 'prompt_audit_events')
  AND lower(column_name) ~ '(raw|prompt_text|request_body|payload|token|authorization|secret)';
```

期望 0 行。`prompt_hash` 和 `redacted_preview` 是允許欄位，但必須用 canary 行為測試證明內容安全。

### 6.2 原子性與併發

至少覆蓋：

- 1000 個 queued/retry jobs，由 8 個 Worker、2 個 service 例項消費，每個 job 最多一個最終 event。
- 兩例項同時爭搶最後 N 個 queue slots，admission lock 後 active jobs 不超過 capacity；鎖超時只丟棄審計任務。
- Worker 在 claim 後崩潰，租約到期由另一 Worker reclaim。
- 舊 Worker 恢復後，舊 claim_version 的 refresh/event/done/retry/failed 全部 affected rows=0，無法覆蓋新領取者狀態或建立重複事件。
- staging 在 Redis SET 前不可領取。
- 程式在 Redis SET 與 queued publish 間退出，staging 被回收且 payload TTL 到期。
- event + done 事務中 event insert 失敗時不得留下 done 無 event 的風險任務。
- delete-by-filter 與併發新事件/查詢同時執行時，只刪除 id≤snapshot_max_id；偽造、過期或其他管理員的 confirmation_token 均失敗。

## 7. Redis 驗證

必須驗證：

- key 格式僅包含 job ID，不包含 user email、Prompt hash、模型文本或 token。
- value 是唯一允許的完整 scan text 存放處，預設 TTL 為 1800 秒，測試容差考慮執行時間。
- worker 成功/終態後主動 DEL；DEL 失敗最終依靠 TTL。
- Redis 不可用時 async 主請求繼續、job 明確 failed/staging 回收、runtime degraded。
- blocking 不依賴 Redis payload 才能決定當前請求，但配置通知失敗時按 last-known-good/TTL refresh 規則執行。
- invalidation channel 只發布 config version，不釋出 JSON 配置或 token。

測試程式碼可以讀取 canary value 做等值/TTL 斷言，但不得把 value 輸出到 `t.Log`、CI artifact 或失敗訊息。失敗時只輸出 job ID 和長度/hash。

## 8. 多例項配置測試

啟動兩個 PromptService 例項，共享 PostgreSQL/Redis、使用獨立記憶體快照：

1. A 儲存 config v2，A 立即 active=v2。
2. B 收到 invalidation，從 settings 載入並 active=v2。
3. 在 B 人為製造一次解密/載入失敗，B 保持 v1 且 runtime expected=v2/active=v1/degraded。
4. 修復依賴後，B 通過下一通知或 5 秒有界重新整理到 v2。
5. Redis Pub/Sub 中斷時儲存 v3，A active=v3，B 最遲通過 TTL refresh 收斂。
6. 冷啟動 C 無法載入、期望 blocking 時，C 不得按 off 放行，runtime 必須 error/degraded。
7. A/B 兩個管理員以同一 expected version 併發儲存，只有一個成功，另一個得到 409；config_version 不重複且成功配置不被靜默覆蓋。

證據記錄版本和錯誤碼，不記錄 endpoint token/base URL query。

## 9. Canary 敏感資訊門禁

### 9.1 Canary 設計

每次測試生成唯一、不像普通文本的隨機 canary：

```text
PROMPT_CANARY_<random>
GUARD_TOKEN_CANARY_<random>
AUTH_CANARY_<random>
URL_QUERY_CANARY_<random>
```

不要在 shell 命令列或 CI 引數中直接傳真實 secret；由測試程式生成並只在測試記憶體儲存。

### 9.2 檢查介質

| 介質 | 允許 | 禁止 | 證據 |
| --- | --- | --- | --- |
| PostgreSQL | SHA-256、脫敏預覽、長度、分類 | 完整 Prompt、token、Authorization、Guard raw body | 掃描所有 text/json 列 |
| Redis key/metadata | job ID、TTL | Prompt/hash/email/token 出現在 key/channel | SCAN/channel payload 斷言 |
| Redis value | 完整 Prompt，TTL≤1800 | token/Authorization；終態長期殘留 | 程式內檢查，不列印 value |
| 應用日誌 | ID、長度、狀態、穩定錯誤碼 | 四類 canary、完整 URL/query、raw response | 捕獲 sink 後位元組掃描 |
| 管理 API | 脫敏 preview、has_token/status、分列身份、派生風險摘要 | token/ciphertext/canary Prompt 原文 | 序列化響應掃描 |
| 客戶錯誤 | 通用訊息、code、request ID | 分類證據、Prompt、endpoint、內部錯誤 | HTTP/WS body/reason 掃描 |
| 前端狀態 | 公共 DTO、空 secret state | 儲存後的 token、session/local storage、console | Vitest spies/state snapshot |
| 頁面截圖 | 脫敏預覽、狀態 | token、完整 Prompt | OCR/文本與人工複核 |

資料庫掃描必須覆蓋 `TEXT/VARCHAR/JSON/JSONB`，不能只查兩張新表；至少還要查 settings、audit_logs、ops/error logs 和可能的 request log 表。日誌捕獲應覆蓋成功、探測失敗、超時、invalid response、DB/Redis 錯誤和刪除操作。

發現任何 Guard token/Authorization 洩露是 blocking release 級別 P0：立即停止啟用、刪除不安全 artifact、輪換憑據並做影響範圍調查。Prompt canary 出現在 PostgreSQL/日誌/API/前端同樣禁止釋出。

## 10. 現有內容稽核相容迴歸

必須儲存遷移前後同一套結果：

- off：OpenAI Moderations、關鍵詞、Hash、API Key 健康、非同步/同步模式行為相同。
- Legacy Block：狀態碼、`content_policy_violation`、客戶端文案不變。
- 違規計數、郵件、auto-ban、unban、hash delete/clear 不變。
- `/admin/risk-control` config/status/logs/API-key test/unban/hash API 不變。
- `content_moderation_logs` 行內容和清理行為不變。
- `RiskControlView.vue` 載入、儲存、測試、列表和功能總開關不變。
- 兩引擎同時 Block：客戶端仍得到 Legacy Block；Prompt event 獨立存在，不觸發現有副作用第二次執行。

建議在新增模組前把現有 `ContentModeration` 和 `RiskControlView` 測試輸出儲存為基線，最終對同 commit 執行一次差分對比。

## 11. Async 灰度觀測

### 11.0 當前實施基線（非生產准入）

2026-07-16 在本地 async Worker 完整處理路徑執行 `TestPromptAuditSyntheticAsyncBaseline`，使用 100 條無敏感資訊的確定性測試分組語料：90 benign、5 flag、3 critical、1 invalid、1 timeout。結果為 P50=5ms、P95=5ms、P99=5ms、Guard 失敗率=2%、已知 benign 誤報率=0%、已知 critical 阻斷率=100%、`store_pass_events=false` 時事件增長=8/100。該結果只證明指標鏈路、分母和事件策略可用，不代表真實 Guard/網路/業務流量效能，也不能替代下述 72h/10k 生產前 async 觀測。

復現命令：

```bash
cd /Users/mt/code/mt-ai/sub2api/sub2api-mt/backend
go test ./internal/securityaudit -run TestPromptAuditSyntheticAsyncBaseline -count=1 -v
```

### 11.1 先決條件

- Prompt Audit enabled=true、blocking=false。
- 只選擇內部測試 group，不全量。
- 至少兩個通過真實 probe 的 Guard endpoint；token 已驗證且未出現在任何日誌/API。
- runtime active=expected，DB/Redis/Worker healthy。
- store_pass_events 預設 false，避免一開始放大事件量；指標仍統計 Pass。

### 11.2 最少觀測視窗

推薦至少連續 72 小時且 ≥10,000 個合格請求；流量不足時延長到 7 天。記錄：

- enqueue total/skipped/dropped 及原因。
- queued/processing/retry/failed/staging age 和佇列容量佔比。
- Worker active、處理吞吐、claim/reclaim、payload missing。
- Guard Allow/Flag/Block/Unavailable/Invalid/timeout/failover/bulkhead。
- 每 endpoint 與總體 P50/P95/P99。
- 分類分佈、人工抽檢誤報率、已知惡意迴歸漏報率。
- 事件增長率、索引查詢 P95、刪除批次耗時。
- config version 收斂時間與 reload failure。

完整 Prompt 不得作為人工抽檢材料從 Redis 匯出。複核使用脫敏預覽、類別證據和專門構造的無敏感測試語料；如業務確需原文複核，必須另起隱私/審批 change。

## 12. Blocking 准入和退出閾值

以下是建議初始門檻，最終值必須由安全、運營和業務責任人在上線記錄中籤字；未簽字只能保持 async：

| 指標 | 建議准入閾值 | 建議緊急退出閾值 |
| --- | --- | --- |
| 健康 endpoint | ≥2，連續 72h | <1 個可用立即退出 |
| Guard Unavailable | 24h <0.1% | 5 分鐘 ≥1% |
| Invalid response | 24h <0.01% | 5 分鐘 ≥0.1% 或連續出現 |
| Guard 延遲 | P95 ≤500ms，P99 ≤1000ms | P99 >2000ms 持續 10 分鐘 |
| bulkhead reject | 24h <0.05% | 5 分鐘 ≥0.5% |
| async dropped/payload missing | <0.01%，payload missing=0 | 任一持續增長 |
| 人工確認誤報率 | <0.5%，高價值流程為 0 | 任一嚴重合法流量阻斷事件 |
| 已知惡意語料 | critical 用例 100% Block | 任一 critical 漏報 |
| config version 收斂 | 99.9% 例項 <10s | 任一例項 stale >60s |
| canary 洩露 | 0 | 任意命中立即停用並輪換 |

延遲閾值還必須低於目標介面現有首位元組 SLO 允許的新增預算；若業務 SLO 更嚴格，以更嚴格值為準。

首次 blocking：

1. 僅一個內部 group，短視窗、有人值守。
2. 確認頁面二次提示、指標和告警均工作。
3. 執行 benign/flag/block/unavailable/invalid 合成請求。
4. 證明拒絕時 account/billing/upstream 仍為 0。
5. 觀察至少一個高峰視窗後再擴大 group。

### 12.1 值班檢查步驟

開啟 blocking 前、每次擴組前和收到告警後，值班人員按以下固定順序執行；任一項不滿足立即保持/恢復 async：

1. 開啟 `/admin/prompt-audit`，確認 effective mode、expected/active config version、Worker heartbeat、PostgreSQL、Redis 和至少兩個 endpoint 均健康。
2. 檢查最近 5 分鐘 Guard Unavailable、Invalid、timeout、bulkhead、P95/P99 和 async dropped 是否超過本節閾值。
3. 檢查 queued/retry/staging 最老年齡和容量佔比；佇列持續增長或 staging 未回收時禁止擴組。
4. 對 benign、flag、block、unavailable、invalid 合成用例各執行一次，核對協議 envelope、錯誤碼及 `upstream_dispatched=false`、`billing_preconsumed=false`。
5. 抽查最新風險事件的脫敏預覽、身份分列、分類和 IssueSummary，禁止從 Redis 匯出原文。
6. 記錄值班人、時間、config version、測試 group、指標快照和結論；擴組必須由安全、運營、業務責任人共同確認。

一鍵回滾動作固定為：在獨立頁面關閉 `blocking_enabled` 並儲存，等待所有例項 `active_config_version == expected_config_version` 且 effective mode=`async_audit`。若管理頁面不可用，使用同一管理員 API 的 GET config 取得版本，只修改 `blocking_enabled=false` 並攜帶 `expected_config_version` PUT 回去；不得直接修改 settings JSON。若 async 仍造成壓力，再關閉 `enabled`。全域性 `risk_control_enabled` 只作最後手段，因為它也會停用既有內容稽核。

## 13. 回滾清單

### 13.1 一鍵功能回滾

1. 在 `/admin/prompt-audit` 關閉 `blocking_enabled` 並儲存。
2. 確認所有例項 `active_version == expected_version`，有效模式變為 async_audit。
3. 用 benign 請求證明立即恢復原主流程；用 Guard unavailable 合成請求證明不再返回 503。
4. 繼續觀察 async，保留事件用於復盤。

若 async 本身引發 DB/Redis 壓力或隱私問題：

1. 關閉 `enabled`，有效模式變為 off。
2. 停止 Worker 領取新任務；有界等待活動任務。
3. queued/retry 保留等待明確處置，不自動刪除歷史證據。
4. 若發生 secret 洩露，輪換 endpoint token。

只有在 Prompt 配置通道無法使用且影響仍持續時，才關閉全域性 `risk_control_enabled`；這會同時停用現有內容稽核，是最後手段。

### 13.2 資料和部署回滾

- 不回退已應用的 migration，不 drop 兩張表，不刪除歷史事件。
- 可部署上一版本應用；新表和 setting key 保持向後相容、無人讀取。
- 停 Worker 不改變現有閘道器能力；恢復後按狀態繼續或由管理員明確清理。
- 回滾後記錄觸發時間、閾值、config version、影響 group、錯誤碼分佈和恢復時間。

### 13.3 回滾驗收

- 所有例項模式正確，stale config=0。
- 新 403/503/4403/1013 已停止（除現有稽核自己的響應）。
- 上游成功率、首位元組延遲恢復基線。
- 佇列不繼續增長，Redis payload 最遲按 TTL 清除。
- 現有 `/admin/risk-control` 和 Content Moderation 仍正常。

## 14. 最終釋出簽字模板

| 專案 | 結果/連結 | 責任人 | 時間 |
| --- | --- | --- | --- |
| 源基線凍結 | TODO | TODO | TODO |
| OpenSpec strict validate | TODO | TODO | TODO |
| 後端 unit/race/integration | TODO | TODO | TODO |
| 前端 lint/typecheck/Vitest/build | TODO | TODO | TODO |
| 協議與無副作用矩陣 | TODO | TODO | TODO |
| canary 洩露門禁 | TODO | TODO | TODO |
| async 72h/10k 報告 | TODO | TODO | TODO |
| blocking 閾值批准 | TODO | TODO | TODO |
| 告警和值班人 | TODO | TODO | TODO |
| 回滾演練 | TODO | TODO | TODO |

任何必填項為 TODO、失敗或無證據時，不得開啟生產 blocking。

## 15. 2026-07-16 實施驗證記錄

驗證基線：branch=`dev`，HEAD=`a2779cd5f30d6d3904a9d59088aed09507678dfe`，工作區包含本 change 的未提交實現；時間為 2026-07-16 CST。以下命令退出碼均為 0，除首次發現並修復的 lint 問題外不隱藏失敗。

| 門禁 | 實際證據 |
| --- | --- |
| OpenSpec | `openspec validate add-openai-compatible-prompt-audit --type change --strict --no-interactive` → valid |
| SecurityAudit 單元/整合 | PostgreSQL `127.0.0.1:32768`、Redis `127.0.0.1:32769` 下 `go test ./internal/securityaudit/... -count=1` → pass |
| Race | 同一真實依賴下 `go test -race ./internal/securityaudit/... -count=1` → pass |
| Migration/Repository/Config | `TestPromptAuditConfigCASSecretRoundTripInvalidationAndTTL`、migration/schema、admission/fencing/FK/high-water/concurrent delete、Redis TTL、Worker lifecycle 全部 pass |
| Handler/Routes | `go test ./internal/handler/... ./internal/server/... -count=1` → pass；路由矩陣由 `TestEveryGatewayPOSTRouteIsClassifiedForPromptAuditCoverage` 固定 |
| 全量後端 | 臨時安裝 CI 同版 golangci-lint v2.9 後 `make test-backend` → 全量 Go tests pass，`0 issues` |
| 前端 | ESLint pass；vue-tsc pass；Prompt Audit、RiskControl、Sidebar、router 共 8 個檔案 34 tests pass |
| 生產構建 | `make build` → Go binary 與 Vite production build pass，獨立 `PromptAuditView` chunk 生成 |
| 協議/副作用矩陣 | 13 個實際入口的 Guard-before-side-effect 結構測試；Block/Unavailable/Invalid counter=0；OpenAI/Responses/Claude/Gemini golden；WS 4403/1013；first/subsequent gate；媒體 task/billing gate 全部 pass |
| 洩露門禁 | 統一 canary 覆蓋日誌、DB row、管理 JSON、前端儲存後 DOM；測試 PostgreSQL 39 個 text/json 列全庫掃描 0 命中；Redis key/channel scan 0 命中；feature 原始碼無 local/session storage 或 console |
| Async 指標基線 | 100 條合成 async Worker 樣本：P50/P95/P99=5/5/5ms，failure=2%，known-benign false-positive=0%，event growth=8/100；只用於驗證觀測鏈路 |
| Deploy 容器 | Docker Hub 超時後使用已快取的正式執行層 + 當前 `linux/arm64` embed release binary 構建離線增量映象 `sha256:c86353b0...`；Compose 重建後 app/PostgreSQL/Redis healthy，migration 181 已登記，兩張表存在，`/health`=200 |
| Deploy 管理 API | 本地測試管理員登入成功；`GET config/runtime/events` 均為 200；預設 config=`enabled=false, blocking=false, mode=off, version=1, group_ids=[], endpoints=[]`；runtime active/expected=1/1 |
| Deploy 頁面 | 首次容器檢查發現並修復預設 `group_ids:null` 導致的執行時錯誤；重建後桌面/390px 窄屏 DOM 與截圖均通過，截圖不含 token/Prompt canary |
| Deploy 全介質掃描 | 完整生產測試庫所有 public text/varchar/json/jsonb 列動態掃描：hit_columns=0/hit_rows=0；兩錶停用列=0；Redis canary key=`0`、channel=`[]`、payload key=`0`；容器日誌 canary=0 |

### 15.1 Requirement 自動化證據索引

- A01/G01/G02/G12：`coordinator_test.go`、`prompt_config_test.go`、`prompt_config_integration_test.go`、原 ContentModeration/RiskControl 迴歸。
- A02/A03/G06：`prompt_outbound_security_test.go`、`prompt_qwen3guard_test.go`、配置 secret 往返與 probe handler 測試。
- A04/A05/A09：`prompt_snapshot_test.go`、`TestPromptAuditDatabaseAndAdminJSONNeverPersistCanaryPromptOrRawErrors`、schema leakage gate。
- A06/A07：`prompt_worker_test.go`、Redis payload 整合、Repository admission/claim_version/reclaim 整合和 race。
- A08：Qwen3Guard strict/alias/unknown/aggregate/IssueSummary tests。
- A10/A12/G09：event transaction、FK/filter/high-water/confirmation/concurrent delete、record-once tests。
- A11/G10/G11：runtime aggregation、config invalidation/TTL、metrics/log dictionary/canary tests。
- G03/G04/G07/G08：`security_audit_order_test.go`、`security_audit_media_submit_test.go`、`security_audit_errors_test.go`、`prompt_audit_route_coverage_test.go`。
- G05：Guard complete chunks、last-chunk failure、Block early-stop、shared deadline/context tests。
- C01–C11：`frontend/src/features/prompt-audit/__tests__/`、Sidebar/router/RiskControl tests、handler/admin route tests、lint/typecheck/build。

### 15.2 尚未構成生產 blocking 批准的事項

本地實現驗證通過不等於生產啟用批准。最終簽字表中的真實 async 72h/10k 流量報告、至少兩個真實 endpoint 連續健康、業務流量誤報抽檢、告警接線、值班人和回滾演練仍為 TODO；在這些外部運營證據完成前，生產只能保持 off 或受控 async，不能開啟 blocking。

### 15.3 頁面證據

- 桌面：`/Users/mt/.codex/visualizations/2026/07/16/019f6a2c-ce90-7ae2-8eca-6a3a66b837f2/prompt-audit-desktop.png`
- 390px 窄屏：`/Users/mt/.codex/visualizations/2026/07/16/019f6a2c-ce90-7ae2-8eca-6a3a66b837f2/prompt-audit-narrow.png`

截圖只包含預設關閉狀態、空事件/空節點和測試管理員展示名；未配置節點 token、未產生 Prompt 事件，並已目視確認沒有 canary、Authorization、完整 Prompt 或內部錯誤。截圖完成後測試庫已恢復 `risk_control_enabled=false`，Prompt Audit 保持預設 off。
