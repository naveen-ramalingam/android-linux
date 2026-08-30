# Troubleshooting

Start with the built-in diagnostics:

```bash
android-linux doctor
```

It prints `PASS` / `WARN` / `FAIL` for each check along with suggested fixes.

## Common issues

### `proot is not installed`
PRoot mode needs the `proot` binary. Inside Termux:

```bash
pkg install proot
```

### `xz missing` warning
Debian and Ubuntu rootfs archives are `.tar.xz`. Install the decoder:

```bash
pkg install xz-utils     # Termux
```

Alpine uses `.tar.gz` and does not need xz.

### `/proc not mounted` (chroot mode)
Run `android-linux start`. If it still fails, SELinux or the kernel may block bind
mounts — switch to PRoot:

```bash
android-linux install --proot
```

### Old-kernel warning
Kernels older than 4.0 run basic Linux userspace fine, but Docker, systemd, cgroups, and
FUSE may be unavailable. This is a limitation of the Android kernel, not AndroidLinux.

### Download fails
Check connectivity (`android-linux network`). Downloads support resume; re-running the
install continues where it left off instead of restarting.

### `Checksum mismatch`
The download was corrupted. Delete the file in `downloads/` and retry.

### Not enough space
Choose a smaller distro (Alpine) or skip the desktop. Required space is shown before you
confirm the install.

## Logs

```bash
android-linux logs
```

Verbose mode: `android-linux --debug ...` or `ANDROID_LINUX_DEBUG=1`.
