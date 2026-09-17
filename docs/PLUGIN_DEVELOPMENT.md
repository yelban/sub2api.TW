# Sub2API 外掛開發教程

本文面向希望為 Sub2API 開發、打包和釋出外掛的團隊。外掛是獨立程式和靜態 UI 組成的 `.s2plugin` 包，宿主通過穩定的 gRPC 協議呼叫它。本文以當前宿主已經定義的 `openai.oauth.outbound_transport.v1` 能力作為協議示例，說明開發者需要準備什麼、哪些職責屬於外掛、哪些職責仍由 Sub2API 負責。

本文不是一個可直接安裝的完整外掛，也不代表 Sub2API 已經發布對應的官方外掛包。當前檔案主要描述公開協議、宿主邊界和開發流程。後續是否釋出可安裝包、支援哪些 Provider，以及如何提供示例倉庫，都需要另行公告。

## 1. 準備開發環境

建議使用以下環境：

- Go 1.21 或更高版本；
- Node.js（僅在外掛 UI 使用 JavaScript 時需要）；
- Git；
- 與目標部署環境一致的構建工具鏈。

協議定義和通用說明位於：

- `backend/pkg/pluginapi/v1/plugin.proto`：程式間訊息和流式請求定義；
- `backend/pkg/pluginapi/v1/runtime.go`：外掛程式啟動入口；
- `backend/pkg/pluginapi/v1/manifest.schema.json`：包清單 JSON Schema；
- `backend/pkg/pluginapi/docs/`：開發、UI Bridge、包格式和安全邊界說明。

目前暫未提供可直接複製的官方示例原始碼。開發者可以按照本文的目錄和協議說明建立自己的外掛工程；示例倉庫釋出後，會在本文補充正式的獲取地址、目錄說明和版本要求。公開協議始終以 `backend/pkg/pluginapi/` 為準。

## 2. 建立外掛工程

在示例倉庫釋出前，可以先建立一個獨立的 Go 工程，目錄建議如下：

```text
my-plugin/
├── cmd/<plugin>/main.go
├── internal/pluginconfig/
├── internal/transport/
├── ui/index.html
├── ui/assets/
├── tools/
├── manifest.source.json
└── build.sh
```

開發時至少準備以下部分：

1. `manifest.source.json`：外掛 ID、名稱、版本、作者、能力和相容的 Sub2API 版本；
2. `cmd/<plugin>/main.go`：啟動入口和執行時版本注入，並同步打包器中的構建目標和二進位制名稱；
3. `internal/pluginconfig/`：配置結構、預設值、嚴格校驗和規範化；
4. `internal/transport/`：HTTP 客戶端、代理、請求頭、請求體、網路連線引數、響應流和資源回收；
5. `ui/index.html` 與 `ui/assets/`：外掛自己的配置介面；
6. 單元測試、程式整合測試和目標平臺構建配置。

入口檔案應保持很小，只負責呼叫 `pluginv1.Serve`。實際邏輯放在可獨立測試的包中，避免把配置解析、網路請求和協議組裝全部寫在 `main.go`。

## 3. 編寫執行時

執行時實現 `TransportPlugin` 服務，必須滿足以下約定：

| 方法 | 要求 |
| --- | --- |
| `GetInfo` | 返回的外掛 ID、版本、協議版本、傳輸 API 版本和能力必須與清單一致。 |
| `Health` | 快速返回程式是否可以接收新請求，不執行長時間網路探測。 |
| `ValidateConfig` | 嚴格解析 JSON，拒絕未知欄位和非法範圍，並返回完整的規範化配置。 |
| `ApplyConfig` | 成功後原子切換配置；失敗時保留舊配置和舊連線。 |
| `TestConfig` | 針對已儲存配置進行快速診斷，返回簡短、可展示的結果。 |
| `Forward` | 按協議接收請求流，發出上遊請求，再按順序返回響應流。 |

請求幀順序為 `start`、零到多個 `body_chunk`、`body_end`；響應幀順序為 `start`、零到多個 `body_chunk`、`end`。不能繼續處理時傳送 `error` 幀。

`ForwardResponseError.request_sent` 必須準確：只有在能夠確認尚未呼叫上游 HTTP Transport 時才返回 `false`；一旦已經呼叫，或無法確認上游是否收到請求，就返回 `true`。宿主會據此決定是否允許切換帳號重試，避免重複執行同一個請求。

資源管理也屬於執行時契約：複用 HTTP Transport 和連線池，配置切換時關閉舊空閒連線，沿用 gRPC stream 的 context 取消 DNS、連線、上傳和響應讀取，並始終關閉上游響應體。日誌和錯誤訊息不能包含 Token、代理憑據、完整請求體或敏感響應頭。

