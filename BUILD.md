# Build and release instructions

These instructions are intended to let Nexus Mods reviewers rebuild the **exact launcher binary** contained in the uploaded patch and inspect every installer script. No game files are needed to compile the launcher.

## Prerequisites

1. **Go 1.23.2** (the Go compiler and standard library) from <https://go.dev/dl/>. The original binary was built with this version.
2. **Windows 10/11** to run the `.cmd` and PowerShell scripts, or Linux/macOS with Go 1.23.2 for cross-compiling the launcher.
3. **Windows PowerShell 5.1** (built into Windows) for packaging and for installer script execution.
4. No Go modules, package manager libraries, vendor files or proprietary SDKs are required. The launcher uses the Go standard library only.

## Step 1 — Get all source files

Clone this repository (or download its GitHub ZIP and extract it). Keep the files at the repository root. Ensure `Offline_Launch_Game.go`, `JP_Patcher.ps1`, the three numbered `.cmd` scripts, both README files, `LICENSE.txt` and `section_audit_reference.json` are present.

## Step 2 — Build `Offline_Launch_Game.exe`

On Windows, open **Command Prompt** in the repository directory and run:

```cmd
set GOOS=windows
set GOARCH=386
set CGO_ENABLED=0
go build -trimpath -ldflags="-s -w -H=windowsgui" -o Offline_Launch_Game.exe Offline_Launch_Game.go
certutil -hashfile Offline_Launch_Game.exe SHA256
```

Alternatively, double-click `04_Build_Launcher.cmd`. It builds the launcher and verifies its SHA-256 automatically.

On Linux/macOS with Go 1.23.2:

```sh
GOOS=windows GOARCH=386 CGO_ENABLED=0 go build -trimpath -ldflags='-s -w -H=windowsgui' -o Offline_Launch_Game.exe Offline_Launch_Game.go
sha256sum Offline_Launch_Game.exe
```

### Expected result

- Filename: `Offline_Launch_Game.exe`
- Windows x86 (386), GUI subsystem; no CGO dependencies. It can launch the separately installed 64-bit game EXE.
- File length: **1,711,616 bytes**.
- Expected SHA-256: `c17a7d2c4d8d4643a40d55ab981f6c868c00193176443eadc9aa4bf5e1eb3c0c`

The supplied Go code and the command above were tested with Go 1.23.2 and reproduced the *exact* uploaded launcher EXE byte for byte. Newer Go versions may create different binaries and hashes.

## Step 3 — Build the distributable ZIP

Run `05_Build_Release.cmd`. It executes the launcher build and packages the following files at ZIP root:

```text
01_Install_Japanese_Offline.cmd
02_Restore_Original.cmd
03_Check_Status.cmd
JP_Patcher.ps1
Offline_Launch_Game.exe
Offline_Launch_Game.go
README_はじめに.txt
README_EN.txt
LICENSE.txt
section_audit_reference.json
```

The resulting archive is `SDBHWM_Japanese_Language_Unlock_Rebuilt.zip`. ZIP timestamps/compression metadata may differ from the original upload; the individual source files and launcher binary are what should be compared.

The installer scripts are plain text. **They are not compiled.** The separate script `05_Build_Release.ps1` only assembles the archive and is not required at runtime.

## Step 4 — Inspection notes (do not execute on a reviewer's game automatically)

- `01_Install_Japanese_Offline.cmd` invokes `JP_Patcher.ps1 -Action Install`.
- `02_Restore_Original.cmd` invokes `JP_Patcher.ps1 -Action Restore`.
- `03_Check_Status.cmd` invokes `JP_Patcher.ps1 -Action Check`.
- On `Install`, the PowerShell script checks specific known SHA-256 values for the original game files and launcher. If supported, it downloads the pinned Steamless release, validates its ZIP SHA-256 and uses its CLI to process the *user's local copy* of the game EXE before applying a language-enable change. It saves backups and replaces `Launch_Game.exe` with the compiled offline launcher.
- The offline launcher checks the local patch manifest against the game EXE and starts it using `-eac-nop-loaded`.
- This workflow does not contain or redistribute proprietary game binaries, Steamless binaries or EAC binaries. **It does alter the user's local game installation and is not intended for EAC-protected online play.**

See [REVIEW_NOTES.md](REVIEW_NOTES.md) for exact network endpoints, expected hashes, file writes and limitations.
