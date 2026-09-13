# AICodex Prompt Audit 源基線

## 1. 基線狀態

本檔案記錄用於本 change 功能對照的源倉庫狀態。參考工作區仍可繼續變化，但本 change 已通過第 6 節登記的只讀 patch bundle 固定實施基線；後續實現只以該凍結包和本 change specs 為依據。

| 欄位 | 值 |
| --- | --- |
| 源倉庫 | `/Users/mt/code/mt-ai/aicodex/aicodex-api` |
| 採集時間 | `2026-07-16 20:21:19 CST (+0800)` |
| 分支 | `yjb` |
| HEAD | `7a50378851a80650cb0c086260b23abeb3469e6b` |
| 工作區 | dirty |
| 已跟蹤差異 | 38 files changed, 1306 insertions(+), 227 deletions(-) |
| 未跟蹤範圍 | Prompt Guard 實現/測試 6 個檔案，加 1 個 OpenSpec change 目錄 |
| 凍結狀態 | **已用只讀 patch bundle 凍結並在 detached worktree 恢復驗證** |

當前 HEAD 只代表已提交歷史，不能單獨代表要遷移的完整功能。同步 fail-closed Guard、出站安全校驗、WebSocket/路由順序測試以及相應 OpenSpec 當前存在於未提交或未跟蹤狀態。因此，本 change 的臨時功能參考是“上述 HEAD + 採集時磁碟工作區”，最終行為權威仍是本 change 的 specs。

## 2. 與遷移直接相關的已跟蹤修改

### 後端入口與啟動接線

- `ai-gateway/cmd/aicodex/main.go`
- `ai-gateway/internal/controller/prompt_audit.go`
- `ai-gateway/internal/router/relay-router.go`
- `ai-gateway/internal/router/video-router.go`
- `ai-gateway/internal/relay/ws_responses.go`
- `ai-gateway/internal/gatewayadapter/transport/anthropic.go`
- `ai-gateway/internal/gatewayadapter/transport/gemini.go`
- `ai-gateway/internal/gatewayadapter/transport/jimeng.go`
- `ai-gateway/internal/gatewayadapter/transport/kling.go`
- `ai-gateway/internal/gatewayadapter/transport/midjourney.go`
- `ai-gateway/internal/gatewayadapter/transport/openai.go`
- `ai-gateway/internal/gatewayadapter/transport/suno.go`
- `ai-gateway/internal/gatewayadapter/transport/task.go`

### Prompt Audit 核心

- `ai-gateway/internal/service/promptaudit/client.go`
- `ai-gateway/internal/service/promptaudit/config.go`
- `ai-gateway/internal/service/promptaudit/enqueue.go`
- `ai-gateway/internal/service/promptaudit/openai_client.go`
- `ai-gateway/internal/service/promptaudit/probe.go`
- `ai-gateway/internal/service/promptaudit/qwen3guard.go`
- `ai-gateway/internal/service/promptaudit/runtime.go`
- `ai-gateway/internal/service/promptaudit/runtime_coverage_test.go`
- `ai-gateway/internal/service/promptaudit/types.go`
- `ai-gateway/internal/service/promptaudit/worker.go`
- 同目錄的 config、diagnostics、probe 測試

### 協議、錯誤和迴歸測試

- `ai-gateway/internal/types/error.go`
- `ai-gateway/internal/gatewayadapter/transport/user_concurrency_order_test.go`

### 控制台和型別

- `webui/src/api/promptAudit.test.ts`
- `webui/src/features/prompt-audit/PromptAuditPage.tsx`
- `webui/src/features/prompt-audit/PromptAuditPage.test.tsx`
- `webui/src/features/prompt-audit/promptAuditViewModel.ts`
- `webui/src/features/prompt-audit/promptAuditViewModel.test.ts`
- `webui/src/types/promptAudit.ts`

### 執行說明

- `deploy/.env.example`
- `docs/constraints/41-ai-readable-logging.md`
- `docs/workflows/02-local-dev.md`

## 3. 必須納入凍結基線的未跟蹤檔案

以下檔案不在 HEAD 中，但屬於“完整功能必須要有”的關鍵證據：

