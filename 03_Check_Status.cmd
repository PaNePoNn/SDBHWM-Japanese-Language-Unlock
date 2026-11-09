@echo off
chcp 65001 >nul
title SDBHWM Patcher status
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0JP_Patcher.ps1" -Action Check
set "result=%ERRORLEVEL%"
echo.
pause
exit /b %result%
