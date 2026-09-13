## Why

OpenAI 分組在沒有帳號模型對映時，每次 Codex 客戶端請求 Model Manifest 都會經由排程器挑選一個帳號向上遊拉取。排程結果受優先順序、負載因子和限流視窗影響，而分組內帳號的模型許可權並不一致（例如部分帳號擁有 Trusted Access for Cyber 的特殊模型），導致同一個 API Key 前後看到的模型列表不確定。此外 OAuth 帳號的 manifest 拉取完全沒有快取，每次客戶端重新整理都直接打到 chatgpt.com。

## What Changes

- 為平臺為 OpenAI 的分組新增「使用特定帳號獲取 Codex Model Manifest」配置：一個預設關閉的開關、一個必須至少選擇一個帳號的多選帳號列表，以及「選定帳號全部不可用時回退排程器」的子選項（預設關閉，即返回 503）。
- 開關開啟後，該分組的 API Key 請求 Codex Model Manifest 時只使用選定帳號向上遊拉取，忽略優先順序、負載因子、限流與過載視窗；多個帳號併發請求，`models` 按 slug 取並集後返回。部分帳號失敗時以成功部分合並；全部失敗按配置返回 503 或回退到現有排程器路徑。
- 管理端分組編輯對話方塊的 OpenAI 區塊新增該配置的開關與帶搜尋的多選帳號下拉，帳號來源限定為當前分組內的 OpenAI 帳號。建立對話方塊不展示該配置（分組建立時尚無帳號繫結）。
- 分組複製時該配置重置為關閉。
- 普通 `/v1/models` 與 `/models`（無非空 `client_version`）複用同一固定帳號配置；API Key 請求標準上游模型列表，OAuth 從現有 Codex manifest 提取 ID，輸出 OpenAI 列表。
- **BREAKING**：固定帳號開啟時，普通列表和 Codex manifest 都優先進行指定帳號發現，隨後按來源帳號模型對映生成公開目錄並應用分組過濾；顯式模型對映不再短路固定帳號發現。
- **BREAKING**（行為層面）：Codex Model Manifest 快取統一為 1 分鐘新鮮（命中即返回，不請求上游）、1 到 5 分鐘樂觀返回快取並後臺重新整理、超過 5 分鐘同步等待上游重新整理後再返回。快取覆蓋範圍從僅 API Key 帳號擴充套件到 OAuth 帳號，固定帳號模式的每個帳號也走同一快取。

## Capabilities

### New Capabilities
- `codex-manifest-pinned-accounts`：OpenAI 分組的固定帳號 Manifest 配置（資料模型、管理端校驗與 UI）、執行時的固定帳號併發拉取與合併、不可用時的回退策略。
- `codex-manifest-cache`：Codex Model Manifest 的按帳號快取策略：新鮮期、樂觀期與強制重新整理期的行為，以及對所有帳號型別生效。

### Modified Capabilities
<!-- openspec/specs 目前為空，沒有既有能力需要修改。 -->

## Impact

- **資料庫**：`groups` 新增 JSONB 列 `codex_models_manifest_config`，新增遷移檔案；ent schema 與生成程式碼更新。
- **後端**：`Group` 領域模型、分組倉儲的建立與更新、API Key 載入分組的欄位投影、認證快照快取、管理端分組 DTO 與校驗、分組複製邏輯；`openai_codex_models_handler.go` 新增固定帳號分支；`openai_codex_models_service.go` 新增固定帳號併發拉取與合併、快取策略調整並擴充套件到 OAuth 路徑。
- **管理端 API**：`POST/PUT /admin/groups` 請求與響應新增 `codex_models_manifest_config` 欄位；`GET /admin/accounts` 已支援按分組過濾，無需改動。
- **前端**：`GroupsView.vue` 編輯對話方塊 OpenAI 區塊、`types/index.ts`、中英文 i18n。
- **上游影響**：固定帳號模式下每次快取失效會向 N 個帳號併發請求；快取新鮮期延長到 1 分鐘後，穩態上游請求量低於當前。
