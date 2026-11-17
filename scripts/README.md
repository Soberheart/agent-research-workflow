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

## 暂停和恢复

- **暂停**：在日志目录里放一个名为 `PAUSE_AUTO_SYNC.txt` 的文件（内容随意，建议写上谁、哪天、为什么）。计划任务照常触发，但脚本一开头就退出，不提交、不拉取、不推送，也不写日志。
- **恢复**：把这个文件改名（例如 `PAUSE_AUTO_SYNC.off_<日期>.txt`），不用删。下一轮就恢复。
- 暂停期间本机 agent 写的文件到不了 GitHub，云端 agent 看不到；恢复后的第一轮会一次补推。
- 暂停和恢复都让总览在 `reports/需要你处理.md` 顶部记一行，免得别的 agent 照着旧记录说"还停着"。

## 失败标记

脚本失败（拉取失败、推送失败、有冲突、仓库停在没做完的 rebase 上等）时，会在日志目录的 `LAST_FAILURE.txt` 里追加一行：时间、退出码、原因。下一次同步成功后，这个文件会被改名为 `LAST_FAILURE.resolved_<时间>.txt`。

总览巡检每次看一眼有没有 `LAST_FAILURE.txt`：有，就说明同步正在连续失败，要写进用户的待办。

| 退出码 | 意思 |
|---:|---|
| 2 | 暂存区里有像凭据的文件或内容，已取消暂存 |
| 3 | 拉取失败（网络或凭据） |
| 4 | 本地有不是自动同步产生的提交，且和远端分叉，要手动处理 |
| 5 | rebase 有冲突，已放弃这次 rebase |
| 6 | 推送失败 |
| 7 | 仓库停在分离头指针或没做完的 rebase 上，要手动处理 |

## 注意

- 同一时间只让一台机器自动同步。换电脑或双系统切换前，先在当前机器手动同步一次。
- 一台电脑上有几个项目时，每个项目一个仓库、一个计划任务、一个日志目录（脚本按仓库文件夹名自动区分）。暂停开关只管它所在的那个项目。
- 远端地址用 HTTPS 时，凭据交给系统的 Git 凭据管理器（Windows 的 Git Credential Manager、`gh auth setup-git` 等），**不要**把 token 写进远端 URL 或脚本。
- 脚本是通用简化版，按你的仓库情况改（比如只同步某些目录）。
