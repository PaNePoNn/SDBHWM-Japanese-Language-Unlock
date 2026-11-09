@echo off
setlocal
cd /d "%~dp0"
call "04_Build_Launcher.cmd"
if errorlevel 1 exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp005_Build_Release.ps1"
exit /b %ERRORLEVEL%
