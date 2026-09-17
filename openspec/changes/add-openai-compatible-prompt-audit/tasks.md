## 1. 固定源基線與實施邊界

- [x] 1.1 記錄 aicodex-api 參考倉庫的絕對路徑、分支、HEAD commit、`git status --short` 和 `git diff --stat`，寫入本 change 的 `source-baseline.md`
- [x] 1.2 為參考倉庫未提交的 Prompt Audit/Prompt Guard 檔案生成只讀 patch 或固定到專用 commit/tag，並在 `source-baseline.md` 中記錄校驗和
- [x] 1.3 複核並維護 `source-feature-map.md` 的“源功能 → OpenSpec Requirement → 目的碼 → 目標測試”追蹤表，覆蓋非同步、同步、HTTP、SSE、WS、配置、風險摘要、身份展示、事件、執行態和頁面
- [x] 1.4 確認設計中的五個 Open Questions，並把已確認結論回寫 `design.md`，未確認項不得在實現中自行漂移
- [x] 1.5 執行並儲存現有基線訊號：`cd backend && go test ./internal/service -run ContentModeration -count=1`
- [x] 1.6 執行並儲存前端現有風控頁面和路由相關 Vitest，證明修改前基線通過
- [x] 1.7 將實現拆成資料基礎、非同步審計、控制台、同步門禁和灰度五個可獨立評審的提交/PR 階段

## 2. 建立獨立模組和公共契約

- [x] 2.1 建立 `backend/internal/securityaudit/` 並按 design 的檔案職責建立最小包骨架，不在現有 `content_moderation.go` 中加入 Prompt Audit 實現
- [x] 2.2 定義可信 `Request`、分列身份快照、脫敏 `PromptSnapshot`、`Decision`、`NormalizedResult`、`IssueSummary`、`RuntimeSnapshot` 和穩定列舉/錯誤碼
- [x] 2.3 定義 ConfigStore、JobRepository、PayloadStore、PromptScanner、Clock 和 Metrics 等可注入介面，避免核心邏輯依賴包級全域性變數
- [x] 2.4 實現 Coordinator 的 off/async/blocking 分支和固定阻斷優先順序，並用 fake engine 單測覆蓋兩個引擎所有組合
- [x] 2.5 證明 Coordinator 不轉換現有 Moderations 分類、不觸發其額外副作用、不寫入兩個引擎的業務表
- [x] 2.6 為 PromptService 實現顯式 `Start(ctx)`、`Shutdown(ctx)` 生命週期，禁止建構函式啟動不可控 goroutine
- [x] 2.7 增加 Wire provider 和應用啟動/停止接線，並保證 Prompt Worker 啟動失敗不會阻止主 API 提供非審計能力

## 3. 建立資料庫遷移和 Repository

- [x] 3.1 基於實施時最大遷移序號新增不可變 SQL migration，建立 `prompt_audit_jobs` 和 `prompt_audit_events`
- [x] 3.2 為 jobs 新增 staging/queued/processing/retry/done/failed 狀態列位、遞增 claim_version fencing token、租約、嘗試次數、配置版本、執行模式、使用者名稱/郵箱/API Key 名稱和請求快照列
- [x] 3.3 為 events 新增分列身份快照、脫敏提示詞快照、decision/risk/action、JSONB scanner 資料、節點/策略/版本、分片數和耗時列
- [x] 3.4 新增 jobs 的排程、request、user、API key、group、Hash、時間索引，並檢查索引名不與現有 schema 衝突
- [x] 3.5 新增 events 的 job、request、decision/time、risk/time、user/API key/group/time、Hash 和時間索引
- [x] 3.6 為 events.job_id 配置 `ON DELETE CASCADE`，為 user/api_key/group 配置 `ON DELETE SET NULL`，保留快照字串
- [x] 3.7 新增資料庫約束，拒絕負 attempts/max_attempts/claim_version/prompt_length/message_count/chunk_total/latency_ms 和不支援的關鍵狀態
- [x] 3.8 實現 JobRepository 的 staging 建立、queued 釋出、原子 `FOR UPDATE SKIP LOCKED` 領取並遞增 claim_version，以及所有攜帶 claim_version 條件的租約重新整理、事件提交和 done/retry/failed 更新
- [x] 3.9 實現 staging 和 processing 滯留任務的有界批量回收
- [x] 3.10 實現 EventRepository 的建立、分頁、詳情、複合篩選、計數和穩定排序
- [x] 3.11 實現單條、批次 ID、同一快照下的 snapshot_max_id/filter_hash 預覽、短期管理員繫結 confirmation_token 和分批篩選刪除，並只刪除高水位內事件及無事件引用且非 processing 的孤立 job
- [x] 3.12 新增 migration 重複執行、索引存在、外部索引鍵行為、原子領取併發、舊 Worker fencing 和 Repository 整合測試
- [x] 3.13 新增 schema 洩露門禁，斷言兩張表不存在 raw_prompt、payload、token、authorization 或等價原文/憑據列

