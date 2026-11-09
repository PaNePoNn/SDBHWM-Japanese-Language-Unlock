@echo off
chcp 65001 >nul
title SDBHWM Japanese Patch
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0JP_Patcher.ps1" -Action Install
set "result=%ERRORLEVEL%"
echo.
pause
exit /b %result%
