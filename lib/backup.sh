#!/usr/bin/env bash
# backup.sh - Back up the Linux rootfs + AndroidLinux configuration.
# Never touches Android /data as a whole. Source after common.sh.

backup_create() {
  local outdir="${BACKUP_DIR:-$LINUX_BASE/backups}"
  mkdir -p "$outdir" 2>/dev/null || { log_error "Cannot create backup dir: $outdir"; return 1; }
  local date_tag; date_tag=$(date '+%Y-%m-%d-%H%M%S' 2>/dev/null || echo backup)

  # Prefer zstd, fall back to gzip.
  local ext comp
  if have_cmd zstd; then ext="tar.zst"; comp="zstd"; else ext="tar.gz"; comp="gzip"; fi
  local out="$outdir/android-linux-backup-${date_tag}.${ext}"

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would create backup: $out"
    return 0
  fi
  [ -d "$LINUX_ROOT" ] || { log_error "No rootfs to back up: $LINUX_ROOT"; return 1; }

  log_info "Backing up rootfs + config -> $out"
  # Stop mounts so the rootfs is quiescent.
  linux_stop >/dev/null 2>&1 || true

  # Build a staging list: rootfs + config + state.
  local cfg="$ANDROID_LINUX_CONFIG_FILE"
  local base_parent; base_parent=$(dirname "$LINUX_BASE")
  local rel_base; rel_base=$(basename "$LINUX_BASE")

  if [ "$comp" = "zstd" ]; then
    tar --numeric-owner -C "$base_parent" -cf - "$rel_base/rootfs" "$rel_base/config" 2>/dev/null \
      | zstd -q -o "$out" - || { log_error "Backup failed"; return 1; }
  else
    tar --numeric-owner -C "$base_parent" -czf "$out" "$rel_base/rootfs" "$rel_base/config" 2>/dev/null \
      || { log_error "Backup failed"; return 1; }
  fi
  # Include the user config file separately if outside base.
  [ -f "$cfg" ] && cp -f "$cfg" "$outdir/config.conf.bak" 2>/dev/null || true

  log_ok "Backup created: $out ($(human_bytes "$(wc -c <"$out" 2>/dev/null || echo 0)"))"
  printf '%s\n' "$out"
}
