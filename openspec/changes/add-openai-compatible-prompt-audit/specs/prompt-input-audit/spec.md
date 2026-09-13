## ADDED Requirements

### Requirement: 提示詞審計必須是獨立且預設關閉的安全審計引擎
系統 SHALL 在現有內容稽核之外提供獨立的提示詞審計引擎。新引擎 MUST 擁有獨立配置、執行態、任務、事件和開關，並 MUST 預設關閉；現有 OpenAI Moderations 內容稽核的配置、判定、關鍵詞、Hash、郵件、自動封號、日誌表和清理行為 MUST NOT 因本能力而改變。

#### Scenario: 升級後未啟用新引擎
- **WHEN** 系統完成包含本能力的升級且管理員尚未儲存提示詞審計配置
- **THEN** 所有模型請求 MUST 繼續按升級前的內容稽核和轉發鏈路執行
- **THEN** 系統 MUST NOT 建立提示詞審計任務、寫入提示詞審計事件或呼叫外部 Guard

#### Scenario: 兩個審計引擎同時啟用
- **WHEN** 現有內容稽核和新增提示詞審計都已啟用
- **THEN** 兩個引擎 MUST 使用各自的配置與風險語義獨立執行
- **THEN** 提示詞審計命中 MUST NOT 自動觸發現有內容稽核的郵件、封號或 Hash 黑名單副作用

### Requirement: 提示詞審計節點必須使用 OpenAI 相容協議
系統 SHALL 僅支援通過 OpenAI 相容 Chat Completions 介面呼叫提示詞審計節點。節點配置 MUST 支援名稱、Base URL、API Key、Model、超時、單片輸入上限、啟用狀態和有序優先順序；預設模型 MUST 為 `sileader/qwen3guard:0.6b`。

#### Scenario: Worker 呼叫已配置節點
- **WHEN** Worker 領取到可處理任務並選擇一個啟用節點
- **THEN** 系統 MUST 向 `{base_url}/v1/chat/completions` 傳送請求
- **THEN** 請求 MUST 使用 `role=user`、`temperature=0`、確定性的輸出限制和管理員配置的模型
- **THEN** 系統 MUST NOT 呼叫舊的 `/v1/scan/prompt` 或 `llm_guard` 專用協議

#### Scenario: 管理員儲存未填寫模型的節點
- **WHEN** 管理員儲存一個 Base URL 有效但 Model 為空的節點
- **THEN** 系統 MUST 將節點模型歸一為 `sileader/qwen3guard:0.6b`

#### Scenario: 管理員探測節點
- **WHEN** 管理員請求探測一個節點
- **THEN** 後端 MUST 使用服務端網路環境執行真實的認證與模型連通性探測
- **THEN** 響應 MUST 包含成功狀態、穩定錯誤碼、HTTP 狀態、耗時、是否可重試和檢查時間
- **THEN** 響應 MUST NOT 回顯 API Key

### Requirement: 審計節點憑據必須受到安全保護且出站目標由管理員負責
系統 MUST 使用現有 SecretEncryptor 加密持久化節點 API Key，並 MUST 對響應體實施大小限制。節點地址及其網路目標由管理員自行配置和負責；系統 MUST NOT 按公網、私網、迴環、link-local、後設資料、保留地址或 DNS 解析結果阻止儲存、探測和實際呼叫，也 MUST NOT 禁止 HTTP 或正常 HTTP 重定向。完整憑據只允許短暫存在於管理員寫入請求、前端未持久化輸入記憶體、服務端解密記憶體和發往 Guard 的 Authorization Header；它們以及 URL query、提示詞正文 MUST NOT 出現在日誌、錯誤響應、管理讀取響應或前端持久化/除錯狀態中。

#### Scenario: 儲存帶 API Key 的節點
- **WHEN** 管理員儲存一個包含 API Key 的節點
- **THEN** settings 中 MUST 只儲存加密密文和是否已配置標記
- **THEN** 後續讀取配置 MUST 只返回 `has_token=true` 或等價狀態

