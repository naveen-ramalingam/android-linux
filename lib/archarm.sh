#!/usr/bin/env bash
# archarm.sh - Arch Linux ARM rootfs source (official os.archlinuxarm.org).
# Advanced/optional. Arch Linux ARM only ships ARM tarballs and provides md5
# sidecars (no sha256), so checksum verification is best-effort. Source after distro.sh.

archarm_url() {
  local arch
  case "$ARCH" in
    arm64) arch="aarch64" ;;
    arm)   arch="armv7" ;;
    *)
      error_report "Arch Linux ARM supports only ARM architectures" \
        "Detected architecture $ARCH has no Arch Linux ARM image." \
        "Use Debian, Ubuntu, or Alpine instead."
      return 1 ;;
  esac
  printf 'http://os-archlinuxarm.org/os/ArchLinuxARM-%s-latest.tar.gz' "$arch"
}

# Arch Linux ARM does not publish sha256 sidecars on this path.
archarm_sha256() { printf ''; }
