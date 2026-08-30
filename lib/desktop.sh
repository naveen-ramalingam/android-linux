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
  log_ok "$de desktop installed."
  # Automatically start VNC server after install
  desktop_start
}

# desktop_set_vnc_password: prompt for or create a VNC password.
desktop_set_vnc_password() {
  local pass=""
  if is_interactive; then
    pass=$(ask_secret "Set VNC password (press Enter for auto-generated)")
  fi
  if [ -z "$pass" ]; then
    pass=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 8)
    [ -z "$pass" ] && pass="vncpass1"
    log_ok "VNC password generated: ${pass}"
    log_warn "Save this password - your VNC viewer app will ask for it."
  else
    log_ok "VNC password configured."
  fi
  # The password is alphanumeric/safe string; embed securely into vncpasswd.
  local b64
  if have_cmd base64; then
    b64=$(printf '%s' "$pass" | base64 | tr -d '\n')
    linux_run "mkdir -p /root/.vnc && printf '%s' '${b64}' | base64 -d | vncpasswd -f > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd"
  else
    linux_run "mkdir -p /root/.vnc && printf '%s\n%s\n\n' '${pass}' '${pass}' | vncpasswd 2>/dev/null || true && chmod 600 /root/.vnc/passwd 2>/dev/null || true"
  fi
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
  printf '\n%s▸ VNC Desktop Server Running%s\n' "${C_BOLD}" "${C_RESET}"
  printf '  Display: %s\n' "$display"
  printf '  Port:    %s\n' "$vncport"
  printf '\n  %s1. Connect on Your Phone (Android):%s\n' "$C_BOLD" "$C_RESET"
  printf '     • Open any VNC app (e.g. AVNC, RealVNC, bVNC)\n'
  printf '     • Address:  127.0.0.1:%s\n' "$vncport"
  printf '     • Password: (your configured VNC password)\n'
  printf '\n  %s2. Connect from Your Computer (Mac/Linux/Windows):%s\n' "$C_BOLD" "$C_RESET"
  if [ "${VNC_LOCALHOST:-1}" != "0" ]; then
    printf '     • Run SSH Tunnel:  ssh -p %s -L %s:127.0.0.1:%s %s@%s\n' "${SSH_PORT:-2222}" "$vncport" "$vncport" "${LINUX_USER:-android}" "${NET_IPV4:-<device-ip>}"
    printf '     • In VNC Viewer:   localhost:%s\n' "$vncport"
  else
    printf '     • In VNC Viewer:   %s:%s\n' "${NET_IPV4:-<device-ip>}" "$vncport"
  fi
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
