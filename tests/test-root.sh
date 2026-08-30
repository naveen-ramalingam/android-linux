#!/usr/bin/env bash
# test-root.sh - Root detection across rooted and non-rooted profiles.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/root.sh"
. "$LIB_DIR/architecture.sh"
. "$LIB_DIR/detect.sh"

printf 'Root detection\n'

t_root_available() { detect_root; printf '%s' "$ROOT_AVAILABLE"; }
t_root_provider()  { detect_root; printf '%s' "$ROOT_PROVIDER"; }

assert_eq "1" "$(with_mock arm64-root   t_root_available)" "rooted profile -> root available"
assert_eq "0" "$(with_mock arm32-noroot t_root_available)" "non-root profile -> no root"
assert_eq "Magisk" "$(with_mock arm64-root t_root_provider)" "root provider detected as Magisk"

# recommend_mode: rooted+chroot -> chroot; non-root -> proot
t_mode() {
  detect_root; detect_termux; detect_capabilities; recommend_mode; printf '%s' "$RECOMMENDED_MODE"
}
# Force chroot capability on for the rooted case by shimming have_cmd is complex;
# instead assert the decision logic directly.
ROOT_AVAILABLE=1; CAP_CHROOT=1; CAP_PROOT=1; IS_TERMUX=0
recommend_mode; assert_eq "chroot" "$RECOMMENDED_MODE" "root + chroot -> chroot mode"
ROOT_AVAILABLE=0; CAP_CHROOT=0; CAP_PROOT=1
recommend_mode; assert_eq "proot" "$RECOMMENDED_MODE" "no root + proot -> proot mode"

test_summary
