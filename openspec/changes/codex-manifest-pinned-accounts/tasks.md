## 1. 資料模型與持久化

- [x] 1.1 在 `backend/internal/domain` 新增 `GroupCodexModelsManifestConfig{Enabled, AccountIDs, FallbackToScheduler}`，JSON 鍵為 `enabled`、`account_ids`、`fallback_to_scheduler`
- [x] 1.2 在 `backend/ent/schema/group.go` 新增 JSONB 欄位 `codex_models_manifest_config`（預設空結構體），執行 `go generate ./ent`
- [x] 1.3 新增遷移 `backend/migrations/234_group_codex_models_manifest_config.sql`（`ADD COLUMN IF NOT EXISTS ... JSONB NOT NULL DEFAULT '{}'::jsonb`）
- [x] 1.4 `service.Group` 新增 `CodexModelsManifestConfig` 欄位並新增類型別名；`group_repo.go` 建立與更新兩處 setter 寫入該欄位
- [x] 1.5 `api_key_repo.go`：分組欄位投影列表與 `groupEntityToService` 加入新欄位
- [x] 1.6 `api_key_auth_cache.go` 快照結構體與 `api_key_auth_cache_impl.go` 兩處對映加入新欄位
- [x] 1.7 `admin_group_duplicate.go` 複製分組時將該配置重置為關閉且帳號列表為空
- [x] 1.8 更新 API Key 分組投影對帳整合測試，覆蓋新欄位

## 2. 管理端配置介面與校驗

- [x] 2.1 新增 `backend/internal/service/group_codex_models_manifest.go`：`normalizeCodexModelsManifestConfig`（非 openai 平臺歸零、去重保序）與 `validateCodexModelsManifestConfig`（開啟時非空、≤10、全部為分組內 active 的 openai 帳號），錯誤碼 `INVALID_CODEX_MODELS_MANIFEST_CONFIG`
- [x] 2.2 `admin_service.go` 的 `CreateGroupInput`/`UpdateGroupInput` 與 `admin_group.go` 建立、更新路徑接入歸一化與校驗；建立路徑 `enabled=true` 返回 400
- [x] 2.3 `handler/admin/group_handler.go` 的建立與更新請求結構體、`dto/types.go` 響應結構體、`dto/mappers.go` 增加 `codex_models_manifest_config`
- [x] 2.4 在 `admin_service_group_test.go` 增加測試：開啟但空列表被拒、非成員或非 openai 帳號被拒、超過 10 個被拒、非 openai 平臺被歸零、重複 ID 去重保序、建立時開啟被拒

## 3. 快取策略統一

- [x] 3.1 將 `codexModelsManifestCacheTTL` 調整為 60 秒，保持 `codexModelsManifestCacheStaleTTL` 為 5 分鐘，將 `codexModelsManifestCacheMaxEntries` 提高到 512，並更新常量註釋說明三段時效與容量依據
- [x] 3.2 將 `fetchCachedAPIKeyCodexModelsManifest`/`refreshCachedAPIKeyCodexModelsManifest` 泛化為接受 `fetch` 閉包的 `fetchCachedCodexModelsManifest`/`refreshCachedCodexModelsManifest`
- [x] 3.3 `FetchCodexModelsManifest` 的 OAuth 分支改為經快取呼叫，閉包內保留 agent identity 任務恢復邏輯，錯誤時仍呼叫 `handleCodexModelsManifestAccountAuthError`
- [x] 3.4 在 `openai_codex_models_service_test.go` 增加或調整測試：OAuth 帳號新鮮期內零上游請求、樂觀期返回舊值且單飛後臺重新整理、超期後同步等待並寫回、超期上游失敗返回錯誤、令牌變化後快取未命中、If-None-Match 基於快取 ETag 返回 304、同一帳號被兩個分組同時請求時只發一次上游請求且各分組過濾互不影響
- [x] 3.5 檢查現有測試對 30 秒 TTL 或 OAuth 不快取的隱含假設並修正

## 4. 固定帳號模式執行時

