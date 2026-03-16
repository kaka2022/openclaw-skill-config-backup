#!/bin/bash
# OpenClaw 配置文件备份脚本 v2.0
# 改进：记录完整路径、权限、属主信息

set -e

# 配置
BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)/configs"
MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE=$(date +%Y-%m-%d)
MAX_VERSIONS=7

# 备份日志数组，用于记录元数据
declare -a BACKUP_LOG=()

# 创建目录
mkdir -p "$BACKUP_DIR/$DATE"
mkdir -p "$MANIFEST_DIR"

# 默认备份的配置文件列表
DEFAULT_CONFIGS=(
    "/root/.openclaw/openclaw.json"
    "/root/.openclaw/exec-approvals.json"
    "/root/.config/clash/config.yaml"
)

# 显示帮助
show_help() {
    cat << EOF
OpenClaw 配置文件备份脚本 v2.0

用法:
    $0 [选项] [文件路径...]

选项:
    -h, --help              显示帮助
    -a, --all-openclaw     备份所有 OpenClaw 配置
    -s, --all-system       备份所有系统配置
    -m, --message MSG      备份说明信息
    -p, --push             自动推送到 GitHub
    --exclude-git           排除 .git 目录
    --exclude-swap          排除 vim swap 文件

示例:
    $0                              # 备份默认配置
    $0 /path/to/config.json        # 备份指定文件
    $0 -a -p                       # 备份所有并推送

EOF
}

# 检查是否为 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️  警告: 非 root 用户，某些文件可能无法读取"
    fi
}

# 备份单个文件（改进版：记录完整元数据）
backup_file() {
    local src="$1"
    
    # 获取绝对路径
    src=$(realpath "$src" 2>/dev/null || echo "$src")
    
    local filename=$(basename "$src")
    local dest="$BACKUP_DIR/$DATE/${TIMESTAMP}-${filename}"
    
    # 排除 vim swap 文件
    if [[ "$filename" =~ \.(swp|swo|swn)$ ]]; then
        echo "⏭️  跳过 swap 文件: $filename"
        return 0
    fi
    
    # 排除 .git 目录
    if [[ "$src" =~ /.git/ ]] || [[ "$filename" == ".git" ]]; then
        echo "⏭️  跳过 .git 目录: $filename"
        return 0
    fi
    
    if [ -f "$src" ]; then
        # 获取文件元数据
        local perm=$(stat -c "%a" "$src" 2>/dev/null || echo "644")
        local og=$(stat -c "%U:%G" "$src" 2>/dev/null || echo "root:root")
        local md5=$(md5sum "$src" 2>/dev/null | cut -d' ' -f1 || echo "")
        
        # 复制文件
        cp "$src" "$dest"
        
        # 记录到备份日志（格式: filename|path|perm|owner:group|md5）
        BACKUP_LOG+=("$filename|$src|$perm|$og|$md5")
        
        echo "✅ 已备份: $src"
        echo "   权限: $perm, 属主: $og, MD5: ${md5:0:8}..."
        return 0
    else
        echo "⚠️  文件不存在: $src"
        return 1
    fi
}

# 备份所有 OpenClaw 配置
backup_all_openclaw() {
    echo "📦 备份所有 OpenClaw 配置..."
    
    local openclaw_configs=(
        "/root/.openclaw/openclaw.json"
        "/root/.openclaw/exec-approvals.json"
        "/root/.openclaw/AGENTS.md"
        "/root/.openclaw/SOUL.md"
        "/root/.openclaw/USER.md"
        "/root/.openclaw/TOOLS.md"
        "/root/.openclaw/HEARTBEAT.md"
    )
    
    for config in "${openclaw_configs[@]}"; do
        backup_file "$config" || true
    done
}

