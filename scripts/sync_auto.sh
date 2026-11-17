#!/usr/bin/env bash
# 本机自动同步：提交本地改动 → 拉取（只 rebase 自动提交）→ 推送。绝不 force。
# 用法：REPO=/path/to/repo ./sync_auto.sh
set -uo pipefail
REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
NAME="$(basename "$REPO")"
LOGDIR="$HOME/${NAME}_sync_logs"; mkdir -p "$LOGDIR"
# 暂停开关：日志目录里有 PAUSE_AUTO_SYNC.txt 就什么都不做。恢复时把这个文件改名。
[ -e "$LOGDIR/PAUSE_AUTO_SYNC.txt" ] && exit 0
LOG="$LOGDIR/auto_$(date +%F_%H%M).log"
FAILMARK="$LOGDIR/LAST_FAILURE.txt"
exec >>"$LOG" 2>&1
# 失败时留下标记文件，巡检看到它就提醒用户；下一次成功后改名移开。
fail() { echo "$2"; echo "$(date '+%F %T')  exit $1  $2" >>"$FAILMARK"; exit "$1"; }
echo "== auto sync $(date '+%F %T') =="
cd "$REPO" || fail 1 "no repo: $REPO"
LOCK="$REPO/.git/auto-sync.lock"
if ! mkdir "$LOCK" 2>/dev/null; then echo "another sync running"; exit 0; fi
trap 'rmdir "$LOCK"' EXIT
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" = "HEAD" ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  fail 7 "STOP: detached HEAD or unfinished rebase; resolve manually"
fi

git add -A
# 凭据检查
if git diff --cached --name-only | grep -E '(^|/)\.env$|\.pem$|\.key$|id_(rsa|ed25519)$|credentials\.json$' ; then
  git reset -q; fail 2 "STOP: credential-like file staged"
fi
if git diff --cached -U0 | grep -E 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}' ; then
  git reset -q; fail 2 "STOP: secret-like content staged"
fi
if ! git diff --cached --quiet; then
  git commit -q -m "Auto sync $(date +%F_%H%M) [auto-sync]" && echo "committed $(git rev-parse --short HEAD)"
fi

git fetch -q origin "$BRANCH" || fail 3 "fetch failed"
AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")
BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH")
if [ "$BEHIND" -gt 0 ]; then
  if [ "$AHEAD" -gt 0 ]; then
    # 只允许 rebase 自动同步提交
    if git log --format=%s "origin/$BRANCH..HEAD" | grep -qv '\[auto-sync\]'; then
      fail 4 "STOP: local non-auto commits diverged; resolve manually"
    fi
    git rebase -q "origin/$BRANCH" || { git rebase --abort; fail 5 "STOP: rebase conflict"; }
    echo "rebased $AHEAD auto commit(s)"
  else
    git merge -q --ff-only "origin/$BRANCH" && echo "fast-forwarded $BEHIND"
  fi
fi
if [ "$(git rev-list --count "origin/$BRANCH..HEAD")" -gt 0 ]; then
  git push -q origin "$BRANCH" && echo "pushed $(git rev-parse --short HEAD)" || fail 6 "push failed"
fi
[ -e "$FAILMARK" ] && mv "$FAILMARK" "$LOGDIR/LAST_FAILURE.resolved_$(date +%Y%m%d_%H%M).txt"
echo "done"
