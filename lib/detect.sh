#!/usr/bin/env bash
# detect.sh - Device, Android, kernel, SELinux, environment and capability detection.
# Source after common.sh, architecture.sh, root.sh, storage.sh, network.sh.

# getprop_safe: read an Android system property, empty if unavailable.
getprop_safe() {
  have_cmd getprop || { printf ''; return 0; }
  local v; v=$(getprop "$1" 2>/dev/null) || v=""
  printf '%s' "$v"
}

# detect_device: sets DEV_MANUFACTURER, DEV_MODEL, DEV_CODENAME, DEV_BUILD_ID.
detect_device() {
  DEV_MANUFACTURER=$(getprop_safe ro.product.manufacturer)
  DEV_MODEL=$(getprop_safe ro.product.model)
  DEV_CODENAME=$(getprop_safe ro.product.device)
  [ -z "$DEV_CODENAME" ] && DEV_CODENAME=$(getprop_safe ro.boot.hardware)
  DEV_BUILD_ID=$(getprop_safe ro.build.id)

  [ -z "$DEV_MANUFACTURER" ] && DEV_MANUFACTURER="Unknown"
  [ -z "$DEV_MODEL" ] && DEV_MODEL="$(safe_get uname -n)"
  [ -z "$DEV_MODEL" ] && DEV_MODEL="Unknown device"

  export DEV_MANUFACTURER DEV_MODEL DEV_CODENAME DEV_BUILD_ID
  log_debug "device: $DEV_MANUFACTURER $DEV_MODEL ($DEV_CODENAME)"
}

# detect_android: sets ANDROID_RELEASE, ANDROID_SDK, IS_ANDROID(0/1).
detect_android() {
  ANDROID_RELEASE=$(getprop_safe ro.build.version.release)
  ANDROID_SDK=$(getprop_safe ro.build.version.sdk)
  if [ -n "$ANDROID_RELEASE" ] || [ -n "$ANDROID_SDK" ] || [ -d /system/app ]; then
    IS_ANDROID=1
  else
    IS_ANDROID=0
  fi
  [ -z "$ANDROID_RELEASE" ] && ANDROID_RELEASE="unknown"
  export ANDROID_RELEASE ANDROID_SDK IS_ANDROID
  log_debug "android: release=$ANDROID_RELEASE sdk=$ANDROID_SDK is_android=$IS_ANDROID"
}

# detect_kernel: sets KERNEL_VERSION, KERNEL_ARCH, KERNEL_OLD(0/1).
detect_kernel() {
  KERNEL_VERSION=$(safe_get uname -r)
  KERNEL_ARCH=$(safe_get uname -m)
  KERNEL_OLD=0
  # Consider < 4.0 "old" for feature warnings.
  local major minor
  major=${KERNEL_VERSION%%.*}
  minor=${KERNEL_VERSION#*.}; minor=${minor%%.*}
  case "$major" in
    ''|*[!0-9]*) : ;;
    *) [ "$major" -lt 4 ] 2>/dev/null && KERNEL_OLD=1 ;;
  esac
  export KERNEL_VERSION KERNEL_ARCH KERNEL_OLD
  log_debug "kernel: $KERNEL_VERSION ($KERNEL_ARCH) old=$KERNEL_OLD"
}

# detect_selinux: sets SELINUX_STATUS (Enforcing|Permissive|Disabled|Unknown).
detect_selinux() {
  if have_cmd getenforce; then
    SELINUX_STATUS=$(safe_get getenforce)
  elif [ -r /sys/fs/selinux/enforce ]; then
    case "$(cat /sys/fs/selinux/enforce 2>/dev/null)" in
      1) SELINUX_STATUS="Enforcing" ;;
      0) SELINUX_STATUS="Permissive" ;;
      *) SELINUX_STATUS="Unknown" ;;
    esac
  else
    SELINUX_STATUS="Disabled"
  fi
  [ -z "$SELINUX_STATUS" ] && SELINUX_STATUS="Unknown"
  export SELINUX_STATUS
  log_debug "selinux: $SELINUX_STATUS"
}

# detect_termux: sets IS_TERMUX(0/1), TERMUX_PREFIX, HAS_TERMUX_API(0/1).
detect_termux() {
  IS_TERMUX=0
  TERMUX_PREFIX="${PREFIX:-}"
  HAS_TERMUX_API=0
  case "${PREFIX:-}" in
    *com.termux*) IS_TERMUX=1 ;;
  esac
  [ -d /data/data/com.termux/files/usr ] && IS_TERMUX=1
  if [ "$IS_TERMUX" = 1 ]; then
    [ -z "$TERMUX_PREFIX" ] && TERMUX_PREFIX="/data/data/com.termux/files/usr"
    have_cmd termux-setup-storage && HAS_TERMUX_API=1
    have_cmd termux-battery-status && HAS_TERMUX_API=1
  fi
  export IS_TERMUX TERMUX_PREFIX HAS_TERMUX_API
  log_debug "termux: is_termux=$IS_TERMUX prefix=$TERMUX_PREFIX api=$HAS_TERMUX_API"
}

