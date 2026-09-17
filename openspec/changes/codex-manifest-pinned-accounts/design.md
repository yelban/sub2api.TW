## Context

動機見 proposal.md。與方案相關的現狀：

- Codex Model Manifest 入口是 `OpenAIGatewayHandler.CodexModels`：先嚐試用帳號模型對映本地生成；否則迴圈 `SelectAccountForModelWithExclusions` 選帳號、`FetchCodexModelsManifest` 拉取、`CompleteAPIKeyCodexModelsManifestForClient` 補全、`MergeGroupConfiguredCodexModels` 做分組過濾與 ETag。
- `FetchCodexModelsManifest` 對 API Key 帳號走 `fetchCachedAPIKeyCodexModelsManifest`（30 秒新鮮、5 分鐘樂觀、單飛後臺重新整理），對 OAuth 帳號直接請求上游且帶 agent identity 任務恢復邏輯，不快取。
- 分組配置落地鏈路：ent schema → SQL 遷移 → `service.Group` → `group_repo` 建立與更新 setter → `api_key_repo` 分組欄位投影與 `groupEntityToService` → 認證快照 `api_key_auth_cache.go` 結構體及 impl 兩處對映 → 管理端 DTO / mapper → `admin_group.go` 建立與更新 → 分組複製。`models_list_config` 是完整樣板。
- 前端 `GroupsView.vue` 已有 7000 行；模型路由的帳號選擇用「標籤 + 搜尋輸入 + 下拉」內聯實現，`Select.vue` 僅支援單選。`components/admin/group/` 下已有抽出的表單片段元件（如 `ReasoningEffortPolicyFields.vue`）。
- 後端管理端帳號列表介面支援 `platform`、`group`、`search` 過濾。

## Goals / Non-Goals

**Goals:**
- 固定帳號模式的執行時邏輯放在 service 層，handler 只做分支與錯誤對映。
- 合併邏輯是純函式，可獨立單測。
- 快取策略只有一套實現，OAuth 與 API Key 帳號共用；固定帳號模式不引入第二層分組級快取。
- 新欄位在所有分組載入路徑上都可見，特別是認證快照與 API Key 投影。

**Non-Goals:**
- 不改動排程器邏輯與普通請求的帳號選擇。
- 不為帳號解綁或刪除增加對該配置的級聯清理，執行時容忍失效 ID。
- 固定帳號關閉時保留本地生成 manifest 的路徑；開啟時以指定帳號上游發現為先，對映在發現後應用。
- 建立分組對話方塊不提供該配置。

## Decisions

### D1：配置以單個 JSONB 列儲存
`groups.codex_models_manifest_config`，領域型別 `domain.GroupCodexModelsManifestConfig{Enabled bool; AccountIDs []int64; FallbackToScheduler bool}`，JSON 鍵為 `enabled`、`account_ids`、`fallback_to_scheduler`。
- 備選：三個獨立列。否決：三個欄位語義耦合，JSON 保證原子寫入，且與 `models_list_config` 一致。
- 遷移檔案 `234_group_codex_models_manifest_config.sql`：`ADD COLUMN IF NOT EXISTS ... JSONB NOT NULL DEFAULT '{}'::jsonb`。ent schema 使用 `field.JSON(...).Default(domain.GroupCodexModelsManifestConfig{})`。

### D2：校驗放在 admin service，建立路徑拒絕開啟
- 新檔案 `group_codex_models_manifest.go` 提供 `normalizeCodexModelsManifestConfig`（平臺非 openai 歸零；去重保序；`enabled=false` 時保留列表便於再次啟用）與 `validateCodexModelsManifestConfig(ctx, groupID, cfg)`（`enabled=true` 時：非空、≤10、全部屬於 `accountRepo.ListByGroup(groupID)` 且平臺 openai）。
- 建立路徑：`enabled=true` 直接 400。原因：帳號繫結發生在分組建立之後，建立時無法校驗成員關係；前端也不展示。
- 備選：校驗放 handler。否決：需要訪問帳號倉儲，且建立與更新兩條路徑共用，service 是唯一收口。