## 4. 實現配置、憑據和多例項快照

- [x] 4.1 新增 `SettingKeyPromptAuditConfig`，實現 DefaultConfig、儲存 DTO、公共 DTO 和儲存請求 DTO
- [x] 4.2 實現 enabled/blocking_enabled 三態歸一和 `prompt_guard_requires_audit_enabled` 校驗
- [x] 4.3 實現唯一 `strategy=priority`、worker_count、queue_capacity、timeout、input_limit、group_ids 和 scanners 邊界校驗
- [x] 4.4 複用 SecretEncryptor 儲存 endpoint token_ciphertext，並實現“保留原密文、替換、顯式清除”三種寫入語義
- [x] 4.5 確保公共配置只返回 has_token/token_status，任何 JSON marshal 路徑都不會輸出密文或明文
- [x] 4.6 實現攜帶 expected_config_version 的 PostgreSQL advisory-lock CAS 儲存、單調 config_version、409 conflict、updated_at、updated_by 和脫敏 change_summary
- [x] 4.7 實現原子記憶體配置快照、最後有效版本、載入錯誤和有界 TTL 重新整理
- [x] 4.8 實現 Redis `sub2api:prompt_guard:config:invalidate` publish/subscribe 和 publish 失敗降級日誌
- [x] 4.9 新增配置加密往返、舊欄位缺失、非法組合、邊界值、兩管理員/兩例項併發 CAS、多例項失效和 Redis 不可用測試
- [x] 4.10 新增 canary secret 測試，斷言 settings 公共讀取、日誌和錯誤均不出現節點 API Key

## 5. 實現安全出站 Client 和節點探測

- [x] 5.1 實現統一 Base URL 規範化並固定呼叫 `{base}/v1/chat/completions`
- [x] 5.2 實現 scheme、userinfo、query、fragment、metadata host、link-local、multicast、unspecified 和保留地址校驗
- [x] 5.3 實現公網必須 HTTPS、本機/顯式私網 HTTP 例外和 DNS 解析後 DialContext IP 二次校驗
- [x] 5.4 建立獨立 HTTP Transport，配置 Dial/TLS/ResponseHeader timeout、連線池和 256 KiB 響應上限
- [x] 5.5 禁止 HTTP 重定向，並確保每個錯誤只暴露 endpoint ID 和穩定錯誤碼
- [x] 5.6 實現節點 `/models` 就緒檢查以及必要時的真實 Qwen3Guard fallback probe
- [x] 5.7 實現探測結果 DTO：ok/status/error_code/message/latency_ms/http_status/retryable/checked_at/token_applied
- [x] 5.8 新增 SSRF、DNS rebinding、重定向、超大響應、認證失敗、429、5xx、連線失敗和超時測試

## 6. 實現協議快照、脫敏和分片

- [x] 6.1 實現 OpenAI Chat Completions 使用者訊息提取，支援字串和文本內容塊並把最新使用者輸入置於首段
- [x] 6.2 實現 OpenAI Responses input 字串、訊息陣列和內容塊提取
- [x] 6.3 實現 Claude Messages 使用者文本塊提取
- [x] 6.4 實現 Gemini contents/parts 使用者文本提取
- [x] 6.5 實現 OpenAI Images、Grok 媒體和目標專案其他生成請求的純文本 prompt 提取，明確排除圖片/base64 資料
- [x] 6.6 實現 Responses WebSocket `response.create` 幀提取並支援 first_turn/subsequent_turn stage
- [x] 6.7 實現 SHA-256、訊息數、Unicode 字元數和確定性 metadata 計算
- [x] 6.8 實現憑據、Bearer、郵箱、電話及常見敏感模式的預覽脫敏和 rune 安全裁剪
- [x] 6.9 實現最新輸入優先的 scan text 組合和按 rune 的 input_limit 分片
- [x] 6.10 新增中文、emoji、組合字元、超長文本、空輸入、混合 content block、媒體 payload 和最新輸入優先測試
- [x] 6.11 新增 canary prompt 測試，斷言預覽不可恢復完整輸入且 Hash 與實際 scan text 一致

## 7. 實現 Qwen3Guard 嚴格解析和結果聚合

