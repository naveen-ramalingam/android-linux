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
  mkdir -p "$rootfs/etc" 2>/dev/null || true
  {
    printf 'nameserver %s\n' "$dns"
    printf 'nameserver 8.8.8.8\n'
  } >"$rootfs/etc/resolv.conf" 2>/dev/null || {
    log_warn "Could not write resolv.conf into rootfs"; return 1; }
  log_debug "wrote DNS ($dns) into $rootfs/etc/resolv.conf"
}
