#!/bin/bash
# 繁體中文化配置檔
# 此檔案由 convert-to-traditional-chinese.sh 載入
#
# 詳細說明請參考：docs/i18n-traditional-chinese.md

# =============================================================================
# OpenCC 同步配置：source → target
# 格式：OPENCC_SYNC[index]="source|target"
# =============================================================================
OPENCC_SYNC=(
    "frontend/src/i18n/locales/zh-Hans.ts|frontend/src/i18n/locales/zh-Hant.ts"
    "README_CN.md|README_TW.md"
)

# =============================================================================
# 手動校正詞彙：pattern → replacement
# 格式：MANUAL_CORRECTIONS[index]="pattern|replacement"
# 說明：OpenCC 無法完美處理的詞彙，需要手動校正
# =============================================================================
MANUAL_CORRECTIONS=(
    "賬|帳"    # 台灣用語：帳號、帳戶、帳單
)

# =============================================================================
# 排除的目錄（不會遞迴處理）
# =============================================================================
EXCLUDE_DIRS=(
    "node_modules"
    ".git"
    "vendor"
    "dist"
    "build"
    ".cache"
    ".vscode"
    ".idea"
)

# =============================================================================
# 排除的檔案（不應轉換的配置檔）
# =============================================================================
EXCLUDE_FILES=(
    "config.yaml"
    "config.example.yaml"
    "docker-compose.yml"
    "docker-compose.yaml"
    "docker-compose-test.yml"
    ".goreleaser.yaml"
    ".goreleaser.simple.yaml"
    "release.yml"
    "HANDOFF.md"
)
