## Purpose

規定 Codex Model Manifest 按帳號快取的時效策略，使所有帳號型別的 manifest 拉取在新鮮期內不打上游、樂觀期內先返回快取再後臺重新整理、超期後同步重新整理。

## ADDED Requirements

### Requirement: 所有帳號型別的 manifest 拉取都經過快取
系統 MUST 對 OAuth 帳號與 API Key 帳號的 Codex Model Manifest 上游拉取統一使用同一套按帳號快取。快取鍵 MUST 區分帳號、憑據帳號、代理與請求頭（含授權頭與客戶端版本），憑據變化後 MUST 視為新的快取項。快取鍵 MUST NOT 包含分組資訊，多個分組共用同一帳號時 MUST 共享同一快取項；固定帳號模式下每個選定帳號的拉取 MUST 同樣經過該快取。快取 MUST 至少容納 512 個條目。

#### Scenario: OAuth 帳號命中快取
- **WHEN** 同一 OAuth 帳號在新鮮期內被再次用於獲取 manifest
- **THEN** 系統 MUST 直接返回快取內容，MUST NOT 向 chatgpt.com 發起請求

#### Scenario: 多個分組共用同一帳號
- **WHEN** 兩個分組在同一時刻通過同一帳號請求 manifest 且快取已超期
- **THEN** 系統 MUST 只向上遊發起一次請求，兩個分組 MUST 各自基於該結果做分組級處理
- **THEN** 一個分組的過濾結果 MUST NOT 影響另一個分組收到的內容

#### Scenario: 憑據重新整理後
- **WHEN** 帳號的訪問令牌被重新整理
- **THEN** 下一次拉取 MUST 視為快取未命中並同步請求上游

### Requirement: 新鮮期 1 分鐘內強制使用快取
快取項寫入後 1 分鐘內 MUST 視為新鮮：系統 MUST 直接返回快取內容且 MUST NOT 觸發任何上游請求（包括後臺重新整理）。

#### Scenario: 新鮮期內併發請求
- **WHEN** 快取寫入後 30 秒內收到 10 個同帳號 manifest 請求
- **THEN** 上游請求次數 MUST 為 0

### Requirement: 1 到 5 分鐘樂觀返回並後臺重新整理
快取項寫入後超過 1 分鐘且不超過 5 分鐘時 MUST 視為過期但可用：系統 MUST 立即返回快取內容，並在後臺對同一快取鍵做單飛重新整理。後臺重新整理 MUST 攜帶上游 ETag，上游返回 304 時 MUST 續期現有快取項。

#### Scenario: 樂觀期返回舊值
- **WHEN** 快取寫入後 3 分鐘收到請求
- **THEN** 系統 MUST 立即返回快取內容
- **THEN** 系統 MUST 觸發一次後臺上遊重新整理，同一時刻多個請求 MUST 只觸發一次

#### Scenario: 後臺重新整理失敗
- **WHEN** 樂觀期後臺重新整理失敗
- **THEN** 已返回給客戶端的響應 MUST 不受影響
- **THEN** 快取項 MUST 保持不變直到超期

### Requirement: 超過 5 分鐘強制同步重新整理
快取項寫入後超過 5 分鐘 MUST 視為失效：系統 MUST 丟棄該快取項，同步等待上游響應後再返回；上游失敗時 MUST 向客戶端返回錯誤而不是舊快取。

#### Scenario: 超期後同步等待
- **WHEN** 快取寫入後 6 分鐘收到請求
- **THEN** 系統 MUST 等待上游響應後返回新內容
- **THEN** 新內容 MUST 寫入快取並重新開始 1 分鐘新鮮期

#### Scenario: 超期後上遊失敗
- **WHEN** 快取已超期且上游請求失敗
- **THEN** 系統 MUST 返回上游錯誤，MUST NOT 返回舊快取

### Requirement: 條件請求基於快取內容的 ETag
客戶端攜帶的 `If-None-Match` MUST 與返回給客戶端的最終響應體 ETag 比較，而不是透傳給上游。快取命中且 ETag 匹配時 MUST 返回 304。

#### Scenario: 快取命中且 ETag 匹配
- **WHEN** 客戶端 `If-None-Match` 等於當前快取內容的 ETag
- **THEN** 系統 MUST 返回 304 且不請求上游

### Requirement: 普通模型發現使用相同快取策略
普通固定帳號模型列表的上游獲取 MUST 使用本規範的同一套按帳號快取與單飛實現。完整請求 URL MUST 參與快取鍵；API Key 的普通請求與 Codex 協議請求 MUST 分離。OAuth 普通列表使用規範版本獲取的 manifest MUST 與相同請求條件的 Codex manifest 共享快取。分組後處理 MUST NOT 修改快取。

#### Scenario: OAuth 兩種列表共用快取
- **WHEN** 相同 OAuth 帳號的普通列表與相同版本 Codex manifest 在新鮮期內連續請求
- **THEN** 系統 MUST 僅發起一次上游請求，並輸出各自正確的響應結構

#### Scenario: API Key 兩種協議分離
- **WHEN** 相同 API Key 帳號先後被用於普通列表和帶 client_version 的 Codex manifest
- **THEN** 各請求 MUST 獲取並快取自己的上游響應，MUST NOT 複用另一協議已轉換的內容
