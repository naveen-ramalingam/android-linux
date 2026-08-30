#!/usr/bin/env bash
# test-path-safety.sh - Path normalization, forbidden paths, and safe_remove.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"

printf 'Path safety\n'

assert_eq "/a/b"    "$(normalize_path /a/b)"     "absolute path unchanged"
assert_eq "/a/b"    "$(normalize_path /a/./b)"   "dot segment removed"
assert_eq "/a"      "$(normalize_path /a/b/..)"  "parent segment collapsed"
assert_eq "$PWD/abs" "$(normalize_path abs)" "relative path anchored at cwd"

assert_true  is_forbidden_path /        "root path forbidden"
assert_true  is_forbidden_path /system  "/system forbidden"
assert_true  is_forbidden_path /data    "/data forbidden"
assert_true  is_forbidden_path /sdcard  "/sdcard forbidden"
assert_true  is_forbidden_path "/usr/bin/.." "parent traversal to /usr forbidden"
assert_false is_forbidden_path "$TEST_TMP/safe" "sandbox path allowed"

assert_true  path_within "$TEST_TMP/safe/x" "$TEST_TMP/safe" "child within base"
assert_false path_within "$TEST_TMP/other" "$TEST_TMP/safe" "outside base rejected"

# safe_remove must refuse anything outside its base.
SAFE_BASE="$TEST_TMP/base"; mkdir -p "$SAFE_BASE/inner"
assert_true  safe_remove "$SAFE_BASE/inner" "$SAFE_BASE" "safe_remove inside base"
assert_false safe_remove "$TEST_TMP/outside" "$SAFE_BASE" "safe_remove outside base refused"
assert_false safe_remove / "$SAFE_BASE" "safe_remove refuses /"
assert_false safe_remove /system "$SAFE_BASE" "safe_remove refuses /system"

test_summary
