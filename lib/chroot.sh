#!/usr/bin/env bash
# chroot.sh - Rooted chroot lifecycle (start/stop/enter/status).
# Requires root. Binds Android kernel filesystems into the rootfs, safely and
# reversibly. Never modifies Android system partitions. Source after common.sh,
# root.sh, network.sh.

# chroot_bind_points: "source:target-relative-to-rootfs" pairs.
_CHROOT_BINDS="/dev:dev /sys:sys /proc:proc /dev/pts:dev/pts"

# _is_mounted: true if target path is currently a mountpoint.
_is_mounted() {
  local t="$1"
  if [ -r /proc/mounts ]; then
    awk -v t="$t" '$2==t{found=1} END{exit !found}' /proc/mounts
  else
    mountpoint -q "$t" 2>/dev/null
  fi
}

chroot_start() {
  local rootfs="${1:-$LINUX_ROOT}"
  [ -n "$rootfs" ] || { log_error "chroot_start: LINUX_ROOT unset"; return 1; }
  [ -d "$rootfs" ] || { log_error "chroot_start: rootfs missing: $rootfs"; return 1; }
  if [ "${ROOT_AVAILABLE:-0}" != "1" ]; then
    error_report "chroot requires root" \
      "No working su binary was detected." \
      "Use PRoot mode: android-linux install --proot"
    return 1
  fi
  path_within "$rootfs" "$LINUX_BASE" || { log_error "rootfs outside base"; return 1; }

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would bind-mount kernel fs and prepare $rootfs"
    return 0
  fi

  local pair src rel target
  for pair in $_CHROOT_BINDS; do
    src=${pair%%:*}; rel=${pair##*:}
    target="$rootfs/$rel"
    run_as_root mkdir -p "$target" 2>/dev/null || true
    if _is_mounted "$target"; then
      log_debug "already mounted: $target"
      continue
    fi
    [ -e "$src" ] || { log_debug "skip missing source $src"; continue; }
    if [ "$rel" = "dev/pts" ]; then
      if ! run_as_root mount -t devpts devpts "$target" -o rw,nosuid,noexec,relatime,mode=600,ptmxmode=000 2>/dev/null; then
        run_as_root mount --bind "$src" "$target" 2>/dev/null || log_warn "Could not bind-mount $src -> $target"
      fi
    else
      if ! run_as_root mount --bind "$src" "$target" 2>/dev/null; then
        log_warn "Could not bind-mount $src -> $target (kernel/SELinux policy may forbid it)"
      fi
    fi
  done

  configure_rootfs_environment "$rootfs" "${DNS:-1.1.1.1}"
  state_set READY
  log_ok "chroot environment ready"
}

chroot_stop() {
  local rootfs="${1:-$LINUX_ROOT}"
  [ -n "$rootfs" ] || return 1
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would unmount bind mounts under $rootfs"
    return 0
  fi
  # Unmount in reverse order (pts before dev).
  local rels="dev/pts proc sys dev"
  local rel target
  for rel in $rels; do
    target="$rootfs/$rel"
    if _is_mounted "$target"; then
      run_as_root umount "$target" 2>/dev/null \
        || run_as_root umount -l "$target" 2>/dev/null \
        || log_warn "Could not unmount $target"
    fi
  done
  unmount_all_under "$rootfs"
  log_ok "chroot environment stopped"
}

# chroot_enter: open an interactive shell inside the rootfs.
chroot_enter() {
  local rootfs="${1:-$LINUX_ROOT}"
  local user="${2:-root}"
  [ -d "$rootfs" ] || { log_error "rootfs missing: $rootfs"; return 1; }
  fix_rootfs_symlinks "$rootfs"
  chroot_start "$rootfs" || return 1
  local shell="/bin/sh"
  if [ -x "$rootfs/bin/bash" ]; then shell="/bin/bash"
  elif [ -x "$rootfs/usr/bin/bash" ]; then shell="/bin/bash"
  elif [ -x "$rootfs/bin/sh" ]; then shell="/bin/sh"
  elif [ -x "$rootfs/usr/bin/sh" ]; then shell="/bin/sh"
  fi
  log_info "Entering ${DISTRO_DISPLAY:-Linux} (chroot). Type 'exit' to leave."
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would chroot into $rootfs as $user"
    return 0
  fi
  run_as_root chmod 666 "$rootfs/dev/null" "$rootfs/dev/zero" "$rootfs/dev/full" "$rootfs/dev/random" "$rootfs/dev/urandom" "$rootfs/dev/tty" 2>/dev/null || true
  if [ -e "$rootfs/dev/pts/ptmx" ] && [ ! -e "$rootfs/dev/ptmx" ]; then
    run_as_root ln -sf pts/ptmx "$rootfs/dev/ptmx" 2>/dev/null || true
  fi
  run_as_root chmod 666 "$rootfs/dev/ptmx" 2>/dev/null || true
  local chroot_bin
  chroot_bin=$(command -v chroot 2>/dev/null || echo "chroot")
  run_as_root "$chroot_bin" "$rootfs" /usr/bin/env -i \
    HOME=/root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM="${TERM:-xterm}" \
    TMPDIR=/tmp \
    TMP=/tmp \
    TEMP=/tmp \
    LANG=C.UTF-8 \
    "$shell" -l
}

chroot_status() {
  local rootfs="${1:-$LINUX_ROOT}"
  local up=0 pair rel
  for pair in $_CHROOT_BINDS; do
    rel=${pair##*:}
    _is_mounted "$rootfs/$rel" && up=1
  done
  [ "$up" = 1 ] && printf 'running' || printf 'stopped'
}
