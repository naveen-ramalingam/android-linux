#!/usr/bin/env bash
# test-detect.sh - Device/Android/kernel/SELinux detection under mocked Android.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/architecture.sh"
. "$LIB_DIR/root.sh"
. "$LIB_DIR/storage.sh"
. "$LIB_DIR/network.sh"
. "$LIB_DIR/detect.sh"

printf 'Detection\n'

t_device() { detect_device; printf '%s|%s|%s' "$DEV_MANUFACTURER" "$DEV_MODEL" "$DEV_CODENAME"; }
t_android() { detect_android; printf '%s|%s|%s' "$ANDROID_RELEASE" "$ANDROID_SDK" "$IS_ANDROID"; }
t_kernel() { detect_kernel; printf '%s|%s' "$KERNEL_VERSION" "$KERNEL_OLD"; }
t_selinux() { detect_selinux; printf '%s' "$SELINUX_STATUS"; }

assert_eq "Google|Pixel Test|testdev" "$(with_mock arm64-root t_device)" "device props detected"
assert_eq "13|33|1" "$(with_mock arm64-root t_android)" "android version detected"
assert_eq "5.10.100|0" "$(with_mock arm64-root t_kernel)" "modern kernel not flagged old"
assert_eq "3.18.140|1" "$(with_mock old-kernel t_kernel)" "3.18 kernel flagged old"
assert_eq "Enforcing" "$(with_mock arm64-root t_selinux)" "SELinux Enforcing detected"

# Storage / memory helpers (real host values, just check numeric output)
detect_memory
assert_true bash -c "[ \"$MEM_TOTAL_BYTES\" -ge 0 ] 2>/dev/null" "memory bytes numeric"
detect_storage "$TEST_TMP"
assert_true bash -c "[ \"$STORAGE_AVAIL_BYTES\" -ge 0 ] 2>/dev/null" "storage bytes numeric"

# Missing-utility tolerance: with only getprop/uname/id available.
t_detect_all() { detect_all; printf '%s|%s' "$ARCH" "$IS_ANDROID"; }
assert_eq "arm64|1" "$(with_mock missing-tools t_detect_all)" "detect_all survives missing tools"

test_summary
