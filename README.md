# SDBHWM – Japanese Language Unlock

Source repository for the **SDBHWM – Japanese Language Unlock** patch submitted to Nexus Mods for security review. This repository contains the source files from the current distributed package, together with reproducible build and review instructions.

The patch targets **SUPER DRAGON BALL HEROES WORLD MISSION (Steam, Windows)**. It enables Japanese language data already present in the user's game installation and replaces the official launcher with a locally built offline-only launcher. **This is not an official game patch.**

## Source and build

- `JP_Patcher.ps1`: installer, restore/status commands, Steam library discovery, file checks, game patching and external tool download.
- `01_Install_Japanese_Offline.cmd`, `02_Restore_Original.cmd`, `03_Check_Status.cmd`: entry points that call the PowerShell script.
- `Offline_Launch_Game.go`: **complete source** of the compiled offline launcher included in the Nexus Mods upload.
- `section_audit_reference.json`: supplemental PE-section audit digests.
- `README_はじめに.txt`, `README_EN.txt`, `LICENSE.txt`: distributed documentation and license.
- `BUILD.md`: step-by-step instructions to recreate the launcher and release archive.
- `REVIEW_NOTES.md`: details on network access, game-file modifications, checksums and limitations.

### Build the launcher

Install **Go 1.23.2** and run `04_Build_Launcher.cmd` on Windows, or use the manual command documented in [BUILD.md](BUILD.md). The documented build produces `Offline_Launch_Game.exe` with SHA-256:

`c17a7d2c4d8d4643a40d55ab981f6c868c00193176443eadc9aa4bf5e1eb3c0c`

The byte-identical rebuild was verified on Linux with Go 1.23.2 targeting Windows/386. No third-party binary or proprietary game EXE is checked into this repository.

## Safety and support limitations

The installer downloads Steamless from its author's GitHub release and verifies its pinned SHA-256; Steamless itself is **not** included in the source or release ZIP. The installer processes the user's locally installed Steam game EXE, creates backup files, and installs an offline-only launcher. The launcher starts the locally installed game using an argument indicating EAC is not loaded. It does **not** patch an EAC service or driver. The official EAC launcher is not supported by the patched game. Online play is not recommended.

This source disclosure is for security inspection, not a claim that Nexus Mods has approved publication or that DRM/anti-cheat related modifications are permitted under any particular terms. See [REVIEW_NOTES.md](REVIEW_NOTES.md).