- [x] 4.1 新增 `backend/internal/service/openai_codex_models_pinned.go`：`mergeCodexModelsManifestBodies` 純函式（第一個信封為基底、`models` 按 slug 並集且先出現者優先）
- [x] 4.2 同文件實現 `FetchPinnedCodexModelsManifest(ctx, group, clientVersion)`：`ListByGroup` 取成員、按配置順序篩選可用帳號（active、Schedulable、未過期；忽略限流與過載）、errgroup 併發拉取與補全、按下標收集結果、部分失敗記錄 `slog.Warn`、全部不可用返回 `ErrNoPinnedCodexModelsAccounts`、全部失敗返回最後一個錯誤、成功時設定合併體 ETag 並返回首個成功帳號
- [x] 4.3 `openai_codex_models_handler.go`：本地生成分支之後加入固定帳號分支，成功時 `setOpsSelectedAccount` 後呼叫 `MergeGroupConfiguredCodexModels` 並寫響應；按 `FallbackToScheduler` 決定回退排程器迴圈或返回 503 / 上游錯誤
- [x] 4.4 為合併函式編寫單元測試：並集與順序、重複 slug 取靠前帳號條目、信封欄位來源、無 slug 條目處理
- [x] 4.5 在 `openai_codex_models_handler_test.go` 增加測試：兩個帳號返回不同模型時客戶端收到並集且未呼叫排程器、限流帳號仍被使用、停用帳號被跳過、不在分組的 ID 被跳過、部分失敗仍 200、全部不可用時預設 503、開啟回退時走排程器、自定義模型列表過濾仍生效、ETag 匹配返回 304

## 5. 前端

- [x] 5.1 `frontend/src/types/index.ts` 新增 `CodexModelsManifestConfig` 型別，並加入 `AdminGroup`、建立與更新請求型別
- [x] 5.2 新增 `frontend/src/components/admin/group/CodexManifestAccountsField.vue`：開關、已選帳號標籤、帶防抖的搜尋下拉（`adminAPI.accounts.list` 按 `platform=openai` 與 `group` 過濾）、回退子開關
- [x] 5.3 `GroupsView.vue` 編輯對話方塊 OpenAI 區塊掛載元件；開啟編輯時解析已存帳號名稱（失敗顯示 `#<id>`）；提交時開關開啟且列表為空則提示並阻止；更新請求攜帶該欄位；建立請求固定傳送關閉狀態
- [x] 5.4 中英文 i18n（`overview.ts` 的 `admin.groups.codexModelsManifest.*`）：標題、開關文案、啟用與未啟用提示、帳號標籤、搜尋佔位、回退開關文案、至少選擇一個帳號的錯誤提示
- [x] 5.5 為新元件編寫 Vitest 測試：開關切換顯示、選擇與移除帳號、開啟後空列表觸發校驗

## 6. 驗證

- [x] 6.1 `cd backend && go test -tags=unit ./...` 與 `golangci-lint run ./...` 通過
- [x] 6.2 `cd backend && go test -tags=integration ./internal/repository/...` 通過（含投影對帳測試）
- [x] 6.3 `cd frontend && pnpm test` 與型別檢查通過
- [ ] 6.4 本地啟動後手動驗證：編輯 OpenAI 分組開啟固定帳號並選擇兩個許可權不同的帳號，Codex 客戶端拉取 manifest 得到並集；1 分鐘內重複請求不打上游

## 7. 普通模型列表擴充套件

- [x] 7.1 泛化模型響應/快取基礎，抽出原始上游傳輸和 API Key 標準請求構造，OAuth 複用現有認證與快取
- [x] 7.2 固定帳號篩選與併發獲取共用，新增普通模型目錄聚合及排程器回退
- [x] 7.3 實現來源帳號對映投影、分組最終過濾、空目錄與 ETag；Codex 固定帳號優先於本地生成
- [x] 7.4 普通 `/v1/models` 與 `/models` 接入固定帳號邏輯，中英文 UI 文案覆蓋兩個入口
- [x] 7.5 新增兩種上游、對映優先順序、失敗回退、跨分組及跨協議快取、三段時效和 ETag 迴歸測試
- [x] 7.6 完成受影響測試、race、unit/lint、前端型別與元件驗證及 OpenSpec 校驗，記錄驗證範圍
