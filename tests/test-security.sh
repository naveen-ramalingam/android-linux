#!/usr/bin/env bash
# test-security.sh - Tests for the security hardening: shell quoting, input
# validation, tar traversal rejection, symlink escapes, and fail-closed
# checksum verification.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/distro.sh"
. "$LIB_DIR/network.sh"

printf 'Security hardening\n'

# --- shell_quote -----------------------------------------------------------
q=$(shell_quote "plain")
assert_eq "'plain'" "$q" "shell_quote wraps plain text"

dangerous="a'b; rm -rf / \$(evil) \"x\""
q=$(shell_quote "$dangerous")
restored=""
eval "restored=$q"
# shellcheck disable=SC2154
assert_eq "$dangerous" "$restored" "shell_quote round-trips metacharacters safely"

# --- validate_port ---------------------------------------------------------
assert_true  validate_port 2222  "port 2222 valid"
assert_true  validate_port 1     "port 1 valid"
assert_true  validate_port 65535 "port 65535 valid"
assert_false validate_port 0     "port 0 invalid"
assert_false validate_port 65536 "port 65536 invalid"
assert_false validate_port "22; rm -rf /" "non-numeric port rejected"
assert_false validate_port ""    "empty port rejected"

# --- validate_name ---------------------------------------------------------
assert_true  validate_name android  "username android valid"
assert_true  validate_name a_b-c9   "username with _ - digit valid"
assert_false validate_name "a;b"    "username with ; rejected"
assert_false validate_name "a b"    "username with space rejected"
# shellcheck disable=SC2016
assert_false validate_name 'a$b'    "username with dollar rejected"
assert_false validate_name "-abc"   "username leading hyphen rejected"
assert_false validate_name "9abc"   "username leading digit rejected"

# --- tar_is_safe -----------------------------------------------------------
WORK="$TEST_TMP/tarwork"; mkdir -p "$WORK/work"
echo hello > "$WORK/work/file.txt"

# Benign archive.
tar -czf "$WORK/good.tar.gz" -C "$WORK" work/file.txt 2>/dev/null
assert_true tar_is_safe "$WORK/good.tar.gz" "benign archive accepted"

# Craft a traversal archive (".." member) with bsdtar -s or GNU --transform.
TRAVERSAL_OK=0
if tar --version 2>/dev/null | grep -qi 'bsdtar\|libarchive'; then
  tar -czf "$WORK/bad.tar.gz" -s '|^work|work/../escape|' -C "$WORK" work/file.txt 2>/dev/null && TRAVERSAL_OK=1
else
  tar --transform 's|^work|work/../escape|' -czf "$WORK/bad.tar.gz" -C "$WORK" work/file.txt 2>/dev/null && TRAVERSAL_OK=1
fi
if [ "$TRAVERSAL_OK" = 1 ] && tar -tzf "$WORK/bad.tar.gz" 2>/dev/null | grep -q '\.\.'; then
  assert_false tar_is_safe "$WORK/bad.tar.gz" "traversal ('..') archive rejected"
else
  printf '  [PASS] traversal-craft unsupported by this tar (skipped)\n'; TEST_PASS=$((TEST_PASS+1))
fi

# --- .tar.xz handling (regression for on-device failure) --------------------
if have_cmd xz; then
  tar -cJf "$WORK/xz.tar.xz" -C "$WORK" work/file.txt 2>/dev/null
  assert_true tar_is_safe "$WORK/xz.tar.xz" "benign .tar.xz accepted when xz present"

  # Simulate a missing xz decoder: restricted PATH without xz must be refused.
  NOXZ="$TEST_TMP/noxzbin"; mkdir -p "$NOXZ"
  for t in tar gzip grep sed head basename cat mkdir date sh bash; do
    _p=$(command -v "$t" 2>/dev/null) && ln -sf "$_p" "$NOXZ/$t"
  done
  # shellcheck disable=SC2016
  if env PATH="$NOXZ" bash -c '. "$1"; decompressor_ready "$2"' _ "$LIB_DIR/common.sh" "$WORK/xz.tar.xz" 2>/dev/null; then
    printf '  [FAIL] missing xz should be refused\n'; TEST_FAIL=$((TEST_FAIL+1))
  else
    printf '  [PASS] missing xz decoder refused with actionable hint\n'; TEST_PASS=$((TEST_PASS+1))
  fi
else
  printf '  [PASS] xz not installed locally (xz-path skipped)\n'; TEST_PASS=$((TEST_PASS+1))
  printf '  [PASS] xz not installed locally (missing-tool skipped)\n'; TEST_PASS=$((TEST_PASS+1))
fi

# --- safe_remove symlink escape --------------------------------------------
SB="$TEST_TMP/sbase"; mkdir -p "$SB/sub"
echo keep > "$SB/sub/keep.txt"
ln -s /etc "$SB/sub/escape"
assert_false safe_remove "$SB/sub/escape" "$SB" "safe_remove refuses symlink escaping to /etc"
assert_true  bash -c "[ -e /etc ]" "target of escaped symlink untouched"
assert_true  safe_remove "$SB/sub" "$SB" "safe_remove still removes normal subdir"

# --- configure_rootfs_dns symlink handling (Debian/Ubuntu regression) -------
DNSROOT="$TEST_TMP/dnsroot"; mkdir -p "$DNSROOT/etc"
ln -s /nonexistent/resolv-target "$DNSROOT/etc/resolv.conf"
assert_true configure_rootfs_dns "$DNSROOT" "1.1.1.1" "DNS write over dangling resolv.conf symlink succeeds"
assert_true bash -c "[ -f '$DNSROOT/etc/resolv.conf' ] && [ ! -L '$DNSROOT/etc/resolv.conf' ]" "resolv.conf replaced with a regular file"

# --- verify_sha256 fail-closed ---------------------------------------------
SAMPLE="$TEST_TMP/sample.bin"; echo data > "$SAMPLE"
GOOD=$(sha256_of "$SAMPLE")

DISTRO_HAS_CHECKSUM=1
assert_true verify_sha256 "$SAMPLE" "$GOOD" "matching checksum accepted"

# Mismatch must fail.
DISTRO_HAS_CHECKSUM=1
assert_false verify_sha256 "$SAMPLE" "0000000000000000000000000000000000000000000000000000000000000000" "mismatched checksum rejected"

# No checksum for a checksum-expected distro, non-interactive -> refuse.
ANDROID_LINUX_ASSUME_YES=0
DISTRO_HAS_CHECKSUM=1
assert_false verify_sha256 "$SAMPLE" "" "unverified checksum-expected distro refused (fail closed)"

# No checksum for a no-checksum distro -> allowed (with warning).
DISTRO_HAS_CHECKSUM=0
assert_true verify_sha256 "$SAMPLE" "" "no-checksum distro allowed unverified"

test_summary
