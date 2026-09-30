# Sub2API 本地外掛協議

本目錄是外掛開發者可以依賴的公開契約。`v1/plugin.proto` 和 `v1/runtime.go` 定義程序協議，`v1/manifest.schema.json` 定義包清單，`docs/` 記錄開發和釋出規範。Provider 私有實現不應放入本目錄。

## 開發文件

- [開發指南](docs/development.md)：從執行時、配置到整合測試的完整流程。
- [UI Bridge](docs/ui-bridge.md)：沙箱配置 UI 的訊息結構和安全要求。
- [包格式](docs/package-format.md)：清單、檔案雜湊、簽名和版本規則。
- [安全邊界](docs/security.md)：程序許可權、敏感資料和故障策略。

## 實體與執行方式

外掛的交付實體是一個 `.s2plugin` 檔案，本質上是帶清單、簽名、獨立執行檔和靜態 UI 的 ZIP 包。管理員在獨立的外掛管理頁手動上傳，Sub2API 不從網路自動下載外掛，也不要求 Docker。

啟用後，Sub2API 以子程序方式拉起當前作業系統和 CPU 架構對應的二進位制，通過本機 gRPC 流傳遞請求與響應。外掛程序退出時會隨 Sub2API 清理；停用時先停止接收新請求，再等待正在處理的請求結束。

多例項部署不要求共享外掛目錄。宿主會在資料庫儲存已驗籤的原始外掛包，各例項缺少本地檔案時會重新驗籤和解包，並週期性對齊啟用狀態、灰度比例和加密配置。所有例項必須連線同一資料庫並使用相同的加密金鑰。

獨立程序是程式碼和釋出邊界，不是作業系統安全沙箱。外掛擁有 Sub2API 服務使用者所擁有的檔案和網路許可權，因此只應安裝可信釋出者的簽名包。閉源二進位制可提高原始碼分發門檻，但不能承諾無法反編譯。

## 初期能力邊界

當前只接受 `openai.oauth.outbound_transport.v1`：

- 僅匹配 `platform=openai` 且 `account_type=oauth` 的上游 HTTP 請求。
- API Key 帳號、其他 provider、OAuth 登入與 Token 重新整理流程不進入外掛。
- 外掛建立真實的上游 HTTP/TLS 連線並返回原始 HTTP 響應。
- 命中外掛的 OAuth WebSocket 帳號會使用 Sub2API 現有 HTTP Bridge，不直接建立上游 WebSocket，避免繞過 v1 HTTP 外掛協議。
- Sub2API 繼續負責響應狀態處理、SSE 解析、錯誤對映、用量統計、計費和下游輸出。
- 灰度比例以帳號 ID 穩定分桶，未命中的 OAuth 帳號繼續使用原有內建路徑。

## 宿主服務（HostService）

`HostService` 是宿主經 go-plugin broker 反向暴露給外掛的通用能力層，獨立於具體外掛型別，供有狀態外掛使用。它通過 `TransportPlugin.InitHostServices` 在執行時協商：宿主啟動後把一個 broker 流 id 交給外掛，外掛用它撥號回宿主並獲得 `HostServiceClient`。

- **可選且向後相容**：未實現 `InitHostServices` 的舊外掛返回 `Unimplemented`，宿主靜默跳過，轉發能力不受影響。宿主服務有獨立的 `HostServiceAPIVersion`，新增能力不會改變傳輸契約版本，也不會使既有外掛失效。
- **隨程序回收**：宿主服務例項與外掛程序生命週期繫結，外掛退出時 broker 關閉並自動 `GracefulStop`，無需外掛手動清理。

當前提供的通用設施：

- **名稱空間鍵值儲存（KV）**：`KVGet` / `KVSet` / `KVDelete` / `KVList`，為外掛持久化跨請求、跨副本、跨重啟的狀態。儲存由 Redis 支撐，因此多例項部署天然共享同一份狀態。
  - **名稱空間隔離**：宿主根據服務該連線的執行時注入外掛身份（`pluginKey`），外掛無法偽造，也無法讀寫其它外掛的名稱空間。
  - **護欄**：`namespace` / `key` 僅允許 `[A-Za-z0-9._-]`；單值上限 256 KiB；`ttl_seconds` 為 0 表示不過期、正值有上限；`KVList` 返回條數有上限。

