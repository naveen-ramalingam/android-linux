#!/usr/bin/env bash
# storage.sh - Storage and memory detection.
# Source after common.sh.

# bytes_available: available bytes at a given path (best-effort, portable).
bytes_available() {
  local path="$1" avail=""
  [ -d "$path" ] || path=$(dirname "$path")
  # Prefer POSIX `df -k` and parse the "Available" column.
  if have_cmd df; then
    # Try -P (POSIX) then plain.
    local line
    line=$(df -Pk "$path" 2>/dev/null | awk 'NR==2{print $4}') \
      || line=$(df -k "$path" 2>/dev/null | awk 'NR==2{print $4}')
    # Only accept an all-numeric field (df layouts vary across toybox/busybox).
    case "$line" in ''|*[!0-9]*) line="" ;; esac
    if [ -n "$line" ]; then
      avail=$(( line * 1024 ))
    fi
  fi
  printf '%s' "${avail:-0}"
}

# detect_storage: sets STORAGE_AVAIL_BYTES for the install base.
detect_storage() {
  local path="${1:-${LINUX_BASE:-$HOME}}"
  STORAGE_AVAIL_BYTES=$(bytes_available "$path")
  export STORAGE_AVAIL_BYTES
  log_debug "storage: avail=$STORAGE_AVAIL_BYTES bytes at $path"
}

# detect_memory: sets MEM_TOTAL_BYTES from /proc/meminfo when available.
detect_memory() {
  MEM_TOTAL_BYTES=0
  if [ -r /proc/meminfo ]; then
    local kb
    kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    [ -n "$kb" ] && MEM_TOTAL_BYTES=$(( kb * 1024 ))
  fi
  export MEM_TOTAL_BYTES
  log_debug "memory: total=$MEM_TOTAL_BYTES bytes"
}

# mem_gb: memory in GB with one decimal (integer math).
mem_gb() {
  local b="${MEM_TOTAL_BYTES:-0}"
  [ "$b" -gt 0 ] 2>/dev/null || { printf '0.0'; return; }
  local tenths=$(( b * 10 / 1073741824 ))
  printf '%d.%d' $(( tenths / 10 )) $(( tenths % 10 ))
}

# check_space: verify at least <need_bytes> is available. Returns 0/1.
# Usage: check_space <need_bytes> [path]
check_space() {
  local need="$1" path="${2:-${LINUX_BASE:-$HOME}}"
  local have; have=$(bytes_available "$path")
  [ "$have" -ge "$need" ] 2>/dev/null
}

# recommend_desktop: echo a recommendation based on RAM.
recommend_desktop() {
  local b="${MEM_TOTAL_BYTES:-0}"
  if [ "$b" -lt 2147483648 ] 2>/dev/null; then
    printf 'none'      # < 2 GB
  elif [ "$b" -lt 4294967296 ] 2>/dev/null; then
    printf 'xfce'      # 2-4 GB, possible
  else
    printf 'xfce'      # >= 4 GB, recommended
  fi
}