## 4. 設計外掛配置

外掛配置由外掛定義，由 Sub2API 加密儲存。推薦流程是：

1. 在 `internal/pluginconfig.Config` 中定義欄位和預設值；
2. 使用 `json.Decoder.DisallowUnknownFields` 等嚴格方式解析；
3. 將空物件規範化為完整預設配置；
4. 在 `ValidateConfig` 和 `ApplyConfig` 中複用同一套校驗；
5. 配置應用成功後再讓宿主儲存，儲存失敗時允許恢復舊配置。

JSON 欄位統一使用 `snake_case`。敏感配置不要放入 URL、UI 通知、診斷結果或日誌。外掛不應從 UI 讀取、重新整理或持久化 OAuth Token；宿主只在執行時呼叫需要的網路轉發介面。

## 5. 實現外掛自己的配置 UI

UI 是外掛包內的靜態頁面，不需要修改 Sub2API 前端原始碼。宿主會在受限 iframe 中載入 `ui/index.html`，並通過 UI Bridge 提供配置讀寫和測試能力。

頁面初始化流程：

1. 載入包內 HTML、CSS 和 JavaScript；
2. 建立 Bridge 並註冊 `message` 監聽；
3. 傳送 `sub2api.plugin.ready`；
4. 呼叫 `config.load` 渲染表單；
5. 編輯後呼叫 `config.save`；
6. 測試前先儲存，再呼叫 `config.test`；
7. 頁面解除安裝時呼叫 `dispose()`。

當前 Bridge 支援：

| 訊息 | 用途 |
| --- | --- |
| `config.load` | 讀取當前配置。 |
| `config.save` | 提交配置，由執行時校驗、應用並加密儲存。 |
| `config.test` | 執行已儲存配置的診斷。 |
| `ui.resize` | 調整配置 iframe 高度。 |
| `ui.notify` | 顯示成功、錯誤或提示訊息。 |

每條訊息都必須帶 `request_id`，並校驗 `event.source`、訊息來源標識和 Bridge Token。不要依賴 CDN、遠端指令碼、Cookie 或本地儲存。頁面需要相容窄屏和明暗主題，並正確處理載入、儲存、測試、超時和未儲存狀態。

詳細信封格式見 `backend/pkg/pluginapi/docs/ui-bridge.md`。如果後續示例倉庫提供可複用的 Bridge SDK，本文會在示例倉庫章節補充對應路徑和使用方式。

## 6. 編寫包清單

只維護 `manifest.source.json`，不要手工編輯構建目錄中的 `manifest.json`。至少需要填寫：

```json
{
  "schema_version": 1,
  "id": "example.openai.transport",
  "name": "Example OpenAI Transport",
  "version": "0.1.0",
  "requires": {
    "sub2api": ">=0.1.179 <0.2.0",
    "recommended_sub2api_version": "0.1.179",
    "tested_sub2api_versions": ["0.1.179"],
    "plugin_protocol": 1,
    "transport_api": 1,
    "ui_bridge": 1
  },
  "capabilities": [
    {
      "id": "openai.oauth.outbound_transport.v1",
      "platform": "openai",
      "account_type": "oauth"
    }
  ],
  "runtimes": {},
  "ui": { "entrypoint": "ui/index.html" },
  "files": {}
}
```

打包器會自動填充目標平臺執行時、UI 和執行時檔案的 SHA-256。清單中的 `requires.sub2api` 是硬相容範圍；`tested_sub2api_versions` 應只填寫真實驗證過的版本；`recommended_sub2api_version` 用於管理頁面展示。當前宿主僅處理 `openai.oauth.outbound_transport.v1`，宣告其他能力不會自動產生新路由。後續增加 Provider 支援時，會在協議、能力清單和宿主路由完成適配後，再補充對應的清單示例。

## 7. 生成金鑰並簽名

生產包應始終簽名，宿主預設拒絕未簽名包。可以使用外掛工程中的金鑰生成工具生成一對 Ed25519 金鑰；示例倉庫釋出後會提供標準工具和完整命令：

```bash
go run ./tools/keygen -out build/keys/my-publisher
```

生成的 `my-publisher.private` 只儲存在受控的開發機或 CI Secret 中，不能提交到原始碼倉庫、外掛包或部署伺服器。公鑰是 Base64 文本，可以提供給部署者。

外掛工程的 `build.sh` 應呼叫標準打包器。自定義釋出者金鑰時必須同時提供 `-signing-key` 和 `-key-id`：

```bash
./build.sh \
  -signing-key /安全目錄/my-publisher.private \
  -key-id my-publisher-v1 \
  -output dist/my-openai-plugin.s2plugin
```

