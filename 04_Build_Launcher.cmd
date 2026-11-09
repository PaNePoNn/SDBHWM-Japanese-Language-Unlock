@echo off
setlocal
cd /d "%~dp0"
where go >nul 2>&1
if errorlevel 1 (
  echo ERROR: Go is not installed or not in PATH. Install Go 1.23.2.
  exit /b 1
)
set "GOOS=windows"
set "GOARCH=386"
set "CGO_ENABLED=0"
go build -trimpath -ldflags="-s -w -H=windowsgui" -o Offline_Launch_Game.exe Offline_Launch_Game.go
if errorlevel 1 exit /b 1
powershell.exe -NoLogo -NoProfile -Command "$h=(Get-FileHash -LiteralPath 'Offline_Launch_Game.exe' -Algorithm SHA256).Hash.ToLowerInvariant(); if ($h -ne 'c17a7d2c4d8d4643a40d55ab981f6c868c00193176443eadc9aa4bf5e1eb3c0c') { Write-Host 'HASH MISMATCH. Use Go 1.23.2 and the specified flags.'; exit 1 }; Write-Host 'Launcher rebuild verified (SHA-256 match).'"
exit /b %ERRORLEVEL%
