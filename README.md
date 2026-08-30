<div align="center">

# AndroidLinux

**Run a real Linux distribution on Android — rooted or non-rooted — without replacing Android.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ShellCheck](https://github.com/naveen-ramalingam/android-linux/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/naveen-ramalingam/android-linux/actions/workflows/shellcheck.yml)
[![Tests](https://github.com/naveen-ramalingam/android-linux/actions/workflows/tests.yml/badge.svg)](https://github.com/naveen-ramalingam/android-linux/actions/workflows/tests.yml)

</div>

---

> **⚠️ Replace `naveen-ramalingam`** in the badges and one-line install command below with
> your GitHub username after forking this repository.

**AndroidLinux** is a universal, interactive, beginner-friendly installer that runs a
Linux distribution *inside* your existing Android storage. It detects your device,
Android version, CPU architecture, root status, kernel, and available resources, then
installs and manages Linux from a single command.

**It does NOT replace Android.** It never flashes partitions, unlocks bootloaders,
modifies `boot.img`, touches recovery, or erases your data. Everything is reversible.

---

## How it works

AndroidLinux runs a Linux **userspace** on top of your device's existing Android
kernel. It never installs a new kernel. Depending on what your device supports, it uses:

| Mode | Needs root? | How |
|------|:-----------:|-----|
| **Rooted chroot** | Yes | `chroot` with bind-mounted `/proc`, `/sys`, `/dev` |
| **PRoot** | No | Userspace `chroot` emulation via `proot` (works in Termux) |
| **Termux Linux** | No | Lightweight environment inside Termux |

The installer detects the best available method and recommends it.

---

## Requirements

- An Android device (any manufacturer), **or** a Linux/macOS host for testing.
- **Termux** (for non-rooted Android devices): Download from **F-Droid** or **GitHub Releases** (see [Termux Download Guide](#termux-download-guide)).
- ~2 GB free storage for a minimal install, ~5–6 GB with a desktop.
- Root (Magisk / KernelSU / APatch) is **optional** — PRoot works without it.

### Supported architectures

| CPU | Status |
|-----|--------|
| ARM64 (`aarch64`) | ✅ Full |
| ARM32 (`armhf` / `armv7`) | ✅ Full |
| x86_64 (`amd64`) | ✅ Where images exist |
| x86 (`i386`) | ✅ Where images exist |

---

## Termux Download Guide

> ⚠️ **IMPORTANT: DO NOT install Termux from the Google Play Store.**  
> The Google Play Store build of Termux is obsolete and deprecated (last updated in 2020 due to Android SDK restrictions). Its package manager will fail to fetch updates and packages.

### Recommended Download Sources

1. **[F-Droid](https://f-droid.org/en/packages/com.termux/)** *(Recommended)*:
   - Download and install the F-Droid app store or download the standalone Termux APK directly from the F-Droid page.
2. **[GitHub Releases](https://github.com/termux/termux-app/releases)**:
   - Download the latest APK asset (e.g. `termux-app_v..._arm64-v8a.apk` or `termux-app_v..._universal.apk`).

---

## Quick start (one command)

Open Termux (or your shell) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh | bash
```

Or:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh)
```

> **Note:** The installer automatically detects Termux and runs `pkg update` and installs any missing packages (`curl`, `git`, `proot`, `tar`, `xz-utils`) automatically.

Replace `naveen-ramalingam` with your GitHub username after forking:

The bootstrap script detects Termux, checks your architecture and required tools,
downloads the project, installs the `android-linux` command, and launches the
first-run wizard.

### Manual install

```bash
git clone https://github.com/naveen-ramalingam/android-linux.git
cd android-linux
./install.sh
```

---

## The `android-linux` command

Once installed, everything is managed through one command:

```bash
android-linux              # Interactive menu (no arguments)
```

| Command | Description |
|---------|-------------|
| `android-linux install` | Install a Linux distribution (interactive) |
| `android-linux uninstall` | Remove the installation (rootfs only — Android untouched) |
| `android-linux start` | Start the environment (mount/prepare) |
| `android-linux stop` | Stop the environment (unmount/cleanup) |
| `android-linux restart` | Restart the environment |
| `android-linux shell` | Enter an interactive Linux shell |
| `android-linux status` | Show installation and runtime status |
| `android-linux info` | Show device and capability detection |
| `android-linux update` | Update AndroidLinux scripts (keeps your rootfs) |
| `android-linux backup` | Back up rootfs + config |
| `android-linux restore <file>` | Restore from a backup archive |
| `android-linux network` / `ip` | Show network status, interface IPs, and connection commands |
| `android-linux ssh <sub>` | Manage SSH server (`install`/`start`/`stop`/`status`) |
| `android-linux desktop <sub>` | Manage desktop/VNC (`install`/`start`/`stop`/`status`) |
| `android-linux doctor` | Run diagnostics with suggested fixes |
| `android-linux logs` | Show recent log output |
| `android-linux config` | Show current configuration |

### Global options

```
--help             Show help
--version          Show version
--debug            Verbose debug logging
--non-interactive  Never prompt; use defaults
--dry-run          Show actions without downloading/mounting/deleting
--yes              Assume "yes" to confirmations
--root             Force rooted chroot mode
--proot            Force PRoot mode
--ssh              Auto-install and start OpenSSH server
--no-ssh           Skip OpenSSH installation
--desktop <de>     Desktop environment: xfce | lxqt | none
--distro <name>    debian | debian-stable | ubuntu | alpine | archarm
--path <dir>       Installation base directory
```

Example:

```bash
android-linux install --distro debian --proot --ssh --desktop xfce --yes
android-linux install --dry-run
```

---

## Supported distributions

| Distro | Key | Notes |
|--------|-----|-------|
| **Debian 13** (trixie) | `debian` | Default. Broad ARM support, huge package archive. |
| Debian 12 (bookworm) | `debian-stable` | Conservative choice. |
| Ubuntu 24.04 LTS | `ubuntu` | Familiar apt workflow. |
| Alpine Linux 3.20 | `alpine` | Smallest footprint (~350 MB). |
| Arch Linux ARM | `archarm` | Advanced, rolling release. |

Rootfs archives are pulled from **official sources** (Linux Containers image server,
`cdimage.ubuntu.com`, `dl-cdn.alpinelinux.org`, `os.archlinuxarm.org`) and verified
with SHA256 where the source publishes checksums.

---

## Optional extras

### SSH server

```bash
android-linux ssh install    # Installs OpenSSH on port 2222 and auto-starts it
android-linux ssh status     # Check if SSH server is running
android-linux ssh start      # Start SSH server
android-linux ssh stop       # Stop SSH server
```

Port **2222** is used by default because Android often occupies port 22. Connect from your computer:

```bash
ssh -p 2222 android@<device-ip>
```
*(Your device's IP can be found with `android-linux ip`)*

### Desktop (XFCE / LXQt) over VNC

```bash
android-linux desktop install xfce    # Installs XFCE + TigerVNC and auto-starts VNC
android-linux desktop status          # Check if VNC server is running
android-linux desktop start           # Start VNC server (:1, port 5901)
android-linux desktop stop            # Stop VNC server
```

#### Connecting to the Desktop:

1. **On your Android Phone:**
   - Install **[AVNC](https://f-droid.org/packages/com.gaurav.avnc/)** (recommended on F-Droid) or **bVNC**.
   - Connect to `127.0.0.1:5901` with your VNC password.

2. **From your Mac / PC:**
   - Run an SSH tunnel:
     ```bash
     ssh -p 2222 -L 5901:127.0.0.1:5901 android@<device-ip>
     ```
   - Open your VNC viewer (e.g. macOS Screen Sharing `vnc://localhost:5901` or RealVNC) and connect to `localhost:5901`.

---

## Safety model

AndroidLinux is designed to be **safe by default**:

- Never writes to `/`, `/system`, `/vendor`, `/product`, `/proc`, `/sys`, `/dev`, or
  `/etc`. These paths are rejected by a built-in path validator.
- All destructive operations (`rm -rf`) are confined to the AndroidLinux base directory
  and validated before running.
- Never modifies SELinux, boot images, recovery, or system partitions.
- Never assumes `systemd` (Android-hosted environments usually can't run it).
- Downloads are **verify → extract**, never **download → execute**.

Run `android-linux doctor` at any time for a health check with suggested fixes.

---

## Backup and restore

```bash
android-linux backup                       # Creates backups/android-linux-backup-*.tar.gz
android-linux restore path/to/backup.tar.gz
```

Backups contain the rootfs and configuration. They never include Android's `/data`
partition. Restores are validated before any data is overwritten.

---

## Project layout

```
android-linux/
├── install.sh            # One-command bootstrap installer
├── uninstall.sh          # Safe uninstall wrapper
├── bin/
│   └── android-linux     # Main CLI (dispatcher + interactive menu + wizard)
├── lib/
│   ├── common.sh         # Logging, colors, config, path safety, helpers
│   ├── detect.sh         # Device/Android/kernel/SELinux/Termux detection
│   ├── root.sh           # Root + provider detection (Magisk/KernelSU/APatch)
│   ├── architecture.sh   # CPU detection + distro arch mapping
│   ├── storage.sh        # Storage/RAM detection
│   ├── network.sh        # Connectivity + DNS
│   ├── filesystem.sh     # Install layout + FHS tree
│   ├── distro.sh         # Registry + download/verify/extract
│   ├── debian.sh ubuntu.sh alpine.sh archarm.sh   # Per-distro sources
│   ├── chroot.sh         # Rooted chroot lifecycle
│   ├── proot.sh          # PRoot (non-root) lifecycle
│   ├── lifecycle.sh      # Mode-agnostic dispatcher
│   ├── ssh.sh desktop.sh # Optional services
│   ├── backup.sh restore.sh doctor.sh update.sh uninstall.sh
├── profiles/
│   ├── generic.sh        # Default profile (no device quirks)
│   └── devices/          # Optional per-device overrides
├── configs/default.conf
├── tests/                # ShellCheck-clean test suite (no phone needed)
├── docs/                 # In-depth documentation
└── .github/              # CI, issue templates
```

---

## Testing

The test suite mocks rooted/non-rooted Android environments, multiple architectures,
missing tools, old kernels, and SELinux enforcing — **no physical phone required**.

```bash
bash tests/run-all.sh
```

Lint with [ShellCheck](https://www.shellcheck.net/):

```bash
shellcheck install.sh uninstall.sh bin/android-linux lib/*.sh profiles/*.sh tests/*.sh
```

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `proot is not installed` | `pkg install proot` inside Termux |
| `xz missing` warning | `pkg install xz-utils` (needed for Debian/Ubuntu) |
| `/proc not mounted` | Run `android-linux start`, or switch to PRoot mode |
| Old-kernel warning | Expected on kernels < 4.0; Docker/systemd/FUSE may be unavailable |
| SELinux blocks a mount | Use PRoot mode instead of chroot |

Run `android-linux doctor` for guided diagnostics. See
[docs/troubleshooting.md](docs/troubleshooting.md) for more.

---

## FAQ

**Does this replace Android or void my warranty?**
No. AndroidLinux lives inside Android storage and runs on your existing kernel. Nothing
is flashed, and everything can be removed with `android-linux uninstall`.

**Do I need root?**
No. Root enables the faster `chroot` mode, but PRoot works on unrooted devices.

**Does `systemd` work?**
Usually not inside Android-hosted environments. Services use OpenRC or manual startup.

**Can I use my SD card?**
You can point `--path` at writable storage, but many SD cards use filesystems that don't
support Linux permissions. Internal/Termux storage is recommended.

---

## Documentation

- [Architecture & design](docs/architecture.md)
- [Installation guide](docs/installation.md)
- [Rooted mode (chroot)](docs/rooted.md)
- [Non-rooted mode (proot)](docs/non-rooted.md)
- [Desktop & VNC](docs/desktop.md)
- [SSH](docs/ssh.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security](docs/security.md)
- [Supported devices](docs/supported-devices.md)

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the
[Code of Conduct](CODE_OF_CONDUCT.md). Security issues go through
[SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
