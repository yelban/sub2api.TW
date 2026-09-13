## Purpose

讓 OpenAI 分組管理員指定一組固定帳號來獲取普通模型列表與 Codex Model Manifest，使同一分組的 API Key 始終看到確定且合併後的模型列表，而不受排程器選帳結果影響。

## ADDED Requirements

### Requirement: OpenAI 分組可配置固定帳號獲取 Codex Model Manifest
系統 SHALL 為平臺為 `openai` 的分組提供 `codex_models_manifest_config` 配置，包含 `enabled`（預設 false）、`account_ids`（帳號 ID 列表）和 `fallback_to_scheduler`（預設 false）。`enabled=false` 時系統 MUST 保持現有的本地目錄優先、無本地目錄時排程器獲取 manifest 的行為；普通列表保持本地對映/預設列表行為。

#### Scenario: 預設關閉
- **WHEN** 分組未設定或 `enabled=false`
- **THEN** Codex Model Manifest 請求 MUST 走現有本地生成或排程器選帳路徑
- **THEN** `account_ids` 與 `fallback_to_scheduler` MUST 不影響任何執行時行為

#### Scenario: 非 OpenAI 平臺分組
- **WHEN** 分組平臺不是 `openai` 且請求攜帶 `enabled=true` 的配置
- **THEN** 系統 MUST 將該配置歸一化為關閉狀態後落庫，而不是返回錯誤

### Requirement: 開啟時必須至少選擇一個分組內的 OpenAI 帳號
當 `enabled=true` 時，管理端更新介面 MUST 校驗 `account_ids` 去重後至少包含一個帳號，且每個帳號 MUST 是當前分組內狀態為 active、平臺為 `openai` 的帳號；帳號數量 MUST NOT 超過 10 個。校驗失敗 MUST 返回 400，不落庫。

#### Scenario: 開啟但未選擇帳號
- **WHEN** 管理員儲存 `enabled=true` 且 `account_ids` 為空
- **THEN** 系統 MUST 返回 400，錯誤碼為 `INVALID_CODEX_MODELS_MANIFEST_CONFIG`

#### Scenario: 選擇了不屬於當前分組的帳號
- **WHEN** `account_ids` 包含未繫結到該分組、已停用或平臺不是 `openai` 的帳號
- **THEN** 系統 MUST 返回 400，錯誤資訊指出無效帳號 ID

#### Scenario: 建立分組時開啟
- **WHEN** 建立分組請求攜帶 `enabled=true`
- **THEN** 系統 MUST 返回 400，提示建立後再在編輯中配置

#### Scenario: 重複帳號 ID
- **WHEN** `account_ids` 含重複 ID
- **THEN** 系統 MUST 去重後儲存，保持首次出現的順序

### Requirement: 固定帳號模式只使用選定帳號獲取 manifest
當 `enabled=true` 時，該分組 API Key 的 Codex Model Manifest 請求 MUST 只向選定帳號發起上游請求，MUST NOT 呼叫排程器。選定帳號的可用性判定 MUST 只考慮帳號狀態為 active、可排程開關開啟、未因過期自動暫停；MUST 忽略優先順序、負載因子、限流視窗與過載視窗。已從分組移除或已刪除的帳號 MUST 被跳過。

#### Scenario: 限流中的選定帳號仍被使用
- **WHEN** 某個選定帳號處於限流或過載視窗內
- **THEN** 系統 MUST 仍然使用該帳號請求 manifest

#### Scenario: 停用的選定帳號被跳過
- **WHEN** 某個選定帳號狀態為 inactive 或可排程開關關閉
- **THEN** 系統 MUST 跳過該帳號，不向其發起請求

#### Scenario: 選定帳號已不在分組內
- **WHEN** 配置中的帳號 ID 已從分組解綁或已刪除
- **THEN** 系統 MUST 跳過該 ID，並繼續處理其餘帳號

### Requirement: 多個選定帳號併發請求併合並模型列表
系統 MUST 對所有可用的選定帳號併發發起 manifest 請求，並把各帳號響應的 `models` 按 `slug` 取並集：同一 slug 以配置順序中靠前帳號的條目為準；頂層其餘欄位取配置順序中第一個成功帳號的響應。合併結果 MUST 繼續應用分組自定義模型列表過濾；別名 MUST 僅來自成功拉取帳號的對映投影，並基於最終響應體計算 ETag。

#### Scenario: 並集合並
- **WHEN** 帳號 1 返回模型 A、B，帳號 2 返回模型 A、C
- **THEN** 客戶端 MUST 收到模型 A、B、C，且 A 的條目來自帳號 1

#### Scenario: 部分帳號失敗
- **WHEN** 一個選定帳號上游返回錯誤而其他帳號成功
- **THEN** 系統 MUST 以成功帳號的響應合併並返回 200
- **THEN** 系統 MUST 記錄包含失敗帳號 ID 的警告日誌

#### Scenario: 分組自定義模型列表仍然生效
- **WHEN** 分組啟用了自定義 `/v1/models` 列表
- **THEN** 合併後的 manifest MUST 只保留列表中允許的模型

#### Scenario: ETag 條件請求
- **WHEN** 客戶端 `If-None-Match` 與合併後最終響應體的 ETag 匹配
- **THEN** 系統 MUST 返回 304 且響應體為空

