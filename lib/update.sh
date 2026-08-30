#!/usr/bin/env bash
# update.sh - Update the AndroidLinux scripts without touching the Linux rootfs.
# Source after common.sh.

: "${ANDROID_LINUX_REPO_RAW:=https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main}"
: "${ANDROID_LINUX_REPO_GIT:=https://github.com/naveen-ramalingam/android-linux.git}"

update_run() {
  log_info "Updating AndroidLinux scripts (rootfs and config are left untouched)..."
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would update scripts in $APP_HOME"
    return 0
  fi
  # Self-update replaces these scripts with downloaded code; confirm first.
  if ! confirm "Download and apply the latest AndroidLinux scripts?" Y; then
    log_info "Update cancelled."
    return 0
  fi

  if [ -d "$APP_HOME/.git" ] && have_cmd git; then
    if ( cd "$APP_HOME" && git pull --ff-only ); then
      log_ok "Updated via git."
      config_load
      if [ -n "${LINUX_ROOT:-}" ] && [ -d "$LINUX_ROOT" ]; then
        log_info "Applying latest configuration to rootfs (DNS, APT sandbox, Android GIDs)..."
        configure_rootfs_environment "$LINUX_ROOT" "${DNS:-1.1.1.1}"
        log_ok "Rootfs configuration updated."
      fi
      return 0
    fi
    log_warn "git pull failed; falling back to archive download."
  fi

  # Archive fallback: download tarball and refresh script files only.
  local tmp
  tmp=$(mktemp -d 2>/dev/null) || { log_error "mktemp failed; cannot create a safe temp directory"; return 1; }
  mkdir -p "$tmp"
  local tarball="$tmp/src.tar.gz"
  if fetch_file "${ANDROID_LINUX_REPO_GIT%.git}/archive/refs/heads/main.tar.gz" "$tarball"; then
    if ! tar_is_safe "$tarball"; then
      log_error "Update tarball failed safety validation; aborting."
      rm -rf "$tmp" 2>/dev/null || true
      return 1
    fi
    if tar -xzf "$tarball" -C "$tmp" 2>/dev/null; then
      local src; src=$(find "$tmp" -maxdepth 1 -type d -name 'android-linux*' | head -1)
      if [ -n "$src" ]; then
        cp -f "$src"/install.sh "$src"/uninstall.sh "$APP_HOME"/ 2>/dev/null || true
        cp -rf "$src"/bin "$src"/lib "$src"/profiles "$src"/configs "$APP_HOME"/ 2>/dev/null || true
        log_ok "Updated from archive."
        safe_remove "$tmp" "$tmp" 2>/dev/null || rm -rf "$tmp"
        config_load
        if [ -n "${LINUX_ROOT:-}" ] && [ -d "$LINUX_ROOT" ]; then
          log_info "Applying latest configuration to rootfs (DNS, APT sandbox, Android GIDs)..."
          configure_rootfs_environment "$LINUX_ROOT" "${DNS:-1.1.1.1}"
          log_ok "Rootfs configuration updated."
        fi
        return 0
      fi
    fi
  fi
  rm -rf "$tmp" 2>/dev/null || true
  error_report "Update failed" \
    "Could not update via git or archive download." \
    "Check network, or re-run the one-line installer to refresh."
  return 1
}
