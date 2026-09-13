# UI Bridge v1

## 載入方式

宿主為每次開啟配置頁建立短時 UI 會話：

```text
/api/v1/plugin-ui/<asset-token>/index.html#bridge_token=<bridge-token>
```

資源 Token 用於讀取包內 `ui/` 檔案，Bridge Token 只存在於 URL fragment，不會發送到伺服器。iframe 使用 `sandbox="allow-scripts"`，不授予 `allow-same-origin`。

UI 只能載入包內、已在清單宣告的資源。CSP 禁止外部網路連線、表單提交和外部 frame。

## 訊息信封

UI 到宿主：

```json
{
  "source": "sub2api-plugin-ui",
  "bridge_token": "TOKEN",
  "type": "config.load",
  "request_id": "UNIQUE_ID"
}
```

宿主到 UI：

```json
{
  "source": "sub2api-plugin-host",
  "bridge_token": "TOKEN",
  "request_id": "UNIQUE_ID",
  "ok": true
}
```

## 方法

| `type` | UI 引數 | 成功響應 |
|---|---|---|
| `sub2api.plugin.ready` | 無 | 無響應 |
| `config.load` | 無 | `config` |
| `config.save` | `config` 物件 | 規範化後的 `config` |
| `config.test` | 無 | `result` |
| `ui.resize` | `height` | 無響應 |
| `ui.notify` | `level`、`message` | 無響應 |

`config.test` 在 v1 中測試已儲存配置。UI 若要測試當前表單，應先呼叫 `config.save`。

## 必須執行的校驗

UI 接收訊息時必須驗證 `event.source === parent`、訊息來源標識、Bridge Token 和等待中的 `request_id`。每個請求必須有超時和解除安裝清理。

宿主不會向 iframe 提供管理員 Token。外掛 UI 不得嘗試訪問管理 API、Cookie、父頁面 DOM 或瀏覽器儲存中的宿主資料。
