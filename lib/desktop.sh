#!/usr/bin/env bash
# desktop.sh - Optional desktop environment (XFCE/LXQt) with VNC access.
# Never assumes systemd. Source after lifecycle.sh, network.sh.

desktop_install() {
  local de="${1:-${DESKTOP:-xfce}}"
  [ "$de" = "none" ] && { log_info "No desktop selected."; return 0; }

  # Warn on low memory but let the user override.
  if [ "${MEM_TOTAL_BYTES:-0}" -lt 2147483648 ] 2>/dev/null; then
    log_warn "Device has under 2 GB RAM; a desktop may be slow."
    confirm "Continue installing the $de desktop?" N || return 0
  fi

  log_info "Installing $de desktop + VNC server (this downloads a lot of packages)..."
  local base_pkgs vnc_pkg de_pkgs
  case "${DISTRO_FN:-debian}" in
    debian|ubuntu)
      vnc_pkg="tigervnc-standalone-server tigervnc-common"
      base_pkgs="dbus-x11 xfonts-base"
      case "$de" in
        xfce) de_pkgs="xfce4 xfce4-terminal" ;;
        lxqt) de_pkgs="lxqt-core" ;;
        *) de_pkgs="xfce4" ;;
      esac ;;
    alpine)
      vnc_pkg="tigervnc"
      base_pkgs="dbus font-noto"
      case "$de" in
        xfce) de_pkgs="xfce4 xfce4-terminal" ;;
        lxqt) de_pkgs="lxqt" ;;
        *) de_pkgs="xfce4" ;;
      esac ;;
    *) log_error "Desktop install not defined for ${DISTRO_FN}"; return 1 ;;
  esac

  # shellcheck disable=SC2086
  guest_pkg_install $vnc_pkg $base_pkgs $de_pkgs || return 1

  DESKTOP="$de"; config_set DESKTOP "$de"; config_save
  desktop_write_startup "$de"
  desktop_set_vnc_password
  log_ok "$de desktop installed. Start with: android-linux desktop start"
}

# desktop_set_vnc_password: create a random VNC password (shown once).
desktop_set_vnc_password() {
  local pass
  pass=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 12)
  if [ -z "$pass" ]; then
    log_warn "Could not generate a VNC password; set one with 'vncpasswd' inside the guest."
    return 0
  fi
  # The password is alphanumeric, so embedding it single-quoted is safe.
  linux_run "mkdir -p /root/.vnc && printf '%s' '${pass}' | vncpasswd -f > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd"
  log_ok "VNC password generated (shown once): ${pass}"
  log_warn "Store this password - VNC viewers will ask for it."
}

# desktop_write_startup: create ~/.vnc/xstartup inside the guest.
desktop_write_startup() {
  local de="$1" startcmd
  case "$de" in
    xfce) startcmd="startxfce4" ;;
    lxqt) startcmd="startlxqt" ;;
    *) startcmd="startxfce4" ;;
  esac
  linux_run "mkdir -p /root/.vnc && cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
[ -x /usr/bin/dbus-launch ] && eval \"\$(dbus-launch --sh-syntax)\"
exec ${startcmd}
EOF
chmod +x /root/.vnc/xstartup"
}

desktop_start() {
  local vncport="${VNC_PORT:-5901}"
  validate_port "$vncport" || { log_error "Invalid VNC port: $vncport"; return 1; }
  local display=":$(( vncport - 5900 ))"
  # Bind to localhost by default (VNC auth is weak; don't expose it to the LAN).
  local locflag="-localhost yes"
  if [ "${VNC_LOCALHOST:-1}" = "0" ]; then
    locflag="-localhost no"
    log_warn "VNC is bound to ALL network interfaces. Only use this on a trusted network."
  fi
  log_info "Starting VNC on display ${display} (port ${vncport})..."
  linux_run "vncserver -kill ${display} 2>/dev/null || true"
  linux_run "vncserver ${display} -geometry 1280x720 -depth 24 ${locflag}"
  detect_network
  printf '\nVNC desktop:\n'
  printf '  Display: %s\n' "$display"
  printf '  Port:    %s\n' "$vncport"
  if [ "${VNC_LOCALHOST:-1}" != "0" ]; then
    printf '  Bound to localhost only (recommended).\n'
    printf '\nConnect via an SSH tunnel from your computer:\n'
    printf '  ssh -p %s -L %s:localhost:%s %s@%s\n' "${SSH_PORT:-2222}" "$vncport" "$vncport" "${LINUX_USER:-android}" "${NET_IPV4:-<device-ip>}"
    printf 'then point your VNC viewer at  localhost:%s\n' "$vncport"
  else
    printf '  Address: %s:%s\n' "${NET_IPV4:-<device-ip>}" "$vncport"
    printf '\nConnect with any VNC viewer to %s:%s\n' "${NET_IPV4:-<device-ip>}" "$vncport"
  fi
  [ "${IS_TERMUX:-0}" = 1 ] && printf 'Termux:X11 users can also export DISPLAY and run apps directly.\n'
  printf '\n'
}

desktop_stop() {
  local vncport="${VNC_PORT:-5901}"
  local display=":$(( vncport - 5900 ))"
  linux_run "vncserver -kill ${display} 2>/dev/null || true"
  log_ok "VNC stopped"
}

desktop_status() {
  local vncport="${VNC_PORT:-5901}"
  local display=":$(( vncport - 5900 ))"
  if linux_run "vncserver -list 2>/dev/null | grep -q '${display}'"; then
    printf 'running (%s)\n' "$display"
  else
    printf 'stopped\n'
  fi
}
