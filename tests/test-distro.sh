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

# Dependency resolution
distro_resolve debian >/dev/null
assert_eq "xz" "$(distro_decoder)" "debian rootfs needs xz"
distro_resolve alpine >/dev/null
assert_eq "gzip" "$(distro_decoder)" "alpine rootfs needs gzip"
assert_eq "xz-utils" "$(termux_pkg_for xz)" "xz maps to Termux xz-utils"
assert_eq "proot" "$(termux_pkg_for proot)" "proot maps to Termux proot"
assert_eq "coreutils" "$(termux_pkg_for coreutils)" "checksum maps to coreutils"

# On a fully-equipped (non-Termux) host, no packages are needed -> success.
if have_cmd xz && have_cmd tar && have_cmd curl; then
  DISTRO_FN=debian INSTALL_MODE=chroot IS_TERMUX=0
  assert_true ensure_dependencies "deps satisfied on a fully-equipped host"
fi

# Simulate Termux with xz + proot missing: a fake `pkg` should be invoked to
# auto-install them (xz-utils, proot).
FAKEBIN="$TEST_TMP/fakebin"; mkdir -p "$FAKEBIN"
for t in tar gzip curl shasum grep sed head basename cat mkdir date sh bash; do
  _tp=$(command -v "$t" 2>/dev/null) && ln -sf "$_tp" "$FAKEBIN/$t"
done
cat >"$FAKEBIN/pkg" <<EOF
#!/bin/bash
echo "\$*" >> "$FAKEBIN/pkg.log"
exit 0
EOF
chmod +x "$FAKEBIN/pkg"
if ( PATH="$FAKEBIN"; IS_TERMUX=1; INSTALL_MODE=proot; DISTRO_FN=debian; \
     ANDROID_LINUX_ASSUME_YES=1; ensure_dependencies >/dev/null 2>&1 ); then
  TEST_PASS=$((TEST_PASS+1)); printf '  [PASS] Termux auto-install path succeeded\n'
else
  TEST_FAIL=$((TEST_FAIL+1)); printf '  [FAIL] Termux auto-install path failed\n'
fi
if grep -q "xz-utils" "$FAKEBIN/pkg.log" 2>/dev/null && grep -q "proot" "$FAKEBIN/pkg.log" 2>/dev/null; then
  TEST_PASS=$((TEST_PASS+1)); printf '  [PASS] pkg was asked to install xz-utils + proot\n'
else
  TEST_FAIL=$((TEST_FAIL+1)); printf '  [FAIL] pkg not invoked with xz-utils/proot\n'
fi

test_summary