### Requirement: 選定帳號全部不可用或全部失敗時按配置回退
當沒有任何可用的選定帳號，或所有可用帳號的上游請求全部失敗時：`fallback_to_scheduler=false` 時系統 MUST 返回上游錯誤（全部失敗時）或 503（無可用帳號時）；`fallback_to_scheduler=true` 時系統 MUST 回退到現有排程器選帳路徑。

#### Scenario: 預設不回退
- **WHEN** `fallback_to_scheduler=false` 且所有選定帳號都不可用
- **THEN** 系統 MUST 返回 503，錯誤型別為 `upstream_error`

#### Scenario: 全部失敗且不回退
- **WHEN** `fallback_to_scheduler=false` 且所有可用選定帳號的上游請求均失敗
- **THEN** 系統 MUST 返回最後一個上游錯誤對應的狀態碼與資訊

#### Scenario: 開啟回退
- **WHEN** `fallback_to_scheduler=true` 且所有選定帳號不可用或全部失敗
- **THEN** 系統 MUST 使用排程器選擇帳號並按現有流程返回 manifest

### Requirement: 管理端展示與編輯固定帳號配置
分組編輯對話方塊在平臺為 `openai` 時 MUST 展示該配置：一個開關；開關開啟後展示帶搜尋的多選帳號下拉與「全部不可用時回退排程器」子開關。帳號下拉 MUST 只列出當前分組內平臺為 `openai` 的帳號，並支援按名稱搜尋。分組建立對話方塊 MUST NOT 展示該配置。

#### Scenario: 開啟後未選帳號即提交
- **WHEN** 管理員開啟開關但未選擇任何帳號並點選儲存
- **THEN** 前端 MUST 阻止提交併提示至少選擇一個帳號

#### Scenario: 回顯已儲存帳號
- **WHEN** 開啟一個已配置固定帳號的分組編輯對話方塊
- **THEN** 已選帳號 MUST 以名稱標籤展示；無法解析名稱的帳號 MUST 以 `#<id>` 展示

#### Scenario: 分組複製
- **WHEN** 管理員複製一個開啟了固定帳號配置的分組
- **THEN** 新分組的該配置 MUST 為關閉且帳號列表為空

### Requirement: 普通模型列表複用固定帳號配置
當 OpenAI 分組開啟固定帳號時，普通 `/v1/models` 與 `/models` 請求 MUST 使用同一組指定帳號向上遊發現模型，並輸出 `{object:"list",data:[...]}`。API Key 請求 MUST 使用標準模型列表端點，不新增 `client_version`；OAuth MUST 使用已有 Codex manifest 鏈路，將 slug 轉為標準 ID。普通列表 MUST 保留上游媒體模型與未知具體模型。

#### Scenario: 普通客戶端發現特殊模型
- **WHEN** 不帶 `client_version` 的請求使用開啟固定帳號的分組，所選帳號返回非內建的模型
- **THEN** 普通列表 MUST 包含該模型且 MUST NOT 請求未選帳號

#### Scenario: API Key 與 OAuth 帳號混合
- **WHEN** 所選帳號包含 API Key 與 OAuth
- **THEN** 系統 MUST 按各自協議獲取目錄並按 ID 合併，重複 ID MUST 取配置順序靠前帳號的條目

#### Scenario: 普通請求回退
- **WHEN** 固定帳號全不可用或全失敗且開啟回退
- **THEN** 系統 MUST 經由排程器選帳號獲取普通模型目錄，而不是返回本地預設列表

### Requirement: 固定帳號發現先於本地目錄生成
固定帳號開啟時，普通列表與 Codex manifest MUST 先獲取指定帳號目錄，再按照來源帳號的模型對映生成公開名稱，最後應用分組列表過濾。MUST NOT 因為存在顯式模型對映而跳過上游發現。透傳帳號 MUST 忽略殘留模型對映；普通模式的具體別名僅在對映目標存在於來源帳號目錄時可見。MUST NOT 注入未成功拉取帳號的別名或把通配模式作為模型 ID 返回。

#### Scenario: 有對映的固定帳號
- **WHEN** 所選帳號配置 public-name 到 upstream-name 的對映且上游返回 upstream-name
- **THEN** 系統 MUST 請求該帳號上游並以 public-name 返回該模型，Codex 條目 MUST 繼承上游能力後設資料

#### Scenario: 固定帳號開啟但列表為空
- **WHEN** 執行時配置開啟但帳號 ID 列表為空
- **THEN** 系統 MUST 按無可用固定帳號的失敗/回退規則處理，MUST NOT 靜默使用本地目錄

#### Scenario: 成功空目錄或過濾為空
- **WHEN** 上游返回有效空陣列或分組過濾排除了全部模型
- **THEN** 普通模型列表 MUST 返回 200 且 data 為空陣列，MUST NOT 返回預設模型或觸發失敗回退

### Requirement: 普通模型列表的條件請求
普通固定帳號列表 MUST 基於對映、合併和過濾後的最終響應體計算 ETag。

#### Scenario: 普通列表 ETag 匹配
- **WHEN** 客戶端 If-None-Match 與最終普通列表響應的 ETag 匹配
- **THEN** 系統 MUST 返回 304 且無響應體
