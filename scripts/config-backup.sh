#!/bin/bash
# Config Backup Skill - 主入口脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_REPO="${BACKUP_REPO:-$HOME/.config-backup}"

# 显示帮助
show_help() {
    cat << EOF
Config Backup Skill - 配置文件备份与恢复

用法:
    config-backup <命令> [选项]

命令:
    backup          备份配置文件
    restore         恢复配置文件
    list            列出所有备份版本
    cleanup         清理旧版本
    init            初始化备份仓库
    verify-token    验证 GitHub Token
    config          配置 skill

示例:
    config-backup backup /root/.openclaw/openclaw.json
    config-backup restore latest
    config-backup list
    config-backup init

详细帮助:
    config-backup backup --help
    config-backup restore --help
EOF
}

# 检查备份仓库是否存在
check_repo() {
    if [ ! -d "$BACKUP_REPO/.git" ]; then
        echo "❌ 备份仓库不存在，请先运行: config-backup init"
        return 1
    fi
    return 0
}

# 初始化仓库
init_repo() {
    echo "🔧 初始化 Config Backup Skill..."
    
    if [ -d "$BACKUP_REPO/.git" ]; then
        echo "✅ 备份仓库已存在: $BACKUP_REPO"
        return 0
    fi
    
    # 克隆仓库（用户需替换为自己的仓库地址）
    mkdir -p "$(dirname "$BACKUP_REPO")"
    echo "📥 请配置您的备份仓库地址:"
    echo "   1. Fork 模板仓库: https://github.com/openclaw-community/config-backup-template"
    echo "   2. 修改 ~/.config-backup/config 设置您的仓库地址"
    echo ""
    echo "⚠️  使用本地仓库作为示例..."
    mkdir -p "$BACKUP_REPO"
    cd "$BACKUP_REPO"
    git init 2>/dev/null || true
    
    echo "✅ 初始化完成: $BACKUP_REPO"
}

# 主逻辑
main() {
    local command="${1:-}"
    
    case "$command" in
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
        verify-token)
            echo "🔑 验证 GitHub Token..."
            curl -s -H "Authorization: token $(git config --get user.token 2>/dev/null || echo 'not-set')" \
                https://api.github.com/user | jq -r '.login // "Token 无效"'
            ;;
        config)
            shift
            echo "⚙️  配置功能待实现"
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
