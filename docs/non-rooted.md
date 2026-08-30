# Non-rooted mode (PRoot)

PRoot lets you run Linux without root by emulating `chroot` in userspace (via `ptrace`).
It's the recommended path for unrooted devices and works seamlessly inside Termux.

## Getting Started with Termux

1. **Download Termux**:
   - [F-Droid](https://f-droid.org/en/packages/com.termux/) (Recommended)
   - [GitHub Releases](https://github.com/termux/termux-app/releases)
   - *(Do not install from Google Play Store)*

2. **One-Command Installation**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh | bash
   ```
   The installer automatically handles installing `proot` and required tools via `pkg`.

## Install Linux with PRoot

```bash
android-linux install --proot
```

Or simply run `android-linux install`; if no root is detected, the wizard recommends
PRoot automatically.

## How it works

PRoot binds `/dev`, `/proc`, `/sys`, and storage into the guest and rewrites paths so
the guest believes it is at `/`. Because it runs in userspace, it needs no privileges.

```bash
android-linux shell      # enter via proot
android-linux start      # no-op for proot (on-demand)
android-linux status     # reports "on-demand"
```

## Trade-offs vs chroot

| | PRoot | chroot |
|---|---|---|
| Root needed | No | Yes |
| Speed | Slower (ptrace) | Native |
| SELinux issues | Rare | Possible |
| Mount support | Emulated | Real |

For everyday use both are fine; chroot is faster for heavy workloads.
