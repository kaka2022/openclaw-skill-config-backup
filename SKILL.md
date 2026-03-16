---
name: config-backup
description: |
  自动备份和恢复系统配置文件。在修改配置前自动备份，出问题时可快速恢复。
  支持版本管理（最多保留7个版本），自动清理旧版本。
  适用于 OpenClaw、Nginx、Clash 等所有配置文件。
version: "2.0.0"
author: "OpenClaw Community"
tags: ["backup", "config", "system", "restore", "version-control"]
permissions: ["read", "write", "exec", "network"]
gated: false
requires: ["git", "curl", "jq"]
metadata:
  openclaw:
    emoji: 💾
    category: system
    os: [linux, darwin]
    min_version: "2026.3.0"
    virus_total: "clean"  # 已通过 VirusTotal 检测
---

# Config Backup Skill

自动备份和恢复系统配置文件，防止配置错误导致服务不可用。

## 什么时候调用我

- 用户要修改系统配置文件（OpenClaw、Nginx、Clash 等）
- 用户想备份当前配置
- 用户配置出错，需要恢复
- 用户想查看配置历史版本
- 用户想清理旧备份

## 安全声明

⚠️ **权限范围**（已明确声明）：
- **读取**: 只能读取用户指定的配置文件
- **写入**: 只能写入备份目录 `~/.config-backup/`
- **执行**: 执行 git、curl 等命令
- **网络**: 只访问 GitHub API 进行备份推送

🔒 **安全特性**：
- 备份仓库默认为私有，保护敏感信息
- Token 存储在 `~/.config-backup/config`，权限 600
- 恢复前自动备份当前配置，防止二次丢失
- 所有破坏性操作需要用户确认

## 快速开始

### 1. 首次配置（必须）

```bash
# 运行配置向导，设置 GitHub Token 和仓库
config-backup setup
```

配置向导会引导你：
1. **获取 GitHub Token** - 访问 https://github.com/settings/tokens 生成
2. **创建备份仓库** - 自动创建或指定现有仓库
3. **初始化本地仓库** - 自动克隆和配置

### 2. 手动配置（可选）

如果不想使用向导，可以手动创建配置文件：

```bash
mkdir -p ~/.config-backup
cat > ~/.config-backup/config << 'EOF'
GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
BACKUP_REPO_URL="https://github.com/YOUR_USERNAME/config-backup"
EOF
chmod 600 ~/.config-backup/config
```

## 使用示例

### 示例 1：修改配置前备份

**用户输入**：我要修改 OpenClaw 配置，先帮我备份

**执行步骤**：
```bash
config-backup backup /root/.openclaw/openclaw.json -m "准备修改 exec 权限"
# 用户修改配置...
# 如果出问题，立即恢复
config-backup restore latest
```

### 示例 2：批量备份所有配置

**用户输入**：备份所有 OpenClaw 配置

**执行步骤**：
```bash
config-backup backup --all-openclaw
```

### 示例 3：查看和恢复历史版本

**用户输入**：查看有哪些备份版本，恢复到昨天的

**执行步骤**：
```bash
config-backup list
# 显示版本列表
config-backup restore 20260315-120000
```

### 示例 4：模拟恢复（安全预览）

**用户输入**：我想看看恢复后会怎么样，但先不真的恢复

**执行步骤**：
```bash
config-backup restore latest --dry-run
```

## 详细指令

### 命令列表

| 命令 | 说明 | 示例 |
|------|------|------|
| `setup` | 首次配置向导 | `config-backup setup` |
| `backup` | 备份配置文件 | `config-backup backup /path/to/file` |
| `restore` | 恢复配置文件 | `config-backup restore latest` |
| `list` | 列出所有版本 | `config-backup list` |
| `cleanup` | 清理旧版本 | `config-backup cleanup` |
| `config` | 查看配置 | `config-backup config` |

### backup 选项

- `-a, --all-openclaw` - 备份所有 OpenClaw 配置
- `-m, --message MSG` - 添加备份说明
- `-p, --push` - 自动推送到 GitHub

### restore 选项

- `-f, --file FILE` - 只恢复指定文件
- `-y, --yes` - 自动确认，不提示
- `--dry-run` - 模拟恢复，不实际执行
- `--diff` - 显示 diff 预览

## 实现细节

### 备份流程

1. **读取配置** - 从 `~/.config-backup/config` 加载 Token 和仓库地址
2. **检查文件** - 验证源文件存在，排除 `.git`、`.swp` 等垃圾文件
3. **记录元数据** - 获取文件权限、属主、MD5 校验值
4. **复制文件** - 复制到备份目录，文件名带时间戳
5. **生成清单** - 生成 JSON 格式清单，包含完整元数据
6. **Git 提交** - 自动 commit 并 push 到 GitHub
7. **清理旧版本** - 如果超过 7 个版本，删除最旧的

### 恢复流程

1. **读取清单** - 从 JSON 清单获取文件路径和元数据
2. **显示预览** - 显示将要恢复的文件列表（可选 diff）
3. **用户确认** - 等待用户确认（除非 `-y`）
4. **备份当前** - 先备份当前配置，防止二次丢失
5. **恢复文件** - 从备份目录复制到原始路径
6. **应用权限** - 恢复原始权限和属主
7. **提示重启** - 提示用户可能需要重启服务

### 版本管理

- **最多保留 7 个版本**
- 版本号格式：`YYYYMMDD-HHMMSS`
- 自动清理超过 7 个版本的旧备份
- 每个版本包含：时间戳、文件、权限、属主、MD5

## 自进化指令

如果用户反馈以下问题，自动记录到 `.learnings/` 并优化：

1. **备份失败** → 记录错误原因，检查 Token 和仓库权限
2. **恢复后服务起不来** → 记录文件权限问题，改进权限恢复逻辑
3. **版本太多占用空间** → 建议用户运行 `config-backup cleanup`
4. **想备份其他目录** → 记录需求，考虑添加自定义路径支持

记录格式：
```bash
echo "[$(date)] 用户反馈: XXX" >> ~/.config-backup/.learnings/feedback.log
```

## 故障排除

### 问题 1：Token 无效

```bash
# 症状：推送失败，提示 401
# 解决：重新配置 Token
config-backup setup
```

### 问题 2：仓库不存在

```bash
# 症状：克隆失败
# 解决：检查仓库地址，或让向导自动创建
config-backup setup
```

### 问题 3：恢复后权限不对

```bash
# 症状：服务启动失败，提示 Permission denied
# 解决：手动修复权限
chmod 644 /root/.openclaw/openclaw.json
chown root:root /root/.openclaw/openclaw.json
```

### 问题 4：版本太多

```bash
# 症状：备份仓库太大
# 解决：手动清理旧版本
config-backup cleanup
```

## 依赖要求

- **git** - 版本控制
- **curl** - GitHub API 调用
- **jq** - JSON 处理（可选，但推荐）
- **md5sum** - 文件校验
- **stat** - 获取文件元数据

## 兼容性

- **OpenClaw**: >= 2026.3.0
- **操作系统**: Linux, macOS
- **Shell**: bash >= 4.0

## 社区链接

- **模板仓库**: https://github.com/openclaw-community/config-backup-template
- **问题反馈**: https://github.com/kaka2022/openclaw-skill-config-backup/issues
- **ClawHub**: https://clawhub.com/skill/config-backup

---

**版本**: 2.0.0  
**最后更新**: 2026-03-16  
**VirusTotal**: ✅ Clean  
**许可证**: MIT
