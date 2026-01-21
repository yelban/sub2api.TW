# Fork 專案同步與開發工作流程指南

> 適用於：維護 fork 專案、開發自訂功能、同時保持與上游同步的場景

## 情境說明

當你 fork 一個開源專案並進行自訂開發時，會面臨以下挑戰：

```
上游倉庫 (upstream)          你的 fork (origin)
      │                            │
      ├── 持續更新 ──────────────► 需要同步
      │                            │
      └── bug fixes, new features  └── 你的自訂功能
```

**目標：** 既能開發自己的功能，又能隨時獲取上游的更新（bug fixes、新功能等）

---

## 初始設定

### 1. Fork 並 Clone

```bash
# 在 GitHub 上 fork 專案後
git clone git@github.com:YOUR_USERNAME/YOUR_FORK.git
cd YOUR_FORK
```

### 2. 設定 Upstream Remote

```bash
# 新增上游倉庫作為 remote
git remote add upstream https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git

# 驗證設定
git remote -v
# origin    git@github.com:YOUR_USERNAME/YOUR_FORK.git (fetch)
# origin    git@github.com:YOUR_USERNAME/YOUR_FORK.git (push)
# upstream  https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git (fetch)
# upstream  https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git (push)
```

---

## 同步策略比較

### 策略 A: Merge（合併）

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

| 優點 | 缺點 |
|------|------|
| ✅ 保留完整歷史記錄 | ❌ 產生 merge commit |
| ✅ 不需要 force push | ❌ 歷史線圖較複雜 |
| ✅ 衝突一次性處理 | |
| ✅ 適合團隊協作 | |

**適用場景：**
- Fork 已經 push 到遠端
- 有其他人在你的 fork 上協作
- 想保留清晰的「何時同步了上游」記錄
- **推薦作為預設策略**

---

### 策略 B: Rebase（變基）

```bash
git fetch upstream
git checkout main
git rebase upstream/main
git push origin main --force-with-lease
```

| 優點 | 缺點 |
|------|------|
| ✅ 線性歷史，乾淨整潔 | ❌ 需要 force push |
| ✅ 看起來像基於最新上游開發 | ❌ 可能影響協作者 |
| | ❌ 衝突需逐 commit 處理 |

**適用場景：**
- 個人專案，無其他協作者
- 尚未 push 到遠端的本地修改
- 準備向上游提交 PR 時

---

### 策略 C: Cherry-pick（挑選）

```bash
git fetch upstream
git log upstream/main --oneline  # 查看新 commits
git cherry-pick <commit-hash>    # 挑選需要的
```

| 優點 | 缺點 |
|------|------|
| ✅ 精確控制要合併的內容 | ❌ 需要手動挑選每個 commit |
| ✅ 避免不想要的變更 | ❌ 長期維護困難 |

**適用場景：**
- 只需要上游的特定 bug fix
- 上游大改版但只想要部分功能
- 上游有不相容的 breaking changes

---

### 策略 D: 分支隔離（進階）

維護獨立的功能分支，只在 main 上同步上游：

```bash
# main 分支專門用於同步上游
git checkout main
git fetch upstream
git reset --hard upstream/main
git push origin main --force-with-lease

# 自訂功能在獨立分支開發
git checkout -b my-features
# ... 開發 ...
git rebase main  # 定期 rebase 到最新的 main
```

| 優點 | 缺點 |
|------|------|
| ✅ main 永遠與上游一致 | ❌ 需要管理多個分支 |
| ✅ 功能分支清晰隔離 | ❌ rebase 可能頻繁產生衝突 |
| ✅ 容易向上游提交 PR | |

**適用場景：**
- 計畫向上游貢獻程式碼
- 多個獨立功能同時開發
- 需要清晰區分「上游程式碼」和「自訂程式碼」

---

## 實務建議

### 日常開發流程

```bash
# 1. 開始工作前，先同步上游
git fetch upstream

# 2. 查看上游有多少新更新
git log main..upstream/main --oneline

# 3. 如果有更新，合併它
git checkout main
git merge upstream/main

# 4. 推送到你的 fork
git push origin main

# 5. 繼續開發你的功能
```

### 處理衝突

當你的修改與上游衝突時：

```bash
# Merge 時遇到衝突
git merge upstream/main
# CONFLICT (content): Merge conflict in path/to/file

# 1. 查看衝突檔案
git status

# 2. 手動編輯解決衝突（找到 <<<<<<< ======= >>>>>>> 標記）

# 3. 標記為已解決
git add path/to/file

# 4. 完成合併
git commit
```

### 減少衝突的技巧

1. **頻繁同步**：定期（每週或每次開發前）同步上游，避免差異過大
2. **隔離修改**：盡量不修改上游的核心檔案，用擴展/覆蓋方式新增功能
3. **獨立配置**：使用 `.env`、`config.local.yaml` 等方式隔離本地配置
4. **文件隔離**：自訂文檔放在獨立目錄（如 `docs/local/`）

---

## 常用命令速查

```bash
# 查看 remote 設定
git remote -v

# 取得上游更新（不合併）
git fetch upstream

# 查看上游新增的 commits
git log main..upstream/main --oneline

# 查看上游變更的檔案
git diff main..upstream/main --stat

# 查看特定檔案的上游變更
git diff main..upstream/main -- path/to/file

# 合併上游（推薦）
git merge upstream/main

# 取消進行中的合併
git merge --abort

# 變基到上游（需 force push）
git rebase upstream/main

# 取消進行中的變基
git rebase --abort
```

---

## 本專案設定

```bash
# 上游倉庫
upstream: https://github.com/Wei-Shaw/sub2api.git

# 你的 fork
origin: git@github.com:yelban/twsub2api.git
```

### 同步命令

```bash
# 一次性設定 upstream（只需執行一次）
git remote add upstream https://github.com/Wei-Shaw/sub2api.git

# 日常同步
git fetch upstream
git merge upstream/main
git push origin main
```

---

## 同步後繁體中文化

本專案維護繁體中文翻譯，每次同步上游後需要重新執行中文化流程。

> **配置檔**：同步規則定義在 [.fork-sync.yaml](../.fork-sync.yaml)

### 快速流程

```bash
# 1. 同步上游
git fetch upstream
git merge upstream/main

# 2. 重新中文化（OpenCC + 手動校正）
# ⚠️ 手動校正規則定義在 .fork-sync.yaml 的 manual_corrections
opencc -i frontend/src/i18n/locales/zh-Hans.ts \
       -o frontend/src/i18n/locales/zh-Hant.ts \
       -c s2twp.json && \
sed -i '' 's/賬/帳/g' frontend/src/i18n/locales/zh-Hant.ts

# 3. 提交
git add frontend/src/i18n/locales/zh-Hant.ts
git commit -m "chore(i18n): update Traditional Chinese translations"
git push origin main
```

> **詳細說明**：參見 [i18n-traditional-chinese.md](./i18n-traditional-chinese.md)
