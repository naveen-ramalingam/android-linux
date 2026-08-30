# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
