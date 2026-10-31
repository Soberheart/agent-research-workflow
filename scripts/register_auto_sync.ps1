# 登记 Windows 计划任务：每 20 分钟运行 sync_auto.ps1。允许用电池运行（笔记本拔电源也不停）。
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'sync_auto.ps1'
$repo = Split-Path -Parent $PSScriptRoot
$name = ('{0} Auto Sync' -f (Split-Path -Leaf $repo))
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"')
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 20) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Description 'Commit, pull (rebase auto commits only), push every 20 minutes' -Force | Out-Null
Write-Host "REGISTERED: $name (every 20 minutes). Running once now..."
Start-ScheduledTask -TaskName $name
