# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-08-30

### Security
- Harden `safe_remove` against symlink escapes: resolve the real path and refuse
  targets that resolve to a protected location or outside the install base.
- Reject tar archives containing absolute paths or `..` traversal members before
  extraction (rootfs install, restore, self-update, and bootstrap installer).
- Clean the rootfs before extraction so an interrupted install cannot merge into a
  corrupted hybrid filesystem.
- Fix command injection: shell-quote every argument passed through `su -c`.
- Fix SSH password injection: set guest passwords via base64 piped to `chpasswd`
  instead of embedding the raw password in a shell string.
- Validate SSH/VNC ports and Linux usernames before use in guest commands.
- Fail closed on checksum verification: a distro that publishes checksums can no
  longer be installed unverified silently; it now requires explicit confirmation.
- Gate Arch Linux ARM behind an explicit warning/confirmation (HTTP only, no checksum).
- Bind VNC to localhost by default and generate a random VNC password.
- Make PRoot binding of Android shared storage (/sdcard, /storage) opt-in.
- Reject protected system paths as the install base for every subcommand.
- Require `mktemp` for secure staging directories (no predictable fallback paths).

### Changed
- Use `--numeric-owner` only when the available tar supports it (toybox/busybox).
- Portable broken-symlink detection in `doctor` (no GNU-only `find -xtype`).
- Backup only includes layout directories that exist; validates the backup path.

### Added
- `tests/test-security.sh` covering quoting, validators, traversal, symlink escape,
  and fail-closed verification.

## [1.0.0] - 2026-08-30

### Added
- Universal device, Android, CPU, root, kernel, storage, RAM, SELinux, and Termux
  detection with safe fallbacks when commands are missing.
- Root detection for Magisk, KernelSU, and APatch with automatic `su` discovery.
- Execution modes: rooted **chroot**, **PRoot** (no root), and **Termux**, with an
  automatic recommendation.
- Distribution support: Debian (default), Debian stable, Ubuntu, Alpine, and Arch Linux
  ARM, sourced from official mirrors with SHA256 verification.
- Automatic architecture mapping (ARM64, ARM32, x86_64, x86).
- One-command installer (`install.sh`) and the `android-linux` CLI.
- Interactive menu and first-run wizard.
- Lifecycle commands: `install`, `uninstall`, `start`, `stop`, `restart`, `shell`,
  `status`, `info`, `update`, `backup`, `restore`, `network`, `ssh`, `desktop`,
  `doctor`, `logs`, `config`.
- Optional OpenSSH server (port 2222) and XFCE/LXQt desktop over VNC.
- Backup/restore with validation, `doctor` diagnostics, update, and safe uninstall.
- Path-safety validation that confines all destructive operations to the install base.
- Logging, debug mode, dry-run, and resumable installation state.
- ShellCheck-clean codebase and a phone-free test suite.
