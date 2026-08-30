#!/usr/bin/env bash
# ssh.sh - Optional OpenSSH server inside the Linux guest.
# Source after lifecycle.sh, network.sh.

ssh_install() {
  local port="${1:-${SSH_PORT:-2222}}"
  local user="${LINUX_USER:-android}"
  log_info "Installing OpenSSH server in ${DISTRO_DISPLAY:-Linux}..."

  case "${DISTRO_FN:-debian}" in
    debian|ubuntu) guest_pkg_install openssh-server || return 1 ;;
    alpine) guest_pkg_install openssh || return 1 ;;
    archarm) guest_pkg_install openssh || return 1 ;;
  esac

  SSH_PORT="$port"; config_set SSH_PORT "$port"
  # Configure sshd to use the non-conflicting port and generate host keys.
  linux_run "mkdir -p /etc/ssh && sed -i 's/^#\\?Port .*/Port ${port}/' /etc/ssh/sshd_config 2>/dev/null || printf 'Port %s\n' '${port}' >> /etc/ssh/sshd_config"
  linux_run "ssh-keygen -A 2>/dev/null || true"

  # Create the Linux user if missing.
  ssh_ensure_user "$user"

  config_save
  log_ok "SSH installed. Use: android-linux ssh start"
  ssh_connection_info "$port" "$user"
}

ssh_ensure_user() {
  local user="$1"
  case "${DISTRO_FN:-debian}" in
    alpine)
      linux_run "id ${user} >/dev/null 2>&1 || adduser -D ${user} 2>/dev/null || true" ;;
    *)
      linux_run "id ${user} >/dev/null 2>&1 || useradd -m -s /bin/bash ${user} 2>/dev/null || true" ;;
  esac
  if is_interactive; then
    local pw pw2
    pw=$(ask_secret "Set password for guest user '${user}'")
    pw2=$(ask_secret "Confirm password")
    if [ -n "$pw" ] && [ "$pw" = "$pw2" ]; then
      linux_run "printf '%s:%s' '${user}' '${pw}' | chpasswd 2>/dev/null || echo '${user}:${pw}' | chpasswd"
      log_ok "Password set for ${user}"
    else
      log_warn "Passwords empty or mismatched; skipped. Set later with 'passwd ${user}' inside the guest."
    fi
  else
    log_warn "Non-interactive: no password set. Prefer SSH keys or set a password later."
  fi
}

ssh_start() {
  local port="${SSH_PORT:-2222}"
  log_info "Starting sshd on port ${port}..."
  case "${DISTRO_FN:-debian}" in
    alpine) linux_run "/usr/sbin/sshd -p ${port}" ;;
    *) linux_run "mkdir -p /run/sshd; /usr/sbin/sshd -p ${port}" ;;
  esac
  ssh_connection_info "$port" "${LINUX_USER:-android}"
}

ssh_stop() { linux_run "pkill -x sshd 2>/dev/null || true"; log_ok "sshd stopped"; }

ssh_connection_info() {
  local port="${1:-${SSH_PORT:-2222}}" user="${2:-${LINUX_USER:-android}}"
  detect_network
  printf '\nSSH server:\n'
  printf '  Port:    %s\n' "$port"
  printf '  User:    %s\n' "$user"
  printf '  Address: %s\n' "${NET_IPV4:-<device-ip>}"
  printf '\nConnect from Mac/Linux/Windows:\n'
  printf '  ssh -p %s %s@%s\n\n' "$port" "$user" "${NET_IPV4:-<device-ip>}"
  log_warn "SSH is bound to the device network only. Do not expose it to the public internet."
}
