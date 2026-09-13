## ADDED Requirements

### Requirement: 同步提示詞門禁必須由顯式配置啟用
系統 SHALL 使用 `enabled` 與 `blocking_enabled` 表達關閉、非同步只審計、同步審計並阻止三態。舊配置或缺失欄位 MUST 歸一為 `blocking_enabled=false`；系統 MUST 拒絕 `enabled=false && blocking_enabled=true` 的配置。

#### Scenario: 關閉提示詞審計
- **WHEN** enabled=false
- **THEN** 有效模式 MUST 為 off
- **THEN** blocking_enabled MUST 被視為 false

#### Scenario: 啟用非同步審計
- **WHEN** enabled=true 且 blocking_enabled=false
- **THEN** 有效模式 MUST 為 async_audit
- **THEN** Guard 故障 MUST NOT 改變主請求結果

#### Scenario: 啟用同步阻止
- **WHEN** enabled=true 且 blocking_enabled=true
- **THEN** 有效模式 MUST 為 blocking
- **THEN** 適用請求 MUST 等待 Guard 判定後才能進入帳號選擇、計費和上游階段

#### Scenario: 儲存非法開關組合
- **WHEN** 管理員儲存 enabled=false 且 blocking_enabled=true
- **THEN** 後端 MUST 返回 400 和 `prompt_guard_requires_audit_enabled`

### Requirement: 安全審計協調器必須保持兩個引擎的獨立語義
系統 SHALL 通過一個薄協調器把可信請求上下文交給現有內容稽核和新增提示詞審計。協調器 MUST 不轉換兩套風險分類、不共用事件表、不讓提示詞審計觸發內容稽核副作用，並 MUST 使用確定性的阻斷優先順序。

#### Scenario: 現有內容稽核阻斷
- **WHEN** 現有內容稽核返回 Block
- **THEN** 客戶端 MUST 繼續收到升級前的狀態碼、錯誤碼和文案
- **THEN** 提示詞審計非同步模式 MAY 繼續完成自己的獨立記錄

#### Scenario: 僅提示詞 Guard 阻斷
- **WHEN** 現有內容稽核允許但提示詞 Guard 返回 Block
- **THEN** 客戶端 MUST 收到 `prompt_guard_blocked`

#### Scenario: 兩個引擎同時阻斷
- **WHEN** 兩個引擎都返回 Block
- **THEN** 現有內容稽核錯誤語義 MUST 具有客戶端響應優先順序
- **THEN** 兩個引擎 MUST 各自記錄其結果和結構化日誌

### Requirement: 同步門禁必須位於外部副作用之前
系統 MUST 在鑑權和請求格式校驗完成後、帳號選擇、帳戶併發、計費資格檢查、任何預扣、上游連線和上游寫入之前完成同步判定。被 Block 或 fail-closed 拒絕的請求 MUST 不產生這些下游副作用。

#### Scenario: HTTP 請求被 Guard 阻斷
- **WHEN** 任一支援的 HTTP 模型請求得到 Block
- **THEN** 帳號選擇次數、計費檢查/預扣次數和上游請求次數 MUST 均為 0
- **THEN** 流式請求 MUST 在拒絕前未寫出 SSE 響應頭或首位元組

#### Scenario: Guard 不可用
- **WHEN** 同步模式下所有可用節點均失敗
- **THEN** 請求 MUST 在任何帳號、計費或上游副作用之前返回 503

### Requirement: 同步門禁必須覆蓋所有目標協議入口
系統 SHALL 覆蓋現有內容稽核已接入的所有使用者文本入口，並通過結構測試防止後續路由繞過。至少包括 OpenAI Chat Completions、OpenAI Responses、Claude Messages、Gemini、OpenAI Images/Grok 媒體文本 prompt，以及 Responses WebSocket 首輪和後續輪次。

#### Scenario: OpenAI 相容 HTTP 入口
- **WHEN** 客戶端呼叫 Chat Completions 或 Responses 相容入口
- **THEN** 系統 MUST 使用對應協議提取器並執行同一 Guard evaluator
- **THEN** 現有 OpenAI 請求和響應 envelope MUST 保持相容

#### Scenario: Claude 或 Gemini 入口
- **WHEN** 客戶端呼叫 Claude Messages 或 Gemini 入口
- **THEN** 系統 MUST 執行相同策略判定
- **THEN** 拒絕響應 MUST 使用該協議現有錯誤 envelope 和共享穩定 error_code

#### Scenario: 新增使用者文本入口
- **WHEN** 後續程式碼新增一個可觸發模型執行且包含使用者文本的路由
- **THEN** 路由覆蓋門禁 MUST 在缺少安全審計接線時失敗