#### Scenario: 儲存管理員配置的內網或特殊地址
- **WHEN** Base URL 使用 HTTP(S) 且指向私網、迴環、link-local、後設資料、保留地址或解析到這些地址的域名
- **THEN** 系統 MUST 接受該節點配置並從服務端網路環境執行探測和實際呼叫
- **THEN** 系統 MUST NOT 對 DNS 結果進行地址類別攔截

#### Scenario: 節點返回重定向或超大響應
- **WHEN** Guard 返回正常 HTTP 重定向
- **THEN** 系統 MUST 使用標準 HTTP 客戶端行為跟隨重定向
- **WHEN** Guard 返回超過配置上限的響應體
- **THEN** 系統 MUST 將響應判定為無效或不可用

### Requirement: 系統必須按協議提取使用者輸入提示詞快照
系統 SHALL 從目標專案所有已支援、包含使用者文本的模型入口提取提示詞快照。快照 MUST 包含 request ID、user ID、使用者名稱、使用者郵箱、API key ID/名稱、group ID/名稱、provider、endpoint、protocol、model、提示詞 Hash、脫敏預覽、Unicode 字元數和訊息數量；文本審計 MUST 優先掃描最新使用者輸入，同時完整覆蓋需要審計的歷史使用者文本。

#### Scenario: 提取 OpenAI Chat Completions 輸入
- **WHEN** `/v1/chat/completions` 或等價相容入口包含一個或多個 `role=user` 訊息
- **THEN** 系統 MUST 提取使用者文本內容並把最新使用者輸入置於掃描順序最前
- **THEN** 系統 MUST 不把 assistant 或 tool 輸出當作使用者提示詞主體

#### Scenario: 提取 OpenAI Responses 輸入
- **WHEN** `/v1/responses` 請求使用字串、訊息陣列或內容塊表達使用者輸入
- **THEN** 系統 MUST 提取其中的使用者文本並保留 Responses 協議標識

#### Scenario: 提取 Claude 和 Gemini 輸入
- **WHEN** Claude Messages 或 Gemini 相容入口包含使用者角色文本
- **THEN** 系統 MUST 提取可審計文本並保留真實 protocol、endpoint 和 model

#### Scenario: 提取影像或媒體生成提示詞
- **WHEN** OpenAI Images、Grok 媒體或目標專案其他生成入口包含文本 prompt
- **THEN** 新引擎 MUST 審計文本 prompt
- **THEN** 新引擎 MUST NOT 把圖片二進位制、base64 圖片或遠端圖片內容傳送給 Qwen3Guard
- **THEN** 圖片內容稽核 MUST 繼續由現有內容稽核引擎負責

#### Scenario: 請求沒有使用者文本
- **WHEN** 請求體有效但沒有可審計的使用者文本
- **THEN** 系統 MUST 跳過提示詞任務並記錄穩定的 skipped reason

### Requirement: 提示詞資料庫快照必須脫敏且不可恢復原文
系統 SHALL 在寫入資料庫前計算 SHA-256 Hash 和脫敏裁剪預覽。PostgreSQL、結構化日誌、管理 API 和前端 MUST NOT 儲存或返回完整原始提示詞；用於實際掃描的正文只允許儲存在請求記憶體或 Redis 短 TTL 載荷中。

#### Scenario: 建立非同步任務
- **WHEN** 系統為使用者輸入建立非同步審計任務
- **THEN** `prompt_audit_jobs` MUST 儲存 Hash、脫敏預覽、字元數、訊息數、分列的使用者/API Key 展示快照和可關聯請求上下文
- **THEN** 表中 MUST 不存在 raw_prompt、payload 或等價原文欄位

#### Scenario: 管理員檢視事件詳情
- **WHEN** 管理員開啟提示詞審計事件詳情
- **THEN** 頁面和 API MUST 只展示脫敏預覽、Hash、分類、結構化風險摘要、證據摘要和技術後設資料
- **THEN** 任何證據片段 MUST 經過脫敏、長度限制並包含不可逆 Hash，而不是完整命中正文

