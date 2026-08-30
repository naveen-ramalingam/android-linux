#!/usr/bin/env bash
# filesystem.sh - Installation layout and rootfs tree creation.
# Source after common.sh.

# fs_default_base: pick a sensible default install base for the environment.
fs_default_base() {
  if [ "${IS_TERMUX:-0}" = "1" ] && [ -n "${TERMUX_PREFIX:-}" ]; then
    printf '%s/var/lib/android-linux' "$TERMUX_PREFIX"
  elif [ "${ROOT_AVAILABLE:-0}" = "1" ] && [ -d /data/local ] && [ -w /data/local ] 2>/dev/null; then
    printf '/data/local/android-linux'
  else
    printf '%s/android-linux' "${HOME:-/data/local/tmp}"
  fi
}

# fs_layout_dirs: the top-level layout directories under LINUX_BASE.
FS_LAYOUT_DIRS="rootfs downloads backups logs config scripts mounts"

# fs_rootfs_dirs: standard FHS directories to guarantee inside rootfs.
FS_ROOTFS_DIRS="bin boot dev etc home lib media mnt opt proc root run sbin srv sys tmp usr var"

# fs_init_layout: create the AndroidLinux layout under LINUX_BASE.
fs_init_layout() {
  local base="${1:-$LINUX_BASE}"
  [ -n "$base" ] || { log_error "fs_init_layout: no base"; return 1; }
  if is_forbidden_path "$base"; then
    log_error "fs_init_layout: refusing to use protected path '$base'"; return 1
  fi
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would create layout under $base"
    return 0
  fi
  local d
  for d in $FS_LAYOUT_DIRS; do
    mkdir -p "$base/$d" 2>/dev/null || { log_error "Cannot create $base/$d"; return 1; }
  done
  log_debug "layout created under $base"
}

# fs_init_rootfs_tree: ensure FHS directories exist inside rootfs.
fs_init_rootfs_tree() {
  local rootfs="${1:-$LINUX_ROOT}"
  [ -n "$rootfs" ] || return 1
  path_within "$rootfs" "${LINUX_BASE:-$rootfs}" || {
    log_error "fs_init_rootfs_tree: rootfs '$rootfs' not within base"; return 1; }
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would create FHS tree in $rootfs"
    return 0
  fi
  local d
  for d in $FS_ROOTFS_DIRS; do
    mkdir -p "$rootfs/$d" 2>/dev/null || true
  done
}

# fs_estimate_bytes: rough disk requirement for a distro + desktop combo.
# Usage: fs_estimate_bytes <distro> <desktop>
fs_estimate_bytes() {
  local distro="$1" desktop="$2" base=0
  case "$distro" in
    alpine) base=$(( 350 * 1024 * 1024 )) ;;      # ~350 MB
    debian*|ubuntu) base=$(( 2 * 1024 * 1024 * 1024 )) ;; # ~2 GB
    archarm) base=$(( 2 * 1024 * 1024 * 1024 )) ;;
    *) base=$(( 2 * 1024 * 1024 * 1024 )) ;;
  esac
  case "$desktop" in
    xfce|lxqt) base=$(( base + 3 * 1024 * 1024 * 1024 )) ;; # +3 GB
  esac
  printf '%s' "$base"
}

# fs_validate_install_base: sanity-check a chosen base directory.
fs_validate_install_base() {
  local base="$1"
  [ -n "$base" ] || return 1
  if is_forbidden_path "$base"; then
    error_report "Invalid install location: $base" \
      "This is a protected Android/system path." \
      "Choose internal storage, Termux storage, or a custom subdirectory."
    return 1
  fi
  return 0
}
