# 本机自动同步（Windows）：提交本地改动 → 拉取（只 rebase 自动提交）→ 推送。绝不 force。
param([string]$Repo = (Split-Path -Parent $PSScriptRoot))
$name = Split-Path -Leaf $Repo
$logDir = Join-Path $env:USERPROFILE ("{0}_sync_logs" -f $name)
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("auto_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
function Log($m) { $m | Out-File -FilePath $log -Append -Encoding utf8 }
Log "== auto sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =="
Set-Location $Repo
$branch = (git rev-parse --abbrev-ref HEAD).Trim()

git add -A
$staged = git diff --cached --name-only
if ($staged | Select-String -Pattern '(^|/)\.env$|\.pem$|\.key$|id_(rsa|ed25519)$|credentials\.json$') {
  Log 'STOP: credential-like file staged'; git reset -q; exit 2
}
$diff = git diff --cached -U0
if ($diff | Select-String -Pattern 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}') {
  Log 'STOP: secret-like content staged'; git reset -q; exit 2
}
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -q -m ("Auto sync {0} [auto-sync]" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
  Log ("committed " + (git rev-parse --short HEAD))
}

git fetch -q origin $branch
if ($LASTEXITCODE -ne 0) { Log 'fetch failed'; exit 3 }
$ahead  = [int](git rev-list --count "origin/$branch..HEAD")
$behind = [int](git rev-list --count "HEAD..origin/$branch")
if ($behind -gt 0) {
  if ($ahead -gt 0) {
    $nonAuto = git log --format=%s "origin/$branch..HEAD" | Where-Object { $_ -notmatch '\[auto-sync\]' }
    if ($nonAuto) { Log 'STOP: local non-auto commits diverged; resolve manually'; exit 4 }
    git rebase -q "origin/$branch"
    if ($LASTEXITCODE -ne 0) { git rebase --abort; Log 'STOP: rebase conflict'; exit 5 }
    Log "rebased $ahead auto commit(s)"
  } else {
    git merge -q --ff-only "origin/$branch"; Log "fast-forwarded $behind"
  }
}
if ([int](git rev-list --count "origin/$branch..HEAD") -gt 0) {
  git push -q origin $branch
  if ($LASTEXITCODE -ne 0) { Log 'push failed'; exit 6 }
  Log ("pushed " + (git rev-parse --short HEAD))
}
Log 'done'