### D3：執行時入口與回退策略
- handler 在本地生成分支之前判斷 `group.Platform == openai && cfg.Enabled`，呼叫 `gatewayService.FetchPinnedCodexModelsManifest(ctx, group, clientVersion)`。
- 返回值：`(*OpenAIModelsResponse, *Account, error)`，`*Account` 為配置順序中第一個成功帳號，用於 `setOpsSelectedAccount`。
- 「無可用帳號」以哨兵錯誤 `ErrNoPinnedCodexModelsAccounts` 表示；「全部失敗」返回最後一個上游錯誤。handler 根據 `FallbackToScheduler` 決定：true 時跌入現有排程器迴圈；false 時無可用帳號返回 503、全部失敗按 `infraerrors.Code(err)` 返回。
- 可用性判定：`IsActive() && Schedulable && !(AutoPauseOnExpired && 已過期)`。刻意不使用 `IsSchedulable()`，因為它包含限流、過載與臨時不可排程視窗。
- 帳號來源：`accountRepo.ListByGroup(group.ID)`（active 成員），按配置順序篩選並跳過缺失 ID。
- 備選：複用 `BuildGroupConfiguredCodexModelsManifest` 已載入的帳號列表以省一次查詢。否決：那兩個列表是可排程集合，會漏掉限流中的帳號；一次按分組的查詢成本可接受。

### D4：併發拉取與純函式合併
- 用 `sync.WaitGroup` 對每個可用帳號併發執行：`FetchCodexModelsManifest(ctx, acc, clientVersion, "")` → API Key 帳號再 `CompleteAPIKeyCodexModelsManifestForClient`。結果寫入按配置順序索引的切片，失敗記錄到同下標的錯誤切片；各帳號獨立完成，不因單帳號失敗取消其他請求。
- Codex 合併函式 `mergeCodexModelsManifestBodies(bodies [][]byte) ([]byte, error)`：以第一個 body 的頂層信封為基底，`models` 按 slug 並集，先出現者優先；slug 為空或解析失敗的條目按出現順序保留一次。輸出後設定 `ETag = codexModelsManifestBodyETag(body)`，再交給 `MergeGroupConfiguredCodexModels` 做分組過濾與 304 判斷。
- 部分失敗：`slog.Warn` 帶 group_id 與失敗帳號 ID 列表。
- 實現放在新檔案 `openai_codex_models_pinned.go`，避免繼續膨脹 2300 行的主檔案。

### D5：快取統一併調整時效
- 將 `fetchCachedAPIKeyCodexModelsManifest` 泛化為 `fetchCachedOpenAIModels(ctx, request, fetch, ifNoneMatch)`，`fetch func(ctx, ifNoneMatch) (*CodexModelsManifest, error)` 由呼叫方提供：API Key 路徑傳 `fetchCodexModelsManifestUpstream`；OAuth 路徑傳一個包含 agent identity 任務恢復邏輯的閉包。`handleCodexModelsManifestAccountAuthError` 在 OAuth 閉包返回錯誤時照舊呼叫。
- 常量：`openAIModelsCacheTTL` 30s → 60s；`openAIModelsCacheStaleTTL` 保持 5 分鐘；超過 5 分鐘 `get` 刪除條目返回 miss，呼叫方同步等待單飛結果，這與「超期強制等待上游重新整理」一致，無需新狀態。
- 快取鍵已包含 Authorization 與 Version 頭，令牌重新整理自然失效舊條目；`client_version` 不同的客戶端各佔一個條目。
- 快取鍵不含分組資訊，多個分組共用同一帳號時共享同一條目，新鮮期內零上游請求，樂觀期與超期重新整理均按鍵單飛，同一時刻一個帳號只發一次上游請求；分組級處理（並集合並、自定義列表過濾、別名合併）都在快取體的克隆上進行，不寫回快取。
- `openAIModelsCacheMaxEntries` 64 → 512。OAuth 路徑接入後條目數為「帳號數 × 客戶端版本數」，64 條在大規模部署下會被淘汰導致額外上游請求；單條清單通常幾十 KB，最壞情況記憶體佔用為幾十 MB 量級。
- 後臺重新整理使用 `context.Background()` 加上游 15 秒超時，與現狀一致。
- 備選：為固定帳號模式增加分組級合併結果快取。否決：帳號級快取命中後合併只是記憶體操作，再加一層會引入兩套時效與失效問題。

### D6：前端拆出獨立元件
- 新元件 `components/admin/group/CodexManifestAccountsField.vue`：props 為 `groupId`、`modelValue`（`{enabled, account_ids, fallback_to_scheduler}`）與已選帳號名稱對映；內部實現開關、標籤列表、帶防抖的搜尋輸入與下拉、回退子開關。搜尋呼叫 `adminAPI.accounts.list(1, 20, {search, platform: 'openai', group: String(groupId)})`。
- `GroupsView.vue` 只在編輯對話方塊 OpenAI 區塊掛載元件，開啟編輯時用 `adminAPI.accounts.getById` 解析已存 ID 的名稱，失敗則顯示 `#<id>`。提交時開關開啟且列表為空則 toast 報錯並阻止。
- 備選：在 GroupsView 內聯複製模型路由的搜尋狀態。否決：會再引入一套按 key 索引的搜尋狀態，檔案已過大。

