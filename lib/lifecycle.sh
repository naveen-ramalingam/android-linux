#!/usr/bin/env bash
# lifecycle.sh - Mode-agnostic Linux lifecycle dispatcher.
# Delegates to chroot.sh or proot.sh based on INSTALL_MODE. Source after both.

linux_start() {
  case "${INSTALL_MODE:-}" in
    chroot) chroot_start "$@" ;;
    proot|termux) proot_start "$@" ;;
    *) log_error "Unknown INSTALL_MODE '${INSTALL_MODE:-}'"; return 1 ;;
  esac
}

linux_stop() {
  case "${INSTALL_MODE:-}" in
    chroot) chroot_stop "$@" ;;
    proot|termux) proot_stop "$@" ;;
    *) log_error "Unknown INSTALL_MODE '${INSTALL_MODE:-}'"; return 1 ;;
  esac
}

linux_enter() {
  case "${INSTALL_MODE:-}" in
    chroot) chroot_enter "$LINUX_ROOT" "${LINUX_USER:-root}" ;;
    proot|termux) proot_enter "$LINUX_ROOT" ;;
    *) log_error "Unknown INSTALL_MODE '${INSTALL_MODE:-}'"; return 1 ;;
  esac
}

linux_restart() { linux_stop "$@"; linux_start "$@"; }

linux_status() {
  case "${INSTALL_MODE:-}" in
    chroot) chroot_status "$LINUX_ROOT" ;;
    proot|termux) proot_status ;;
    *) printf 'unknown' ;;
  esac
}

# linux_run: run a non-interactive command inside the guest as root.
# Used by ssh/desktop installers. Usage: linux_run "apt-get update"
linux_run() {
  local cmd="$*"
  [ -d "$LINUX_ROOT" ] || { log_error "rootfs missing"; return 1; }
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] (guest) $cmd"
    return 0
  fi
  case "${INSTALL_MODE:-}" in
    chroot)
      chroot_start "$LINUX_ROOT" >/dev/null 2>&1 || true
      run_as_root env -i HOME=/root \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        chroot "$LINUX_ROOT" /bin/sh -c "$cmd" ;;
    proot|termux)
      proot_enter "$LINUX_ROOT" "$cmd" ;;
    *) log_error "Unknown INSTALL_MODE"; return 1 ;;
  esac
}

# guest_pkg_install: install packages using the guest's package manager.
guest_pkg_install() {
  local pkgs="$*"
  case "${DISTRO_FN:-debian}" in
    debian|ubuntu)
      linux_run "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y $pkgs" ;;
    alpine)
      linux_run "apk update && apk add $pkgs" ;;
    archarm)
      linux_run "pacman -Sy --noconfirm $pkgs" ;;
    *) log_error "guest_pkg_install: unknown distro"; return 1 ;;
  esac
}