### Requirement: 同步分片必須共享總預算並完整覆蓋
系統 SHALL 以有序節點列表中首個啟用節點的 timeout 作為一次同步 evaluation 的總預算。所有分片和節點故障切換 MUST 共享該 deadline；任一必要分片失敗、超時或無合法結果時 MUST fail-closed。

#### Scenario: 所有分片均為安全
- **WHEN** 每個非空分片都在總預算內返回 Safe 或允許的 Warn
- **THEN** 請求 MAY 進入下一階段

#### Scenario: 中間分片阻斷
- **WHEN** 任一分片返回 Block
- **THEN** evaluator MAY 立即早停
- **THEN** 請求 MUST 被阻斷且不得部分轉發

#### Scenario: 最後一個必要分片失敗
- **WHEN** 前面分片安全但最後一個必要分片超時或響應無效
- **THEN** 系統 MUST 返回 unavailable/invalid_response
- **THEN** 系統 MUST NOT 根據部分結果放行

### Requirement: 同步節點故障切換必須有序且 fail-closed
系統 SHALL 按配置順序嘗試啟用節點。連線失敗、429、5xx 和超時 MAY 在總 deadline 尚有剩餘時切換到下一節點；401/403、嚴格解析失敗或耗盡節點 MUST 結束為不可用/非法響應。同步模式 MUST NOT 提供隱式 fail-open。

#### Scenario: 首節點暫時失敗而次節點成功
- **WHEN** 首節點返回可重試錯誤且次節點在剩餘預算內返回合法結果
- **THEN** 系統 MUST 使用次節點結果
- **THEN** failover 指標 MUST 增加

#### Scenario: 認證失敗
- **WHEN** 節點返回 401 或 403
- **THEN** 系統 MUST 視為不可重試配置錯誤
- **THEN** 請求 MUST 返回 503 而不是按 Safe 放行

#### Scenario: 所有節點容量飽和
- **WHEN** 全域性或每節點 bulkhead 均無法接受 evaluation
- **THEN** 系統 MUST 快速返回 `prompt_guard_unavailable`
- **THEN** 系統 MUST 不無限排隊

### Requirement: HTTP 拒絕必須保持協議相容和穩定錯誤碼
同步 Guard MUST 使用現有 Handler 的協議錯誤建構子和最小擴充套件，且只向客戶端暴露通用訊息、穩定 Prompt Guard code/reason 和 request ID。OpenAI/Claude MUST 在 error 物件的可選 `code` 欄位攜帶穩定程式碼並保留原合法 type；Gemini MUST 保留數值 `error.code` 與 canonical status，並在 `google.rpc.ErrorInfo.reason` 攜帶穩定程式碼。響應 MUST 不包含風險正文、類別細節、內部節點地址或憑據。

#### Scenario: HTTP Block
- **WHEN** 同步 Guard 判定為 Block
- **THEN** HTTP 狀態 MUST 為 403
- **THEN** error_code MUST 為 `prompt_guard_blocked`

#### Scenario: Gemini HTTP Block
- **WHEN** Gemini 入口的同步 Guard 判定為 Block
- **THEN** Google error envelope 的 `error.code` MUST 保持數值 403 且 status MUST 為對應 canonical status
- **THEN** `error.details` 中 ErrorInfo reason MUST 為 `prompt_guard_blocked`

#### Scenario: HTTP Guard 不可用
- **WHEN** 節點超時、連線失敗、熔斷或容量不足
- **THEN** HTTP 狀態 MUST 為 503
- **THEN** error_code MUST 為 `prompt_guard_unavailable`

#### Scenario: HTTP Guard 響應非法
- **WHEN** Guard 輸出無法嚴格解析
- **THEN** HTTP 狀態 MUST 為 503
- **THEN** error_code MUST 為 `prompt_guard_invalid_response`

### Requirement: Responses WebSocket 必須對每個 response.create 執行門禁
系統 SHALL 在 WebSocket 首次和後續每個 `response.create` 幀進入本輪使用者/帳號併發、計費和上游傳送之前執行同步 Guard。一次安全結果 MUST NOT 被複用於不同的後續幀。

#### Scenario: 首輪 Block
- **WHEN** 首個 response.create 被判定為 Block
- **THEN** 服務端 MUST 不建立本輪上游請求或計費記錄
- **THEN** 服務端 MUST 使用 close code 4403 和 reason `prompt_guard_blocked` 關閉連線

#### Scenario: 後續輪次 Block
- **WHEN** 已建立連線的後續 response.create 被判定為 Block
- **THEN** 該幀 MUST 不傳送給上游且不得建立本輪計費記錄
- **THEN** 服務端 MUST 使用 4403 關閉連線並記錄 stage=subsequent_turn