# 生成清单（改进版：JSON 格式，包含完整元数据）
generate_manifest() {
    local message="${1:-自动备份}"
    local manifest="$MANIFEST_DIR/${TIMESTAMP}-backup.json"
    
    echo "📝 生成清单: $manifest"
    
    # 使用 jq 生成 JSON（如果可用）
    if command -v jq >/dev/null 2>&1; then
        # 构建 JSON
        local files_json="{}"
        for entry in "${BACKUP_LOG[@]}"; do
            local name=$(echo "$entry" | cut -d'|' -f1)
            local path=$(echo "$entry" | cut -d'|' -f2)
            local perm=$(echo "$entry" | cut -d'|' -f3)
            local og=$(echo "$entry" | cut -d'|' -f4)
            local md5=$(echo "$entry" | cut -d'|' -f5)
            
            files_json=$(echo "$files_json" | jq --arg name "$name" --arg path "$path" --arg perm "$perm" --arg og "$og" --arg md5 "$md5" \
                '.[$name] = {path: $path, perm: $perm, owner: $og, md5: $md5}')
        done
        
        # 生成完整 JSON
        echo "{" > "$manifest"
        echo "  \"version\": \"2.0\"," >> "$manifest"
        echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$manifest"
        echo "  \"date\": \"$DATE\"," >> "$manifest"
        echo "  \"message\": \"$message\"," >> "$manifest"
        echo "  \"hostname\": \"$(hostname)\"," >> "$manifest"
        echo "  \"user\": \"$(whoami)\"," >> "$manifest"
        echo "  \"files\": $files_json" >> "$manifest"
        echo "}" >> "$manifest"
    else
        # 回退到手动生成
        echo "{" > "$manifest"
        echo "  \"version\": \"2.0\"," >> "$manifest"
        echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$manifest"
        echo "  \"date\": \"$DATE\"," >> "$manifest"
        echo "  \"message\": \"$message\"," >> "$manifest"
        echo "  \"hostname\": \"$(hostname)\"," >> "$manifest"
        echo "  \"user\": \"$(whoami)\"," >> "$manifest"
        echo "  \"files\": {" >> "$manifest"
        
        local first=true
        for entry in "${BACKUP_LOG[@]}"; do
            local name=$(echo "$entry" | cut -d'|' -f1)
            local path=$(echo "$entry" | cut -d'|' -f2)
            local perm=$(echo "$entry" | cut -d'|' -f3)
            local og=$(echo "$entry" | cut -d'|' -f4)
            local md5=$(echo "$entry" | cut -d'|' -f5)
            
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$manifest"
            fi
            
            echo -n "    \"$name\": { \"path\": \"$path\", \"perm\": \"$perm\", \"owner\": \"$og\", \"md5\": \"$md5\" }" >> "$manifest"
        done
        
        echo "" >> "$manifest"
        echo "  }" >> "$manifest"
        echo "}" >> "$manifest"
    fi
    
    echo "✅ 清单已生成"
}

# 清理旧版本（保留最新的 MAX_VERSIONS 个）
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

# 推送到 GitHub
push_to_github() {
    echo "🚀 推送到 GitHub..."
    
    cd "$(dirname "$0")"
    
    if [ -d ".git" ]; then
        # 先清理旧版本
        cleanup_old_versions
        
        # 检查 git 配置
        if ! git config --get user.email >/dev/null 2>&1; then
            git config user.email "openclaw@localhost"
            git config user.name "OpenClaw Agent"
        fi
        
        git add -A
        git commit -m "backup: $TIMESTAMP - ${MESSAGE:-自动备份}" || echo "没有变更需要提交"
        git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "⚠️ 推送失败"
        echo "✅ 推送完成"
    else
        echo "⚠️  不是 git 仓库，跳过推送"
    fi
}

# 主逻辑
main() {
    local files=()
    local backup_all_openclaw=false
    local backup_all_system=false
    local auto_push=false
    MESSAGE=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all-openclaw)
                backup_all_openclaw=true
                shift
                ;;
            -s|--all-system)
                backup_all_system=true
                shift
                ;;
            -m|--message)
                MESSAGE="$2"
                shift 2
                ;;
            -p|--push)
                auto_push=true
                shift
                ;;
            -*)
                echo "❌ 未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    echo "🔧 OpenClaw 配置备份工具 v2.0"
    echo "=========================="
    echo "备份时间: $TIMESTAMP"
    echo ""
    
    # 执行备份
    if $backup_all_openclaw; then
        backup_all_openclaw
    elif $backup_all_system; then
        echo "⚠️ 系统配置备份功能待实现"
    elif [ ${#files[@]} -eq 0 ]; then
        # 默认备份
        echo "📦 备份默认配置..."
        for config in "${DEFAULT_CONFIGS[@]}"; do
            backup_file "$config" || true
        done
    else
        # 备份指定文件
        for file in "${files[@]}"; do
            backup_file "$file" || true
        done
    fi
    
    # 生成清单
    generate_manifest "$MESSAGE"
    
    # 推送
    if $auto_push; then
        push_to_github
    fi
    
    echo ""
    echo "✅ 备份完成!"
    echo "备份目录: $BACKUP_DIR/$DATE"
}

main "$@"