- [x] 7.1 定義九類 Qwen3Guard 官方輸入類別和目標專案展示標籤
- [x] 7.2 構建 OpenAI Chat Completions 請求，固定 role=user、temperature=0、max_tokens=64、seed=42
- [x] 7.3 實現 choices/message/content 提取，相容目標審計節點允許的最小合法響應形態
- [x] 7.4 實現嚴格單 Safety 行、單 Categories 行、無額外非空說明解析
- [x] 7.5 實現類別別名歸一、未知類別保留和啟用類別過濾
- [x] 7.6 實現 Safe/Controversial/Unsafe 到 pass/flag/critical 與 Allow/Warn/Block 的確定性對映
- [x] 7.7 實現 Jailbreak、PII、Suicide & Self-Harm 的高風險 Controversial 提升規則
- [x] 7.8 實現多分片最嚴重結果聚合、分類/證據去重、分片 metadata 和 Block 早停
- [x] 7.9 確保只有全部必要分片成功才能 Allow，部分成功不得產生 Safe
- [x] 7.10 新增模型合法輸出、重複欄位、額外說明、未知 Safety、未知類別、停用類別和多分片聚合測試
- [x] 7.11 從分類、策略和脫敏 evidence 確定性生成 IssueSummary，覆蓋標題/說明/嚴重度/動作/score/位置/Hash，且不新增重複資料庫事實列

## 8. 實現非同步投遞和 Worker

- [x] 8.1 實現 Prompt Audit 有效模式、risk_control_enabled、分組範圍、節點可用性，以及 advisory-lock 事務內 active count + staging INSERT 的多例項嚴格佇列容量准入
- [x] 8.2 實現 staging job → Redis SET EX 1800 → queued 的釋出協議
- [x] 8.3 實現所有投遞失敗 reason 和 `prompt_audit.enqueue_skipped/enqueue_dropped/job_enqueued` 結構化日誌
- [x] 8.4 保證非同步投遞複製必要請求資料並使用有界後臺 context，不引用 Gin request 生命週期後的可變記憶體
- [x] 8.5 實現 Redis PayloadStore 的 Set/Get/Delete 和名稱空間 key
- [x] 8.6 實現 Worker 輪詢、活動計數、processing 租約、節點有序故障切換和任務處理
- [x] 8.7 實現 5s/30s/2m 有界退避、可重試分類和 max_attempts 終止
- [x] 8.8 實現 store_pass_events=false 時僅完成 job、不寫 Pass event
- [x] 8.9 實現風險事件和 `prompt_audit.finding_recorded/processed/process_failed` 日誌
- [x] 8.10 實現 Worker panic 單任務恢復、優雅停止和 shutdown timeout 日誌
- [x] 8.11 新增佇列滿、Redis SET 失敗、釋出失敗、程式中斷、重複領取、租約重新整理、滯留回收、舊 Worker claim_version 失效和重試整合測試
- [x] 8.12 證明非同步模式所有失敗都不改變模型請求狀態、錯誤體和上游轉發次數
- [x] 8.13 為逐分片開始/完成/失敗和聚合輸出穩定日誌，欄位只含索引、字元數、限制、節點、動作、耗時和錯誤碼

## 9. 實現同步 Guard evaluator

- [x] 9.1 實現全域性 64、每節點 16 的非阻塞 bulkhead，並允許測試注入更小容量
- [x] 9.2 實現以首個啟用節點 timeout 為總 deadline，分片和節點切換共享剩餘預算
- [x] 9.3 實現連線/429/5xx/超時切換下一節點，401/403/invalid_response 終止
- [x] 9.4 實現 Allow/Flag/Block/Unavailable Decision 和 allow_next_stage
- [x] 9.5 實現 prompt_guard total/allowed/flagged/blocked/unavailable/invalid/timeouts/failovers/bulkhead_full 指標
- [x] 9.6 實現同步結果輕量記錄 adapter，在單事務中建立 done job 和可選 event，禁止再次掃描
- [x] 9.7 實現記錄失敗 `prompt_guard.result_record_failed`，並證明不改變已確定的 Allow/Block
- [x] 9.8 新增完整分片、Block 早停、最後分片失敗、所有節點失敗、bulkhead 滿和 context cancel 測試

## 10. 接入閘道器並保持相容

