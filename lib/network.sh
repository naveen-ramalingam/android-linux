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
    [ -z "$NET_IPV4" ] && NET_IPV4=$(ip -4 route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
  fi
  if [ -z "$NET_IPV4" ] && have_cmd getprop; then
    NET_IPV4=$(getprop_safe dhcp.wlan0.ipaddress)
    [ -z "$NET_IPV4" ] && NET_IPV4=$(getprop_safe dhcp.wlan1.ipaddress)
  fi
  if [ -z "$NET_IPV4" ]; then
    if have_cmd ip; then
      NET_IPV4=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127' | head -1 | cut -d/ -f1)
    elif have_cmd ifconfig; then
      NET_IPV4=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127' | head -1 | sed 's/addr://')
    fi
  fi

  # Primary IPv6
  if have_cmd ip; then
    NET_IPV6=$(ip -6 addr show 2>/dev/null | awk '/inet6 /{print $2}' | grep -vi '^fe80\|^::1' | head -1 | cut -d/ -f1)
  fi

  # DNS from getprop or resolv.conf if present.
  local android_dns; android_dns=$(getprop_safe net.dns1)
  if [ -n "$android_dns" ]; then
    NET_DNS="$android_dns"
  elif [ -r /etc/resolv.conf ]; then
    local d
    d=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
    [ -n "$d" ] && NET_DNS="$d"
  fi

  # Connectivity probe (ping first, then any http client, then IP existence).
  if have_cmd ping && timeout_run 3 ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    NET_ONLINE=1
  elif have_cmd curl && timeout_run 5 curl -fsS -o /dev/null --max-time 4 https://1.1.1.1 2>/dev/null; then
    NET_ONLINE=1
  elif have_cmd wget && timeout_run 5 wget -q -O /dev/null --timeout=4 https://1.1.1.1 2>/dev/null; then
    NET_ONLINE=1
  elif [ -n "$NET_IPV4" ]; then
    NET_ONLINE=1
  fi

  export NET_ONLINE NET_IPV4 NET_IPV6 NET_DNS
  log_debug "network: online=$NET_ONLINE ipv4=$NET_IPV4 dns=$NET_DNS"
}

# net_status_print: human-readable network status.
net_status_print() {
  detect_network
  printf '\n%s▸ Network & Device IP Information%s\n\n' "${C_BOLD}" "${C_RESET}"
  printf '  %sStatus:%s       %s\n' "$C_BOLD" "$C_RESET" "$([ "$NET_ONLINE" = 1 ] && echo "${C_GREEN}CONNECTED (Online)${C_RESET}" || echo "${C_YELLOW}OFFLINE / Local only${C_RESET}")"
  printf '  %sDevice IP:%s    %s\n' "$C_BOLD" "$C_RESET" "${NET_IPV4:-Not detected}"
  [ -n "$NET_IPV6" ] && printf '  %sIPv6:%s         %s\n' "$C_BOLD" "$C_RESET" "$NET_IPV6"
  printf '  %sDNS Server:%s   %s\n' "$C_BOLD" "$C_RESET" "${NET_DNS:-1.1.1.1}"
  
  # List all interface addresses
  printf '\n  %sInterface IP Addresses:%s\n' "$C_BOLD" "$C_RESET"
  local found_if=0
  if have_cmd ip; then
    while read -r iface ipaddr; do
      if [ -z "$iface" ] || [ -z "$ipaddr" ]; then continue; fi
      printf '    • %-12s %s\n' "$iface:" "$ipaddr"
      found_if=1
    done < <(ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}' | cut -d/ -f1)
  elif have_cmd ifconfig; then
    while read -r iface ipaddr; do
      if [ -z "$iface" ] || [ -z "$ipaddr" ]; then continue; fi
      printf '    • %-12s %s\n' "$iface:" "$ipaddr"
      found_if=1
    done < <(ifconfig 2>/dev/null | awk '/^[a-zA-Z0-9]+/{iface=$1} /inet /{print iface, $2}' | sed 's/addr://')
  fi
  [ "$found_if" = 0 ] && [ -n "$NET_IPV4" ] && printf '    • %-12s %s\n' "default:" "$NET_IPV4"

  # Show connection shortcuts for SSH and VNC
  if [ -n "${NET_IPV4:-}" ]; then
    printf '\n  %sConnection Shortcuts:%s\n' "$C_BOLD" "$C_RESET"
    printf '    • SSH Command:  ssh %s@%s -p %s\n' "${LINUX_USER:-android}" "$NET_IPV4" "${SSH_PORT:-2222}"
    printf '    • VNC Viewer:   %s:%s\n' "$NET_IPV4" "${VNC_PORT:-5901}"
    printf '    • Local Device: 127.0.0.1:%s\n' "${VNC_PORT:-5901}"
  fi
  printf '\n'
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
  
  # Debian/Ubuntu ship etc/resolv.conf as a symlink (e.g. -> /run/systemd/...).
  # Redirecting would follow the dangling link and fail, so replace it with a
  # regular file.
  if [ -L "$rootfs/etc/resolv.conf" ]; then
    if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
      run_as_root rm -f "$rootfs/etc/resolv.conf" 2>/dev/null || true
    else
      rm -f "$rootfs/etc/resolv.conf" 2>/dev/null || true
    fi
  fi
  
  local resolv_content
  resolv_content=$(
    local d
    for d in "$dns" \
      "$(safe_get getprop net.dns1)" \
      "$(safe_get getprop net.dns2)" \
      "1.1.1.1" "8.8.8.8" "9.9.9.9" "8.8.4.4"; do
      [ -n "$d" ] && printf 'nameserver %s\n' "$d"
    done | awk '!seen[$0]++'
  )
  
  if ! write_rootfs_file "$rootfs/etc/resolv.conf" "$resolv_content"; then
    log_warn "Could not write resolv.conf into rootfs"
    return 1
  fi
  
  log_debug "wrote DNS ($dns) into $rootfs/etc/resolv.conf"
}

