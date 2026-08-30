#!/usr/bin/env bash
# ubuntu.sh - Ubuntu rootfs source (official ubuntu-base cloud images).
# cdimage.ubuntu.com publishes ubuntu-base tarballs with SHA256SUMS.
# Source after distro.sh.

# _ubuntu_release: map suite name to release number.
_ubuntu_release() {
  case "$DISTRO_SUITE" in
    noble) printf '24.04' ;;
    jammy) printf '22.04' ;;
    *) printf '24.04' ;;
  esac
}

_ubuntu_base_url() {
  local rel arch
  rel=$(_ubuntu_release)
  arch=$(arch_for_distro ubuntu) || return 1
  printf 'https://cdimage.ubuntu.com/ubuntu-base/releases/%s/release/ubuntu-base-%s-base-%s.tar.gz' \
    "$rel" "$rel" "$arch"
}

ubuntu_url() {
  _ubuntu_base_url || {
    error_report "Could not build Ubuntu rootfs URL" \
      "Architecture $ARCH may not have an ubuntu-base image." \
      "Try Debian or Alpine instead."
    return 1
  }
}

ubuntu_sha256() {
  local rel arch sums fname
  rel=$(_ubuntu_release)
  arch=$(arch_for_distro ubuntu) || { printf ''; return 0; }
  fname="ubuntu-base-${rel}-base-${arch}.tar.gz"
  sums=$(fetch_to_stdout "https://cdimage.ubuntu.com/ubuntu-base/releases/${rel}/release/SHA256SUMS") \
    || { printf ''; return 0; }
  printf '%s\n' "$sums" | awk -v f="$fname" '$2 ~ f {gsub(/[*]/,"",$1); print $1; exit}'
}
