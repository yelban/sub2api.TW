# `.s2plugin` 包格式

`.s2plugin` 是 ZIP 檔案，根目錄必須包含 `manifest.json`，生產包還必須包含 `signature.json`。

## 標準佈局

```text
manifest.json
signature.json
runtimes/<goos>-<goarch>/<binary>
ui/index.html
ui/assets/...
```

所有執行時和 UI 檔案必須出現在 `manifest.files`，值為小寫十六進位制 SHA-256。清單和簽名檔案自身不寫入 `files`。

包不允許絕對路徑、父目錄跳轉、重複路徑、符號連結、未宣告檔案或缺失檔案。宿主還限制上傳大小、解壓後大小和檔案數量。

## 清單

欄位規範見 [`v1/manifest.schema.json`](../v1/manifest.schema.json)。版本欄位含義：

- `version`：外掛自身語義化版本。
- `requires.sub2api`：宿主硬相容範圍。
- `recommended_sub2api_version`：建議宿主版本。
- `tested_sub2api_versions`：釋出者真實驗證過的版本。
- `plugin_protocol`：程式握手協議。
- `transport_api`：請求和響應幀協議。
- `ui_bridge`：配置 UI 訊息協議。

## 簽名

`signature.json`：

```json
{
  "algorithm": "ed25519",
  "key_id": "publisher-key-id",
  "signature": "BASE64_SIGNATURE"
}
```

簽名物件是 `manifest.json` 的精確原始位元組。釋出者私鑰不得進入外掛包、原始碼倉庫或 Sub2API 執行環境。部署者只配置 Base64 Ed25519 公鑰。

預設生產配置拒絕未簽名包。官方 OpenAI Transport 使用宿主內建公鑰驗籤，不需要配置；其他釋出者仍需配置 `trusted_publishers`。`allow_unsigned` 只用於開發者自己構建的本地包。
