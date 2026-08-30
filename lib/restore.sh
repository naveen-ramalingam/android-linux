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
  local numopt=""
  tar --help 2>&1 | grep -q 'numeric-owner' && numopt="--numeric-owner"
  case "$archive" in
    *.zst)
      # shellcheck disable=SC2086
      zstd -dc "$archive" | tar $numopt -C "$parent" -xf - || { log_error "Restore failed"; return 1; } ;;
    *.xz|*.txz)
      # shellcheck disable=SC2086
      xz -dc "$archive" | tar $numopt -C "$parent" -xf - || { log_error "Restore failed"; return 1; } ;;
    *.gz|*.tgz)
      # shellcheck disable=SC2086
      gzip -dc "$archive" | tar $numopt -C "$parent" -xf - || { log_error "Restore failed"; return 1; } ;;
    *)
      # shellcheck disable=SC2086
      tar $numopt -C "$parent" -xf "$archive" || { log_error "Restore failed"; return 1; } ;;
  esac
  log_ok "Restore complete."
}

restore_list() {
  tar_list "$1"
}
