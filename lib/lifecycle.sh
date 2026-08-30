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
  [ -d "$LINUX_ROOT" ] || { log_error "rootfs missing: $LINUX_ROOT"; return 1; }
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] (guest) $cmd"
    return 0
  fi
  fix_rootfs_symlinks "$LINUX_ROOT"
  local gshell="/bin/sh"
  if [ -x "$LINUX_ROOT/bin/bash" ]; then gshell="/bin/bash"
  elif [ -x "$LINUX_ROOT/usr/bin/bash" ]; then gshell="/bin/bash"
  elif [ -x "$LINUX_ROOT/bin/sh" ]; then gshell="/bin/sh"
  elif [ -x "$LINUX_ROOT/usr/bin/sh" ]; then gshell="/bin/sh"
  fi
  local chroot_bin
  chroot_bin=$(command -v chroot 2>/dev/null || echo "chroot")
  case "${INSTALL_MODE:-}" in
    chroot)
      chroot_start "$LINUX_ROOT" >/dev/null 2>&1 || true
      run_as_root "$chroot_bin" "$LINUX_ROOT" "$gshell" -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=${TERM:-xterm} DEBIAN_FRONTEND=noninteractive; $cmd" ;;
    proot|termux)
      proot_enter "$LINUX_ROOT" "$cmd" ;;
    *) log_error "Unknown INSTALL_MODE"; return 1 ;;
  esac
}

# guest_pkg_install: install packages using the guest's package manager.
guest_pkg_install() {
  local pkgs="$*"
  configure_rootfs_environment "$LINUX_ROOT" "${DNS:-1.1.1.1}"
  case "${DISTRO_FN:-debian}" in
    debian|ubuntu)
      # Bootstrap the keyring if trusted.gpg.d is empty (fresh rootfs tarball
      # does not include keyring files). Use --allow-unauthenticated only for
      # this one-time bootstrap so subsequent apt calls verify signatures.
      linux_run "export DEBIAN_FRONTEND=noninteractive; \
        if [ ! -f /etc/apt/trusted.gpg ] && \
           [ -z \"\$(ls /etc/apt/trusted.gpg.d/ 2>/dev/null)\" ]; then \
          mkdir -p /etc/apt/trusted.gpg.d; \
          apt-get update -o Acquire::AllowInsecureRepositories=true \
                         -o APT::Get::AllowUnauthenticated=true 2>/dev/null || true; \
          apt-get install -y --allow-unauthenticated --fix-missing \
                          ${DISTRO_FN:-debian}-archive-keyring 2>/dev/null || true; \
        fi; \
        apt-get update && apt-get install -y --fix-missing $pkgs"
      ;;
    alpine)
      linux_run "apk update && apk add $pkgs" ;;
    archarm)
      linux_run "pacman -Sy --noconfirm $pkgs" ;;
    *) log_error "guest_pkg_install: unknown distro"; return 1 ;;
  esac
}