- [x] 10.1 在 GatewayHandler 和 OpenAIGatewayHandler 中注入 SecurityAudit Coordinator，同時保留現有 ContentModerationService 供 cyber policy 記錄使用
- [x] 10.2 將 Chat Completions 現有稽核呼叫替換為統一 `checkSecurityAudit`
- [x] 10.3 將 HTTP Responses 現有稽核呼叫替換為統一 `checkSecurityAudit`
- [x] 10.4 將 Claude Messages 現有稽核呼叫替換為統一 `checkSecurityAudit`
- [x] 10.5 將 Gemini 現有稽核呼叫替換為統一 `checkSecurityAudit`
- [x] 10.6 將 OpenAI Images 和 Grok 媒體文本 prompt 稽核呼叫替換為統一 `checkSecurityAudit`
- [x] 10.7 接入 Responses WebSocket 首個 response.create 門禁，置於使用者/帳號 slot、計費和上游撥號前
- [x] 10.8 接入 Responses WebSocket 後續每個 response.create 門禁，置於本輪 slot、計費和上游傳送前
- [x] 10.9 為現有錯誤 helper 增加最小 Prompt Guard adapter：OpenAI/Claude 可選 error.code，Gemini 保留數值 code/status 並使用 google.rpc.ErrorInfo.reason，對映 blocked/unavailable/invalid_response
- [x] 10.10 確保 SSE 在 Guard 完成前沒有寫 response header 或首位元組
- [x] 10.11 增加靜態/結構測試，列舉所有現有使用者文本路由並在缺少 Coordinator 接線時失敗
- [x] 10.12 用帳號選擇、計費和上游 fake counter 證明 Block/Unavailable/Invalid 時三者呼叫均為 0
- [x] 10.13 迴歸現有 ContentModeration Block 響應優先順序、文案、封號、郵件和記錄語義

## 11. 實現管理 API 和管理操作審計

- [x] 11.1 建立 PromptAdminHandler 並註冊 `/admin/prompt-audit` 獨立路由組，複用 AdminAuth 和現有安全中介軟體
- [x] 11.2 實現 GET/PUT config，PUT 強制 expected_config_version 並對映 409 conflict，返回公共 DTO 並記錄脫敏配置更新審計
- [x] 11.3 實現 POST endpoints/probe，支援使用已儲存密文或請求中的臨時 token 且絕不回顯
- [x] 11.4 實現 GET runtime，聚合配置版本、Worker、DB 佇列、Redis、節點連通性和 Guard 指標
- [x] 11.5 實現 GET events 和 GET events/:id，支援完整篩選、分頁、使用者名稱/郵箱/API Key 名稱分列快照和派生 issue_summaries
- [x] 11.6 實現 DELETE 單事件和 POST batch-delete，並限制單批 ID 數量
- [x] 11.7 實現 delete-preview 和 delete-by-filter，強制時間範圍、snapshot_max_id、canonical filter_hash、SecretEncryptor 認證的管理員繫結/5 分鐘 confirmation_token 和 confirm=true
- [x] 11.8 為配置、探測和刪除的成功/失敗寫入現有管理員操作審計，detail 使用欄位 allowlist
- [x] 11.9 新增未認證、非管理員、非法 ID/時間、Hash/token/操作者/過期不匹配、預覽後新事件、併發刪除和敏感欄位響應測試

## 12. 實現獨立控制台頁面

- [x] 12.1 建立 `frontend/src/features/prompt-audit/` 的 api、types、viewModel、components、PromptAuditView 和測試目錄
- [x] 12.2 新增 `/admin/prompt-audit` 路由並複用 requiresAuth/requiresAdmin/requiresRiskControl guard
- [x] 12.3 將側欄現有風控入口改為 expandOnly“安全審計”分組，保留 `/admin/risk-control` 子入口並新增 Prompt Audit 子入口
- [x] 12.4 實現配置、執行態、分組和事件的有界並行載入及獨立錯誤狀態
- [x] 12.5 實現審計池新增/編輯/啟停/刪除、引數對話方塊和真實探測進度/結果
- [x] 12.6 實現 API Key 空值保留、顯式替換/清除和儲存成功後清除明文 state
- [x] 12.7 實現 all/selected group 範圍、分組搜尋、失效分組提示和九類 scanner 選擇
- [x] 12.8 實現 enabled/blocking/store pass 固定儲存欄、dirty snapshot、重置和同步阻止二次確認
- [x] 12.9 實現配置版本、Worker/佇列、Redis、連通性、最近錯誤和 Guard 指標概覽
- [x] 12.10 實現事件複合篩選、時間範圍、分頁、行選擇、使用者名稱/郵箱/API Key 名稱分列複製、模型資訊和風險展示
- [x] 12.11 實現事件詳情的脫敏預覽、審計返回、IssueSummary 具體風險和技術資訊 tabs
- [x] 12.12 實現單條、批次和按篩選 snapshot/Hash/token/確認刪除流程，篩選變化後使舊 Hash 與 confirmation_token 同時失效
- [x] 12.13 新增中英文對稱 i18n，併為所有輸入、開關、按鈕、狀態和對話方塊提供可訪問名稱
- [x] 12.14 新增桌面、窄屏、鍵盤操作、dirty 狀態、探測、模式聯動、事件刪除和 secret state 清理 Vitest
- [x] 12.15 迴歸原 RiskControlView 的路由、功能開關和關鍵測試，確認業務邏輯未改變

