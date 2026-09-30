# Seedance 原生 API

支援火山方舟 Ark 的非同步影片任務協議，無需把 `content[]` 轉換成 OpenAI `messages` 或 Grok `prompt`。

## 配置

1. 建立 OpenAI 平臺的 **API Key** 帳號，填寫 Ark API Key，Base URL 使用 `https://ark.cn-beijing.volces.com/api/v3`。相容服務可填寫自己的 `/api/v3` 或 `/v3` Base URL。
2. 在帳號的端點能力中勾選 **Seedance (Ark)**。預設不啟用，避免請求誤排程到其他 OpenAI 帳號。支援建立、編輯與批次編輯。
3. 將帳號加入 OpenAI 分組並啟用分組的「允許圖片生成」媒體許可權；合成分組也可路由到這些帳號。
4. 配置模型對映，例如將公開模型名 `seedance-video` 對映到實際 `doubao-seedance-*` 模型或 `ep-*` 推理接入點。配置對應模型的輸出 token 價格；本介面不使用 Grok 的按秒影片價格。

## 呼叫

```bash
curl "$SUB2API_BASE_URL/api/v3/contents/generations/tasks" \
  -H "Authorization: Bearer $SUB2API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "seedance-video",
    "content": [{"type": "text", "text": "海浪輕輕拍打沙灘"}],
    "duration": 5,
    "resolution": "720p",
    "ratio": "16:9",
    "generate_audio": true
  }'

# 使用建立響應中的原生 id 查詢，直至 succeeded / failed / cancelled 等終態。
curl "$SUB2API_BASE_URL/api/v3/contents/generations/tasks/$TASK_ID" \
  -H "Authorization: Bearer $SUB2API_KEY"

curl -X DELETE "$SUB2API_BASE_URL/api/v3/contents/generations/tasks/$TASK_ID" \
  -H "Authorization: Bearer $SUB2API_KEY"
```

亦支援 `/v3`、`/v1` 和無版本字首別名。Ark SDK 的 Base URL 可改為 `$SUB2API_BASE_URL/api/v3`。文本、圖片、影片、音訊內容、角色及擴充套件引數原樣傳遞，僅按帳號配置改寫模型名；響應保持上游原生格式。

## 任務與計費

- 查詢和刪除只能訪問同一使用者、同一 API Key、同一分組建立的任務，並始終使用原提交帳號；不會轉到其他帳號查詢。
- 建立時不扣 token 用量。首次查詢到 `succeeded` 後，根據上游 `usage.completion_tokens` 計費；重複查詢由共享快取宣告和持久化用量去重共同保護。失敗、排隊及執行中的任務不計費。
- Redis 儲存任務繫結及建立時的模型快照，預設 24 小時。需保留 Redis 狀態並在有效期內查詢完成結果。當前不會後臺輪詢；只使用回撥而不查詢的任務不會自動結算。
- 不開放上游的任務列表介面，防止共享帳號的任務洩露給其他使用者。刪除遵循上游語義，不自動退款。
- 非同步建立的上游錯誤不自動重試，以免重複建立付費任務。

協議依據：[火山官方 Go SDK](https://github.com/volcengine/volcengine-go-sdk/blob/master/service/arkruntime/model/content_generation.go)、[建立任務文件](https://www.volcengine.com/docs/82379/1520757)、[查詢任務文件](https://www.volcengine.com/docs/82379/1521309)。