#### Scenario: WebSocket Guard 不可用
- **WHEN** 首輪或後續輪次 Guard 不可用或響應非法
- **THEN** 服務端 MUST 使用 close code 1013
- **THEN** reason MUST 為 `prompt_guard_unavailable` 或 `prompt_guard_invalid_response`

### Requirement: 同步結果必須複用到脫敏事件且不得重複掃描
系統 SHALL 在一次同步 evaluation 後把已得到的歸一化結果交給獨立記錄路徑。記錄路徑 MUST NOT 重新呼叫 Guard，也 MUST NOT 需要完整提示詞正文；同步結果最多對應一個任務事實和一個按儲存策略決定的事件。

#### Scenario: 同步 Block 被記錄
- **WHEN** evaluator 已得到 Block
- **THEN** 系統 MUST 用脫敏快照和既有結果建立 done 任務及風險事件
- **THEN** Guard 呼叫次數 MUST 等於 evaluation 實際需要的節點/分片次數，而不是因記錄而增加

#### Scenario: 同步 Allow 且不儲存 Pass
- **WHEN** evaluator 得到 Allow 且 store_pass_events=false
- **THEN** 系統 MAY 只儲存任務/指標而不建立 Pass 事件

### Requirement: 配置必須以版本化快照發布到請求熱路徑
系統 SHALL 為提示詞審計配置維護單調遞增 config_version、updated_at、updated_by 和 change_summary。儲存後 MUST 原子替換本例項快照並通過 Redis 釋出失效通知；請求熱路徑 MUST 讀取記憶體快照而不是逐請求查詢資料庫。

#### Scenario: 多例項收到配置更新
- **WHEN** 管理員成功儲存新配置
- **THEN** 儲存例項 MUST 立即安裝新版本併發布 Redis 失效通知
- **THEN** 其他例項 MUST 重新載入並原子替換快照

#### Scenario: 兩個管理員併發儲存配置
- **WHEN** 兩個儲存請求攜帶相同 expected_config_version 且第一個已提交新版本
- **THEN** 第二個請求 MUST 返回 409 `prompt_audit_config_conflict`
- **THEN** 第二個請求 MUST NOT 靜默覆蓋第一個請求或複用相同 config_version

#### Scenario: Redis 通知不可用
- **WHEN** 配置已儲存但 Redis publish 失敗
- **THEN** 系統 MUST 記錄 `prompt_guard.config_reload_degraded`
- **THEN** 其他例項 MUST 通過有界 TTL 重新整理最終獲得新版本

#### Scenario: 冷啟動無法載入嚴格配置
- **WHEN** 例項冷啟動且無法獲得有效配置快照
- **THEN** 對已知要求同步阻止的適用請求 MUST fail-closed
- **THEN** 執行態 MUST 暴露配置載入錯誤

### Requirement: Guard 關鍵路徑必須可觀測且不得洩密
系統 SHALL 輸出穩定結構化事件並提供計數/耗時指標。日誌至少 MUST 覆蓋配置更新/載入/降級、evaluation 開始、Allow、Block、失敗、結果記錄失敗、非同步投遞/丟棄、Worker 處理/重試/失敗、逐分片開始/完成/失敗、分片聚合和滯留回收。

#### Scenario: 同步請求被阻斷
- **WHEN** Guard 阻斷一個請求
- **THEN** 日誌 MUST 包含 request_id、user_id、api_key_id、group_id、protocol、endpoint、model、config_version、guard_endpoint_id、decision、action、chunk_total、latency_ms、status 和 error_code
- **THEN** 日誌 MUST 明確包含 `upstream_dispatched=false` 和 `billing_preconsumed=false` 或目標專案等價欄位

#### Scenario: 檢查日誌敏感欄位
- **WHEN** 測試捕獲提示詞審計日誌
- **THEN** 日誌中 MUST 不包含原始提示詞、API Key、Authorization、完整 Guard URL query 或 Redis 載荷

### Requirement: 停用或回滾同步阻止必須即時恢復非同步行為
系統 SHALL 支援僅通過關閉 blocking_enabled 回到非同步只審計，無需刪除表、清空歷史事件或停止現有內容稽核。

#### Scenario: 管理員關閉同步阻止
- **WHEN** blocking_enabled 從 true 儲存為 false 且新配置已生效
- **THEN** 後續適用請求 MUST 不再等待 Guard 同步結果
- **THEN** enabled=true 時後續請求 MUST 改為非同步投遞
- **THEN** 歷史任務和事件 MUST 保留
