# 本机自动同步（Windows）：提交本地改动 → 拉取（只 rebase 自动提交）→ 推送。绝不 force。
param([string]$Repo = (Split-Path -Parent $PSScriptRoot))
$name = Split-Path -Leaf $Repo
$logDir = Join-Path $env:USERPROFILE ("{0}_sync_logs" -f $name)
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
# Pause switch: if PAUSE_AUTO_SYNC.txt exists in the log folder, do nothing. Rename the file to resume.
if (Test-Path -LiteralPath (Join-Path $logDir 'PAUSE_AUTO_SYNC.txt')) { exit 0 }
$log = Join-Path $logDir ("auto_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
$failMark = Join-Path $logDir 'LAST_FAILURE.txt'
function Log($m) { $m | Out-File -FilePath $log -Append -Encoding utf8 }
# On failure leave a marker file for the patrol to notice; it is renamed away after the next success.
function Fail($code, $m) {
  Log $m
  ("{0}  exit {1}  {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $code, $m) | Out-File -FilePath $failMark -Append -Encoding utf8
  exit $code
}
Log "== auto sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =="
Set-Location $Repo
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq 'HEAD' -or (Test-Path -LiteralPath (Join-Path $Repo '.git\rebase-merge')) -or (Test-Path -LiteralPath (Join-Path $Repo '.git\rebase-apply'))) {
  Fail 7 'STOP: detached HEAD or unfinished rebase; resolve manually'
}

git add -A
$staged = git diff --cached --name-only
if ($staged | Select-String -Pattern '(^|/)\.env$|\.pem$|\.key$|id_(rsa|ed25519)$|credentials\.json$') {
  git reset -q; Fail 2 'STOP: credential-like file staged'
}
$diff = git diff --cached -U0
if ($diff | Select-String -Pattern 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}') {
  git reset -q; Fail 2 'STOP: secret-like content staged'
}
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -q -m ("Auto sync {0} [auto-sync]" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
  Log ("committed " + (git rev-parse --short HEAD))
}

git fetch -q origin $branch
if ($LASTEXITCODE -ne 0) { Fail 3 'fetch failed' }
$ahead  = [int](git rev-list --count "origin/$branch..HEAD")
$behind = [int](git rev-list --count "HEAD..origin/$branch")
if ($behind -gt 0) {
  if ($ahead -gt 0) {
    $nonAuto = git log --format=%s "origin/$branch..HEAD" | Where-Object { $_ -notmatch '\[auto-sync\]' }
    if ($nonAuto) { Fail 4 'STOP: local non-auto commits diverged; resolve manually' }
    git rebase -q "origin/$branch"
    if ($LASTEXITCODE -ne 0) { git rebase --abort; Fail 5 'STOP: rebase conflict' }
    Log "rebased $ahead auto commit(s)"
  } else {
    git merge -q --ff-only "origin/$branch"; Log "fast-forwarded $behind"
  }
}
if ([int](git rev-list --count "origin/$branch..HEAD") -gt 0) {
  git push -q origin $branch
  if ($LASTEXITCODE -ne 0) { Fail 6 'push failed' }
  Log ("pushed " + (git rev-parse --short HEAD))
}
if (Test-Path -LiteralPath $failMark) {
  Move-Item -LiteralPath $failMark -Destination (Join-Path $logDir ("LAST_FAILURE.resolved_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmm'))) -Force
}
Log 'done'
