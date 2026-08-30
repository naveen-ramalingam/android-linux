#!/usr/bin/env bash
# architecture.sh - CPU architecture detection and rootfs arch mapping.
# Source after common.sh.

# detect_architecture: sets ARCH (normalized) and ARCH_RAW.
# Normalized values: arm64 | arm | x86_64 | x86 | unknown
detect_architecture() {
  local m abilist abi
  m=$(safe_get uname -m)
  abi=$(getprop_safe ro.product.cpu.abi)
  abilist=$(getprop_safe ro.product.cpu.abilist)
  ARCH_RAW="$m"
  [ -n "$abi" ] && ARCH_RAW="$ARCH_RAW $abi"

  local probe="$m $abi $abilist"
  case "$probe" in
    *aarch64*|*arm64*|*armv8*) ARCH="arm64" ;;
    *armv7*|*armeabi*|*armhf*|*armv6*) ARCH="arm" ;;
    *x86_64*|*amd64*) ARCH="x86_64" ;;
    *i686*|*i386*|*x86*) ARCH="x86" ;;
    *) ARCH="unknown" ;;
  esac
  export ARCH ARCH_RAW
  log_debug "architecture: ARCH=$ARCH ARCH_RAW=$ARCH_RAW"
}

# arch_label: pretty label for display.
arch_label() {
  case "${1:-$ARCH}" in
    arm64) printf 'ARM64 (aarch64)' ;;
    arm)   printf 'ARM32 (armhf)' ;;
    x86_64) printf 'x86_64 (amd64)' ;;
    x86)   printf 'x86 (i386)' ;;
    *)     printf 'Unknown' ;;
  esac
}

# arch_for_distro: map normalized ARCH to a distro's naming convention.
# Usage: arch_for_distro <distro>
arch_for_distro() {
  local distro="$1"
  case "$distro" in
    debian*|ubuntu)
      case "$ARCH" in
        arm64) printf 'arm64' ;;
        arm)   printf 'armhf' ;;
        x86_64) printf 'amd64' ;;
        x86)   printf 'i386' ;;
        *) return 1 ;;
      esac ;;
    alpine)
      case "$ARCH" in
        arm64) printf 'aarch64' ;;
        arm)   printf 'armv7' ;;
        x86_64) printf 'x86_64' ;;
        x86)   printf 'x86' ;;
        *) return 1 ;;
      esac ;;
    archarm)
      case "$ARCH" in
        arm64) printf 'aarch64' ;;
        arm)   printf 'armv7' ;;
        *) return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}

# arch_is_supported: true if the architecture can run at all.
arch_is_supported() {
  case "$ARCH" in
    arm64|arm|x86_64|x86) return 0 ;;
    *) return 1 ;;
  esac
}
