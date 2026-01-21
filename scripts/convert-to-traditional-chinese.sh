#!/bin/bash
# 繁體中文化腳本
# 使用 OpenCC s2twp + 手動校正，批次轉換 i18n 翻譯檔、.md、.yaml 檔案
#
# 用法：
#   ./scripts/convert-to-traditional-chinese.sh [選項] [目錄]
#
# 選項：
#   -n, --dry-run    只顯示會處理的檔案，不實際轉換
#   -v, --verbose    顯示詳細輸出
#   -h, --help       顯示說明
#
# 範例：
#   ./scripts/convert-to-traditional-chinese.sh                 # 處理整個專案
#   ./scripts/convert-to-traditional-chinese.sh docs/           # 只處理 docs 目錄
#   ./scripts/convert-to-traditional-chinese.sh -n              # Dry run 模式

set -euo pipefail

# 取得腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/convert-config.sh"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 預設值
DRY_RUN=false
VERBOSE=false
TARGET_DIR="."

# 預設配置（如果配置檔不存在）
OPENCC_SYNC=()
MANUAL_CORRECTIONS=("賬|帳")
EXCLUDE_DIRS=("node_modules" ".git" "vendor" "dist" "build" ".cache" ".vscode" ".idea")
EXCLUDE_FILES=("config.yaml" "config.example.yaml" "docker-compose.yml" "docker-compose.yaml" "HANDOFF.md")

# 載入配置檔
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=convert-config.sh
        source "$CONFIG_FILE"
        log_verbose "已載入配置檔：$CONFIG_FILE"
    else
        log_warning "找不到配置檔：$CONFIG_FILE，使用預設值"
    fi
}

# 顯示說明
show_help() {
    cat << EOF
繁體中文化腳本 - 使用 OpenCC s2twp + 手動校正

用法：
    $(basename "$0") [選項] [目錄]

選項：
    -n, --dry-run    只顯示會處理的檔案，不實際轉換
    -v, --verbose    顯示詳細輸出
    -h, --help       顯示此說明

範例：
    $(basename "$0")                    # 處理整個專案
    $(basename "$0") docs/              # 只處理 docs 目錄
    $(basename "$0") -n                 # Dry run 模式
    $(basename "$0") -v frontend/       # 詳細模式處理 frontend 目錄

處理範圍：
    1. opencc_sync：從配置檔讀取 source → target 配置
    2. 文件檔案：遞迴處理 .md, .yaml, .yml

配置檔：
    ${CONFIG_FILE}
    - OPENCC_SYNC: 指定的 source → target 轉換
    - MANUAL_CORRECTIONS: 手動校正詞彙
    - EXCLUDE_DIRS: 排除的目錄
    - EXCLUDE_FILES: 排除的檔案

注意：
    - 需要安裝 opencc（brew install opencc）
    - 會跳過 node_modules、.git 等目錄
EOF
}

# 記錄函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 檢查依賴
check_dependencies() {
    if ! command -v opencc &> /dev/null; then
        log_error "opencc 未安裝。請執行：brew install opencc"
        exit 1
    fi
    log_verbose "opencc 版本：$(opencc --version 2>&1 | head -1)"
}

# 套用手動校正
apply_manual_corrections() {
    local file="$1"
    for correction in "${MANUAL_CORRECTIONS[@]}"; do
        local pattern="${correction%%|*}"
        local replacement="${correction##*|}"
        [[ -z "$pattern" ]] && continue
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/${pattern}/${replacement}/g" "$file"
        else
            sed -i "s/${pattern}/${replacement}/g" "$file"
        fi
    done
}

