# Build-only packaging script. Does not install/modify game files.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$files = @(
  '01_Install_Japanese_Offline.cmd',
  '02_Restore_Original.cmd',
  '03_Check_Status.cmd',
  'JP_Patcher.ps1',
  'Offline_Launch_Game.exe',
  'Offline_Launch_Game.go',
  'README_はじめに.txt',
  'README_EN.txt',
  'LICENSE.txt',
  'section_audit_reference.json'
)
$paths = foreach ($name in $files) {
  $p = Join-Path $root $name
  if (!(Test-Path -LiteralPath $p -PathType Leaf)) { throw "Missing: $name" }
  $p
}
$destination = Join-Path $root 'SDBHWM_Japanese_Language_Unlock_Rebuilt.zip'
Compress-Archive -LiteralPath $paths -DestinationPath $destination -Force
Write-Host "Created: $destination"
