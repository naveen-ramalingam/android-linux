#!/usr/bin/env bash
# root.sh - Root availability and provider detection.
# Source after common.sh.

# detect_root: sets ROOT_AVAILABLE (0/1), ROOT_PROVIDER, SU_BIN.
detect_root() {
  ROOT_AVAILABLE=0
  ROOT_PROVIDER="none"
  SU_BIN=""

  # Already uid 0? (some rooted shells / chroot)
  local uid
  uid=$(safe_get id -u)
  if [ "$uid" = "0" ]; then
    ROOT_AVAILABLE=1
    ROOT_PROVIDER="uid0"
    SU_BIN=""
  fi

  # Locate an su binary.
  local candidate
  for candidate in su /system/xbin/su /system/bin/su /sbin/su /su/bin/su /debug_ramdisk/su; do
    if [ "$candidate" = "su" ]; then
      have_cmd su || continue
      candidate=$(command -v su)
    else
      [ -x "$candidate" ] || continue
    fi
    # Verify it actually grants root without hanging.
    local out
    out=$(timeout_run 8 "$candidate" -c id 2>/dev/null || true)
    case "$out" in
      *uid=0*)
        ROOT_AVAILABLE=1
        SU_BIN="$candidate"
        break ;;
    esac
  done

  if [ "$ROOT_AVAILABLE" = "1" ] && [ "$ROOT_PROVIDER" = "none" ]; then
    ROOT_PROVIDER=$(detect_root_provider)
  fi

  export ROOT_AVAILABLE ROOT_PROVIDER SU_BIN
  log_debug "root: available=$ROOT_AVAILABLE provider=$ROOT_PROVIDER su=$SU_BIN"
}

# detect_root_provider: best-effort identification of the root manager.
detect_root_provider() {
  # KernelSU exposes /data/adb/ksu or the `ksud` binary.
  if [ -d /data/adb/ksu ] || have_cmd ksud || [ -e /data/adb/ksud ]; then
    printf 'KernelSU'; return 0
  fi
  # APatch.
  if [ -d /data/adb/ap ] || [ -e /data/adb/apd ] || have_cmd apd; then
    printf 'APatch'; return 0
  fi
  # Magisk.
  if have_cmd magisk || [ -d /data/adb/magisk ] || [ -d /sbin/.magisk ] || [ -e /data/adb/magisk.db ]; then
    printf 'Magisk'; return 0
  fi
  printf 'Unknown'
}

# run_as_root: execute a command with root privileges when available.
# Falls back to direct execution when already uid 0.
run_as_root() {
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] (root) $*"
    return 0
  fi
  if [ "$(safe_get id -u)" = "0" ]; then
    "$@"
  elif [ -n "${SU_BIN:-}" ]; then
    "$SU_BIN" -c "$*"
  else
    log_error "run_as_root: no root available for: $*"
    return 1
  fi
}

# timeout_run: run a command with a timeout if `timeout` exists, else run plain.
timeout_run() {
  local secs="$1"; shift
  if have_cmd timeout; then
    timeout "$secs" "$@"
  else
    "$@"
  fi
}
