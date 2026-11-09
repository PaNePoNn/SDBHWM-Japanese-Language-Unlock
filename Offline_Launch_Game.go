// SDBHWM Offline Japanese Launcher
// Copyright (c) 2026. MIT licensed. Source included for auditing.
// This launcher only starts the user's existing Japanese-patched executable.
// It does not inject, tamper with, or emulate the Easy Anti-Cheat client.
// It is intended for offline single-player sessions only.
package main

import (
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "syscall"
    "unsafe"
)

const targetName = "SDBHeroes_WorldMission.exe"
const manifestName = "SDBHWM_JP_Offline_Manifest.txt"

func showError(msg string) {
    title, _ := syscall.UTF16PtrFromString("SDBHWM Offline Japanese Launcher")
    body, _ := syscall.UTF16PtrFromString(msg)
    proc := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
    proc.Call(0, uintptr(unsafe.Pointer(body)), uintptr(unsafe.Pointer(title)), 0x10)
}

func digestFile(path string) (string, error) {
    data, err := os.ReadFile(path)
    if err != nil { return "", err }
    h := sha256.Sum256(data)
    return hex.EncodeToString(h[:]), nil
}

func run() error {
    self, err := os.Executable()
    if err != nil { return err }
    dir := filepath.Dir(self)
    game := filepath.Join(dir, targetName)
    manifest := filepath.Join(dir, manifestName)
    expectedBytes, err := os.ReadFile(manifest)
    if err != nil {
        return fmt.Errorf("日本語版のインストール記録がありません。先に 01_Install_Japanese_Offline.cmd を実行してください。\n%v", err)
    }
    expected := strings.TrimSpace(string(expectedBytes))
    if len(expected) != 64 { return fmt.Errorf("インストール記録が不正です。") }
    actual, err := digestFile(game)
    if err != nil { return fmt.Errorf("ゲーム本体を開けません: %v", err) }
    if !strings.EqualFold(expected, actual) { return fmt.Errorf("ゲームEXEがパッチ適用時から変更されています。起動を中止します。\nCheck: %s", actual) }

    // This is the known direct-launch flag used by the verified offline launcher.
    // No EAC code is changed and no online anti-cheat session is established.
    args := []string{"-eac-nop-loaded"}
    args = append(args, os.Args[1:]...)
    cmd := exec.Command(game, args...)
    cmd.Dir = dir
    cmd.Env = os.Environ()
    if err := cmd.Start(); err != nil { return fmt.Errorf("ゲームの起動に失敗しました: %v", err) }
    return cmd.Wait()
}

func main() {
    if err := run(); err != nil { showError(err.Error()); os.Exit(1) }
}
