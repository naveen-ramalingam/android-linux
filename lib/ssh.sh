#!/usr/bin/env bash
# ssh.sh - Optional OpenSSH server inside the Linux guest.
# Source after lifecycle.sh, network.sh.

ssh_install() {
  local port="${1:-${SSH_PORT:-2222}}"
  local user="${2:-${LINUX_USER:-android}}"
  validate_port "$port" || { log_error "Invalid SSH port: $port"; return 1; }
  validate_name "$user" || { log_error "Invalid Linux username: $user (use lowercase letters, digits, _ or -)"; return 1; }
  log_info "Installing OpenSSH server in ${DISTRO_DISPLAY:-Linux}..."

  case "${DISTRO_FN:-debian}" in
    debian|ubuntu) guest_pkg_install openssh-server sudo || guest_pkg_install openssh-server || return 1 ;;
    alpine) guest_pkg_install openssh sudo || guest_pkg_install openssh || return 1 ;;
    archarm) guest_pkg_install openssh sudo || guest_pkg_install openssh || return 1 ;;
  esac

  SSH_PORT="$port"; config_set SSH_PORT "$port"
  LINUX_USER="$user"; config_set LINUX_USER "$user"
  # Configure sshd to use the non-conflicting port, permit password auth, root login, and generate host keys.
  linux_run "mkdir -p /etc/ssh /run/sshd /var/run/sshd /var/empty /tmp"
  linux_run "sed -i 's/^[#]*Port .*/Port ${port}/' /etc/ssh/sshd_config 2>/dev/null || printf 'Port %s\n' '${port}' >> /etc/ssh/sshd_config"
  linux_run "sed -i 's/^[#]*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || printf 'PermitRootLogin yes\n' >> /etc/ssh/sshd_config"
  linux_run "sed -i 's/^[#]*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || printf 'PasswordAuthentication yes\n' >> /etc/ssh/sshd_config"
  linux_run "ssh-keygen -A 2>/dev/null || true"

  # Create the Linux user if missing.
  ssh_ensure_user "$user"

  config_save
  log_ok "SSH installed."
  # Automatically start SSH server after install
  ssh_start "$port" "$user"
}

ssh_ensure_user() {
  local user="${1:-${LINUX_USER:-android}}"
  validate_name "$user" || { log_error "Invalid username; skipping user creation"; return 1; }
  LINUX_USER="$user"; config_set LINUX_USER "$user"; config_save

  log_info "Configuring guest user account '${user}'..."
  case "${DISTRO_FN:-debian}" in
    alpine)
      linux_run "id ${user} >/dev/null 2>&1 || adduser -D -s /bin/sh ${user} 2>/dev/null || true"
      linux_run "addgroup ${user} wheel 2>/dev/null || true" ;;
    *)
      linux_run "id ${user} >/dev/null 2>&1 || useradd -m -s /bin/bash ${user} 2>/dev/null || true"
      linux_run "usermod -aG sudo ${user} 2>/dev/null || usermod -aG wheel ${user} 2>/dev/null || true" ;;
  esac

  if is_interactive; then
    local attempts=0 max_attempts=3 pw pw2
    while [ "$attempts" -lt "$max_attempts" ]; do
      attempts=$(( attempts + 1 ))
      pw=$(ask_secret "Set password for Linux user '${user}' (press Enter to skip)")
      if [ -z "$pw" ]; then
        log_info "Password setup skipped for '${user}'. Set later with 'passwd ${user}' inside Linux."
        return 0
      fi
      pw2=$(ask_secret "Confirm password")
      if [ "$pw" = "$pw2" ]; then
        if have_cmd base64; then
          # Encode user:password as base64 on the host; the base64 alphabet has no
          # shell metacharacters, so it cannot inject commands in the guest shell.
          local cred
          cred=$(printf '%s:%s' "$user" "$pw" | base64 | tr -d '\n')
          linux_run "printf '%s' '${cred}' | base64 -d | chpasswd"
          log_ok "Password configured successfully for user '${user}'."
        else
          linux_run "printf '%s\n%s\n' '${pw}' '${pw}' | passwd ${user} 2>/dev/null || true"
          log_ok "Password configured successfully for user '${user}'."
        fi
        return 0
      else
        log_warn "Passwords do not match. Please try again ($attempts/$max_attempts)."
      fi
    done
    log_warn "Password configuration skipped after $max_attempts attempts. Set later with 'passwd ${user}' inside Linux."
  else
    log_warn "Non-interactive: no password set. Prefer SSH keys or set a password later."
  fi
}

ssh_is_running() {
  if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
    run_as_root pgrep -x sshd >/dev/null 2>&1
  else
    pgrep -x sshd >/dev/null 2>&1
  fi
}

ssh_start() {
  local port="${SSH_PORT:-2222}"
  validate_port "$port" || { log_error "Invalid SSH port: $port"; return 1; }
  log_info "Starting sshd on port ${port}..."
  linux_run "mkdir -p /run/sshd /var/run/sshd /var/empty /etc/ssh"
  linux_run "ssh-keygen -A 2>/dev/null || true"
  case "${DISTRO_FN:-debian}" in
    alpine) linux_run "/usr/sbin/sshd -p ${port}" ;;
    *) linux_run "/usr/sbin/sshd -p ${port}" ;;
  esac
  if ssh_is_running; then
    log_ok "sshd is running on port ${port}"
  fi
  ssh_connection_info "$port" "${LINUX_USER:-android}"
}

ssh_stop() { linux_run "pkill -x sshd 2>/dev/null || true"; log_ok "sshd stopped"; }

ssh_status() {
  local port="${SSH_PORT:-2222}"
  if ssh_is_running; then
    printf '\nSSH server: %sRUNNING%s (port %s)\n' "$C_GREEN" "$C_RESET" "$port"
    ssh_connection_info "$port" "${LINUX_USER:-android}"
  else
    printf '\nSSH server: %sSTOPPED%s (port %s)\n' "$C_YELLOW" "$C_RESET" "$port"
    printf 'Start it with:  android-linux ssh start\n\n'
  fi
}

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