新增宿主設施時，在 `HostService` 上追加 RPC 即可，無需改動傳輸契約或清單格式。

## 包結構

```text
manifest.json
signature.json                 # 生產包必需
runtimes/linux-amd64/plugin
runtimes/linux-arm64/plugin
runtimes/windows-amd64/plugin.exe
ui/index.html
ui/assets/...
```

`manifest.json` 必須宣告所有執行時和 UI 檔案的 SHA-256。`signature.json` 使用受信任釋出者的 Ed25519 私鑰對 `manifest.json` 原始位元組簽名。官方 OpenAI Transport 公鑰由宿主內建，第三方釋出者公鑰由部署者追加到 `plugins.trusted_publishers`。檔案雜湊由已簽名清單保護。

外掛預設保持停用。未簽名包預設拒絕安裝；`plugins.allow_unsigned` 只應用於開發者自己構建的本地除錯包。

## 相容性

清單必須同時宣告：

- `requires.sub2api`：允許的 Sub2API 語義化版本範圍。
- `requires.recommended_sub2api_version`：建議使用的宿主版本。
- `requires.tested_sub2api_versions`：釋出者實際驗證過的宿主版本。
- `plugin_protocol`、`transport_api`、`ui_bridge`：三個獨立協議版本。

宿主版本超出範圍時，外掛可以安裝並檢視，但保持“不相容”狀態且不能啟用。版本在範圍內但未列入已測試版本時，管理員必須再次確認才能啟用。

## UI 隔離與 Bridge

外掛 UI 由包內靜態檔案實現，宿主使用只有 `allow-scripts` 許可權的 sandbox iframe 載入。iframe 沒有管理員 Token，也不能直接訪問管理 API。宿主為每次開啟配置頁生成短時資源 URL 和獨立 Bridge Token，並且同時校驗訊息來源視窗與 Token。

UI 可以傳送以下訊息。訊息按語義分層，鑑權與副作用一致對應（讀操作免二次驗證，寫/主動測試需要二次驗證），任何外掛都可複用，不針對具體外掛定製：

| 訊息 | 語義 | 二次驗證 | 對映的外掛 RPC |
| --- | --- | --- | --- |
| `config.load` | 讀取已儲存配置 | 否 | 宿主資料庫 |
| `config.save` | 寫入配置 | 是 | `ValidateConfig` + `ApplyConfig` |
| `config.test` | 主動測試配置/連通性（可產生副作用） | 是 | `TestConfig` |
| `plugin.status` | 讀取執行時狀態（無副作用） | 否 | `Health`（`status_json`） |
| `ui.resize` / `ui.notify` | 僅 UI 互動 | — | — |

每個請求訊息帶 `request_id`，宿主以 `<type>.result` 返回結果。

- 配置整體使用 Sub2API 的金鑰加密後存入資料庫；執行中外掛會先驗證並應用新配置，資料庫寫入失敗時恢復舊配置。
- `config.test` 的結果由外掛 UI 自行展示（內聯或經 `ui.notify`），宿主不再對成功結果強制彈出提示，避免外掛把它當作輕量狀態輪詢時刷屏。
- `plugin.status` 是通用的**只讀**狀態通道：宿主經 `GET /admin/plugins/:id/status` 呼叫執行中外掛的 `Health`，返回 `{healthy, message, status_json}`。`status_json` 是外掛自定義的**不透明** JSON 快照（宿主不解析、不參與健康判定），外掛必須以無副作用方式生成（不得應用配置、訪問上游或觸發探測），因此該端點只讀、免二次驗證。外掛未執行時返回 `healthy=false` 且不含 `status_json`。這樣帶狀態面板的外掛無需濫用 `config.test` 即可展示即時狀態。

## 協議原始碼

- `v1/plugin.proto`：穩定的程序間訊息定義。
- `v1/runtime.go`：Go 外掛程序啟動入口和宿主客戶端宣告。
- `v1/manifest.schema.json`：`manifest.json` 的 JSON Schema。

外掛通過程序協議協作，不使用 Go 動態連結，也不要求外掛與 Sub2API 使用相同編譯器或共享記憶體 ABI。
