#!/usr/bin/env bash
# debian.sh - Debian rootfs source (via the official Linux Containers image server).
# The linuxcontainers.org image server publishes minimal, reproducible rootfs
# tarballs with SHA256SUMS for every architecture. Source after distro.sh.

# lc_base: build the linuxcontainers directory URL for a series/arch.
# Usage: lc_base <distro> <series> <arch>
lc_base() {
  printf 'https://images.linuxcontainers.org/images/%s/%s/%s/default/' "$1" "$2" "$3"
}

# lc_latest_dir: resolve the newest timestamped build directory.
# Echoes the full URL of the latest build folder (with trailing slash).
lc_latest_dir() {
  local base="$1" listing latest
  listing=$(fetch_to_stdout "$base") || return 1
  # Directory listing contains links like href="20240101_05:24/".
  latest=$(printf '%s\n' "$listing" \
    | grep -oE '[0-9]{8}_[0-9]{2}:[0-9]{2}/' \
    | sort | tail -n1)
  [ -n "$latest" ] || return 1
  printf '%s%s' "$base" "$latest"
}

# _debian_dir: cache and return the resolved build directory.
_debian_dir() {
  if [ -z "${_DEBIAN_DIR_CACHE:-}" ]; then
    local arch; arch=$(arch_for_distro debian) || return 1
    _DEBIAN_DIR_CACHE=$(lc_latest_dir "$(lc_base debian "$DISTRO_SUITE" "$arch")") || return 1
  fi
  printf '%s' "$_DEBIAN_DIR_CACHE"
}

debian_url() {
  local dir; dir=$(_debian_dir) || {
    error_report "Could not resolve Debian rootfs URL" \
      "The Linux Containers image index could not be reached or parsed." \
      "Check network connectivity, or choose Alpine which uses a fixed CDN URL."
    return 1
  }
  printf '%srootfs.tar.xz' "$dir"
}

debian_sha256() {
  local dir sums
  dir=$(_debian_dir) || return 0
  sums=$(fetch_to_stdout "${dir}SHA256SUMS") || { printf ''; return 0; }
  printf '%s\n' "$sums" | awk '/rootfs\.tar\.xz$/{print $1; exit}'
}
