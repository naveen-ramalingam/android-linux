#!/usr/bin/env bash
# uninstall.sh - Remove the AndroidLinux installation safely.
# Only ever deletes inside LINUX_BASE. Android system is never modified.
# Source after common.sh.

uninstall_run() {
  config_load
  local base="${LINUX_BASE:-}"
  if [ -z "$base" ] || [ ! -d "$base" ]; then
    log_warn "No installation found (LINUX_BASE not set or missing)."
    base="${base:-$ANDROID_LINUX_HOME}"
  fi

  local size="unknown"
  [ -d "${LINUX_ROOT:-/nonexistent}" ] && size=$(du -sh "$LINUX_ROOT" 2>/dev/null | awk '{print $1}')

  banner
  printf '\nThis will delete:\n'
  printf '  Install base: %s\n' "$base"
  printf '  Linux rootfs: %s (%s)\n' "${LINUX_ROOT:-<none>}" "$size"
  printf '\nAndroid system: %sNOT modified%s\n\n' "$C_GREEN" "$C_RESET"

  if is_forbidden_path "$base"; then
    die "Refusing to uninstall: '$base' is a protected system path."
  fi

  confirm "Permanently delete the AndroidLinux installation?" N || { log_info "Aborted."; return 0; }

  # Stop any running environment first.
  linux_stop >/dev/null 2>&1 || true

  safe_remove "$base" "$base" || { log_error "Uninstall failed."; return 1; }

  if confirm "Also remove configuration ($ANDROID_LINUX_CONFIG_DIR)?" N; then
    safe_remove "$ANDROID_LINUX_CONFIG_DIR" "$ANDROID_LINUX_CONFIG_DIR" 2>/dev/null || true
  fi

  log_ok "AndroidLinux uninstalled. The 'android-linux' command itself remains; delete it manually if desired."
}
