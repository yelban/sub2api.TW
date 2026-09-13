## ADDED Requirements

### Requirement: 管理臺必須提供安全審計分組和獨立提示詞審計頁面
控制台 SHALL 把安全相關的內容稽核頁面組織到“安全審計”導航分組中，並新增獨立“提示詞審計”頁面。原 `/admin/risk-control` 路由、頁面狀態和功能 MUST 保持相容；新頁面路由 MUST 為 `/admin/prompt-audit` 或經實現評審確認的等價穩定路由。

#### Scenario: 管理員檢視側欄
- **WHEN** 管理員已登入且 risk_control_enabled=true
- **THEN** 側欄 MUST 展示“安全審計”可展開分組
- **THEN** 分組 MUST 至少包含“內容稽核”和“提示詞審計”兩個子入口

#### Scenario: 管理員開啟原內容稽核頁面
- **WHEN** 管理員訪問 `/admin/risk-control`
- **THEN** 頁面 MUST 繼續展示原有 Moderations、關鍵詞、Hash、封號、郵件和記錄功能
- **THEN** 頁面 MUST NOT 被提示詞審計配置或事件替換

#### Scenario: 功能總開關關閉
- **WHEN** risk_control_enabled=false
- **THEN** 安全審計導航和提示詞審計閘道器執行 MUST 按現有功能開關策略停用
- **THEN** 已儲存的配置和歷史事件 MUST 不被刪除

### Requirement: 提示詞審計頁面必須提供清晰的獨立工作區
頁面 SHALL 在同一工作區展示執行概覽、審計池、審計策略、事件列表和固定儲存操作區。頁面 MUST 清楚區分“非同步只審計”和“同步阻止”，並 MUST 展示未儲存狀態和最終生效狀態。

#### Scenario: 初次開啟頁面
- **WHEN** 管理員開啟提示詞審計頁面
- **THEN** 頁面 MUST 並行或有界載入配置、執行態、分組列表和事件列表
- **THEN** 頁面 MUST 展示有效模式、Worker 狀態、佇列狀態、節點連通性和最近錯誤

#### Scenario: 修改但未儲存配置
- **WHEN** 管理員修改審計池、分類、範圍或模式開關
- **THEN** 頁面 MUST 顯示“有未儲存的更改”
- **THEN** 執行態 MUST 繼續標識服務端當前生效版本，不能把草稿顯示為已生效

### Requirement: 頁面必須支援完整審計池管理和真實探測
頁面 SHALL 支援新增、編輯、啟用、停用和刪除審計池，並允許配置 Base URL、API Key、Model、超時和 input_limit。API Key 已儲存後 MUST 只顯示配置狀態，不能回顯明文。

#### Scenario: 編輯已儲存節點
- **WHEN** 管理員開啟已配置 API Key 的節點
- **THEN** API Key 輸入框 MUST 為空或顯示不可逆佔位狀態
- **THEN** 未填寫新 Key 儲存時 MUST 保留原密文
- **THEN** 頁面 MUST 提供顯式清除憑據操作

#### Scenario: 執行連線測試
- **WHEN** 管理員點選節點“連線測試”
- **THEN** 頁面 MUST 展示配置校驗、傳送請求、服務響應和測試結論狀態
- **THEN** 結果 MUST 展示耗時、HTTP 狀態、穩定錯誤碼和脫敏訊息

### Requirement: 頁面必須支援審計範圍和九類風險配置
頁面 SHALL 支援全部分組或指定 group ID 範圍，並展示九類 Qwen3Guard 風險分類。頁面 MUST 使用目標專案真實分組資料，已刪除但仍存在於配置中的分組 MUST 顯示為失效項而不是被靜默丟棄。

#### Scenario: 選擇指定分組
- **WHEN** 管理員把範圍切換為 selected 並選擇一個或多個分組
- **THEN** 儲存載荷 MUST 使用穩定 group ID
- **THEN** 頁面 MUST 展示已選數量並支援搜尋

