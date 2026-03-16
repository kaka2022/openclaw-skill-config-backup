#!/bin/bash
# OpenClaw 配置文件恢复脚本 v2.0
# 改进：从 JSON 清单读取路径和权限，支持 diff 预览

set -e

# 配置
BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)/configs"
MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests"
MAX_VERSIONS=7

# 显示帮助
show_help() {
    cat << EOF
OpenClaw 配置文件恢复脚本 v2.0

用法:
    $0 [选项] [版本号]

选项:
    -h, --help              显示帮助
    -l, --list              列出所有备份版本
    -r, --restore VERSION   恢复到指定版本
    -f, --file FILE         只恢复指定文件
    -y, --yes               自动确认，不提示
    --dry-run               模拟恢复，不实际执行
    --diff                  显示 diff 预览
    --cleanup               清理旧版本

示例:
    $0 -l                              # 列出所有备份
    $0 -r 20260316-143022             # 恢复到指定版本
    $0 -r latest --diff               # 先 diff 再恢复
    $0 -r latest -f openclaw.json     # 只恢复指定文件

EOF
}

# 列出所有备份版本
list_versions() {
    echo "📋 备份版本列表 (最多保留 $MAX_VERSIONS 个版本):"
    echo "================================================"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ 备份目录不存在"
        return 1
    fi
    
    local count=0
    for manifest in $(ls -t "$MANIFEST_DIR"/*-backup.json 2>/dev/null); do
        if [ -f "$manifest" ]; then
            local version=$(basename "$manifest" -backup.json)
            local date=$(jq -r '.date' "$manifest" 2>/dev/null || echo "unknown")
            local message=$(jq -r '.message' "$manifest" 2>/dev/null || echo "no message")
            local files=$(jq -r '.files | length' "$manifest" 2>/dev/null || echo "0")
            
            count=$((count + 1))
            if [ $count -eq 1 ]; then
                echo "  ⭐ $version  [最新]  $date - $message ($files 个文件)"
            else
                echo "     $version  $date - $message ($files 个文件)"
            fi
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "⚠️  没有找到备份版本"
        return 1
    fi
    
    echo ""
    echo "共 $count 个版本"
}

# 获取最新版本
get_latest_version() {
    ls -t "$MANIFEST_DIR"/*-backup.json 2>/dev/null | head -1 | xargs basename | sed 's/-backup.json//'
}

# 获取版本目录
get_version_dir() {
    local version="$1"
    local date=$(echo "$version" | cut -d'-' -f1)
    date="${date:0:4}-${date:4:2}-${date:6:2}"
    echo "$BACKUP_DIR/$date"
}

# 显示 diff 预览
show_diff() {
    local current="$1"
    local backup="$2"
    local filename=$(basename "$current")
    
    echo ""
    echo "📊 Diff 预览: $filename"
    echo "========================================"
    
    if [ ! -f "$current" ]; then
        echo "⚠️  当前文件不存在，将创建新文件"
        return 0
    fi
    
    if command -v diff >/dev/null 2>&1; then
        diff -u "$current" "$backup" 2>/dev/null | head -50 || echo "   (文件差异较大，只显示前50行)"
    else
        echo "⚠️  diff 命令不可用，跳过预览"
    fi
    
    echo ""
}

# 应用权限
apply_permissions() {
    local dest="$1"
    local perm="$2"
    local og="$3"
    
    if [ -n "$perm" ]; then
        chmod "$perm" "$dest"
        echo "   ⚖️ 权限: $perm"
    fi
    
    if [ -n "$og" ] && [ "$og" != ":" ]; then
        chown "$og" "$dest" 2>/dev/null || echo "   ⚠️ 无法修改属主为 $og（可能需要 root）"
        echo "   👤 属主: $og"
    fi
}

# 恢复文件（改进版：从 JSON 读取路径和权限）
restore_file() {
    local manifest="$1"
    local filename="$2"
    local dry_run="$3"
    local show_diff_preview="$4"
    
    # 从 JSON 读取信息
    local src=$(jq -r ".files[\"$filename\"].path" "$manifest" 2>/dev/null || echo "")
    local perm=$(jq -r ".files[\"$filename\"].perm" "$manifest" 2>/dev/null || echo "")
    local og=$(jq -r ".files[\"$filename\"].owner" "$manifest" 2>/dev/null || echo "")
    
    if [ -z "$src" ] || [ "$src" = "null" ]; then
        echo "❌ 在清单中找不到文件: $filename"
        return 1
    fi
    
    local version=$(basename "$manifest" -backup.json)
    local version_dir=$(get_version_dir "$version")
    local backup_file="$version_dir/${version}-${filename}"
    
    if [ ! -f "$backup_file" ]; then
        echo "❌ 备份文件不存在: $backup_file"
        return 1
    fi
    
    # 显示 diff 预览
    if [ "$show_diff_preview" = "true" ] && [ -f "$src" ]; then
        show_diff "$src" "$backup_file"
    fi
    
    if [ "$dry_run" = "true" ]; then
        echo "[模拟] 将恢复: $backup_file -> $src"
        echo "       权限: $perm, 属主: $og"
        return 0
    fi
    
    # 创建目标目录
    mkdir -p "$(dirname "$src")"
    
    # 备份当前文件（如果存在）
    if [ -f "$src" ]; then
        local backup_suffix=".backup.$(date +%Y%m%d-%H%M%S)"
        cp "$src" "${src}${backup_suffix}"
        echo "📦 已备份当前文件: ${src}${backup_suffix}"
    fi
    
    # 恢复文件
    cp "$backup_file" "$src"
    echo "✅ 已恢复: $src"
    
    # 应用权限
    apply_permissions "$src" "$perm" "$og"
}

# 恢复版本（改进版：从 JSON 清单读取）
restore_version() {
    local version="$1"
    local specific_file="$2"
    local dry_run="$3"
    local auto_confirm="$4"
    local show_diff_preview="$5"
    
    # 处理 latest
    if [ "$version" = "latest" ]; then
        version=$(get_latest_version)
        if [ -z "$version" ]; then
            echo "❌ 没有找到最新版本"
            return 1
        fi
        echo "🔄 使用最新版本: $version"
    fi
    
    local manifest="$MANIFEST_DIR/${version}-backup.json"
    
    if [ ! -f "$manifest" ]; then
        echo "❌ 清单文件不存在: $manifest"
        return 1
    fi
    
    # 获取文件列表
    local files=()
    if [ -n "$specific_file" ]; then
        files+=("$specific_file")
    else
        # 从 JSON 获取所有文件
        while IFS= read -r file; do
            files+=("$file")
        done < <(jq -r '.files | keys[]' "$manifest" 2>/dev/null)
    fi
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "❌ 版本 $version 中没有找到文件"
        return 1
    fi
    
    # 显示恢复计划
    echo ""
    echo "📋 恢复计划:"
    echo "============="
    echo "版本: $version"
    echo "文件数: ${#files[@]}"
    echo ""
    
    for file in "${files[@]}"; do
        local path=$(jq -r ".files[\"$file\"].path" "$manifest" 2>/dev/null || echo "unknown")
        echo "📝 $file -> $path"
    done
    
    # 确认
    if [ "$auto_confirm" != "true" ] && [ "$dry_run" != "true" ]; then
        echo ""
        read -p "⚠️  确认恢复? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "❌ 已取消"
            return 1
        fi
    fi
    
    # 执行恢复
    echo ""
    echo "🔄 开始恢复..."
    echo "==============="
    
    for file in "${files[@]}"; do
        restore_file "$manifest" "$file" "$dry_run" "$show_diff_preview"
    done
    
    echo ""
    echo "✅ 恢复完成!"
    
    if [ "$dry_run" != "true" ]; then
        echo ""
        echo "💡 提示: 如果恢复后服务不正常，可能需要重启:"
        echo "   openclaw gateway restart"
        echo "   systemctl restart nginx"
        echo "   pkill clash && /root/clash/clash -d /root/.config/clash &"
    fi
}

# 清理旧版本
cleanup_old_versions() {
    echo "🧹 清理旧版本 (保留 $MAX_VERSIONS 个)..."
    
    local all_manifests=($(ls -t "$MANIFEST_DIR"/*-backup.json 2>/dev/null))
    local total=${#all_manifests[@]}
    
    if [ $total -le $MAX_VERSIONS ]; then
        echo "✅ 版本数量 ($total) 未超过限制，无需清理"
        return 0
    fi
    
    local to_delete=$((total - MAX_VERSIONS))
    echo "发现 $total 个版本，将删除 $to_delete 个旧版本"
    
    for ((i=MAX_VERSIONS; i<total; i++)); do
        local manifest="${all_manifests[$i]}"
        local version=$(basename "$manifest" -backup.json)
        local date=$(echo "$version" | cut -d'-' -f1)
        date="${date:0:4}-${date:4:2}-${date:6:2}"
        local version_dir="$BACKUP_DIR/$date"
        
        # 删除该版本的文件
        if [ -d "$version_dir" ]; then
            find "$version_dir" -name "${version}-*" -type f -delete 2>/dev/null || true
            
            # 如果目录为空，删除目录
            if [ -z "$(ls -A "$version_dir" 2>/dev/null)" ]; then
                rmdir "$version_dir" 2>/dev/null || true
            fi
        fi
        
        # 删除清单文件
        rm -f "$manifest"
        
        echo "  🗑️  已删除版本: $version"
    done
    
    echo "✅ 清理完成，保留 $MAX_VERSIONS 个最新版本"
}

# 主逻辑
main() {
    local version=""
    local specific_file=""
    local dry_run="false"
    local auto_confirm="false"
    local show_diff_preview="false"
    local action=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -r|--restore)
                action="restore"
                version="$2"
                shift 2
                ;;
            -f|--file)
                specific_file="$2"
                shift 2
                ;;
            -y|--yes)
                auto_confirm="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --diff)
                show_diff_preview="true"
                shift
                ;;
            --cleanup)
                action="cleanup"
                shift
                ;;
            -*)
                echo "❌ 未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$version" ]; then
                    version="$1"
                fi
                shift
                ;;
        esac
    done
    
    # 执行操作
    case "$action" in
        list)
            list_versions
            ;;
        restore)
            if [ -z "$version" ]; then
                echo "❌ 请指定版本号"
                show_help
                exit 1
            fi
            restore_version "$version" "$specific_file" "$dry_run" "$auto_confirm" "$show_diff_preview"
            ;;
        cleanup)
            cleanup_old_versions
            ;;
        *)
            if [ -n "$version" ]; then
                restore_version "$version" "$specific_file" "$dry_run" "$auto_confirm" "$show_diff_preview"
            else
                show_help
            fi
            ;;
    esac
}

main "$@"