# AICodex 源功能遷移對映

## 1. 目的

本表用於證明“完整功能都必須要有”不是一句籠統目標。每個 AICodex 當前使用者可見或執行時能力都必須對映到目標 Requirement、預期程式碼位置和驗證證據；實施中發現新源能力時，先更新本表和相關 spec/tasks，再編碼。

源參考狀態見 `source-baseline.md`。只讀凍結包已在 detached worktree 中恢復，以下測試在恢復副本執行：

```text
cd /Users/mt/code/mt-ai/aicodex/aicodex-api/ai-gateway
go test ./internal/service/promptaudit -count=1
ok github.com/mt21625457/aicodex/internal/service/promptaudit 2.081s

go test ./internal/router ./internal/relay ./internal/gatewayadapter/transport \
  -run 'PromptGuard|PromptAudit|ConcurrencyOrder' -count=1
ok github.com/mt21625457/aicodex/internal/router 1.184s
ok github.com/mt21625457/aicodex/internal/relay 2.201s
ok github.com/mt21625457/aicodex/internal/gatewayadapter/transport 3.233s
```

這證明凍結包可恢復且源參考測試通過，但不證明目標實現已完成；目的碼和證據仍須逐行補齊。

## 2. 功能對映

| # | AICodex 當前能力與源證據 | 目標 OpenSpec 契約 | 目標主要程式碼 | 驗證證據 |
| ---: | --- | --- | --- | --- |
| 1 | 獨立 Prompt Audit 開關、預設關閉；`config.go` | prompt-input-audit：獨立且預設關閉；prompt-input-guard：顯式三態 | `prompt_config.go`、`coordinator.go` | A01、G01 |
| 2 | enabled + blocking_enabled 表達 off/async/blocking；`config.go`、`synchronous_guard.go` | prompt-input-guard：顯式啟用、即時回滾 | `prompt_config.go`、`prompt_guard.go` | G01、G12 |
| 3 | 配置持久化、版本、updated_by/change_summary；`config.go` | prompt-input-guard：版本化快照/CAS；console：可驗證儲存 | `prompt_config.go` | G10、C06、C10 |
| 4 | token 加密、空值保留、替換、clear；`config.go`、`config_test.go` | prompt-input-audit：憑據安全；console：池管理/儲存 | `prompt_config.go`、`prompt_handler.go` | A03、C03、C06 |
| 5 | OpenAI-compatible endpoint、Qwen3Guard 預設模型；`openai_client.go` | prompt-input-audit：OpenAI 相容節點 | `prompt_qwen3guard.go` | A02 |
| 6 | Base URL 規範化，固定 `/v1/chat/completions`；`openai_client.go` | prompt-input-audit：OpenAI 相容節點/出站安全 | `prompt_qwen3guard.go`、`prompt_outbound_security.go` | A02、A03 |
| 7 | `/v1/models` readiness + scan fallback probe；`openai_client.go`、`probe.go` | prompt-input-audit：管理員探測；console：真實探測 | `prompt_qwen3guard.go`、`prompt_handler.go` | A02、C03 |
| 8 | probe 對話方塊階段、結果、狀態/耗時/錯誤；`PromptAuditPage.tsx` | console：完整審計池和真實探測 | `features/prompt-audit/components` | C03 |
| 9 | Guard SSRF、DNS/Dial 複檢、重定向/響應上限；`outbound_security.go` | prompt-input-audit：憑據和出站地址安全 | `prompt_outbound_security.go` | A03 |
| 10 | Qwen3Guard `Safety/Categories` 解析；`qwen3guard.go` | prompt-input-audit：嚴格歸一 | `prompt_qwen3guard.go` | A08 |
| 11 | 九類官方輸入風險；`qwen3guard.go`、頁面 scanner catalog | prompt-input-audit：九類；console：九類配置 | `prompt_qwen3guard.go`、前端 types/viewModel | A08、C04 |
| 12 | Safe/Controversial/Unsafe → Allow/Warn/Block；`openai_client.go`、`normalize.go` | prompt-input-audit：嚴格歸一；guard：fail-closed | `prompt_qwen3guard.go`、`prompt_scanner.go` | A08、G06 |
| 13 | 高風險 Controversial 提升、未知 Unsafe 保持 Block；`openai_client.go` | prompt-input-audit：嚴格歸一 | `prompt_qwen3guard.go` | A08 |
| 14 | Chat/Responses/Claude 多協議快照；`snapshot.go`、`multiprotocol.go` | prompt-input-audit：按協議提取 | `prompt_snapshot.go` | A04 |
| 15 | Gemini、圖片/媒體等 transport 傳遞提示詞上下文；gatewayadapter changes | prompt-input-audit：所有文本入口；guard：路由覆蓋 | `prompt_snapshot.go`、各 Handler 薄接線 | A04、G04 |
| 16 | Responses WS 首輪和後續幀；`ws_responses.go`、順序測試 | prompt-input-guard：每個 response.create 門禁 | `openai_gateway_handler.go` 薄接線 | G08 |
| 17 | 最新使用者輸入優先；`snapshot.go` | prompt-input-audit：提取/Unicode 分片 | `prompt_snapshot.go`、`prompt_scanner.go` | A04、A09 |
| 18 | rune input_limit 完整分片；`openai_client.go` | prompt-input-audit：Unicode 完整分片 | `prompt_scanner.go` | A09 |
| 19 | 多片最嚴重聚合、證據 metadata/去重、Block 早停；`openai_client.go` | prompt-input-audit：分片；guard：共享預算 | `prompt_scanner.go`、`prompt_guard.go` | A09、G05 |
| 20 | 每片前重新整理 processing lease；`openai_client.go`、`worker.go` | prompt-input-audit：Worker/Unicode 分片 | `prompt_worker.go` | A07、A09 |
| 21 | scan_chunk_started/completed/failed/aggregated 日誌；`openai_client.go` | prompt-input-audit：Unicode 分片；guard：可觀測 | `prompt_logging.go`、`prompt_scanner.go` | A09、G11 |
| 22 | Prompt hash、脫敏 preview、敏感模式處理；`snapshot.go` | prompt-input-audit：不可恢復快照 | `prompt_snapshot.go` | A05 |
| 23 | 完整 scan text 使用 Redis 30 分鐘 TTL；`payload_store.go` | prompt-input-audit：持久任務 + Redis TTL | `prompt_payload_store.go` | A06 |
| 24 | 非同步 enqueue、範圍/容量檢查；`enqueue.go` | prompt-input-audit：非同步持久投遞 | `prompt_enqueue.go` | A06 |
| 25 | PromptAuditJob/Event 持久事實；Ent schema/store | prompt-input-audit：jobs/events | SQL migration、`prompt_repository.go` | A05、A07、A10 |
| 26 | 程序內 Worker、可配置數量、Start/Stop；`worker.go` | prompt-input-audit：可靠 Worker | `prompt_worker.go`、`prompt_module.go` | A07 |
| 27 | retry/backoff/max attempts；`worker.go` | prompt-input-audit：可靠 Worker | `prompt_worker.go` | A07 |
| 28 | processing stale reclaim；`worker.go` | prompt-input-audit：可靠 Worker | `prompt_worker.go`、Repository | A07 |
| 29 | runtime queue/Worker/DB/payload/connectivity/heartbeat；`runtime.go` | prompt-input-audit：真實執行態 | `prompt_runtime.go` | A11、C07 |
| 30 | config active/expected version 和失效通知；`config.go`、`runtime.go` | prompt-input-guard：版本化熱路徑快照 | `prompt_config.go`、`prompt_runtime.go` | G10、C07 |
| 31 | 同步 evaluator 不依賴 Worker；`synchronous_guard.go` | prompt-input-guard：同步門禁/結果複用 | `prompt_guard.go` | G03、G09 |
| 32 | 總 deadline、ordered failover、bulkhead；`synchronous_guard.go` | prompt-input-guard：共享預算/故障切換 | `prompt_guard.go` | G05、G06 |
| 33 | HTTP fail-closed 403/503；`prompt_guard.go`、router 接線 | prompt-input-guard：HTTP 穩定錯誤 | Handler helper + OpenAI/Claude code、Gemini ErrorInfo adapter | G03、G07 |
| 34 | WS 4403/1013；`ws_responses.go` | prompt-input-guard：每輪 WS 門禁 | Responses WS Handler | G08 |
| 35 | 同步結果輕量記錄、不重複 Guard；`synchronous_guard.go` | prompt-input-guard：結果複用 | `prompt_guard.go`、Repository | G09 |
| 36 | Guard metrics Allow/Flag/Block/Unavailable/timeout/failover/bulkhead；`synchronous_guard.go`、`runtime.go` | prompt-input-guard：可觀測；console：執行態 | `prompt_runtime.go`、metrics adapter | G11、C07 |
| 37 | 事件列表/詳情、複合篩選；`store.go`、controller | prompt-input-audit：查詢事件；console：列表詳情 | `prompt_repository.go`、`prompt_handler.go`、前端 | A12、C08 |
| 38 | 使用者名稱/郵箱分別展示和複製；probe-dialog change + controller/UI tests | prompt-input-audit：分列身份快照；console：複核身份 | Request/snapshot、event DTO、前端詳情 | A04、A10、C08 |
| 39 | scanner evidence、Guard policy、結構化 issue summaries；`issue_summary.go` | prompt-input-audit：事件/風險摘要；console：具體風險 | `prompt_issue_summary.go`、event DTO | A10、C08 |
| 40 | 單條/批次硬刪除；controller/store | prompt-input-audit：安全刪除；console：防誤操作 | Repository/Admin Handler/前端 | A12、C09 |
| 41 | delete preview + canonical filter hash + confirm；filter helper | prompt-input-audit：安全刪除；console：防誤操作 | Repository/Admin Handler/前端，增加 max_id/認證 token | A12、C09 |
| 42 | 配置、probe、刪除的管理審計；controller/router tests | console：管理員操作審計 | `prompt_handler.go` + 現有 audit | C10 |
| 43 | 獨立控制台、執行概覽、池/策略/事件/儲存欄；`PromptAuditPage.tsx` | console：獨立工作區 | `frontend/src/features/prompt-audit/` | C01、C02 |
| 44 | dirty snapshot、統一儲存、重置；頁面/viewModel | console：工作區/可驗證儲存 | 前端 viewModel/page | C02、C06 |
| 45 | all/selected group、搜尋、stale group；頁面/config | prompt-input-audit：範圍；console：範圍配置 | config + 前端 selector | C04 |
| 46 | endpoint 新增/編輯/啟停/刪除、引數對話方塊；頁面 | console：審計池管理 | 前端 components | C03 |
| 47 | blocking 二次確認和儲存欄開關聯動；頁面 | console：開啟風險確認 | 前端 viewModel/page | C05 |
| 48 | 事件技術/具體風險/結構化返回 tabs 和 JSON 檢視；頁面 | console：可複核詳情 | 前端 detail components | C08 |
| 49 | 響應式、可訪問狀態、頁面測試；redesign change | console：響應式/可訪問/i18n | 前端 + i18n | C11 |
| 50 | AI 可讀穩定日誌和敏感欄位約束；logging.go/constraints | prompt-input-guard：可觀測且不洩密 | `prompt_logging.go` | G11 |

