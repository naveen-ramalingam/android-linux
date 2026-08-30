#!/usr/bin/env bash
# test-distro.sh - Distro registry, archive naming, FS layout and estimates.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/architecture.sh"
. "$LIB_DIR/detect.sh"
. "$LIB_DIR/filesystem.sh"
. "$LIB_DIR/distro.sh"
. "$LIB_DIR/debian.sh"
. "$LIB_DIR/ubuntu.sh"
. "$LIB_DIR/alpine.sh"
. "$LIB_DIR/archarm.sh"

printf 'Distro + filesystem\n'

ARCH="arm64"
distro_resolve "debian"
assert_eq "Debian 13 (trixie)" "$DISTRO_DISPLAY" "debian resolves to trixie"
assert_eq "alpine-minirootfs-3.20.3-aarch64.tar.gz" \
  "$(distro_resolve alpine; distro_archive_name)" "alpine archive name"

# Forbidden base rejection
assert_false fs_validate_install_base "/system/foo" "reject /system as base"
assert_false fs_validate_install_base "/data" "reject /data as base"
assert_true fs_validate_install_base "$TEST_TMP/ok" "accept normal base"

# Layout creation is confined to the sandbox
LINUX_BASE="$TEST_TMP/layout"
ANDROID_LINUX_DRY_RUN=0
fs_init_layout "$LINUX_BASE"
assert_true bash -c "[ -d \"$LINUX_BASE/rootfs\" ]" "layout created rootfs dir"
assert_true bash -c "[ -d \"$LINUX_BASE/downloads\" ]" "layout created downloads dir"

# Estimates: desktop adds headroom
MIN=$(fs_estimate_bytes alpine none)
GUI=$(fs_estimate_bytes alpine xfce)
assert_true bash -c "[ $GUI -gt $MIN ]" "desktop estimate larger than minimal"

test_summary
