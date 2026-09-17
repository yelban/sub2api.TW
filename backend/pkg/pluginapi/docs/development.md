# 外掛開發指南

## 穩定邊界

當前宿主只支援 `openai.oauth.outbound_transport.v1`。外掛負責建立實際上游 HTTP/TLS 連線，Sub2API 負責帳號選擇、OAuth Token 生命週期、下游協議、響應解析、SSE、錯誤對映、用量統計和計費。

外掛不應修改 API Key 路徑，也不應自行重新整理或持久化 OAuth Token。

## 推薦結構

```text
plugin/
├── cmd/<plugin>/main.go
├── internal/config/
├── internal/transport/
├── ui/index.html
├── ui/assets/
├── tools/packager/
├── manifest.source.json
└── README.md
```

入口只呼叫 `pluginv1.Serve`。配置解析和傳輸實現放入獨立包，以便不啟動子程式就能單元測試。

## 執行時方法

| 方法 | 要求 |
|---|---|
| `GetInfo` | ID、版本、協議和能力必須與清單一致 |
| `Health` | 返回程式是否可以接受新請求，不執行昂貴探測 |
| `ValidateConfig` | 嚴格解析並返回完整規範化 JSON |
| `ApplyConfig` | 原子應用配置；失敗時保留舊配置 |
| `TestConfig` | 驗證當前環境和已儲存配置，返回簡短診斷 |
| `Forward` | 雙向流式傳輸請求與原始 HTTP 響應 |

請求幀順序：`start`、零到多個 `body_chunk`、`body_end`。響應幀順序：`start`、零到多個 `body_chunk`、`end`。不能繼續處理的錯誤使用 `error` 幀。

`request_sent` 必須如實表示請求是否可能已經到達上游。值為 `true` 時宿主禁止自動切換帳號重放；只有能確認尚未呼叫上游 Transport 時才能返回 `false`。

## 配置

- JSON 欄位統一使用 `snake_case`。
- 拒絕未知欄位、非法範圍和受保護請求頭。
- 預設配置必須完整，空物件應規範化為所有預設欄位。
- 儲存時由外掛先驗證和應用，再由宿主加密寫入資料庫。
- 資料庫寫入失敗時宿主會嘗試恢復舊配置，外掛必須允許重複應用。

## 資源管理

- 複用 HTTP Transport 和連線池，不要為每個請求建立新連線池。
- 配置切換後關閉舊空閒連線。
- 使用 stream context 取消 DNS、連線、上傳和響應讀取。
- 始終關閉上游響應體。
- 不在外掛內無限快取按帳號區分的客戶端。

## 最低測試集

- 配置預設值、未知欄位、邊界值和深複製。
- 外掛身份及協議版本。
- 請求體分塊、無請求體、固定 Content-Length。
- 響應狀態、重複請求頭、流式響應和響應讀取錯誤。
- 上下文取消、外掛退出和超時。
- 代理開啟與停用。
- 包雜湊、簽名、路徑穿越和目標平臺執行時。
- UI Bridge 載入、儲存、測試、錯誤和超時。

釋出前還應使用真實構建包執行宿主的外掛程式整合測試。