# detect_capabilities: sets a set of CAP_* flags for available tooling.
detect_capabilities() {
  CAP_TOOLBOX=0; CAP_BUSYBOX=0; CAP_COREUTILS=0
  CAP_TAR=0; CAP_GZIP=0; CAP_XZ=0; CAP_ZSTD=0
  CAP_CURL=0; CAP_WGET=0; CAP_ARIA2=0
  CAP_PROOT=0; CAP_CHROOT=0; CAP_UNSHARE=0; CAP_MOUNT=0

  have_cmd toybox && CAP_TOOLBOX=1
  have_cmd busybox && CAP_BUSYBOX=1
  # coreutils heuristic: GNU ls understands --version.
  ls --version >/dev/null 2>&1 && CAP_COREUTILS=1

  have_cmd tar && CAP_TAR=1
  have_cmd gzip && CAP_GZIP=1
  have_cmd xz && CAP_XZ=1
  have_cmd zstd && CAP_ZSTD=1
  have_cmd curl && CAP_CURL=1
  have_cmd wget && CAP_WGET=1
  have_cmd aria2c && CAP_ARIA2=1
  have_cmd proot && CAP_PROOT=1
  have_cmd chroot && CAP_CHROOT=1
  have_cmd unshare && CAP_UNSHARE=1
  have_cmd mount && CAP_MOUNT=1

  export CAP_TOOLBOX CAP_BUSYBOX CAP_COREUTILS CAP_TAR CAP_GZIP CAP_XZ CAP_ZSTD
  export CAP_CURL CAP_WGET CAP_ARIA2 CAP_PROOT CAP_CHROOT CAP_UNSHARE CAP_MOUNT
  log_debug "caps: tar=$CAP_TAR xz=$CAP_XZ zstd=$CAP_ZSTD curl=$CAP_CURL wget=$CAP_WGET proot=$CAP_PROOT chroot=$CAP_CHROOT unshare=$CAP_UNSHARE"
}

# recommend_mode: choose the best execution mode.
# Sets RECOMMENDED_MODE: chroot | proot | termux
recommend_mode() {
  if [ "${ROOT_AVAILABLE:-0}" = "1" ] && [ "${CAP_CHROOT:-0}" = "1" ]; then
    RECOMMENDED_MODE="chroot"
  elif [ "${CAP_PROOT:-0}" = "1" ]; then
    RECOMMENDED_MODE="proot"
  elif [ "${IS_TERMUX:-0}" = "1" ]; then
    RECOMMENDED_MODE="termux"
  else
    RECOMMENDED_MODE="proot"
  fi
  export RECOMMENDED_MODE
  log_debug "recommended mode: $RECOMMENDED_MODE"
}

# detect_all: run the whole detection pipeline once.
detect_all() {
  detect_device
  detect_android
  detect_architecture
  detect_root
  detect_kernel
  detect_selinux
  detect_termux
  detect_memory
  detect_storage "${LINUX_BASE:-$HOME}"
  detect_capabilities
  recommend_mode
}

# print_detection: display the detection summary block.
print_detection() {
  banner
  printf '\n'
  printf 'Device:        %s %s\n' "$DEV_MANUFACTURER" "$DEV_MODEL"
  [ -n "$DEV_CODENAME" ] && printf 'Codename:      %s\n' "$DEV_CODENAME"
  printf 'Android:       %s (SDK %s)\n' "$ANDROID_RELEASE" "${ANDROID_SDK:-?}"
  printf 'Architecture:  %s\n' "$(arch_label)"
  printf 'RAM:           %s GB\n' "$(mem_gb)"
  printf 'Storage free:  %s\n' "$(human_bytes "${STORAGE_AVAIL_BYTES:-0}")"
  printf 'Kernel:        %s\n' "$KERNEL_VERSION"
  printf 'Root:          %s\n' "$([ "${ROOT_AVAILABLE:-0}" = 1 ] && echo YES || echo NO)"
  [ "${ROOT_AVAILABLE:-0}" = 1 ] && printf 'Root provider: %s\n' "$ROOT_PROVIDER"
  printf 'SELinux:       %s\n' "$SELINUX_STATUS"
  printf 'Termux:        %s\n' "$([ "${IS_TERMUX:-0}" = 1 ] && echo YES || echo NO)"
  printf 'Recommended:   %s\n' "$(mode_label "$RECOMMENDED_MODE")"
  printf '\n'
  hr
}

mode_label() {
  case "$1" in
    chroot) printf 'ROOTED CHROOT' ;;
    proot)  printf 'PROOT (no root needed)' ;;
    termux) printf 'TERMUX LINUX' ;;
    *) printf '%s' "$1" ;;
  esac
}
