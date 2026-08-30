#!/usr/bin/env bash
# backup.sh - Back up the Linux rootfs + AndroidLinux configuration.
# Never touches Android /data as a whole. Source after common.sh.

backup_create() {
  local outdir="${BACKUP_DIR:-$LINUX_BASE/backups}"
  if is_forbidden_path "$outdir"; then
    log_error "Refusing to write backup into protected path: $outdir"
    return 1
  fi
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

  local base_parent; base_parent=$(dirname "$LINUX_BASE")
  local rel_base; rel_base=$(basename "$LINUX_BASE")

  # Only include layout dirs that exist, so a missing one doesn't abort backup.
  local members=("$rel_base/rootfs") d
  for d in config scripts; do
    [ -d "$LINUX_BASE/$d" ] && members+=("$rel_base/$d")
  done

  local numopt=""
  tar --help 2>&1 | grep -q 'numeric-owner' && numopt="--numeric-owner"

  # shellcheck disable=SC2086
  if [ "$comp" = "zstd" ]; then
    tar $numopt -C "$base_parent" -cf - "${members[@]}" 2>/dev/null \
      | zstd -q -o "$out" - || { log_error "Backup failed"; return 1; }
  else
    tar $numopt -C "$base_parent" -czf "$out" "${members[@]}" 2>/dev/null \
      || { log_error "Backup failed"; return 1; }
  fi
  # Include the user config file separately if it lives outside the base.
  if [ -f "$ANDROID_LINUX_CONFIG_FILE" ]; then
    cp -f "$ANDROID_LINUX_CONFIG_FILE" "$outdir/config.conf.bak" 2>/dev/null || true
  fi

  log_ok "Backup created: $out ($(human_bytes "$(wc -c <"$out" 2>/dev/null || echo 0)"))"
  printf '%s\n' "$out"
}
