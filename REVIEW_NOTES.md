# Security review notes

These notes are provided to Nexus Mods Support to describe the exact contents of the uploaded mod and help with inspection. They are not a security audit or a guarantee of acceptance.

## Provenance and files

The source files in this repository were copied without changes from `SDBHWM_Japanese_OneClick_Bilingual_Status.zip`, the current patch package. Specifically, `JP_Patcher.ps1`, the three `.cmd` files and `Offline_Launch_Game.go` are **identical** to that package's source files. The Go program has been compiled independently with Go 1.23.2, reproducing the exact bundled executable:

```text
Offline_Launch_Game.exe
SHA-256: c17a7d2c4d8d4643a40d55ab981f6c868c00193176443eadc9aa4bf5e1eb3c0c
Size:   1711616 bytes
```

`section_audit_reference.json` contains hashes of expected PE sections, for independent auditing. The installer also embeds expected PE-section hashes in `JP_Patcher.ps1` and verifies them before editing.

## Network access

The installer makes an HTTPS request to a fixed GitHub release URL:

```text
https://github.com/atom0s/Steamless/releases/download/v3.1.0.5/Steamless.v3.1.0.5.-.by.atom0s.zip
```

The download is verified against hardcoded SHA-256:

```text
e3e2d22e098ff3fb359b2876aa2bed9596f0501e6ff588cbffae90a76d2dc4f5
```

It extracts that download into a temporary folder, invokes its `Steamless.CLI.exe` on a **temporary copy** of the user's installed game EXE, and attempts to delete the temporary working directory afterward. No separate installer or package manager is used. **The external Steamless utility is not distributed by this repository.** Its use and the modified game EXE's compatibility are subject to third-party terms and Nexus Mods review.

## Local access and changes

- Searches standard Steam installation paths, Windows Steam registry entries and Steam `libraryfolders.vdf`. If necessary, opens a local game-EXE file chooser or prompts for a path.
- Reads hashes of `SDBHeroes_WorldMission.exe` and `Launch_Game.exe`. Rejects unexpected original binaries.
- Copies the user's original binaries to sibling files ending in `.JP_ORIGINAL_BACKUP`, if backups do not already exist.
- Changes the local game EXE to enable built-in Japanese language data after processing the user's own SteamStub-wrapped EXE.
- Writes `SDBHWM_JP_Offline_Manifest.txt` containing a SHA-256 of the patched local game EXE.
- Copies the self-built `Offline_Launch_Game.exe` to the game folder as `Launch_Game.exe`, retaining the previous official launcher in its backup file.
- Offers `Restore` and `Check` actions. Restoration requires the expected original game backup.

## Offline launcher behavior

The complete launcher source is `Offline_Launch_Game.go`. It reads the game EXE and patch manifest, validates their SHA-256, then starts the game from the install directory with a `-eac-nop-loaded` command-line argument. It forwards additional arguments. It does not modify EAC services, drivers or installation files. **This is not EAC-compatible online play; the EAC-enabled launcher has not been validated with this patch.**

## Review boundaries

- No game EXEs, CPK assets, EAC binaries, Steamless ZIP, user account files or other proprietary binaries are included in this source repository.
- The installer intentionally performs local EXE modification and uses an external SteamStub unpacking tool. These actions may raise DRM/anti-cheat and Nexus Mods policy issues, irrespective of the absence of proprietary binaries in this repository.
- Testing on all Windows configurations has not been performed; validated operation has been reported on one Windows game installation.
- Source availability and a matching Go build **do not** establish that the runtime download, overall installer, or uploaded binary is universally safe or permitted under applicable site rules.
- The script itself does not collect credentials or contain a telemetry endpoint. It may read Steam installation metadata, but its code contains no routine that uploads such data.
