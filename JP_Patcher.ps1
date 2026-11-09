#Requires -Version 5.1
param(
  [ValidateSet('Install','Restore','Check')][string]$Action = 'Install',
  [string]$GameDir = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# This script never installs, modifies or interacts with an EAC service or driver.
# It installs a new offline-only launch wrapper in place of Launch_Game.exe
# after preserving the existing launcher. No code from the game is distributed.
$AppId = '798510'
$GameFolder = 'SUPER DRAGON BALL HEROES WORLD MISSION'
$GameExeName = 'SDBHeroes_WorldMission.exe'
$LauncherName = 'Launch_Game.exe'
$ManifestName = 'SDBHWM_JP_Offline_Manifest.txt'
$OriginalExeSHA = '10d27b52dcc817ba955bb6b395b44a663c0567ad19b14fd95d077fb6a2fcc494'
$PatchedExeSHA  = '4e5fd4d8e8336649bee5bc8cc10b324dd925a484a9326ff67f5c83afd7ee1cae'
$UnpackedSHA    = 'b93550e180d6f63bf7a975c10f928c035253ef431215c74784d658f2eda02e06'
$OfficialLauncherSHA = 'c3f63d3209016f4c261fee86042506ed78852bb8f22bb99649f171316ecb0f56'
$KnownLegacyOfflineLauncherSHA = 'e03885d62c55c4e88bd267c5ded515d4cb8afc28e36b820f8cf3cdbc8e72b8d0'
$OwnLauncherSHA = 'c17a7d2c4d8d4643a40d55ab981f6c868c00193176443eadc9aa4bf5e1eb3c0c'
$OriginalExeBackup = $GameExeName + '.JP_ORIGINAL_BACKUP'
$OriginalLauncherBackup = $LauncherName + '.JP_ORIGINAL_BACKUP'
$SteamlessUrl = 'https://github.com/atom0s/Steamless/releases/download/v3.1.0.5/Steamless.v3.1.0.5.-.by.atom0s.zip'
$SteamlessZipSHA = 'e3e2d22e098ff3fb359b2876aa2bed9596f0501e6ff588cbffae90a76d2dc4f5'

function Say([string]$message) { }
function Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Fail([string]$message) { throw $message }
function AssertHash([string]$path,[string]$expected,[string]$label) {
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) { Fail "$label が見つかりません。" }
  $actual = Sha $path
  if ($actual -ne $expected) { Fail "$label の確認に失敗しました。" }
}

