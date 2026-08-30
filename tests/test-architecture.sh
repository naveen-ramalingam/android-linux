#!/usr/bin/env bash
# test-architecture.sh - Architecture detection and distro arch mapping.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/architecture.sh"
. "$LIB_DIR/detect.sh"

printf 'Architecture detection\n'

t_arch() {
  detect_architecture
  printf '%s' "$ARCH"
}

assert_eq "arm64"  "$(with_mock arm64-root   t_arch)" "aarch64 -> arm64"
assert_eq "arm"    "$(with_mock arm32-noroot t_arch)" "armv7l -> arm"
assert_eq "x86_64" "$(with_mock x86_64-noroot t_arch)" "x86_64 -> x86_64"

# Distro arch mapping
ARCH="arm64"
assert_eq "arm64"   "$(arch_for_distro debian)" "debian arm64 mapping"
assert_eq "aarch64" "$(arch_for_distro alpine)" "alpine aarch64 mapping"
ARCH="arm"
assert_eq "armhf"  "$(arch_for_distro ubuntu)" "ubuntu armhf mapping"
ARCH="x86"
assert_eq "i386"   "$(arch_for_distro debian)" "debian i386 mapping"
ARCH="unknown"
assert_false arch_for_distro debian "unknown arch has no debian mapping"
assert_false arch_is_supported "unknown arch unsupported"
ARCH="arm64"
assert_true arch_is_supported "arm64 supported"

test_summary