### Requirement: 非同步審計必須使用持久任務和短期 Redis 載荷
系統 SHALL 使用 PostgreSQL `prompt_audit_jobs` 作為任務事實源，並使用 Redis 儲存預設 30 分鐘 TTL 的完整掃描正文。非同步任務投遞 MUST 不阻塞或改變主模型請求結果。

#### Scenario: 成功投遞非同步任務
- **WHEN** 提示詞審計處於 async_audit、請求在審計範圍內且佇列未滿
- **THEN** 系統 MUST 先建立不可被 Worker 領取的 staging 任務
- **THEN** 系統 MUST 成功寫入 Redis 載荷後再把任務釋出為 queued
- **THEN** 主請求 MUST 繼續進入現有閘道器鏈路

#### Scenario: Redis 載荷寫入失敗
- **WHEN** 資料庫任務已建立但 Redis 載荷寫入失敗
- **THEN** 系統 MUST 將任務標記為 failed 或保持可清理的 staging 狀態
- **THEN** 系統 MUST 輸出 `prompt_audit.enqueue_dropped` 和穩定錯誤碼
- **THEN** 主模型請求 MUST 不受影響

#### Scenario: 佇列達到容量上限
- **WHEN** queued、retry、processing 和 staging 活躍任務達到配置容量
- **THEN** 系統 MUST 拒絕建立新的非同步任務並記錄 `reason=queue_full`
- **THEN** 主模型請求 MUST 繼續轉發

#### Scenario: 多例項同時爭搶最後佇列容量
- **WHEN** 多個例項併發入隊且剩餘容量不足以容納全部請求
- **THEN** active count 檢查與 staging INSERT MUST 在同一資料庫准入鎖事務中序列化
- **THEN** 已接受的 active jobs MUST NOT 超過該配置快照的 queue_capacity
- **THEN** 未獲準任務 MUST 按 queue_full 或 queue_admission_busy 丟棄且不影響主請求

### Requirement: 程序內 Worker 必須可靠消費持久任務
系統 SHALL 在主服務程序內啟動可配置數量的 Worker。多例項 Worker MUST 通過 PostgreSQL 原子領取任務，併為每次領取生成單調遞增的 claim version fencing token；租約重新整理、事件提交和終態更新 MUST 校驗該 token。系統還 MUST 支援重試退避、processing 租約重新整理、滯留任務回收、最大嘗試次數和優雅關閉。

#### Scenario: 多 Worker 併發領取任務
- **WHEN** 多個程序或 Worker 同時尋找可執行任務
- **THEN** 每個任務 MUST 只被一個 Worker 原子領取
- **THEN** 領取過程 MUST 使用資料庫行鎖/條件更新或等價的無重複執行機制

#### Scenario: 已回收的舊 Worker 恢復
- **WHEN** Worker A 的 processing 租約已被回收且任務隨後由 Worker B 以更高 claim version 重新領取
- **THEN** Worker A 的租約重新整理、事件寫入和終態更新 MUST 因 claim version 不匹配而失敗
- **THEN** Worker A MUST NOT 覆蓋 Worker B 的任務狀態或建立重複事件

#### Scenario: 可重試節點故障
- **WHEN** Guard 返回 429、5xx、連線失敗或超時且任務仍有剩餘嘗試次數
- **THEN** Worker MUST 將任務置為 retry 並設定有界退避的 next_attempt_at

#### Scenario: 不可重試錯誤或達到最大嘗試次數
- **WHEN** Guard 返回認證失敗、嚴格解析失敗或任務達到最大嘗試次數
- **THEN** Worker MUST 將任務標記為 failed 並儲存脫敏後的穩定錯誤碼
- **THEN** Redis 載荷 MUST 被刪除或等待短 TTL 自動清理