function FindGameDirectory {
  $candidates = New-Object 'System.Collections.Generic.List[string]'
  if ($GameDir) { $candidates.Add($GameDir) }
  if (Test-Path -LiteralPath (Join-Path $PSScriptRoot $GameExeName)) { $candidates.Add($PSScriptRoot) }
  foreach ($drive in [IO.DriveInfo]::GetDrives()) {
    if (!$drive.IsReady -or $drive.DriveType -ne [IO.DriveType]::Fixed) { continue }
    foreach ($base in @('Steam','SteamLibrary','Games\Steam','Program Files (x86)\Steam','Program Files\Steam')) {
      $candidates.Add((Join-Path $drive.RootDirectory.FullName (Join-Path $base ('steamapps\common\' + $GameFolder))))
    }
  }
  $steamRoots = New-Object 'System.Collections.Generic.List[string]'
  try {
    $steamReg = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop
    if ($steamReg.SteamPath) { $steamRoots.Add(([string]$steamReg.SteamPath).Replace('/','\')) }
  } catch { }
  try {
    $reg = Get-ItemProperty 'HKLM:\Software\WOW6432Node\Valve\Steam' -ErrorAction Stop
    if ($reg.InstallPath) { $steamRoots.Add([string]$reg.InstallPath) }
  } catch { }
  foreach ($root in $steamRoots) {
    $candidates.Add((Join-Path $root ('steamapps\common\' + $GameFolder)))
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      foreach ($line in [IO.File]::ReadAllLines($vdf)) {
        if ($line -match '^\s*"path"\s+"([^\"]+)"') {
          $lib = $matches[1].Replace('\\','\')
          $candidates.Add((Join-Path $lib ('steamapps\common\' + $GameFolder)))
        }
      }
    }
  }
  foreach ($candidate in $candidates) {
    $candidate = $candidate.Trim('"').Trim()
    if ([IO.Path]::GetFileName($candidate) -eq $GameExeName) { $candidate = Split-Path -Parent $candidate }
    if (Test-Path -LiteralPath (Join-Path $candidate $GameExeName) -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  Write-Host 'ゲーム本体を選択してください。'
  Say "Steamのゲームフォルダ、または $GameExeName を選択してください。"
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.OpenFileDialog
    $picker.Title = 'SDBHWM ゲーム本体を選択'
    $picker.Filter = 'SDBHWM game EXE|SDBHeroes_WorldMission.exe'
    if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      $chosen = $picker.FileName
      if ([IO.Path]::GetFileName($chosen) -ne $GameExeName) { Fail '異なるファイルが選択されました。' }
      return (Split-Path -Parent $chosen)
    }
  } catch { Say ('ファイル選択ダイアログを開けません: ' + $_.Exception.Message) }
  $value = (Read-Host 'ゲームフォルダまたはゲームEXEのフルパスを入力').Trim('"').Trim()
  if ([IO.Path]::GetFileName($value) -eq $GameExeName) { $value = Split-Path -Parent $value }
  if (!(Test-Path -LiteralPath (Join-Path $value $GameExeName) -PathType Leaf)) { Fail 'ゲームEXEが見つかりません。' }
  return (Resolve-Path -LiteralPath $value).Path
}

function SectionOffsetAndAssert([byte[]]$bytes) {
  if ($bytes.Length -ne 23419904) { Fail "Steamlessの出力サイズが未対応です: $($bytes.Length)" }
  if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { Fail 'MZ署名がありません。' }
  $pe = [int][BitConverter]::ToUInt32($bytes,0x3C)
  if ($pe -lt 0x40 -or ($pe+264) -gt $bytes.Length) { Fail 'PEヘッダーが破損しています。' }
  if ($bytes[$pe] -ne 0x50 -or $bytes[$pe+1] -ne 0x45 -or $bytes[$pe+2] -ne 0 -or $bytes[$pe+3] -ne 0) { Fail 'PE署名が異なります。' }
  $n = [int][BitConverter]::ToUInt16($bytes,$pe+6)
  $opt = $pe+24
  if ([BitConverter]::ToUInt16($bytes,$opt) -ne 0x20B) { Fail 'x64実行ファイルではありません。' }
  $entry = [BitConverter]::ToUInt32($bytes,$opt+16)
  if ($n -ne 8 -or $entry -ne 0xDB7014) { Fail 'EXEの構成またはエントリーポイントが未対応です。' }
  $sec = $opt + [BitConverter]::ToUInt16($bytes,$pe+20)
  if (($sec + $n*40) -gt $bytes.Length) { Fail 'PEのセクション情報が破損しています。' }
  $sections = @{}
  for ($i=0; $i -lt $n; $i++) {
    $o = $sec+40*$i
    $name = [Text.Encoding]::ASCII.GetString($bytes,$o,8).TrimEnd([char]0)
    $rva = [int64][BitConverter]::ToUInt32($bytes,$o+12)
    $size = [int64][BitConverter]::ToUInt32($bytes,$o+16)
    $ptr = [int64][BitConverter]::ToUInt32($bytes,$o+20)
    if ($ptr+$size -gt $bytes.Length) { Fail "セクション$name が範囲外です。" }
    if ($sections.ContainsKey($name)) { Fail 'セクション名が重複しています。' }
    $sections[$name] = @{ rva=$rva; size=$size; ptr=$ptr }
  }
  $expected = @{
    '.text'='e31a5c2b2d7c74a5931d2da60b11db856764b36d9155a6a77bfaa1a301554144'
    '.rdata'='f3de9df3a073a1d4ce6d61508c6f3766ab3395ee79da127067be80b5c652f204'
    '.data'='e9c7f11bbfd74957421d697704ff36bda96e49e088f4506cbdc62a420895f3b3'
    '.pdata'='5b60ab1c7b8169b244b6dcffdf2a28de447a5246b6049f8a4fef6e2c31ab898b'
    '.gfids'='bca378a61d98cb6be76c1d67cf14eab3ed06188d67a25b71ee20c6753f4ed41a'
    '.tls'='4c6474903705cb450bb6434c29e8854f17d8324efca1fdb9ee9008599060883a'
    '.rsrc'='727212ce8300f846139f15df24591ea91fa69435424795bb2648cfbc828b70ac'
    '.reloc'='128d99ac80fbbc952bc2c88d58a1a3065b36e3bbfa8d208efc7b81f9d50f890a'
  }
  if ($sections.Count -ne $expected.Count) { Fail '予期しないPEセクションがあります。' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    foreach ($name in $expected.Keys) {
      if (!$sections.ContainsKey($name)) { Fail "セクション $name がありません。" }
      $s=$sections[$name]
      $digest = [BitConverter]::ToString($sha.ComputeHash($bytes,[int]$s.ptr,[int]$s.size)).Replace('-','').ToLowerInvariant()
      if ($digest -ne $expected[$name]) { Fail "セクション $name の一致確認に失敗。別のバージョン・別の展開結果です。" }
    }
  } finally { $sha.Dispose() }
  $data=$sections['.data']
  $rva=0x150B300
  if ($rva -lt $data.rva -or ($rva+32) -gt ($data.rva+$data.size)) { Fail '日本語化の対象が.dataセクションにありません。' }
  $patchAt=[int]($data.ptr+$rva-$data.rva)
  for ($i=0;$i -lt 8;$i++) {
    $val=[BitConverter]::ToUInt32($bytes,$patchAt+4*$i)
    if ($val -ne ($i+1)) { Fail "言語ホワイトリストが想定外 ($i = $val)。" }
  }
  return $patchAt
}

function DownloadAndUnpackSteamless([string]$temp) {
  $zip = Join-Path $temp 'Steamless_official.zip'
  $out = Join-Path $temp 'Steamless'
  Say 'Steamless v3.1.0.5 を作者のGitHubから取得します（約611KB）。'
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  Invoke-WebRequest -UseBasicParsing -Uri $SteamlessUrl -OutFile $zip -MaximumRedirection 8
  AssertHash $zip $SteamlessZipSHA 'Steamless公式ZIP'
  Expand-Archive -LiteralPath $zip -DestinationPath $out
  $cli = Get-ChildItem -LiteralPath $out -Filter 'Steamless.CLI.exe' -Recurse -File | Select-Object -First 1
  if (!$cli) { Fail 'Steamless.CLI.exeがZIP内にありません。' }
  if (!(Test-Path -LiteralPath (Join-Path $cli.DirectoryName 'Plugins') -PathType Container)) { Fail 'Steamlessプラグインが見つかりません。' }
  return $cli.FullName
}

$workspace = $null
try {
  if ($Action -eq 'Check') { Write-Host 'SDBHWM Patch Status / 日本語化状態' }
  else { Write-Host 'SDBHWM 日本語化パッチ' }
  if ($Action -eq 'Install') { Write-Host '準備しています...' }
  $dir = FindGameDirectory
  $game = Join-Path $dir $GameExeName
  $launch = Join-Path $dir $LauncherName
  $manifest = Join-Path $dir $ManifestName
  $gameBak = Join-Path $dir $OriginalExeBackup
  $launchBak = Join-Path $dir $OriginalLauncherBackup
  $launcherSource = Join-Path $PSScriptRoot 'Offline_Launch_Game.exe'
  Say "ゲームフォルダ: $dir"
  $gameHash = Sha $game
  Say "ゲームEXE SHA-256: $gameHash"
  $launcherHash = if (Test-Path -LiteralPath $launch -PathType Leaf) { Sha $launch } else { '' }
  $manifestHash = ''
  if (Test-Path -LiteralPath $manifest -PathType Leaf) { $manifestHash = ([IO.File]::ReadAllText($manifest)).Trim().ToLowerInvariant() }
  Say "ランチャー SHA-256: $launcherHash"

  if ($Action -eq 'Check') {
    if ($gameHash -eq $OriginalExeSHA) { Write-Host 'Game / ゲーム: Original (not patched) / 日本語化前' }
    elseif ($gameHash -eq $PatchedExeSHA) { Write-Host 'Game / ゲーム: Japanese enabled / 日本語化済み' }
    elseif ($gameHash -eq $manifestHash -and $gameHash.Length -eq 64) { Write-Host 'Game / ゲーム: Japanese enabled / 日本語化済み' }
    else { Write-Host 'Game / ゲーム: Unrecognized file / 未確認のファイル' }
    if ($launcherHash -eq $OwnLauncherSHA) { Write-Host 'Launcher / 起動設定: Offline launcher installed / パッチ適用済み' }
    elseif ($launcherHash -eq $OfficialLauncherSHA) { Write-Host 'Launcher / 起動設定: Official launcher / 公式版' }
    elseif ($launcherHash -eq $KnownLegacyOfflineLauncherSHA) { Write-Host 'Launcher / 起動設定: Existing compatible launcher / 既存の対応版' }
    else { Write-Host 'Launcher / 起動設定: Unknown / 未確認' }
    exit 0
  }

  if ($Action -eq 'Restore') {
    if (!(Test-Path -LiteralPath $gameBak -PathType Leaf)) { Fail '元ゲームEXEのバックアップがありません。' }
    AssertHash $gameBak $OriginalExeSHA '元ゲームEXEバックアップ'
    $manifestHash = ''
    if (Test-Path -LiteralPath $manifest -PathType Leaf) { $manifestHash = ([IO.File]::ReadAllText($manifest)).Trim().ToLowerInvariant() }
    if ($gameHash -ne $OriginalExeSHA -and $gameHash -ne $PatchedExeSHA -and $gameHash -ne $manifestHash) { Fail 'ゲームEXEが別バージョンです。安全のため復元を中止しました。' }
    if ((Test-Path -LiteralPath $launchBak -PathType Leaf) -and $launcherHash -ne $OwnLauncherSHA -and $launcherHash -ne $OfficialLauncherSHA) { Fail 'ランチャーが別バージョンです。自動上書きを中止しました。' }
    if (Test-Path -LiteralPath $launchBak -PathType Leaf) { AssertHash $launchBak $OfficialLauncherSHA '元ランチャーバックアップ' }
    Copy-Item -LiteralPath $gameBak -Destination $game -Force
    if (Test-Path -LiteralPath $launchBak -PathType Leaf) { Copy-Item -LiteralPath $launchBak -Destination $launch -Force }
    if (Test-Path -LiteralPath $manifest -PathType Leaf) { Remove-Item -LiteralPath $manifest -Force }
    Write-Host '復元が完了しました。' -ForegroundColor Green
    exit 0
  }

  # Preflight all existing files BEFORE changing anything.
  AssertHash $launcherSource $OwnLauncherSHA '同梱オフラインランチャー'
  if ($gameHash -ne $OriginalExeSHA -and $gameHash -ne $PatchedExeSHA -and $gameHash -ne $manifestHash) { Fail 'ゲームEXEが未対応です。Steamで元EXEへ戻してから実行してください。' }
  if ($launcherHash -ne $OfficialLauncherSHA -and $launcherHash -ne $KnownLegacyOfflineLauncherSHA -and $launcherHash -ne $OwnLauncherSHA) { Fail '未確認のLaunch_Game.exeです。既存ファイルを保護するため、処理を中止しました。' }
  if (Test-Path -LiteralPath $gameBak -PathType Leaf) { AssertHash $gameBak $OriginalExeSHA '元ゲームEXEバックアップ' }
  if (Test-Path -LiteralPath $launchBak -PathType Leaf) { AssertHash $launchBak $OfficialLauncherSHA '元ランチャーバックアップ' }
  if (($gameHash -eq $PatchedExeSHA -or ($gameHash -eq $manifestHash -and $gameHash.Length -eq 64)) -and $launcherHash -ne $OfficialLauncherSHA) {
    Write-Host 'すでに日本語化されています。' -ForegroundColor Green
    exit 0
  }

  $workspace = Join-Path ([IO.Path]::GetTempPath()) ('SDBHWM_JP_' + [guid]::NewGuid().ToString('N'))
  [void](New-Item -ItemType Directory -Path $workspace)
  $candidate = Join-Path $workspace $GameExeName
  if ($gameHash -eq $OriginalExeSHA) {
    Write-Host '日本語化を適用しています...'
    $cli = DownloadAndUnpackSteamless $workspace
    $tempOriginal = Join-Path $workspace $GameExeName
    Copy-Item -LiteralPath $game -Destination $tempOriginal
    Say '自分の正規EXEのSteamStubを一時フォルダで展開中です。'
    $a='--keepstub "' + $tempOriginal + '"'
    $p = Start-Process -FilePath $cli -ArgumentList $a -WorkingDirectory (Split-Path -Parent $cli) -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $workspace 'unpack_stdout.log') -RedirectStandardError (Join-Path $workspace 'unpack_stderr.log')
    $unpacked = $tempOriginal + '.unpacked.exe'
    if ($p.ExitCode -ne 0 -or !(Test-Path -LiteralPath $unpacked -PathType Leaf)) { Fail "Steamlessの展開に失敗: 終了コード $($p.ExitCode)" }
    $bytes = [IO.File]::ReadAllBytes($unpacked)
    $patchAt = SectionOffsetAndAssert $bytes
    $bytes[$patchAt] = 0
    [IO.File]::WriteAllBytes($candidate,$bytes)
    $result = Sha $candidate
    Say "日本語化済みSHA-256: $result"
    if ($result -ne $PatchedExeSHA) {
      # Eight section digests (including the restored language bytes) were all
      # checked against the successful user's EXE before the one-byte edit.
      # Steamless can differ in non-code PE metadata. This is experimental.
      Write-Host '注意: EXEの形式が検証済み版と異なります。正常起動は未確認です。' -ForegroundColor Yellow
    } else {
      # Verified candidate: no extra console output.
    }
  }

  # The first install may already have a verified Japanese-patched EXE.
  # Make the backup of official data only after preflight and candidate validation.
  if ($gameHash -eq $OriginalExeSHA) {
    if (!(Test-Path -LiteralPath $gameBak)) {
      Copy-Item -LiteralPath $game -Destination $gameBak
      AssertHash $gameBak $OriginalExeSHA '作成した元ゲームEXEバックアップ'
    }
  } elseif (!(Test-Path -LiteralPath $gameBak)) {
    Say '警告: 元ゲームEXEのバックアップはありません。Steamの整合性チェックで復元できます。'
  }
  if ($launcherHash -eq $OfficialLauncherSHA -and !(Test-Path -LiteralPath $launchBak)) {
    Copy-Item -LiteralPath $launch -Destination $launchBak
    AssertHash $launchBak $OfficialLauncherSHA '作成した元ランチャーバックアップ'
  }
  Say 'ファイル適用中です。'
  if ($gameHash -eq $OriginalExeSHA) {
    Copy-Item -LiteralPath $candidate -Destination $game -Force
    $installedHash = Sha $game
    if ($installedHash -ne $result) { Fail 'インストールした日本語化ゲームEXEの照合に失敗しました。' }
  }
  $expectedGameHash = Sha $game
  [IO.File]::WriteAllText($manifest,$expectedGameHash + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  if ($launcherHash -eq $OfficialLauncherSHA) {
    Copy-Item -LiteralPath $launcherSource -Destination $launch -Force
    AssertHash $launch $OwnLauncherSHA 'インストールしたオフラインランチャー'
    Say '公式EAC起動ランチャーをバックアップし、直接起動するオフライン用に切り替えました。'
  } elseif ($launcherHash -eq $KnownLegacyOfflineLauncherSHA) {
    Say '既存の動作済みオフラインランチャーをそのまま維持しました。'
  } else {
    Say 'オフライン用ランチャーはすでに導入されています。'
  }
  Say ''
  Write-Host '完了しました。Steamから起動してください。' -ForegroundColor Green
} catch {
  Write-Host ''
  Write-Host ('エラー: ' + $_.Exception.Message) -ForegroundColor Red
  Write-Host '失敗した場合は、READMEの復元手順を確認してください。' -ForegroundColor Yellow
  exit 1
} finally {
  if ($workspace -and (Test-Path -LiteralPath $workspace)) {
    try { Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  }
}
