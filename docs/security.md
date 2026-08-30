# Security

AndroidLinux treats security as a first-class concern. This page describes the
protections built into the project.

## What it will never do

- Flash partitions or modify `boot`, `recovery`, or `system`.
- Unlock the bootloader.
- Disable SELinux or Android security features.
- Erase user data.
- Execute a downloaded script without validation.

## Download pipeline

Every rootfs follows **download → verify → extract** (never download → execute):

1. Download over HTTPS from the official source.
2. Verify SHA256 when the source publishes checksums.
3. Only then extract into the rootfs.

Sources used:

| Distro | Source | Transport | Checksum |
|--------|--------|-----------|----------|
| Debian (LXC) | `images.linuxcontainers.org` | HTTPS | SHA256SUMS |
| Ubuntu base | `cdimage.ubuntu.com` | HTTPS | SHA256SUMS |
| Alpine | `dl-cdn.alpinelinux.org` | HTTPS | `.sha256` sidecar |
| Arch Linux ARM | `os.archlinuxarm.org` | HTTP* | none* |

\* Arch Linux ARM's image server has no valid TLS certificate and publishes no
SHA256. It is therefore treated as **untrusted** and is gated behind an explicit
warning and confirmation. Prefer Debian, Ubuntu, or Alpine.

### Fail-closed verification

If a distribution is supposed to publish a checksum but verification is not
possible (fetch fails, or no SHA256 tool is installed), AndroidLinux **refuses**
to proceed unless you explicitly confirm an unverified install. It no longer
silently skips verification.

## Archive safety

Before any extraction (rootfs install, restore, self-update, bootstrap) the
archive's member list is scanned and the archive is **rejected** if it contains:

- absolute paths (e.g. `/etc/passwd`), or
- `..` path-traversal members (e.g. `a/../../evil`).

This blocks "tar-slip" style attacks that try to write outside the target
directory.

## Path safety

A path validator rejects protected locations before any destructive operation:

- Exact-match block: `/`, `/data`, `/storage`, `/sdcard`, `/proc`, `/sys`, `/dev`,
  `/etc`, `/root`, `/home`, `/usr`, `/bin`, `/sbin`, `/var`, `/mnt`, `/boot`.
- Tree block (everything underneath): `/system`, `/vendor`, `/product`, plus the
  virtual filesystems above.

`rm -rf` is only ever called through `safe_remove`, which:

1. Normalizes the path lexically and rejects protected locations.
2. Confirms the target is inside the AndroidLinux base.
3. **Resolves symlinks** and re-checks both rules on the real path, so a link
   planted inside the base cannot point at `/system` or escape the base.

The install base itself is validated for **every** subcommand, not just install.

## Command injection

- All arguments passed to `su -c` are individually shell-quoted, so paths or
  values containing shell metacharacters cannot inject commands.
- Guest passwords are set by piping base64 into `chpasswd` — never embedded raw
  in a shell string.
- SSH/VNC ports and Linux usernames are validated before use in guest commands.

## Privileged access inside the guest

- **PRoot** does not bind Android shared storage (`/sdcard`, `/storage`) into the
  guest by default; opt in with `PROOT_BIND_STORAGE=1`. This prevents a
  destructive command inside Linux from wiping Android files.
- **chroot** mode bind-mounts `/dev`, which is required for a real Linux but means
  a root shell inside the guest can access raw devices. Use PRoot if you want a
  more constrained environment.

## Network exposure

- **SSH** defaults to port **2222** and you are warned not to expose it publicly.
- **VNC** binds to **localhost by default** (`VNC_LOCALHOST=1`) and a random VNC
  password is generated at install. Connect through an SSH tunnel. Set
  `VNC_LOCALHOST=0` only on a trusted network.

## Self-update

`android-linux update` replaces the helper scripts with the latest code, so it
asks for confirmation before downloading and applying changes. Downloaded
tarballs are checked for path traversal before extraction.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md). Please report privately, not as a public issue.
