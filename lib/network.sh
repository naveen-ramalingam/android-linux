#!/usr/bin/env bash
# network.sh - Network connectivity detection and DNS configuration.
# Source after common.sh.

# detect_network: sets NET_ONLINE(0/1), NET_IPV4, NET_IPV6, NET_DNS.
detect_network() {
  NET_ONLINE=0
  NET_IPV4=""
  NET_IPV6=""
  NET_DNS="${DNS:-1.1.1.1}"

  # Primary IPv4 (best-effort, several fallbacks).
  if have_cmd ip; then
    NET_IPV4=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -z "$NET_IPV4" ] && NET_IPV4=$(ip -4 addr 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127' | head -1 | cut -d/ -f1)
    NET_IPV6=$(ip -6 addr 2>/dev/null | awk '/inet6 /{print $2}' | grep -vi '^fe80\|^::1' | head -1 | cut -d/ -f1)
  elif have_cmd ifconfig; then
    NET_IPV4=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127' | head -1)
  fi

  # DNS from resolv.conf if present.
  if [ -r /etc/resolv.conf ]; then
    local d
    d=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
    [ -n "$d" ] && NET_DNS="$d"
  fi

  # Connectivity probe (ping first, then any http client, then getprop).
  if have_cmd ping && timeout_run 5 ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    NET_ONLINE=1
  elif have_cmd curl && timeout_run 8 curl -fsS -o /dev/null --max-time 6 https://1.1.1.1 2>/dev/null; then
    NET_ONLINE=1
  elif have_cmd wget && timeout_run 8 wget -q -O /dev/null --timeout=6 https://1.1.1.1 2>/dev/null; then
    NET_ONLINE=1
  fi

  export NET_ONLINE NET_IPV4 NET_IPV6 NET_DNS
  log_debug "network: online=$NET_ONLINE ipv4=$NET_IPV4 dns=$NET_DNS"
}

# net_status_print: human-readable network status.
net_status_print() {
  detect_network
  printf 'Network: %s\n' "$([ "$NET_ONLINE" = 1 ] && echo CONNECTED || echo OFFLINE)"
  printf 'IPv4:    %s\n' "${NET_IPV4:-unknown}"
  [ -n "$NET_IPV6" ] && printf 'IPv6:    %s\n' "$NET_IPV6"
  printf 'DNS:     %s\n' "${NET_DNS:-unknown}"
}

# configure_rootfs_dns: write a resolv.conf into the target rootfs.
# Never touches Android's own /etc/resolv.conf. Safe and reversible.
configure_rootfs_dns() {
  local rootfs="$1" dns="${2:-${DNS:-1.1.1.1}}"
  [ -n "$rootfs" ] || return 1
  path_within "$rootfs/etc" "$rootfs" || return 1
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would write $rootfs/etc/resolv.conf (nameserver $dns)"
    return 0
  fi
  
  # Create /etc directory with appropriate permissions.
  # In chroot mode, rootfs is owned by root, so use run_as_root.
  if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
    run_as_root mkdir -p "$rootfs/etc" 2>/dev/null || true
  else
    mkdir -p "$rootfs/etc" 2>/dev/null || true
  fi
  
  # Debian/Ubuntu ship etc/resolv.conf as a symlink (e.g. -> /run/systemd/...).
  # Redirecting would follow the dangling link and fail, so replace it with a
  # regular file. Only this single file inside the rootfs is removed.
  if [ -L "$rootfs/etc/resolv.conf" ]; then
    if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
      run_as_root rm -f "$rootfs/etc/resolv.conf" 2>/dev/null || true
    else
      rm -f "$rootfs/etc/resolv.conf" 2>/dev/null || true
    fi
  fi
  
  # Write resolv.conf with root if needed.
  local tmp_resolv
  tmp_resolv=$(mktemp 2>/dev/null || printf '/tmp/resolv.conf.%s' "$$")
  {
    local d
    for d in "$dns" \
      "$(safe_get getprop net.dns1)" \
      "$(safe_get getprop net.dns2)" \
      "1.1.1.1" "8.8.8.8" "9.9.9.9" "8.8.4.4"; do
      [ -n "$d" ] && printf 'nameserver %s\n' "$d"
    done | awk '!seen[$0]++'
  } >"$tmp_resolv" || { log_warn "Could not create temporary resolv.conf"; return 1; }
  
  if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
    if ! run_as_root cp "$tmp_resolv" "$rootfs/etc/resolv.conf" 2>/dev/null; then
      rm -f "$tmp_resolv" 2>/dev/null
      log_warn "Could not write resolv.conf into rootfs"
      return 1
    fi
  else
    if ! cp "$tmp_resolv" "$rootfs/etc/resolv.conf" 2>/dev/null; then
      rm -f "$tmp_resolv" 2>/dev/null
      log_warn "Could not write resolv.conf into rootfs"
      return 1
    fi
  fi
  
  rm -f "$tmp_resolv" 2>/dev/null
  log_debug "wrote DNS ($dns) into $rootfs/etc/resolv.conf"
}

