#!/bin/bash
# Config Backup Skill 安装脚本

set -e

echo "🔧 安装 Config Backup Skill..."

# 1. 检查依赖
echo "📦 检查依赖..."
command -v git >/dev/null 2>&1 || { echo "❌ 需要安装 git"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "❌ 需要安装 curl"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "⚠️  建议安装 jq (用于 JSON 处理)"; }

# 2. 设置路径
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/bin"
BACKUP_REPO="$HOME/.config-backup"

echo "📁 安装路径: $INSTALL_DIR"
echo "💾 备份仓库: $BACKUP_REPO"

# 3. 创建软链接
echo "🔗 创建命令软链接..."
ln -sf "$SKILL_DIR/scripts/config-backup.sh" "$INSTALL_DIR/config-backup"

# 4. 克隆备份仓库
if [ ! -d "$BACKUP_REPO/.git" ]; then
    echo "📥 克隆备份仓库..."
    mkdir -p "$(dirname "$BACKUP_REPO")"
    # 注意：用户需要配置自己的备份仓库
    # 模板仓库: https://github.com/openclaw-community/config-backup-template
    git clone "${BACKUP_REPO_URL:-https://github.com/openclaw-community/config-backup-template.git}" "$BACKUP_REPO" 2>/dev/null || {
        echo "⚠️  无法克隆仓库，将创建本地仓库"
        mkdir -p "$BACKUP_REPO"
        cd "$BACKUP_REPO"
        git init
    }
fi

# 5. 复制备份和恢复脚本
echo "📋 复制脚本..."
cp -f "$SKILL_DIR/scripts/"*.sh "$BACKUP_REPO/" 2>/dev/null || true
chmod +x "$BACKUP_REPO/"*.sh

# 6. 验证安装
echo "✅ 验证安装..."
if command -v config-backup >/dev/null 2>&1; then
    echo ""
    echo "🎉 Config Backup Skill 安装成功!"
    echo ""
    echo "使用方法:"
    echo "  config-backup init              # 初始化"
    echo "  config-backup backup --help     # 查看备份帮助"
    echo "  config-backup restore --help    # 查看恢复帮助"
    echo ""
    echo "快速开始:"
    echo "  config-backup backup /root/.openclaw/openclaw.json"
    echo "  config-backup list"
    echo "  config-backup restore latest"
else
    echo "❌ 安装失败"
    exit 1
fi