# 處理 opencc_sync 配置
process_opencc_sync() {
    if [[ ${#OPENCC_SYNC[@]} -eq 0 ]]; then
        log_verbose "沒有 opencc_sync 配置"
        return
    fi

    log_info "=== opencc_sync（從配置檔）==="

    for item in "${OPENCC_SYNC[@]}"; do
        local source="${item%%|*}"
        local target="${item##*|}"

        if [[ -f "$source" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "會轉換：$source → $target"
            else
                if opencc -i "$source" -o "$target" -c s2twp.json 2>/dev/null; then
                    apply_manual_corrections "$target"
                    log_success "已轉換：$source → $target"
                else
                    log_error "轉換失敗：$source"
                fi
            fi
        else
            log_verbose "來源檔案不存在：$source"
        fi
    done
}

# 建立排除參數
build_exclude_args() {
    local args=""
    for dir in "${EXCLUDE_DIRS[@]}"; do
        args="$args -not -path '*/$dir/*'"
    done
    echo "$args"
}

# 檢查檔案是否包含簡體中文
contains_simplified_chinese() {
    local file="$1"
    # 檢查常見簡體字
    if grep -qE '(简体|数据|软件|视频|账号|应用|网络|环境|运行|配置|服务|创建|发送|设置|实现|优化|错误|调试|测试|开发|项目|组件|处理|验证|检查)' "$file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 檢查檔案是否在排除清單中
is_excluded_file() {
    local file="$1"
    local basename
    basename=$(basename "$file")

    for excluded in "${EXCLUDE_FILES[@]}"; do
        if [[ "$basename" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# 轉換單一檔案
convert_file() {
    local file="$1"
    local temp_file="${file}.opencc.tmp"

    log_verbose "處理：$file"

    # 檢查是否在排除清單
    if is_excluded_file "$file"; then
        log_verbose "  跳過（排除清單）：$file"
        return 2  # 返回 2 表示跳過
    fi

    # 檢查是否包含簡體中文
    if ! contains_simplified_chinese "$file"; then
        log_verbose "  跳過（無簡體中文）：$file"
        return 2
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "會轉換：$file"
        return 0
    fi

    # OpenCC 轉換
    if opencc -i "$file" -o "$temp_file" -c s2twp.json 2>/dev/null; then
        mv "$temp_file" "$file"

        # 套用手動校正
        apply_manual_corrections "$file"

        log_success "已轉換：$file"
        return 0
    else
        log_error "轉換失敗：$file"
        rm -f "$temp_file"
        return 1
    fi
}

# 主函數
main() {
    # 解析參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知選項：$1"
                show_help
                exit 1
                ;;
            *)
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done

    # 載入配置
    load_config

    # 檢查目標目錄
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "目錄不存在：$TARGET_DIR"
        exit 1
    fi

    # 檢查依賴
    check_dependencies

    log_info "開始繁體中文化..."
    log_info "目標目錄：$TARGET_DIR"
    [[ "$DRY_RUN" == true ]] && log_warning "Dry run 模式 - 不會實際修改檔案"

    # === 處理配置檔中定義的 opencc_sync ===
    process_opencc_sync

    # === 處理 .md 和 .yaml 檔案 ===
    log_info "=== 文件檔案（.md, .yaml）==="

    # 建立排除參數
    local exclude_args
    exclude_args=$(build_exclude_args)

    # 找出所有 .md 和 .yaml/.yml 檔案
    local files
    files=$(eval "find '$TARGET_DIR' -type f \\( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \\) $exclude_args" 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        log_warning "找不到任何 .md 或 .yaml 檔案"
        exit 0
    fi

    # 統計
    local total=0
    local converted=0
    local skipped=0
    local failed=0

    # 處理每個檔案
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((total++))

        # 暫時關閉 errexit 以捕獲返回值
        set +e
        convert_file "$file"
        local result=$?
        set -e

        case $result in
            0)  # 成功轉換
                ((converted++))
                ;;
            2)  # 跳過
                ((skipped++))
                ;;
            *)  # 失敗
                ((failed++))
                ;;
        esac
    done <<< "$files"

    # 顯示統計
    echo ""
    log_info "=== 統計 ==="
    log_info "總共掃描：$total 個檔案"
    if [[ "$DRY_RUN" == true ]]; then
        log_info "會轉換：$converted 個檔案"
    else
        log_success "已轉換：$converted 個檔案"
        log_info "已跳過：$skipped 個檔案（無簡體中文）"
        [[ $failed -gt 0 ]] && log_error "失敗：$failed 個檔案"
    fi
}

# 執行主函數
main "$@"
