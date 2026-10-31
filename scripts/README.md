# 本机自动同步脚本

本机的 agent（本机定时任务、交互式总览）只改文件、不提交。由这里的脚本每 20 分钟统一做一次：

1. 提交本地改动（提交信息带 `[auto-sync]` 标记）；
2. 拉取远端；如有分叉，**只 rebase 自动同步自己产生的提交**；
3. 推送。绝不 force push。

推送前会检查暂存区里有没有像凭据的文件（`.env`、私钥、`*.credentials.json`、含 `BEGIN PRIVATE KEY` 的内容），有就停下，不提交。

| 文件 | 平台 | 用途 |
|---|---|---|
| `sync_auto.sh` | Linux / macOS | 同步一次；配合 cron 每 20 分钟跑 |
| `sync_auto.ps1` | Windows | 同步一次 |
| `register_auto_sync.ps1` | Windows | 登记计划任务（每 20 分钟，**允许用电池运行**） |
| `sync_now.cmd` | Windows | 双击立即同步（切换系统前用） |

## Linux / macOS

```bash
chmod +x scripts/sync_auto.sh
REPO=~/path/to/repo scripts/sync_auto.sh          # 先手动跑一次
crontab -e
# 加一行：
# 2,22,42 * * * * REPO=$HOME/path/to/repo $HOME/path/to/repo/scripts/sync_auto.sh
```

## Windows

1. 用 PowerShell 打开仓库目录，运行一次：`powershell -ExecutionPolicy Bypass -File scripts\register_auto_sync.ps1`
2. 以后急着推送就双击 `scripts\sync_now.cmd`。

日志写在 `~/<仓库名>_sync_logs/`。

## 注意

- 同一时间只让一台机器自动同步。换电脑或双系统切换前，先在当前机器手动同步一次。
- 远端地址用 HTTPS 时，凭据交给系统的 Git 凭据管理器（Windows 的 Git Credential Manager、`gh auth setup-git` 等），**不要**把 token 写进远端 URL 或脚本。
- 脚本是通用简化版，按你的仓库情况改（比如只同步某些目录）。