#### Scenario: 檢視風險分類
- **WHEN** 管理員檢視掃描器配置
- **THEN** 頁面 MUST 展示 Violent、Non-violent Illegal Acts、Sexual Content or Sexual Acts、PII、Suicide & Self-Harm、Unethical Acts、Politically Sensitive Topics、Copyright Violation、Jailbreak

### Requirement: 開啟同步阻止必須有明確的風險確認
頁面 SHALL 把 enabled、blocking_enabled 和 store_pass_events 作為獨立開關。關閉 enabled 時 MUST 自動關閉並停用 blocking_enabled；開啟 blocking_enabled 時 MUST 展示二次確認，說明請求延遲、Block 和 Guard 不可用的 fail-closed 行為。

#### Scenario: 開啟同步阻止
- **WHEN** 管理員把 blocking_enabled 從 false 切換為 true
- **THEN** 頁面 MUST 在儲存前展示風險確認
- **THEN** 確認文案 MUST 說明請求會等待 Guard，Block 或 Guard 不可用時不會訪問上游

#### Scenario: 關閉審計總開關
- **WHEN** 管理員關閉 enabled
- **THEN** 頁面草稿 MUST 同時把 blocking_enabled 設為 false

### Requirement: 配置儲存必須可驗證且不得洩露憑據
頁面 SHALL 通過一個統一儲存動作提交完整規範化配置。儲存成功後 MUST 用後端返回值重新整理頁面快照、清除已提交 API Key 明文並顯示 config_version；儲存失敗 MUST 保留草稿並展示穩定錯誤資訊。

#### Scenario: 儲存成功
- **WHEN** 後端成功儲存配置
- **THEN** 頁面 MUST 顯示配置已同步和新的 config_version
- **THEN** 瀏覽器狀態、除錯日誌和快取 MUST 不再保留剛提交的 API Key 明文

#### Scenario: 儲存校驗失敗
- **WHEN** 後端返回節點地址、模式組合或策略校驗錯誤
- **THEN** 頁面 MUST 保留使用者草稿
- **THEN** 頁面 MUST 展示穩定錯誤碼及可行動的中文說明

#### Scenario: 配置被其他管理員更新
- **WHEN** 儲存返回 409 `prompt_audit_config_conflict`
- **THEN** 頁面 MUST 保留本地草稿並提示服務端配置已變化
- **THEN** 頁面 MUST 提供重新載入/對比入口，不得自動用舊草稿覆蓋新配置

### Requirement: 頁面必須展示真實執行態和同步 Guard 指標
頁面 SHALL 展示 process_status、Worker 總數/活動數、佇列容量/長度、queued/processing/done/failed 數、處理/失敗總數、最近時間、節點連通性、配置版本一致性、Redis Payload Store 狀態和同步 Guard Allow/Flag/Block/Unavailable/timeout/failover/bulkhead 指標。

#### Scenario: 配置版本未同步
- **WHEN** expected_config_version 與 active_config_version 不一致
- **THEN** 頁面 MUST 顯示明確的配置未同步或載入中狀態
- **THEN** 頁面 MUST 展示最近載入錯誤和時間（如存在）

#### Scenario: Worker 心跳過期
- **WHEN** heartbeat_at 超過後端定義的健康視窗
- **THEN** 頁面 MUST 顯示 stale 而不是 running

### Requirement: 頁面必須提供可複核的事件列表和詳情
頁面 SHALL 提供事件分頁、總數、decision/risk/endpoint/group/user/API key/request ID/prompt Hash/關鍵字/時間範圍篩選、行選擇和詳情抽屜或彈窗。詳情 MUST 只展示脫敏資料。

#### Scenario: 檢視事件列表
- **WHEN** 管理員應用篩選
- **THEN** 表格 MUST 展示時間、使用者/API key、分組、入口/模型、判定、風險、分類、預覽和操作

