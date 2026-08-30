# Architecture

AndroidLinux's design goal: run a Linux userspace **on top of the existing Android
kernel**, confined to Android storage, fully reversible.

## Principles

1. **Never replace Android.** No partition flashing, no bootloader unlock, no
   `boot.img` changes, no system-partition writes, no data erasure.
2. **Capability detection over hard-coding.** The installer probes what the device
   actually supports instead of assuming a device model or root manager.
3. **Safe by default.** Destructive operations are validated against a path allowlist.
4. **Graceful degradation.** Missing tools degrade to warnings, never crashes.

## Layers

```
┌────────────────────────────────────────────────────────┐
│  bin/android-linux          CLI dispatcher + wizard      │
├────────────────────────────────────────────────────────┤
│  lib/lifecycle.sh           mode-agnostic start/stop/shell│
│  lib/chroot.sh  lib/proot.sh                            │
├────────────────────────────────────────────────────────┤
│  lib/distro.sh + debian/ubuntu/alpine/archarm           │
│            download → verify → extract                  │
├────────────────────────────────────────────────────────┤
│  lib/detect.sh root.sh architecture.sh storage.sh       │
│  lib/network.sh filesystem.sh                           │
├────────────────────────────────────────────────────────┤
│  lib/common.sh   logging, config, path safety           │
└────────────────────────────────────────────────────────┘
```

## Execution modes

| Mode | Requirement | Mechanism |
|------|-------------|-----------|
| `chroot` | root + `chroot` binary | bind-mount `/proc` `/sys` `/dev` `/dev/pts` into rootfs |
| `proot` | `proot` binary | userspace ptrace-based chroot; no root needed |
| `termux` | Termux | lightweight environment inside Termux |

`recommend_mode()` chooses `chroot` when root is present, otherwise `proot`.

## Filesystem layout

```
<LINUX_BASE>/
├── rootfs/        # the extracted Linux filesystem (bin etc home ...)
├── downloads/     # downloaded rootfs archives
├── backups/       # created by `backup`
├── logs/          # per-install logs
├── config/        # install metadata
├── scripts/       # generated helper scripts
└── mounts/        # mount bookkeeping
```

Default bases:

- Termux: `$PREFIX/var/lib/android-linux`
- Rooted: `/data/local/android-linux`
- Other: `$HOME/android-linux`

## State machine

Installation state is persisted to `<LINUX_BASE>/.state` so an interrupted install can
resume: `DETECTED → DOWNLOADING → DOWNLOADED → VERIFIED → EXTRACTING → CONFIGURING → READY`.

## systemd

Android-hosted environments generally cannot run systemd. AndroidLinux never assumes it;
services start via OpenRC or direct invocation. `doctor` reports `systemd unavailable` as
a warning, not an error.
