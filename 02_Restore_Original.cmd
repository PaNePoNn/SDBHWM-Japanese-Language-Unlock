@echo off
chcp 65001 >nul
title SDBHWM Restore original files
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0JP_Patcher.ps1" -Action Restore
set "result=%ERRORLEVEL%"
echo.
pause
exit /b %result%
