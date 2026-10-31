@echo off
rem 立即同步一次（切换电脑或系统前双击）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_auto.ps1"
echo.
echo 同步完成，日志在 %USERPROFILE%\*_sync_logs\ 。看到 pushed 或 done 即成功。
pause