# configure_rootfs_environment: configure /etc/resolv.conf, /etc/hosts,
# APT sandbox overrides for Android, and Android AID network groups.
configure_rootfs_environment() {
  local rootfs="${1:-$LINUX_ROOT}" dns="${2:-${DNS:-1.1.1.1}}"
  [ -n "$rootfs" ] || return 1
  path_within "$rootfs" "${LINUX_BASE:-$rootfs}" || return 1

  configure_rootfs_dns "$rootfs" "$dns"

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would configure rootfs environment (APT, hosts, groups) in $rootfs"
    return 0
  fi

  local is_root=0
  [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ] && is_root=1

  # 1. Configure /etc/hosts if missing or empty
  if [ ! -s "$rootfs/etc/hosts" ]; then
    local tmp_hosts
    tmp_hosts=$(mktemp 2>/dev/null || printf '/tmp/hosts.%s' "$$")
    cat >"$tmp_hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
EOF
    if [ "$is_root" = 1 ]; then
      run_as_root cp "$tmp_hosts" "$rootfs/etc/hosts" 2>/dev/null || true
    else
      cp "$tmp_hosts" "$rootfs/etc/hosts" 2>/dev/null || true
    fi
    rm -f "$tmp_hosts" 2>/dev/null
  fi

  # 2. Fix Debian/Ubuntu APT on Android:
  # Android kernel restricts raw sockets to AID_INET (GID 3003) or root.
  # When apt drops privileges to the '_apt' user, it gets EPERM on socket()
  # resulting in "Temporary failure resolving 'deb.debian.org'".
  # Setting APT::Sandbox::User "root" fixes this cleanly.
  if [ -d "$rootfs/etc/apt" ] || [ -f "$rootfs/usr/bin/apt-get" ] || [ -f "$rootfs/usr/bin/apt" ]; then
    local tmp_apt
    tmp_apt=$(mktemp 2>/dev/null || printf '/tmp/99android.%s' "$$")
    printf 'APT::Sandbox::User "root";\n' >"$tmp_apt"
    if [ "$is_root" = 1 ]; then
      run_as_root mkdir -p "$rootfs/etc/apt/apt.conf.d" 2>/dev/null || true
      run_as_root cp "$tmp_apt" "$rootfs/etc/apt/apt.conf.d/99android" 2>/dev/null || true
    else
      mkdir -p "$rootfs/etc/apt/apt.conf.d" 2>/dev/null || true
      cp "$tmp_apt" "$rootfs/etc/apt/apt.conf.d/99android" 2>/dev/null || true
    fi
    rm -f "$tmp_apt" 2>/dev/null
  fi

  # 3. Android AID network groups in /etc/group
  if [ -f "$rootfs/etc/group" ]; then
    local tmp_group
    tmp_group=$(mktemp 2>/dev/null || printf '/tmp/group.%s' "$$")
    if [ "$is_root" = 1 ]; then
      run_as_root cp "$rootfs/etc/group" "$tmp_group" 2>/dev/null || true
    else
      cp "$rootfs/etc/group" "$tmp_group" 2>/dev/null || true
    fi
    local g
    for g in "aid_inet:x:3003:root,_apt" "aid_net_raw:x:3004:root" "aid_net_admin:x:3005:root" "aid_sdcard_rw:x:1015:root" "aid_media_rw:x:1023:root" "aid_everybody:x:9997:root"; do
      local gname="${g%%:*}"
      if ! grep -q "^${gname}:" "$tmp_group" 2>/dev/null; then
        printf '%s\n' "$g" >>"$tmp_group"
      fi
    done
    if [ "$is_root" = 1 ]; then
      run_as_root cp "$tmp_group" "$rootfs/etc/group" 2>/dev/null || true
    else
      cp "$tmp_group" "$rootfs/etc/group" 2>/dev/null || true
    fi
    rm -f "$tmp_group" 2>/dev/null
  fi
}