## Risks / Trade-offs

- [固定帳號模式下每次快取超期會向 N 個帳號併發請求] → 帳號數上限 10；帳號級快取 1 分鐘新鮮期把穩態請求量壓到低於現狀。
- [限流中的帳號被強制用於拉取 manifest 可能加重其 429] → 這是需求明確要求的行為；manifest 請求不佔併發槽，且被快取吸收；失敗時按部分合並處理。
- [部分帳號失敗導致模型列表短暫缺項] → 記錄警告日誌；下一次超期重新整理恢復。使用者已確認接受。
- [OAuth manifest 首次接入快取，樂觀期內令牌已被撤銷仍會返回舊內容最多 4 分鐘] → manifest 非敏感資料，且撤銷後的下一次重新整理會失敗並按現有 401 處理流程處理帳號。
- [配置引用的帳號被解綁或刪除後成為髒 ID] → 執行時跳過；編輯對話方塊顯示 `#<id>` 提示管理員清理；全部失效時按回退配置處理。
- [認證快照漏投影新欄位會讓開關靜默失效] → 倉庫已有投影對帳整合測試，任務中包含更新該測試。

## Migration Plan

1. 部署包含遷移 234 的後端版本；遷移冪等，預設值 `{}` 反序列化為關閉狀態，存量分組行為不變。
2. 快取時效變化隨部署即時生效，無需資料遷移。
3. 回滾：回退程式碼即可，列保留無副作用；如需徹底清理可手工 `DROP COLUMN`。

### D7：普通模型列表共用固定帳號來源

- `GatewayHandler.Models` 在 OpenAI 分組開啟固定帳號時呼叫 `FetchPinnedOpenAIModelsList`；普通 `/models` 別名共用該入口。
- 共享原有配置、固定帳號成員篩選、併發收集與部分失敗規則；標準列表失敗且允許回退時用現有 OpenAI 排程器選帳，再呼叫普通目錄獲取。無帳號為 503，全部上游失敗保留上游錯誤語義，不以靜態預設列表掩蓋失敗。
- API Key 使用標準模型 URL，不新增 Codex `client_version` 或身份請求頭；從管理端抽出 API Key 請求構造。OAuth 複用 `FetchCodexModelsManifest` 和規範客戶端版本，保留憑據引用、Agent Identity 恢復、401 狀態處理。
- 響應/快取後設資料型別泛化為 `OpenAIModelsResponse`；抽出原始 HTTP 響應獲取，Codex 專用轉換/後設資料補全僅在 manifest 路徑執行。兩種請求使用同一快取實現，以響應格式、完整 URL、帳號、憑據、代理和請求頭區分條目；相同 OAuth 請求共享條目。
- 標準列表保留上游 `id`、`created`、`owned_by` 等欄位。OAuth slug 轉成標準條目；無建立時間採用 0。有效空陣列是成功結果，缺失或錯誤的陣列結構是上游錯誤。

### D8：固定帳號目錄的對映與過濾

- 每個成功帳號先基於它的原始目錄做公開名稱投影，隨後按配置順序取並集。透傳或無對映帳號保留上游具體 ID；有對映帳號僅暴露對映目標存在於該帳號目錄的具體公開名稱。
- 具體對映鍵以及分組選擇的具體名稱可作為別名候選；通配對映可匹配上游/分組提供的具體候選，但通配規則本身不作為模型 ID 返回。複用 `ResolveMappedModel` 的匹配優先順序。
- Codex 別名繼承對應上游條目的能力後設資料；固定帳號開啟時不再注入其他分組帳號的本地別名。固定帳號回退選出的帳號也應用相同投影。
- 分組列表過濾最後執行，遵守配置順序；過濾後為空返回 200 空陣列，不使用靜態預設模型。最終響應體計算 ETag 並處理 304。
- 前端文案說明該配置覆蓋普通模型列表和 Codex Model Manifest。持久化配置名稱和結構不變。

### D9：擴充套件驗證

新增路由/handler 與 service 測試覆蓋普通兩條路由、固定帳號優先、原始媒體和未知模型、對映與通配別名、部分/全部失敗及排程器回退、憑據/請求協議隔離、OAuth 快取複用、三段快取時效、分組過濾隔離與空目錄、最終 ETag。執行受影響 Go 測試（含 race）、完整 unit 檢查及前端型別/元件檢查。
