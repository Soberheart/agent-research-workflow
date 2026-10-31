#!/usr/bin/env bash
# 本机自动同步：提交本地改动 → 拉取（只 rebase 自动提交）→ 推送。绝不 force。
# 用法：REPO=/path/to/repo ./sync_auto.sh
set -uo pipefail
REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
NAME="$(basename "$REPO")"
LOGDIR="$HOME/${NAME}_sync_logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/auto_$(date +%F_%H%M).log"
exec >>"$LOG" 2>&1
echo "== auto sync $(date '+%F %T') =="
cd "$REPO" || { echo "no repo: $REPO"; exit 1; }
LOCK="$REPO/.git/auto-sync.lock"
if ! mkdir "$LOCK" 2>/dev/null; then echo "another sync running"; exit 0; fi
trap 'rmdir "$LOCK"' EXIT
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

git add -A
# 凭据检查
if git diff --cached --name-only | grep -E '(^|/)\.env$|\.pem$|\.key$|id_(rsa|ed25519)$|credentials\.json$' ; then
  echo "STOP: credential-like file staged"; git reset -q; exit 2
fi
if git diff --cached -U0 | grep -E 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}' ; then
  echo "STOP: secret-like content staged"; git reset -q; exit 2
fi
if ! git diff --cached --quiet; then
  git commit -q -m "Auto sync $(date +%F_%H%M) [auto-sync]" && echo "committed $(git rev-parse --short HEAD)"
fi

git fetch -q origin "$BRANCH" || { echo "fetch failed"; exit 3; }
AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")
BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH")
if [ "$BEHIND" -gt 0 ]; then
  if [ "$AHEAD" -gt 0 ]; then
    # 只允许 rebase 自动同步提交
    if git log --format=%s "origin/$BRANCH..HEAD" | grep -qv '\[auto-sync\]'; then
      echo "STOP: local non-auto commits diverged; resolve manually"; exit 4
    fi
    git rebase -q "origin/$BRANCH" || { git rebase --abort; echo "STOP: rebase conflict"; exit 5; }
    echo "rebased $AHEAD auto commit(s)"
  else
    git merge -q --ff-only "origin/$BRANCH" && echo "fast-forwarded $BEHIND"
  fi
fi
if [ "$(git rev-list --count "origin/$BRANCH..HEAD")" -gt 0 ]; then
  git push -q origin "$BRANCH" && echo "pushed $(git rev-parse --short HEAD)" || { echo "push failed"; exit 6; }
fi
echo "done"