# configure_rootfs_environment: configure /etc/resolv.conf, /etc/hosts,
# APT sandbox overrides for Android, and Android AID network groups.
configure_rootfs_environment() {
  local rootfs="${1:-$LINUX_ROOT}" dns="${2:-${DNS:-1.1.1.1}}"
  [ -n "$rootfs" ] || return 1
  path_within "$rootfs" "${LINUX_BASE:-$rootfs}" || return 1

  fix_rootfs_symlinks "$rootfs"
  configure_rootfs_dns "$rootfs" "$dns"

  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would configure rootfs environment (APT, hosts, groups) in $rootfs"
    return 0
  fi

  # 1. Configure /etc/hosts if missing or empty
  if [ ! -s "$rootfs/etc/hosts" ]; then
    local hosts_content
    hosts_content=$(printf '127.0.0.1 localhost\n::1 localhost ip6-localhost ip6-loopback\n')
    write_rootfs_file "$rootfs/etc/hosts" "$hosts_content" || true
  fi

  # 1b. Strip 'systemd' from nsswitch.conf passwd/group/shadow lines.
  #
  # The LXC rootfs ships with "passwd: files systemd". The systemd NSS plugin
  # requires a running systemd (D-Bus socket, /proc, etc.) — none of which
  # exist inside an Android chroot. When the plugin fails to initialise, glibc
  # returns NULL for ALL getpwnam() / getgrnam() calls, even for users that ARE
  # in /etc/passwd. dpkg reads nsswitch.conf on startup and calls getpwnam()
  # for every statoverride entry (e.g. "root messagebus …") — if either lookup
  # returns NULL it prints "unknown system user 'root'" and aborts with a
  # "fatal, unrecoverable error".
  #
  # Fix: rewrite the affected lines to "files" only, in-place.
  # We do this unconditionally on every configure run so it survives upgrades
  # that might restore the original file.
  if [ -f "$rootfs/etc/nsswitch.conf" ]; then
    local nss_content nss_fixed
    nss_content=$(cat "$rootfs/etc/nsswitch.conf" 2>/dev/null || true)
    nss_fixed=$(printf '%s\n' "$nss_content" \
      | sed 's/^\(passwd:\s*\).*files.*/\1files/' \
      | sed 's/^\(group:\s*\).*files.*/\1files/' \
      | sed 's/^\(shadow:\s*\).*files.*/\1files/' \
      | sed 's/^\(gshadow:\s*\).*files.*/\1files/')
    if [ "$nss_content" != "$nss_fixed" ]; then
      write_rootfs_file "$rootfs/etc/nsswitch.conf" "$nss_fixed" || true
    fi
  else
    write_rootfs_file "$rootfs/etc/nsswitch.conf" \
"passwd:   files
group:    files
shadow:   files
gshadow:  files
hosts:    files dns
networks: files
protocols: db files
services: db files
ethers:   db files
rpc:      db files" || true
  fi

  # 2. Fix Debian/Ubuntu APT on Android & populate sources.list if missing
  if [ -d "$rootfs/etc/apt" ] || [ -f "$rootfs/usr/bin/apt-get" ] || [ -f "$rootfs/usr/bin/apt" ]; then
    write_rootfs_file "$rootfs/etc/apt/apt.conf.d/99android" 'APT::Sandbox::User "root";' || true
    if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
      run_as_root mkdir -p \
        "$rootfs/etc/apt/sources.list.d" \
        "$rootfs/etc/apt/preferences.d" \
        "$rootfs/etc/apt/trusted.gpg.d" \
        "$rootfs/etc/apt/apt.conf.d" 2>/dev/null || true
    else
      mkdir -p \
        "$rootfs/etc/apt/sources.list.d" \
        "$rootfs/etc/apt/preferences.d" \
        "$rootfs/etc/apt/trusted.gpg.d" \
        "$rootfs/etc/apt/apt.conf.d" 2>/dev/null || true
    fi

    local has_sources=0
    [ -s "$rootfs/etc/apt/sources.list" ] && has_sources=1
    if [ -d "$rootfs/etc/apt/sources.list.d" ]; then
      local count
      count=$(find "$rootfs/etc/apt/sources.list.d" -maxdepth 1 -type f 2>/dev/null | wc -l)
      [ "${count:-0}" -gt 0 ] && has_sources=1
    fi

    if [ "$has_sources" = 0 ]; then
      case "${DISTRO_FN:-debian}" in
        ubuntu)
          local u_suite="${DISTRO_SUITE:-noble}"
          local ub_sources
          ub_sources=$(cat <<EOF
deb http://ports.ubuntu.com/ubuntu-ports ${u_suite} main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${u_suite}-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${u_suite}-security main restricted universe multiverse
EOF
)
          write_rootfs_file "$rootfs/etc/apt/sources.list" "$ub_sources" || true
          ;;
        *)
          local d_suite="${DISTRO_SUITE:-trixie}"
          local deb_sources
          deb_sources=$(cat <<EOF
deb http://deb.debian.org/debian ${d_suite} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security ${d_suite}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${d_suite}-updates main contrib non-free non-free-firmware
EOF
)
          write_rootfs_file "$rootfs/etc/apt/sources.list" "$deb_sources" || true
          ;;
      esac
    fi
  elif [ -d "$rootfs/etc/apk" ]; then
    if [ ! -s "$rootfs/etc/apk/repositories" ]; then
      local apk_repos
      apk_repos=$(cat <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.20/main
https://dl-cdn.alpinelinux.org/alpine/v3.20/community
EOF
)
      write_rootfs_file "$rootfs/etc/apk/repositories" "$apk_repos" || true
    fi
  fi

  # 3. Android AID network groups in /etc/group
  if [ -f "$rootfs/etc/group" ]; then
    local cur_group
    cur_group=$(cat "$rootfs/etc/group" 2>/dev/null || true)
    local g
    for g in "aid_inet:x:3003:root,_apt" "aid_net_raw:x:3004:root" "aid_net_admin:x:3005:root" "aid_sdcard_rw:x:1015:root" "aid_media_rw:x:1023:root" "aid_everybody:x:9997:root"; do
      local gname="${g%%:*}"
      if ! printf '%s\n' "$cur_group" | grep -q "^${gname}:"; then
        cur_group=$(printf '%s\n%s' "$cur_group" "$g")
      fi
    done
    write_rootfs_file "$rootfs/etc/group" "$cur_group" || true
  fi
}
