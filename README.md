# Config Backup Skill 💾

[![OpenClaw](https://img.shields.io/badge/OpenClaw-Skill-blue)](https://openclaw.ai)
[![Version](https://img.shields.io/badge/version-2.0.0-green)](https://github.com/kaka2022/openclaw-skill-config-backup/releases)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

> 自动备份和恢复系统配置文件，防止配置错误导致服务不可用。

## ✨ 功能特性

- 🤖 **AI 自动备份** - 检测到修改配置意图时，**自动先备份再修改**，无需手动说"备份"
- 🔄 **一键恢复** - 配置出错时，说"恢复刚才的备份"即可自动回滚
- 📦 **版本管理** - 最多保留 7 个版本，自动清理旧版本
- 🎯 **选择性恢复** - 可只恢复特定文件，不影响其他配置
- 🧪 **模拟恢复** - 支持 dry-run 模式，先预览再执行
- 🔒 **安全可靠** - 备份仓库私有，Token 本地加密存储

## 🎯 核心设计：自动备份

**传统方式**：
```bash
# 用户：备份一下
# 用户：修改配置
# 用户：出问题了
# 用户：恢复备份
```

**Config Backup 方式（AI 自动）**：
```bash
# 场景 1：用户要求修改
# 用户：修改配置
# AI：🤖 自动备份 → 修改 → 提示"已备份，可恢复"

# 场景 2：AI 自主修改
# AI：🤖 检测到问题 → 自动备份 → 修复 → 提示"已备份并修复"

# 恢复（两种场景相同）
# 用户：出问题了
# AI：🤖 自动恢复
```

**无论是用户要求改，还是 AI 自己改，都会自动备份！**

## 🚀 快速开始

### 1. 安装

```bash
# 克隆仓库
git clone https://github.com/kaka2022/openclaw-skill-config-backup.git
cd openclaw-skill-config-backup

# 安装
./install.sh
```

### 2. 首次配置

```bash
# 运行配置向导
config-backup setup
```

向导会引导你：
1. 获取 GitHub Token
2. 创建/选择备份仓库
3. 初始化本地仓库

### 3. 使用

```bash
# 备份配置文件
config-backup backup /root/.openclaw/openclaw.json

# 查看所有备份版本
config-backup list

# 恢复到最新版本
config-backup restore latest

# 模拟恢复（安全预览）
config-backup restore latest --dry-run
```

## 📖 详细文档

详见 [SKILL.md](SKILL.md) 获取完整使用指南。

## 🛡️ 安全说明

- **权限范围明确**: 只读取用户指定的配置文件，只写入备份目录
- **Token 安全存储**: 存储在 `~/.config-backup/config`，权限 600
- **恢复前自动备份**: 防止二次丢失
- **私有仓库**: 默认使用私有仓库保护敏感信息

## 🔧 支持的配置文件

- `/root/.openclaw/openclaw.json` - OpenClaw 主配置
- `/root/.openclaw/exec-approvals.json` - 执行审批配置
- `/root/.config/clash/config.yaml` - Clash 代理配置
- `/etc/nginx/nginx.conf` - Nginx 配置
- `/etc/systemd/system/openclaw-gateway.service` - systemd 服务
- 自定义配置文件

## 📋 命令参考

| 命令 | 说明 | 示例 |
|------|------|------|
| `setup` | 配置向导 | `config-backup setup` |
| `backup` | 备份文件 | `config-backup backup /path/to/config` |
| `restore` | 恢复文件 | `config-backup restore latest` |
| `list` | 列出版本 | `config-backup list` |
| `cleanup` | 清理旧版本 | `config-backup cleanup` |

## 🤝 贡献

欢迎提交 Issue 和 PR！

## 📄 许可证

MIT License

---

**Made with ❤️ for OpenClaw Community**
