# 普通模型列表擴充套件驗證（2026-09-05）

## 已實現

普通 `/v1/models` 與 `/models` 共用分組固定帳號配置。API Key 使用標準模型端點；OAuth/Agent Identity 繼續使用現有 Codex 上游認證鏈路。兩種目錄共享固定帳號篩選、併發、部分失敗處理和快取策略；固定帳號發現先於本地目錄，對映、分組過濾和 ETag 在快取之後應用。

普通列表保留上游未知模型、媒體模型及模型後設資料。有效空目錄/過濾為空不會觸發靜態預設或排程器回退。無可用帳號返回 503，上游失敗遵守回退配置；客戶端錯誤使用 OpenAI 錯誤信封。

## 自動驗證

- `GOCACHE=/tmp/sub2api-go-cache go test -tags=unit ./... -timeout=5m`：通過，55 個含測試的包成功。
- 最後補充響應格式快取隔離和冷快取 304 錯誤處理後，執行 `GOCACHE=/tmp/sub2api-go-cache go test -race -tags=unit -p 2 ./internal/service ./internal/handler ./internal/server/routes -run 'Test.*(OpenAIModels|CodexModels|OrdinaryPinned|PinnedModels|ProjectAccountModels)' -count=1 -timeout=3m`：三個包全部通過。
- 最終程式碼執行 `GOCACHE=/tmp/sub2api-go-cache GOLANGCI_LINT_CACHE=/tmp/sub2api-models-lint-cache golangci-lint run ./... --timeout=5m`：0 issues。
- 前端使用已安裝依賴執行 `./node_modules/.bin/vitest run src/components/admin/group/__tests__/CodexManifestAccountsField.spec.ts src/views/admin/__tests__/GroupsView.duplicate.spec.ts`：2 個檔案、10 個測試通過。
- `./node_modules/.bin/vue-tsc --noEmit`：通過。
- 兩個修改的 i18n 檔案 ESLint：通過。
- `openspec validate codex-manifest-pinned-accounts --strict`、`git diff --check`：通過。

迴歸覆蓋普通兩條路由（含空 client_version）、三個 Codex 入口、API Key/OAuth 混合帳號、影子帳號憑據解析、優先順序/臨時限流、停用/過期/非成員跳過、部分失敗/全部失敗/排程器回退、對映別名和通配規則、跨分組併發快取隔離、OAuth 跨入口快取複用、API Key 協議隔離、三段時效/單飛/ETag 續期、最終響應 304、空目錄、媒體別名不能繞過 Codex 專用過濾。

## 驗證邊界

測試使用本地模擬上游和倉儲，沒有訪問真實 OpenAI/ChatGPT 帳號或部署服務。原任務 6.4 的真實客戶端手動聯調仍未勾選；本次新增 7.1—7.6 已完成。