- `ai-gateway/internal/gatewaycore/prompt_guard.go`
- `ai-gateway/internal/service/promptaudit/outbound_security.go`
- `ai-gateway/internal/service/promptaudit/synchronous_guard.go`
- `ai-gateway/internal/service/promptaudit/synchronous_guard_test.go`
- `ai-gateway/internal/relay/ws_responses_prompt_guard_order_test.go`
- `ai-gateway/internal/router/prompt_guard_order_test.go`
- `openspec/changes/add-prompt-audit-synchronous-blocking/`

不得只執行 `git diff HEAD` 後就聲稱已凍結，因為普通 diff 不包含這些未跟蹤檔案。

## 4. 功能對照優先順序

遇到源實現、源測試和本 change 描述不一致時，按以下順序決策：

1. 本 change 的三個 delta specs：目標行為契約。
2. 本 change 的 `design.md` 和 `implementation-guide.md`：目標架構與落地約束。
3. 凍結後的源測試及源 OpenSpec：功能完整性參考。
4. 凍結後的源實現：演算法、邊界和互動參考。
5. 當前已提交 HEAD：歷史參考。

目標專案不得複製源倉庫的 Ent、Caddy/gatewaycore、React 或全域性 option 依賴；只遷移可以被規格和測試證明的行為。

## 5. 實施前凍結步驟

在源倉庫所有者確認工作區內容屬於遷移基線後，選擇一種方式：

### 方案 A：專用 commit/tag（推薦）

1. 在源倉庫專用分支提交與 Prompt Audit/Guard 有關的已跟蹤和未跟蹤檔案。
2. 執行源模組及路由/WS 順序測試。
3. 建立不可移動 tag，或記錄完整 commit SHA。
4. 把最終標識和測試結果回寫本檔案。

### 方案 B：只讀 patch 包

1. 生成 tracked diff。
2. 使用能夠包含未跟蹤檔案的歸檔或補丁流程補齊第 3 節檔案。
3. 生成檔案清單和 SHA-256；在乾淨臨時目錄中恢復並執行測試。
4. 把 patch 路徑、清單路徑和校驗和回寫本檔案。

禁止把包含真實 API Key、Redis payload、`.env` 私密值或執行日誌中的完整 Prompt 放入基線包。

## 6. 最終凍結登記

| 欄位 | 待填寫值 |
| --- | --- |
| 凍結方式 | 只讀 tracked patch + untracked tar archive |
| 凍結 commit/tag | base commit `7a50378851a80650cb0c086260b23abeb3469e6b`（detached restore） |
| patch/archive 絕對路徑 | `/Users/mt/code/mt-ai/sub2api/sub2api-mt/openspec/changes/add-openai-compatible-prompt-audit/source-freeze/` |
| manifest SHA-256 | `badab312bf6af4d2c77857a9400381f4da4fbf45722d9f4a6df23bc7005273b6` |
| tracked patch SHA-256 | `f751a13cce3f3a73cd60cae3aececcef6e1e76dcec8c551a7a4747f032234d2b` |
| untracked archive SHA-256 | `1536e2781703b7620e26f2d08b249431fa5846ad9e32b2e8b0d547c3fa3b3632` |
| 凍結人/複核人 | Codex；由恢復後的檔案清單、`git diff --check` 和測試命令複核 |
| 凍結時間 | `2026-07-16 20:21:19 CST (+0800)` |
| 源測試結果 | 恢復副本中 Prompt Audit 核心、router、relay、gateway transport 目標測試全部通過，詳見 `source-freeze/MANIFEST.md` |

## 7. 複核命令

```bash
cd /Users/mt/code/mt-ai/aicodex/aicodex-api
git branch --show-current
git rev-parse HEAD
git status --short
git diff --stat
git diff --name-only
git ls-files --others --exclude-standard
cd ai-gateway
go test ./internal/service/promptaudit
```

本提案編寫時上述模組測試已在當前 dirty 磁碟狀態通過；凍結後必須再次執行，並記錄最終 commit/patch 校驗和、執行目錄和完整輸出。
