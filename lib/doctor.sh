#!/usr/bin/env bash
# doctor.sh - Health checks with PASS/WARN/FAIL and suggested fixes.
# Source after the detection libraries and lifecycle.sh.

_DOCTOR_FAIL=0
_DOCTOR_WARN=0

_pass() { printf '%s[PASS]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
_warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; _DOCTOR_WARN=$((_DOCTOR_WARN+1)); }
_fail() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*"; _DOCTOR_FAIL=$((_DOCTOR_FAIL+1)); }

doctor_run() {
  _DOCTOR_FAIL=0; _DOCTOR_WARN=0
  detect_all
  config_load

  banner
  printf '\nRunning diagnostics...\n\n'

  # Architecture
  if arch_is_supported; then _pass "Architecture supported: $(arch_label)"
  else _fail "Unsupported architecture: $ARCH_RAW"; fi

  # Root / mode
  if [ "${ROOT_AVAILABLE:-0}" = 1 ]; then _pass "Root available ($ROOT_PROVIDER)"
  else _warn "No root - PRoot mode will be used (fully supported)"; fi

  # Required binaries
  local b
  for b in tar curl; do
    if have_cmd "$b"; then _pass "Found required tool: $b"
    else _fail "Missing required tool: $b (install via pkg/apt)"; fi
  done
  if have_cmd wget || have_cmd aria2c; then _pass "Additional download tool present"; fi
  if have_cmd xz; then _pass "xz present (needed for .tar.xz rootfs)"
  else _warn "xz missing - Debian/Ubuntu extraction may fail (pkg install xz-utils)"; fi

  # Install base + storage
  if [ -n "${LINUX_BASE:-}" ] && [ -d "$LINUX_BASE" ]; then
    _pass "Install base exists: $LINUX_BASE"
    local avail; avail=$(bytes_available "$LINUX_BASE")
    if [ "$avail" -ge $(( 512 * 1024 * 1024 )) ] 2>/dev/null; then _pass "Free space: $(human_bytes "$avail")"
    else _warn "Low free space: $(human_bytes "$avail")"; fi
  else
    _warn "No installation found (run: android-linux install)"
  fi

  # Rootfs integrity
  if [ -n "${LINUX_ROOT:-}" ] && [ -d "$LINUX_ROOT" ]; then
    if [ -e "$LINUX_ROOT/bin/sh" ] || [ -e "$LINUX_ROOT/bin/busybox" ]; then
      _pass "Rootfs looks valid ($LINUX_ROOT)"
    else
      _fail "Rootfs present but missing /bin/sh - extraction may be incomplete"
    fi
    # Broken symlinks (sample check, non-fatal). Portable: toybox/busybox find
    # lack GNU's -xtype, so use -type l and test each link's target with [ -e ].
    local l broken=0
    while IFS= read -r l; do
      [ -e "$l" ] || { broken=1; break; }
    done < <(find "$LINUX_ROOT" -maxdepth 2 -type l 2>/dev/null | head -50)
    if [ "$broken" = 1 ]; then
      _warn "Some broken symlinks found in rootfs (usually harmless)"
    fi
  fi

  # Mounts (chroot mode)
  if [ "${INSTALL_MODE:-}" = "chroot" ] && [ -d "${LINUX_ROOT:-/nonexistent}" ]; then
    if _is_mounted "$LINUX_ROOT/proc" 2>/dev/null; then _pass "/proc mounted in chroot"
    else _warn "/proc not mounted (run: android-linux start)"; fi
  fi

  # systemd expectation
  _warn "systemd is not assumed - services use OpenRC/manual start in this environment"

  # SELinux
  case "$SELINUX_STATUS" in
    Enforcing) _warn "SELinux Enforcing - some chroot mounts may be blocked; PRoot avoids this" ;;
    *) _pass "SELinux: $SELINUX_STATUS" ;;
  esac

  # Kernel age
  if [ "${KERNEL_OLD:-0}" = 1 ]; then
    _warn "Old kernel ($KERNEL_VERSION) - Docker/systemd/FUSE may be unavailable"
  else
    _pass "Kernel: $KERNEL_VERSION"
  fi

  # Network
  detect_network
  if [ "${NET_ONLINE:-0}" = 1 ]; then _pass "Network connectivity OK"
  else _warn "No network detected (needed for install/update)"; fi
  if [ -n "${NET_DNS:-}" ]; then _pass "DNS: $NET_DNS"
  else _warn "DNS not resolved"; fi

  # Stale locks / pid files
  if [ -d "${LINUX_BASE:-/nonexistent}" ] && find "$LINUX_BASE" -maxdepth 2 -name '*.pid' 2>/dev/null | head -1 | grep -q .; then
    _warn "Stale PID files found under $LINUX_BASE"
  fi

  printf '\n'
  hr
  printf 'Summary: %s%d warning(s)%s, %s%d failure(s)%s\n' \
    "$C_YELLOW" "$_DOCTOR_WARN" "$C_RESET" "$C_RED" "$_DOCTOR_FAIL" "$C_RESET"
  [ "$_DOCTOR_FAIL" -eq 0 ]
}