#### Scenario: 回收滯留 processing 任務
- **WHEN** processing 任務的租約超過允許時長
- **THEN** 系統 MUST 按剩餘嘗試次數把任務回收到 retry 或標記 failed
- **THEN** 系統 MUST 輸出可關聯 job ID 的回收日誌

#### Scenario: Worker 啟動失敗
- **WHEN** 資料庫、Redis、配置或加密依賴導致 Worker 無法啟動
- **THEN** 主 API MUST 繼續提供非提示詞審計能力
- **THEN** 執行態 MUST 顯示 error/degraded 和穩定錯誤碼，而不是顯示健康

### Requirement: Qwen3Guard 返回必須被嚴格歸一化
系統 SHALL 嚴格解析單一 `Safety` 行和單一 `Categories` 行，並支援 Violent、Non-violent Illegal Acts、Sexual Content or Sexual Acts、PII、Suicide & Self-Harm、Unethical Acts、Politically Sensitive Topics、Copyright Violation、Jailbreak 九類輸入風險。額外非空說明、重複欄位、未知 Safety 或無法解析響應 MUST 視為 invalid_response。

#### Scenario: Safe 結果
- **WHEN** Guard 返回 `Safety: Safe`
- **THEN** 歸一化結果 MUST 為 pass/low/Allow

#### Scenario: Controversial 結果
- **WHEN** Guard 返回 `Safety: Controversial`
- **THEN** 預設結果 MUST 為 flag/Warn
- **THEN** 命中已啟用的 Jailbreak、PII 或 Suicide & Self-Harm 時 MUST 提升為 critical/Block

#### Scenario: Unsafe 結果
- **WHEN** Guard 返回 `Safety: Unsafe` 且命中至少一個已啟用類別
- **THEN** 結果 MUST 為 critical/Block

#### Scenario: Unsafe 包含未知類別
- **WHEN** Guard 返回 Unsafe 但類別未知或不可對映
- **THEN** 系統 MUST 記錄 `unknown_unsafe` 並保持 Block 語義

#### Scenario: 嚴格響應解析失敗
- **WHEN** Guard 響應缺少欄位、包含重複欄位、出現額外非空說明或 Safety 不在允許列舉中
- **THEN** 系統 MUST 返回 `prompt_guard_invalid_response`
- **THEN** 系統 MUST NOT 把該結果偽裝為 Safe

### Requirement: 長提示詞必須完整進行 Unicode 分片審計
系統 SHALL 按 Unicode rune 而不是位元組對提示詞分片。最新使用者輸入 MUST 作為優先片段，其他輸入按確定順序完整覆蓋；非同步任務必須在每片開始前重新整理 processing 租約，併為每片開始、完成、失敗及最終聚合輸出不含正文的結構化日誌。

#### Scenario: 輸入超過節點單片上限
- **WHEN** 提示詞 Unicode 字元數超過節點 input_limit
- **THEN** 系統 MUST 生成覆蓋全部非空文本的連續分片
- **THEN** 任一分片 Block MUST 使聚合結果為 Block
- **THEN** 只有全部必要分片成功後才能產生 Allow

#### Scenario: 最新輸入包含風險
- **WHEN** 最新使用者輸入位於長會話尾部並包含 Block 風險
- **THEN** 該輸入 MUST 在歷史文本之前接受掃描
- **THEN** 同步模式 MAY 在確認 Block 後停止後續分片，但 MUST NOT 部分放行

#### Scenario: 多分片掃描完成
- **WHEN** 一個提示詞被拆成多個分片並完成聚合
- **THEN** 日誌 MUST 包含 chunk_index、chunk_total、chunk_chars、input_chars、input_limit、guard endpoint、action 和 latency
- **THEN** 日誌 MUST NOT 包含分片正文、脫敏前證據或內部優先順序分隔符

