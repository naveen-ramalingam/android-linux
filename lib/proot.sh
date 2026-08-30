#!/usr/bin/env bash
# proot.sh - Non-root (PRoot) lifecycle. Emulates chroot in userspace, no root
# required. Works inside Termux and ordinary Android shells. Source after
# common.sh, network.sh.

# proot_available: true if the proot binary exists.
proot_available() { have_cmd proot; }

# proot_enter: run an interactive shell (or command) inside the rootfs via proot.
# Usage: proot_enter [rootfs] [command...]
proot_enter() {
  local rootfs="${1:-$LINUX_ROOT}"; shift 2>/dev/null || true
  [ -d "$rootfs" ] || { log_error "rootfs missing: $rootfs"; return 1; }
  if ! proot_available; then
    error_report "proot is not installed" \
      "The PRoot binary was not found in PATH." \
      "Inside Termux run: pkg install proot"
    return 1
  fi
  configure_rootfs_environment "$rootfs" "${DNS:-1.1.1.1}"

  # Bind Android kernel filesystems read-only-ish into the guest.
  local binds=(
    --bind=/dev
    --bind=/proc
    --bind=/sys
    --bind=/dev/urandom:/dev/random
  )
  # Binding Android shared storage (/sdcard, /storage) into a root-privileged
  # guest means a destructive command inside Linux could wipe Android files.
  # It is therefore OPT-IN (PROOT_BIND_STORAGE=1) and off by default.
  if [ "${PROOT_BIND_STORAGE:-0}" = "1" ]; then
    [ -e /sdcard ] && binds+=(--bind=/sdcard)
    [ -e /storage ] && binds+=(--bind=/storage)
  fi

  local shell="/bin/bash"
  [ -x "$rootfs/bin/bash" ] || shell="/bin/sh"

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would launch proot into $rootfs"
    return 0
  fi

  state_set READY
  log_info "Entering ${DISTRO_DISPLAY:-Linux} (proot). Type 'exit' to leave."
  local proot_opts=()
  if proot --help 2>&1 | grep -q -- '--kill-on-exit'; then
    proot_opts+=(--kill-on-exit)
  fi
  if proot --help 2>&1 | grep -q -- '--root-id'; then
    proot_opts+=(--root-id)
  elif proot --help 2>&1 | grep -q -- '-0'; then
    proot_opts+=(-0)
  fi
  proot_opts+=(--cwd=/root)

  # shellcheck disable=SC2016
  local cmd='HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=${TERM:-xterm} TMPDIR=/tmp TMP=/tmp TEMP=/tmp LANG=C.UTF-8 '
  if [ "$#" -gt 0 ]; then
    proot "${proot_opts[@]}" \
      "${binds[@]}" -r "$rootfs" /usr/bin/env -i \
      HOME=/root \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      TERM="${TERM:-xterm}" \
      TMPDIR=/tmp \
      TMP=/tmp \
      TEMP=/tmp \
      LANG=C.UTF-8 \
      sh -c "$cmd exec $*"
  else
    proot "${proot_opts[@]}" \
      "${binds[@]}" -r "$rootfs" /usr/bin/env -i \
      HOME=/root \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      TERM="${TERM:-xterm}" \
      TMPDIR=/tmp \
      TMP=/tmp \
      TEMP=/tmp \
      LANG=C.UTF-8 \
      sh -c "${cmd} exec $shell -l"
  fi
}

# proot mode has no persistent mounts; stop any running proot processes.
proot_start() { log_debug "proot: no persistent mounts to start"; state_set READY; return 0; }
proot_stop() {
  local rootfs="${1:-$LINUX_ROOT}"
  if [ -n "$rootfs" ] && have_cmd pkill; then
    pkill -9 -f "proot.*$rootfs" 2>/dev/null || true
  fi
  log_debug "proot: guest processes stopped"
  return 0
}
proot_status() { printf 'on-demand'; }
