#!/bin/bash
# Config Backup Skill - 主入口脚本 v2.0
# 改进：引导用户配置自己的 GitHub Token 和仓库

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_REPO="${BACKUP_REPO:-$HOME/.config-backup}"
CONFIG_FILE="$HOME/.config-backup/config"

# 显示帮助
show_help() {
    cat << EOF
Config Backup Skill - 配置文件备份与恢复

用法:
    config-backup <命令> [选项]

命令:
    setup           首次配置（引导设置 Token 和仓库）
    backup          备份配置文件
    restore         恢复配置文件
    list            列出所有备份版本
    cleanup         清理旧版本
    init            初始化备份仓库
    config          查看/修改配置

示例:
    config-backup setup               # 首次使用，配置 Token 和仓库
    config-backup backup /path/to/config
    config-backup restore latest
    config-backup list

详细帮助:
    config-backup backup --help
    config-backup restore --help
EOF
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# 保存配置
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# Config Backup Skill 配置文件
# 生成时间: $(date)

# GitHub 个人访问令牌
# 获取方式: https://github.com/settings/tokens
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# 备份仓库地址（使用自己的仓库）
# 格式: https://github.com/用户名/仓库名
BACKUP_REPO_URL="${BACKUP_REPO_URL:-}"

# 备份目录
BACKUP_DIR="${BACKUP_DIR:-$HOME/.config-backup}"
EOF
    chmod 600 "$CONFIG_FILE"
}

# 引导用户配置
setup_wizard() {
    echo "🚀 Config Backup Skill 首次配置向导"
    echo "======================================"
    echo ""
    echo "本工具需要配置 GitHub 仓库来存储备份。"
    echo ""
    
    # 检查是否已配置
    if [ -f "$CONFIG_FILE" ]; then
        echo "⚠️  检测到已有配置，是否重新配置? (yes/no)"
        read -r confirm
        if [ "$confirm" != "yes" ]; then
            echo "✅ 保持现有配置"
            return 0
        fi
    fi
    
    echo "📋 配置步骤:"
    echo ""
    
    # 步骤 1: 获取 GitHub Token
    echo "步骤 1/3: 配置 GitHub Token"
    echo "---------------------------"
    echo "1. 访问: https://github.com/settings/tokens"
    echo "2. 点击 'Generate new token (classic)'"
    echo "3. 勾选 'repo' 权限"
    echo "4. 生成后复制 Token"
    echo ""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "📝 已配置 Token: ${GITHUB_TOKEN:0:10}..."
        echo "是否更新? (yes/no/跳过)"
        read -r update_token
        if [ "$update_token" = "yes" ]; then
            echo -n "请输入 GitHub Token: "
            read -rs GITHUB_TOKEN
            echo ""
        fi
    else
        echo -n "请输入 GitHub Token: "
        read -rs GITHUB_TOKEN
        echo ""
    fi
    
    # 验证 Token
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "🔍 验证 Token..."
        local username=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            https://api.github.com/user | jq -r '.login // empty')
        
        if [ -n "$username" ]; then
            echo "✅ Token 有效，用户名: $username"
        else
            echo "❌ Token 无效，请检查"
            return 1
        fi
    fi
    
    echo ""
    
    # 步骤 2: 配置仓库
    echo "步骤 2/3: 配置备份仓库"
    echo "----------------------"
    echo "选项 A: 使用现有仓库"
    echo "选项 B: 创建新仓库（自动）"
    echo ""
    
    if [ -n "$BACKUP_REPO_URL" ]; then
        echo "📝 已配置仓库: $BACKUP_REPO_URL"
        echo "是否更新? (yes/no/跳过)"
        read -r update_repo
    else
        update_repo="yes"
    fi
    
    if [ "$update_repo" = "yes" ]; then
        echo "请选择:"
        echo "  1) 使用现有仓库"
        echo "  2) 创建新仓库（推荐）"
        echo -n "选择 (1/2): "
        read -r repo_choice
        
        if [ "$repo_choice" = "2" ]; then
            # 自动创建仓库
            echo "🆕 创建新仓库..."
            echo -n "请输入仓库名称 (默认: config-backup): "
            read -r repo_name
            repo_name="${repo_name:-config-backup}"
            
            echo "创建仓库: $username/$repo_name"
            local create_result=$(curl -s -X POST \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                https://api.github.com/user/repos \
                -d "{\"name\":\"$repo_name\",\"description\":\"OpenClaw 配置备份\",\"private\":true}")
            
            if echo "$create_result" | grep -q '"id"'; then
                BACKUP_REPO_URL="https://github.com/$username/$repo_name"
                echo "✅ 仓库创建成功: $BACKUP_REPO_URL"
            else
                echo "❌ 仓库创建失败"
                echo "$create_result" | jq -r '.message // "未知错误"'
                return 1
            fi
        else
            # 使用现有仓库
            echo -n "请输入仓库地址 (如: https://github.com/$username/config-backup): "
            read -r BACKUP_REPO_URL
        fi
    fi
    
    echo ""
    
    # 步骤 3: 保存配置
    echo "步骤 3/3: 保存配置"
    echo "------------------"
    save_config
    echo "✅ 配置已保存到: $CONFIG_FILE"
    
    # 初始化仓库
    echo ""
    echo "🔧 初始化本地仓库..."
    init_repo
    
    echo ""
    echo "🎉 配置完成!"
    echo ""
    echo "快速开始:"
    echo "  config-backup backup /root/.openclaw/openclaw.json"
    echo "  config-backup list"
    echo "  config-backup restore latest"
}