## 3. 架構適配而非逐行復制

以下差異是目標架構適配，不是功能刪減：

| AICodex 實現細節 | sub2api 目標實現 | 等價性理由/門禁 |
| --- | --- | --- |
| Ent PromptAuditJob/Event | PostgreSQL migration + `database/sql` | 目標專案以 SQL migration 為 schema 事實源；欄位和行為由 A05/A07/A10/A12 驗證 |
| 表/物件可能帶 AICodex 命名 | `prompt_audit_jobs/events` | 不復制 `aicodex_` 字首；管理能力不變 |
| `PromptAuditConfigJSON` option | settings `prompt_audit_config` | 複用目標 SettingRepository，Public/Storage DTO 行為不變 |
| AICodex secret helper | 現有 `SecretEncryptor` | A03 canary 和加密往返證明 |
| React/Ant Design 頁面 | Vue 3 既有元件體系 | C01-C11 以行為和可訪問性驗收，不按框架驗收 |
| `/api/prompt-audit` | `/admin/prompt-audit` | 複用目標 AdminAuth/管理審計；API 能力一一對應 |
| token/channel/group 字串 | API key/group/provider 可信 ID + 快照 | 使用目標身份域，保留查詢/複核能力 |
| 6068/9068 雙埠一致性 | `/v1`、root alias、`/backend-api/codex` 等目標路由一致性 | G04 以目標實際 routes 自動列舉，不復制不存在的埠拓撲 |
| 源 queued 後再寫 payload 的競態 | staging → Redis SET EX → queued | 是可靠性增強；A06/A07 證明 Worker 不提前領取 |
| 源程序內喚醒佇列 + DB 事實 | PostgreSQL 原子 claim + 遞增 claim_version fencing + 程序內 Worker | 支援多例項並防舊 Worker 覆蓋，無功能損失；A07 併發測試證明 |
| 源 MemoryRepository | 只作為目標測試 fake，不作為生產 fallback | 生產需要持久任務；依賴失敗由 A11 顯示 degraded，不偽裝成功 |
| `scan_url`/舊 llm_guard 協議相容 | 只接受 Base URL + OpenAI compatible | 目標是新增 setting、無舊 Prompt Audit 配置；A02 明確禁止舊協議 |
| 源舊 strategy 遷移 | 第一版僅 `priority`，其他值拒絕 | 目標無歷史 Prompt config；G01/配置測試保證確定性 |
| endpoint `weight` 相容展示欄位 | 顯式陣列順序作為 priority | 源當前只允許 priority，掃描程式碼未使用 weight 做選擇；目標去除無效歧義，故障切換能力由 G06 證明 |
| endpoint `policy_id/tenant_id` 歷史相容輸入 | Qwen 結果固定 policy_id/version，event 持久化 | 當前 Qwen 請求不傳送這兩個 endpoint 欄位；目標保留實際策略結果而不暴露無效輸入 |
| 源 env 預設配置 | settings 管理頁面初始化預設值 | 目標配置事實源是 settings；預設 off 和完整可配置性由 A01/C03/C06 證明 |
| 源 event API 查詢時解析使用者 | 事件儲存使用者名稱/郵箱/API Key 名稱分列快照 | 刪除主體後仍可複核；訪問與保留沿用現有管理員政策 |
| 源 `issue_summaries` 由 evidence 派生 | 目標同樣派生，不新增資料庫列 | 防止雙份風險事實漂移；A10/C08 golden 測試證明 |