## 13. 補齊日誌、指標和敏感資訊門禁

- [x] 13.1 實現 design 中列出的 prompt_audit/prompt_guard 穩定事件詞典和欄位 allowlist helper
- [x] 13.2 為關鍵路徑補齊 request_id、user/api-key/group、protocol、endpoint、model、config/job/event/node/version、結果、耗時和錯誤欄位
- [x] 13.3 在同步拒絕日誌中明確 upstream_dispatched=false 和 billing_preconsumed=false
- [x] 13.4 實現執行計數和延遲指標，並確保 runtime API 的欄位與日誌錯誤碼使用同一詞典
- [x] 13.5 新增日誌捕獲測試，使用 canary prompt、API Key、Authorization 和帶 query URL 證明敏感內容不出現
- [x] 13.6 新增資料庫/API/前端快照洩露測試，統一掃描 canary secret
- [x] 13.7 對錯誤訊息和 last_error_message 做長度限制與脫敏，禁止儲存 Guard 原始響應正文

## 14. 完成驗證、質量門禁和灰度準備

- [x] 14.1 執行 `openspec validate add-openai-compatible-prompt-audit --type change --strict --no-interactive`
- [x] 14.2 執行 `cd backend && go test ./internal/securityaudit/... -count=1`
- [x] 14.3 執行 `cd backend && go test ./internal/handler/... ./internal/server/... -count=1` 並儲存路由矩陣結果
- [x] 14.4 執行 `cd backend && go test -race ./internal/securityaudit/... -count=1`
- [x] 14.5 在可用 PostgreSQL/Redis 環境執行 migration、Repository、多 Worker 和配置失效整合測試
- [x] 14.6 執行 `make test-backend`，記錄全量 Go test 和 golangci-lint 結果
- [x] 14.7 執行 `pnpm --dir frontend run lint:check`、`pnpm --dir frontend run typecheck` 和 Prompt Audit/RiskControl Vitest
- [x] 14.8 執行 `make build`，驗證後端和前端生產構建
- [x] 14.9 執行 HTTP/SSE/WS 端到端矩陣，儲存 Block/Unavailable 無帳號、無計費、無上游證據
- [x] 14.10 執行敏感資訊審查，檢查 PostgreSQL、Redis key metadata、日誌、API JSON、瀏覽器儲存和頁面截圖
- [x] 14.11 在 async 模式對測試 group 記錄 Guard P50/P95/P99、失敗率、誤報率和事件增長率基線
- [x] 14.12 定義 blocking 灰度准入閾值、告警閾值、值班檢查步驟和一鍵關閉 blocking 的回滾手冊
- [x] 14.13 更新 `verification.md`，為每條驗收 Requirement 關聯測試、日誌、指標、SQL 或截圖證據
- [x] 14.14 在實現偏離設計時先回寫 proposal/design/specs/tasks，再繼續編碼，禁止讓 OpenSpec 落後於程式碼

## 15. 管理員自主管理審計節點網路目標

- [x] 15.1 更新規格與設計，明確節點目標安全由管理員負責，不再實施地址類別、DNS 結果、HTTP 或重定向攔截
- [x] 15.2 移除 Base URL 私網/特殊地址限制和 DialContext DNS/IP 二次攔截，恢復標準重定向行為
- [x] 15.3 更新出站客戶端測試，覆蓋 HTTP、私網/特殊地址配置和重定向，並回歸響應上限與憑據保護
- [x] 15.4 執行 OpenSpec 嚴格校驗和 securityaudit 測試，並用真實內網節點探測驗證

## 16. 最佳化審計池節點列表並重新部署

- [x] 16.1 將審計池改為緊湊、響應式的節點列表，修復開關與節點名稱擁擠並強化狀態、限制和操作層級
- [x] 16.2 迴歸 Prompt Audit 前端元件測試、型別檢查和生產構建
- [x] 16.3 在 deploy 目錄按現有 Compose 配置重建映象、重啟容器並驗證頁面和節點探測