#### Scenario: 檢視事件詳情
- **WHEN** 管理員開啟一條事件
- **THEN** 頁面 MUST 展示脫敏預覽、審計摘要、結構化返回、具體風險摘要和技術資訊
- **THEN** 頁面 MUST 提供 request ID、prompt Hash、scanner、策略、節點、配置版本、分片數和耗時
- **THEN** 頁面 MUST 不展示完整提示詞或節點 API Key

#### Scenario: 複核使用者身份和具體風險
- **WHEN** 事件擁有使用者名稱、使用者郵箱、API Key 名稱和一個或多個風險分類
- **THEN** 頁面 MUST 將使用者名稱、郵箱和 API Key 名稱分列展示並提供獨立複製操作
- **THEN** 頁面 MUST 為每個風險展示 category、標題、說明、嚴重度、動作、scanner、score 和脫敏證據摘要
- **THEN** 使用者不存在或欄位為空時 MUST 顯示穩定 fallback，而不是把其他身份欄位冒充為該欄位

### Requirement: 頁面必須提供防誤操作的事件刪除流程
頁面 SHALL 支援單條刪除、選中項批次刪除和按篩選刪除。按篩選刪除 MUST 先呼叫預覽介面，並要求明確時間範圍、matched_count、snapshot_max_id、filter_hash、服務端認證 confirmation_token 和二次確認。

#### Scenario: 單條刪除
- **WHEN** 管理員確認刪除一條事件
- **THEN** 頁面 MUST 呼叫單條刪除介面並在成功後重新整理列表與執行統計

#### Scenario: 按篩選刪除
- **WHEN** 管理員已設定明確時間範圍並請求按篩選刪除
- **THEN** 頁面 MUST 先展示匹配數量和規範化篩選摘要
- **THEN** 只有管理員再次確認後才能提交 filter_hash、confirmation_token 和 confirm=true

#### Scenario: 篩選在預覽後發生變化
- **WHEN** 管理員預覽後修改任意篩選條件
- **THEN** 舊 filter_hash MUST 失效
- **THEN** 舊 confirmation_token MUST 同時失效
- **THEN** 頁面 MUST 要求重新預覽

### Requirement: 管理 API 操作必須納入現有管理員審計
所有配置寫入、節點探測和事件刪除 SHALL 複用現有管理員鑑權與管理操作審計。審計詳情 MUST 使用脫敏摘要，禁止記錄 API Key、完整提示詞或完整請求載荷。

#### Scenario: 配置更新成功
- **WHEN** 管理員成功儲存提示詞審計配置
- **THEN** 管理操作審計 MUST 記錄操作者、request ID、enabled、blocking_enabled、config_version、節點數量、分類數量和分組範圍摘要

#### Scenario: 節點探測失敗
- **WHEN** 管理員探測節點失敗
- **THEN** 管理操作審計 MUST 記錄節點 ID、穩定錯誤碼、HTTP 狀態和耗時
- **THEN** 審計詳情 MUST 不包含 API Key 或完整 Base URL query

### Requirement: 頁面必須滿足響應式、可訪問和國際化要求
頁面 SHALL 使用現有 Vue 3、i18n 和通用元件體系，支援桌面與窄屏，所有開關、輸入、按鈕、狀態和對話方塊 MUST 具有可訪問名稱；新增中英文文案鍵 MUST 成對提供且通過現有 lint、typecheck 和 Vitest。

#### Scenario: 窄屏使用
- **WHEN** 頁面寬度小於桌面斷點
- **THEN** 配置區、篩選區、表格和固定儲存欄 MUST 可滾動或重排而不遮擋關鍵操作

#### Scenario: 鍵盤和讀屏操作
- **WHEN** 使用者只使用鍵盤或讀屏訪問頁面
- **THEN** 審計池操作、模式開關、篩選、詳情和確認對話方塊 MUST 可識別且可操作
