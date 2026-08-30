# Security

AndroidLinux treats security as a first-class concern.

## What it will never do

- Flash partitions or modify `boot`, `recovery`, or `system`.
- Unlock the bootloader.
- Disable SELinux or Android security features.
- Erase user data.
- Execute a downloaded script without verification.

## Download pipeline

Every rootfs follows **download → verify → extract**:

1. Download over HTTPS from the official source.
2. Verify SHA256 when the source publishes checksums.
3. Only then extract into the rootfs.

Archives are never executed. Sources used:

| Distro | Source |
|--------|--------|
| Debian / Ubuntu (containers) | `images.linuxcontainers.org` |
| Ubuntu base | `cdimage.ubuntu.com` |
| Alpine | `dl-cdn.alpinelinux.org` |
| Arch Linux ARM | `os.archlinuxarm.org` |

## Path safety

A path validator rejects protected locations before any destructive operation:

- Exact-match block: `/`, `/data`, `/storage`, `/sdcard`, `/proc`, `/sys`, `/dev`,
  `/etc`, `/root`, `/home`, `/usr`, `/bin`, `/sbin`, `/var`, `/mnt`, `/boot`.
- Tree block (everything underneath): `/system`, `/vendor`, `/product`, plus the
  virtual filesystems above.

`rm -rf` is only ever called through `safe_remove`, which confirms the target is inside
the AndroidLinux base directory.

## Network exposure

- SSH defaults to port **2222** and binds to the local network only.
- Nothing is exposed to the public internet by default.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md). Please report privately, not as a public issue.