簽名覆蓋最終 `manifest.json` 的精確位元組；清單中的檔案雜湊再覆蓋執行時和 UI 檔案。簽名完成後不要重新格式化 `manifest.json`。

部署者在 Sub2API 配置檔案中追加公鑰：

```yaml
plugins:
  allow_unsigned: false
  trusted_publishers:
    my-publisher-v1: "BASE64_ED25519_PUBLIC_KEY"
```

`trusted_publishers` 是在宿主內建官方公鑰之外追加的信任來源，不能覆蓋內建公鑰。`signature.json` 中的 `key_id` 必須與配置鍵完全一致。金鑰輪換時先發布包含新公鑰的宿主配置或版本，再發布新簽名包，最後再停用舊金鑰。

開發階段如需使用未簽名包，只應在隔離的本地環境臨時設定 `plugins.allow_unsigned: true`，測試完成後立即恢復為 `false`。

## 8. 構建、測試和安裝

在外掛目錄執行：

```bash
go test ./... -count=1
node --check ui/assets/bridge-v1.js
node --check ui/assets/app.js
./build.sh
unzip -t dist/*.s2plugin
```

回到 Sub2API 倉庫根目錄後，再使用真實構建包執行宿主整合測試：

```bash
cd ../..
SUB2API_TEST_PLUGIN_PACKAGE=plugins/my-openai-plugin/dist/my-openai-plugin.s2plugin \
  go test ./backend/internal/service -run '^TestPluginRuntimeIntegration$' -count=1
```

最低測試集應覆蓋配置預設值和邊界值、外掛身份、請求和響應分塊、流式響應、上下文取消、外掛退出、代理開關、包雜湊、簽名、路徑安全、目標平臺執行時以及 UI Bridge 的載入、儲存、測試、錯誤和超時。

安裝後先保持停用，確認清單相容性、簽名和診斷結果，再按帳號灰度啟用。API Key 帳號和未命中灰度的 OAuth 帳號繼續走 Sub2API 原有路徑。

## 9. 釋出前檢查清單

- 外掛版本與 `GetInfo` 返回值一致；
- `requires.sub2api` 覆蓋範圍經過驗證，沒有未經測試的破壞性版本；
- `tested_sub2api_versions` 與實際測試記錄一致；
- 每個支援的平臺和架構都有執行時檔案；
- 生產包存在有效 `signature.json`，公鑰已交付部署者；
- 包中沒有私鑰、源對映、測試資料、日誌和臨時檔案；
- UI 不依賴外部資源，也不儲存宿主會話資訊；
- 配置切換、請求取消、響應關閉和錯誤重試語義經過測試；
- 釋出說明包含升級、停用、回滾和相容版本資訊。

## 10. 常見問題

| 現象 | 排查方向 |
| --- | --- |
| 安裝提示簽名不受信任 | 檢查 `signature.json.key_id`、Base64 公鑰和配置鍵是否完全一致。 |
| 外掛顯示不相容 | 檢查 `requires.sub2api`、`plugin_protocol`、`transport_api` 和 `ui_bridge`。 |
| 外掛程式無法啟動 | 檢查目標系統和架構對應的執行時路徑、可執行許可權和執行使用者許可權。 |
| 配置頁無法載入 | 檢查 `ui.entrypoint`、UI 檔案雜湊、Bridge Token 校驗和 iframe 訊息來源。 |
| 儲存後配置未生效 | 檢視 `ValidateConfig`、`ApplyConfig` 返回的規範化配置和診斷資訊。 |
| 請求失敗後重復執行 | 檢查 `ForwardResponseError.request_sent` 是否準確反映請求是否可能已發出。 |

## 11. 需要擴充套件能力時

如果新外掛需要支援其他 Provider、其他帳號型別或新的訊息欄位，應先擴充套件並版本化公開協議，再由宿主增加能力匹配和生命週期處理。不要僅通過清單宣告一個宿主尚未實現的能力。這樣可以讓舊外掛繼續執行，也能讓新宿主明確拒絕不相容的外掛。

Sub2API 後續會持續補充更多 Provider 的外掛適配說明，包括能力標識、請求和響應契約、配置欄位、UI Bridge 使用方式、版本相容要求以及測試清單。本文會隨著這些能力的落地繼續更新，Provider 專屬章節會放在本節之後。

## 12. 示例倉庫預留

後續計劃提供獨立的外掛示例倉庫，用於存放可複用的執行時骨架、UI 元件、打包工具和各 Provider 的最小實現。目前示例倉庫尚未準備完成，因此暫不提供地址；正式釋出後會在這裡補充倉庫地址、適用的 Sub2API 版本、示例外掛版本和構建說明。