### Requirement: 審計事件必須獨立、可關聯且可安全管理
系統 SHALL 把歸一化結果寫入 `prompt_audit_events`，並支援是否儲存 Pass 事件。事件 MUST 包含請求上下文、分列的使用者名稱/郵箱/API Key 名稱快照、脫敏提示詞快照、decision、risk_level、action、分類、scanner、證據、策略、節點、配置版本、分片數和耗時；管理 DTO MUST 從這些事實確定性派生結構化 `issue_summaries`，不得複製儲存第二套風險事實。

#### Scenario: 風險事件被記錄
- **WHEN** Worker 或同步 Guard 得到 flag/critical 結果
- **THEN** 系統 MUST 建立獨立提示詞審計事件
- **THEN** 事件 MUST 可通過 request_id、user_id、api_key_id、group_id 和 prompt_hash 檢索

#### Scenario: Pass 事件儲存關閉
- **WHEN** 結果為 pass 且 store_pass_events=false
- **THEN** 系統 MUST 完成任務但 MAY 不建立事件

#### Scenario: 同步結果寫入失敗
- **WHEN** 同步 Guard 已完成判定但事件持久化失敗
- **THEN** 系統 MUST 輸出 `prompt_guard.result_record_failed`
- **THEN** 持久化失敗 MUST NOT 把已確定的 Allow 改成 Block，也 MUST NOT 撤銷已確定的 Block

### Requirement: 提示詞審計執行態必須反映真實依賴和處理狀態
系統 SHALL 提供執行態介面，返回有效模式、期望/生效配置版本、配置載入時間與錯誤、Worker 心跳、佇列容量與各狀態數量、處理/失敗統計、最近錯誤、節點連通性、資料庫/Redis 狀態和同步 Guard 指標。

#### Scenario: 管理員查詢健康執行態
- **WHEN** Worker 正常心跳、資料庫與 Redis 可用且至少一個節點探測成功
- **THEN** 執行態 MUST 顯示 running/ok 和真實統計值

#### Scenario: Redis 不可用
- **WHEN** 提示詞審計已啟用但 Redis 載荷儲存不可用
- **THEN** 非同步執行態 MUST 顯示 error 或 degraded
- **THEN** 頁面 MUST NOT 僅因 Base URL 已配置而顯示健康

### Requirement: 管理員必須能夠查詢和安全刪除提示詞審計事件
系統 SHALL 提供分頁列表、詳情、單條刪除、批次 ID 刪除和按篩選刪除。篩選 MUST 支援 decision、risk level、endpoint、group、user、API key、request ID、prompt Hash、關鍵字和時間範圍。

#### Scenario: 按篩選查詢事件
- **WHEN** 管理員提交一個或多個受支援篩選條件
- **THEN** 系統 MUST 返回穩定排序的分頁事件和總數

#### Scenario: 預覽按篩選刪除
- **WHEN** 管理員提交包含明確時間範圍的刪除篩選
- **THEN** 系統 MUST 返回 matched_count、規範化篩選摘要、snapshot_max_id、filter_hash 和綁定當前管理員且短期有效的 confirmation_token
- **THEN** 系統 MUST 不立即刪除資料

#### Scenario: 確認按篩選刪除
- **WHEN** 管理員提交相同篩選、有效 filter_hash、未過期 confirmation_token 和顯式 confirm=true
- **THEN** 系統 MUST 只分批刪除匹配且 id 不高於預覽 snapshot_max_id 的事件，以及已無事件引用的孤立任務
- **THEN** 系統 MUST 清理相關 Redis 載荷並寫入管理操作審計

#### Scenario: 偽造或重放其他管理員的刪除確認
- **WHEN** confirmation_token 無法認證、已過期、操作者不匹配、Hash 不匹配或缺失
- **THEN** 系統 MUST 拒絕刪除並返回穩定錯誤碼
- **THEN** 客戶端自行計算 filter_hash MUST NOT 繞過 delete-preview

#### Scenario: 無時間範圍的大範圍刪除
- **WHEN** 管理員嘗試按篩選刪除但未提供明確時間範圍
- **THEN** 系統 MUST 拒絕操作並返回穩定錯誤碼
