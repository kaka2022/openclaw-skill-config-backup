---
name: config-backup
description: |
  自动备份和恢复系统配置文件。在修改配置前自动备份，出问题时可快速恢复。
  支持版本管理（最多保留7个版本），自动清理旧版本。
  适用于 OpenClaw、Nginx、Clash 等所有配置文件。
metadata:
  openclaw:
    emoji: 💾
    category: system
    os: [linux, darwin]
---

# Config Backup Skill

自动备份和恢复系统配置文件，防止配置错误导致服务不可用。

## 功能特性

- 🔄 **修改前自动备份** - 修改任何配置前，自动备份到 GitHub 私有仓库
- 🏃 **一键恢复** - 配置出错时，一键恢复到上一个可用版本
- 📦 **版本管理** - 最多保留 7 个版本，自动清理旧版本
- 🎯 **选择性恢复** - 可只恢复特定文件，不影响其他配置
- 🧪 **模拟恢复** - 支持 dry-run 模式，先预览再执行

## 快速开始

### 1. 初始化备份仓库

```bash
# 运行配置向导（推荐）
config-backup setup

# 或者手动配置
mkdir -p ~/.config-backup
cat > ~/.config-backup/config << 'EOF'
GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
BACKUP_REPO_URL="https://github.com/YOUR_USERNAME/config-backup"
EOF
chmod 600 ~/.config-backup/config
```

### 2. 备份配置

```bash
# 备份单个文件
config-backup backup /root/.openclaw/openclaw.json

# 备份所有 OpenClaw 配置
config-backup backup --all-openclaw

# 备份并推送到 GitHub
config-backup backup -a -m "修改前备份" --push
```

### 3. 恢复配置

```bash
# 查看所有备份版本
config-backup list

# 恢复到最新版本
config-backup restore latest

# 恢复到指定版本
config-backup restore 20260316-143022

# 只恢复特定文件
config-backup restore latest --file openclaw.json

# 模拟恢复（不实际执行）
config-backup restore latest --dry-run
```

## 支持的配置文件

- `/root/.openclaw/openclaw.json` - OpenClaw 主配置
- `/root/.openclaw/exec-approvals.json` - 执行审批配置
- `/root/.config/clash/config.yaml` - Clash 代理配置
- `/etc/nginx/nginx.conf` - Nginx 配置
- `/etc/systemd/system/openclaw-gateway.service` - systemd 服务
- 自定义配置文件

## 使用场景

### 场景 1：修改 OpenClaw 配置

```bash
# 1. 修改前备份
config-backup backup /root/.openclaw/openclaw.json -m "准备修改 exec 权限"

# 2. 修改配置
# ... 手动修改 openclaw.json ...

# 3. 重启服务
openclaw gateway restart

# 4. 如果出问题，立即恢复
config-backup restore latest
openclaw gateway restart
```

### 场景 2：批量修改多个配置

```bash
# 备份所有配置
config-backup backup --all-openclaw --push

# 修改多个文件...

# 如果出问题，一键恢复所有
config-backup restore latest --yes
```

### 场景 3：定期自动备份

添加到 crontab：
```bash
# 每天凌晨 3 点自动备份
0 3 * * * /root/.openclaw/workspace/skills/config-backup/scripts/config-backup.sh backup --all-openclaw --push
```

## 版本管理规则

- **最多保留 7 个版本**
- 超过 7 个版本时，自动删除最旧的版本
- 每个版本包含：时间戳、备份文件、修改说明
- 版本号格式：`YYYYMMDD-HHMMSS`

## 工具命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `backup` | 备份配置文件 | `config-backup backup /path/to/file` |
| `restore` | 恢复配置文件 | `config-backup restore latest` |
| `list` | 列出所有版本 | `config-backup list` |
| `cleanup` | 清理旧版本 | `config-backup cleanup` |

### backup 选项

- `-a, --all-openclaw` - 备份所有 OpenClaw 配置
- `-s, --all-system` - 备份所有系统配置
- `-m, --message MSG` - 添加备份说明
- `-p, --push` - 自动推送到 GitHub

### restore 选项

- `-f, --file FILE` - 只恢复指定文件
- `-y, --yes` - 自动确认，不提示
- `--dry-run` - 模拟恢复，不实际执行

## 配置文件

### 默认配置路径

```yaml
backup_dir: ~/.config-backup/configs
manifest_dir: ~/.config-backup/manifests
max_versions: 7
auto_push: true
default_configs:
  - /root/.openclaw/openclaw.json
  - /root/.openclaw/exec-approvals.json
  - /root/.config/clash/config.yaml
```

### 自定义配置

创建 `~/.config-backup/config.yaml`：

```yaml
# 添加自定义配置文件
additional_configs:
  - /etc/myapp/config.ini
  - /opt/custom/settings.json

# 修改最大版本数
max_versions: 10

# 禁用自动推送
auto_push: false
```

## 安全说明

- 🔒 备份仓库为**私有仓库**，不会泄露敏感信息
- 🔑 配置文件可能包含 API Key、Token，请妥善保管
- 🛡️ 恢复前会自动备份当前文件，防止二次丢失
- 📋 建议定期检查和清理旧版本

## 故障排除

### 问题 1：推送失败

```bash
# 检查 GitHub Token 是否有效
config-backup verify-token

# 重新配置 Token
config-backup config --token YOUR_NEW_TOKEN
```

### 问题 2：恢复后服务不正常

```bash
# 1. 检查恢复的文件权限
ls -la /root/.openclaw/openclaw.json

# 2. 重启相关服务
openclaw gateway restart
systemctl restart nginx
pkill clash && /root/clash/clash -d /root/.config/clash &

# 3. 如果仍有问题，恢复到更早的版本
config-backup list
config-backup restore 20260315-120000
```

### 问题 3：版本太多占用空间

```bash
# 手动清理旧版本（保留最新的 7 个）
config-backup cleanup

# 或者只保留最近 3 个
config-backup cleanup --keep 3
```

## 集成到 OpenClaw

可以在修改配置前自动调用备份：

```bash
# 在 .bashrc 中添加别名
alias openclaw-edit='config-backup backup /root/.openclaw/openclaw.json && vim'
alias nginx-edit='config-backup backup /etc/nginx/nginx.conf && sudo vim'
```

## 相关仓库

- **社区模板**: https://github.com/openclaw-community/config-backup-template

---

**创建时间**: 2026-03-16
**版本**: 1.0.0
**作者**: OpenClaw Agent
