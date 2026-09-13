## Why

當前專案的“風控中心”只提供基於 OpenAI Moderations 的內容稽核，非同步觀察依賴程序內佇列，且沒有 aicodex-api 已具備的持久任務佇列、短期敏感載荷儲存、Qwen3Guard 分類、同步 fail-closed 門禁和獨立提示詞事件工作臺。直接替換或擴寫現有內容稽核會混淆兩種風險模型，並可能改變關鍵詞、Hash、郵件和自動封號等既有行為，因此需要以並列、預設關閉的獨立能力引入。

本變更以 `/Users/mt/code/mt-ai/aicodex/aicodex-api` 當前磁碟實現為功能參考基線，把其中與目標專案實際協議入口相適配的提示詞輸入審計能力遷入 sub2api，同時保持現有 OpenAI 相容介面、內容稽核頁面、資料庫記錄和錯誤語義不變。

## What Changes

- 新增獨立的 OpenAI 相容提示詞審計引擎，審計節點通過 `{base_url}/v1/chat/completions` 呼叫 Qwen3Guard，並嚴格解析 `Safety` 與 `Categories`。
- 新增三態執行模式：關閉、非同步只審計、同步審計並阻止；所有新增開關預設關閉。
- 新增 PostgreSQL 持久任務佇列、Redis 短 TTL 原文載荷、程序內 Worker、重試退避、processing 租約重新整理和滯留任務回收。
- 新增脫敏提示詞快照、Hash、Unicode 分片、最新使用者輸入優先和九類 Qwen3Guard 風險分類。
- 新增逐分片安全日誌、結構化風險摘要，以及使用者名稱、郵箱、API Key 名稱分列的管理員複核資訊；風險摘要只使用脫敏證據。
- 新增同步 fail-closed 門禁，在帳號選擇、計費檢查和上游呼叫之前完成；覆蓋目標專案現有 Chat Completions、Responses、Claude Messages、Gemini、影像/媒體文本入口及 Responses WebSocket 首輪與後續輪次。
- 新增獨立管理 API、執行態、審計節點探測、事件查詢/詳情/刪除能力和“提示詞審計”頁面。
- 將側欄現有“風控中心”入口組織為“安全審計”分組；保留原 `/admin/risk-control` 頁面和行為，新增 `/admin/prompt-audit` 頁面。
- 新增安全審計協調器，只負責給兩個獨立引擎分發同一份可信請求上下文和歸併最終阻斷結果，不合並配置、風險分類、事件表或副作用。
- 複用現有 SettingRepository、Redis Client、SecretEncryptor、管理員鑑權、管理操作審計、請求身份上下文、分頁、日誌和前端基礎元件。
- 新增結構化日誌、執行指標、路由覆蓋測試、無上游副作用斷言和敏感資訊洩露門禁。
- 不刪除、不遷移、不重新命名現有 `content_moderation_logs`，不改變現有 Moderations 閾值、關鍵詞、Hash、郵件、封號或清理策略。

## Capabilities

### New Capabilities

- `prompt-input-audit`: 定義提示詞快照、非同步投遞、持久任務佇列、OpenAI 相容 Qwen3Guard 掃描、脫敏事件、執行態、配置和事件管理 API。
- `prompt-input-guard`: 定義同步阻止模式、跨協議入口覆蓋、fail-closed 錯誤語義、WebSocket 每輪門禁、配置快照和無計費/無上游副作用不變數。
- `security-audit-console`: 定義安全審計導航、獨立提示詞審計頁面、節點探測、配置儲存、執行態觀測、事件篩選/詳情/安全刪除和響應式可訪問體驗。

### Modified Capabilities

無。倉庫當前沒有已釋出的 OpenSpec capability；現有內容稽核行為在本變更中作為相容基線，不修改其正式需求語義。

## Impact

- **後端模組**：新增 `backend/internal/securityaudit/` 垂直模組；現有 Handler 僅增加協調器依賴和接入呼叫。
- **閘道器入口**：機械替換現有統一內容稽核呼叫點為安全審計協調呼叫，保持其位於鑑權之後、帳號選擇/計費/上游之前；WebSocket 保持逐輪檢查。
- **管理 API**：新增 `/admin/prompt-audit/*`，複用現有管理員鑑權和管理操作審計。
- **資料庫**：新增 `prompt_audit_jobs`、`prompt_audit_events` 和相應索引；配置存入現有 `settings`，API Key 加密儲存；不修改現有內容稽核表。
- **Redis**：新增短 TTL 提示詞載荷和配置失效通知 key/channel；Redis 不可用時非同步 Worker 必須顯式降級或報錯，不得偽裝健康。
- **前端**：新增 `frontend/src/features/prompt-audit/`，少量修改路由、側欄和 i18n；原 `RiskControlView.vue` 業務邏輯保持不變。
- **相容性**：沒有外部 API breaking change；新能力預設關閉。只有管理員顯式開啟同步阻止後，適用請求才可能新增 403/503 或 WebSocket 4403/1013 響應。
- **安全與隱私**：完整提示詞只允許存在於請求記憶體和 Redis 短 TTL 載荷，不得進入 PostgreSQL、日誌、管理 API、前端狀態或錯誤響應；審計節點憑據必須使用現有 SecretEncryptor 加密。
- **實施基線風險**：參考倉庫當前 `yjb` 分支包含未提交的同步阻止相關改動。開始編碼前必須固定源 commit/tag 或儲存可審計 diff，避免“完整遷移”範圍漂移。

## Execution References

- `source-baseline.md`：源倉庫狀態、dirty 檔案和實施前凍結門禁。
- `source-feature-map.md`：AICodex 功能到目標 Requirement、程式碼位置和證據的逐項對映。
- `implementation-guide.md`：按檔案實施順序、時序、狀態機、API/路由矩陣和常見錯誤。
- `verification.md`：35 條 Requirement 的證據矩陣、協議測試、洩露門禁、灰度閾值和回滾手冊。