# 初始化仓库
init_repo() {
    load_config
    
    if [ -d "$BACKUP_REPO/.git" ]; then
        echo "✅ 备份仓库已存在: $BACKUP_REPO"
        
        # 检查远程地址
        cd "$BACKUP_REPO"
        local current_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [ "$current_url" != "$BACKUP_REPO_URL" ] && [ -n "$BACKUP_REPO_URL" ]; then
            echo "🔄 更新远程仓库地址..."
            git remote set-url origin "$BACKUP_REPO_URL" 2>/dev/null || \
                git remote add origin "$BACKUP_REPO_URL"
        fi
        return 0
    fi
    
    # 克隆仓库
    mkdir -p "$(dirname "$BACKUP_REPO")"
    
    if [ -n "$BACKUP_REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        echo "📥 克隆备份仓库..."
        local auth_url="${BACKUP_REPO_URL/https:\/\//https:\/\/$GITHUB_TOKEN@}"
        git clone "$auth_url" "$BACKUP_REPO" 2>/dev/null || {
            echo "⚠️  克隆失败，创建本地仓库..."
            create_local_repo
        }
    else
        echo "⚠️  未配置仓库，创建本地仓库..."
        create_local_repo
    fi
    
    echo "✅ 初始化完成: $BACKUP_REPO"
}

# 创建本地仓库
create_local_repo() {
    mkdir -p "$BACKUP_REPO"
    cd "$BACKUP_REPO"
    git init
    
    # 复制脚本
    if [ -d "$SCRIPT_DIR" ]; then
        cp -f "$SCRIPT_DIR/"*.sh "$BACKUP_REPO/" 2>/dev/null || true
        chmod +x "$BACKUP_REPO/"*.sh
    fi
    
    # 创建 README
    cat > "$BACKUP_REPO/README.md" << 'EOF'
# Config Backup

个人配置备份仓库。

由 Config Backup Skill 自动生成。
EOF
    
    git add .
    git commit -m "init: 初始化备份仓库" || true
}

# 检查备份仓库是否存在
check_repo() {
    load_config
    
    if [ ! -d "$BACKUP_REPO/.git" ]; then
        echo "❌ 备份仓库不存在"
        echo ""
        echo "请先运行: config-backup setup"
        return 1
    fi
    return 0
}

# 查看配置
show_config() {
    load_config
    
    echo "📋 当前配置:"
    echo "============="
    
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE" | grep -v '^#' | grep -v '^$'
    else
        echo "⚠️  未配置"
    fi
    
    echo ""
    echo "配置文件路径: $CONFIG_FILE"
}

# 主逻辑
main() {
    local command="${1:-}"
    
    case "$command" in
        setup)
            setup_wizard
            ;;
        backup)
            shift
            check_repo && "$BACKUP_REPO/backup.sh" "$@"
            ;;
        restore)
            shift
            check_repo && "$BACKUP_REPO/restore.sh" "$@"
            ;;
        list)
            check_repo && "$BACKUP_REPO/restore.sh" --list
            ;;
        cleanup)
            check_repo && "$BACKUP_REPO/restore.sh" --cleanup
            ;;
        init)
            init_repo
            ;;
        config)
            show_config
            ;;
        -h|--help|help)
            show_help
            ;;
        "")
            show_help
            exit 1
            ;;
        *)
            echo "❌ 未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
