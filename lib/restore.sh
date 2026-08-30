#!/usr/bin/env bash
# restore.sh - Restore a backup archive created by backup.sh.
# Validates the archive and never writes outside the AndroidLinux base.
# Source after common.sh.

restore_from() {
  local archive="$1"
  [ -n "$archive" ] || { log_error "restore: no archive given"; return 1; }
  [ -f "$archive" ] || { log_error "restore: archive not found: $archive"; return 1; }

  # Validate archive contents before touching anything.
  local rel_base; rel_base=$(basename "$LINUX_BASE")
  log_info "Validating backup archive..."
  local listing
  listing=$(restore_list "$archive") || { log_error "Cannot read archive (corrupt or unknown format)"; return 1; }

  # Security: reject archives whose members could escape the restore directory.
  tar_is_safe "$archive" || { log_error "Refusing to restore an unsafe archive."; return 1; }

  if ! printf '%s\n' "$listing" | grep -qF "${rel_base}/rootfs"; then
    error_report "Backup does not contain a recognizable rootfs" \
      "Expected a '${rel_base}/rootfs' entry inside the archive." \
      "Make sure you are restoring an AndroidLinux backup."
    return 1
  fi

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would restore $archive into $(dirname "$LINUX_BASE")"
    return 0
  fi

  confirm "This overwrites the current rootfs at $LINUX_ROOT. Continue?" N || { log_info "Aborted."; return 0; }
  linux_stop >/dev/null 2>&1 || true

  # Remove existing rootfs safely, then extract.
  safe_remove "$LINUX_ROOT" "$LINUX_BASE" || return 1
  local parent; parent=$(dirname "$LINUX_BASE")
  log_info "Restoring into $parent ..."
  case "$archive" in
    *.zst)
      have_cmd zstd || { log_error "zstd required to restore this archive"; return 1; }
      zstd -dc "$archive" | tar --numeric-owner -C "$parent" -xf - || { log_error "Restore failed"; return 1; } ;;
    *.gz|*.tgz)
      tar --numeric-owner -C "$parent" -xzf "$archive" || { log_error "Restore failed"; return 1; } ;;
    *)
      tar --numeric-owner -C "$parent" -xf "$archive" || { log_error "Restore failed"; return 1; } ;;
  esac
  log_ok "Restore complete."
}

restore_list() {
  local archive="$1"
  case "$archive" in
    *.zst)
      have_cmd zstd || return 1
      zstd -dc "$archive" 2>/dev/null | tar -tf - 2>/dev/null ;;
    *.gz|*.tgz) tar -tzf "$archive" 2>/dev/null ;;
    *) tar -tf "$archive" 2>/dev/null ;;
  esac
}