## 4. 源專屬能力的明確處理

以下內容不作為目標執行功能移植，但必須明確原因：

- AICodex 舊 `/v1/scan/prompt` 和 llm_guard 配置遷移：目標專案從未釋出 Prompt Audit，無歷史配置需要相容；目標只實現當前 OpenAI-compatible Qwen3Guard 行為。
- AICodex Caddy/gatewaycore、6068/9068 埠和 channel dispatch：目標使用 Gin Handler、目標帳號排程和目標路由 alias；以 G04/G03 證明等價接入順序。
- AICodex React/舊 deprecated 頁面：只遷移當前管理行為到 Vue 獨立 feature，不同時維護兩套前端。
- AICodex 產品特有 transport：目標只覆蓋目標專案實際存在且可觸發模型的文本入口；`implementation-guide.md` 的路由列舉是硬門禁。
- 輸出稽核、Redact、人工審批和申訴：當前遷移範圍是使用者輸入 Prompt Audit/Guard，且本 change 明確列為 Non-Goals；不得把源舊 LLM Guard 的 `Redact` 相容文案誤當成當前 Qwen 輸入審計功能。

如果實施評審發現上述任一項實際上在目標專案有已釋出資料或使用者依賴，必須把它從本節移回第 2 節，新增 Requirement/Scenario 後才能繼續。

## 5. 完整性複核步驟

每次源基線或目標設計變化後執行：

1. 對源 `internal/service/promptaudit`、Prompt Audit controller/router、WS/transport 和當前前端目錄重新列出檔案/公開符號。
2. 對源主 spec 和所有未歸檔 Prompt Audit changes 提取 Requirement/Scenario。
3. 為新發現功能在第 2 節新增一行；若無目標 Requirement，先更新 specs。
4. 檢查每行同時有目的碼位置和 `verification.md` ID。
5. 檢查第 3/4 節每項確實是架構適配或源專屬，而不是為了縮小實現範圍。
6. 凍結時把最終源 commit/tag/patch SHA-256 寫入 `source-baseline.md`。
7. 實現完成後把每行的計劃證據替換為實際測試名/CI artifact 連結。

本表沒有“以後再做”狀態。除第 4 節經解釋的源專屬項外，第 2 節任一行沒有通過證據都表示“完整遷移”未完成。
