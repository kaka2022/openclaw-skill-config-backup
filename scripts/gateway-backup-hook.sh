#!/bin/bash
# Gateway 重启前自动备份钩子
# 安装：将此脚本添加到 openclaw-gateway 重启流程中

set -e

CONFIG_BACKUP_BIN="${CONFIG_BACKUP_BIN:-/usr/local/bin/config-backup}"
BACKUP_TAG="gateway-restart-$(date +%Y%m%d-%H%M%S)"

echo "🔧 Gateway 重启前自动备份..."

# 检查 config-backup 是否安装
if ! command -v "$CONFIG_BACKUP_BIN" >/dev/null 2>&1; then
    echo "⚠️  config-backup 未安装，跳过备份"
    exit 0
fi

# 备份 OpenClaw 核心配置
echo "📦 备份 OpenClaw 核心配置..."
"$CONFIG_BACKUP_BIN" backup /root/.openclaw/openclaw.json -m "Gateway 重启前自动备份: $BACKUP_TAG" 2>/dev/null || true
"$CONFIG_BACKUP_BIN" backup /root/.openclaw/exec-approvals.json -m "Gateway 重启前自动备份: $BACKUP_TAG" 2>/dev/null || true

# 备份 systemd 服务配置（如果存在）
if [ -f "/etc/systemd/system/openclaw-gateway.service" ]; then
    echo "📦 备份 systemd 服务配置..."
    "$CONFIG_BACKUP_BIN" backup /etc/systemd/system/openclaw-gateway.service -m "Gateway 重启前自动备份: $BACKUP_TAG" 2>/dev/null || true
fi

echo "✅ Gateway 重启前备份完成"
echo "   备份标签: $BACKUP_TAG"
echo "   如需恢复: config-backup restore latest"
