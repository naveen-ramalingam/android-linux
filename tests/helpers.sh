#!/usr/bin/env bash
# helpers.sh - Minimal test framework + Android environment mocks.
# Sourced by each tests/test-*.sh script.

set -u

TESTS_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APP_HOME=$(cd -P "$TESTS_DIR/.." && pwd)
LIB_DIR="$APP_HOME/lib"
export APP_HOME

TEST_PASS=0
TEST_FAIL=0

# Sandbox all state under a temp dir so tests never touch the real system.
TEST_TMP=$(mktemp -d 2>/dev/null || echo "/tmp/al-test.$$")
export ANDROID_LINUX_HOME="$TEST_TMP/home/.android-linux"
export ANDROID_LINUX_CONFIG_DIR="$TEST_TMP/home/.config/android-linux"
export ANDROID_LINUX_CONFIG_FILE="$ANDROID_LINUX_CONFIG_DIR/config.conf"
export ANDROID_LINUX_LOG_DIR="$ANDROID_LINUX_HOME/logs"
export ANDROID_LINUX_LOG_FILE="$ANDROID_LINUX_LOG_DIR/test.log"
export HOME="$TEST_TMP/home"
mkdir -p "$HOME"

cleanup() { rm -rf "$TEST_TMP" 2>/dev/null || true; }
trap cleanup EXIT

# --- assertions -------------------------------------------------------------
assert_eq() {
  # assert_eq <expected> <actual> <message>
  if [ "$1" = "$2" ]; then
    printf '  [PASS] %s\n' "$3"; TEST_PASS=$((TEST_PASS+1))
  else
    printf '  [FAIL] %s (expected="%s" actual="%s")\n' "$3" "$1" "$2"; TEST_FAIL=$((TEST_FAIL+1))
  fi
}

assert_true() {
  # assert_true <command...> ; last arg is message
  local msg="${*: -1}"
  set -- "${@:1:$(($#-1))}"
  if "$@"; then printf '  [PASS] %s\n' "$msg"; TEST_PASS=$((TEST_PASS+1))
  else printf '  [FAIL] %s\n' "$msg"; TEST_FAIL=$((TEST_FAIL+1)); fi
}

assert_false() {
  local msg="${*: -1}"
  set -- "${@:1:$(($#-1))}"
  if "$@"; then printf '  [FAIL] %s (expected failure)\n' "$msg"; TEST_FAIL=$((TEST_FAIL+1))
  else printf '  [PASS] %s\n' "$msg"; TEST_PASS=$((TEST_PASS+1)); fi
}

test_summary() {
  printf '\nResult: %d passed, %d failed\n' "$TEST_PASS" "$TEST_FAIL"
  [ "$TEST_FAIL" -eq 0 ]
}

# --- environment mocks ------------------------------------------------------
# mock_env <profile>: build a fake command dir on PATH simulating a device.
# Profiles: arm64-root | arm32-noroot | x86_64-noroot | missing-tools | old-kernel
mock_env() {
  local profile="$1"
  MOCK_BIN="$TEST_TMP/mockbin-$profile"
  mkdir -p "$MOCK_BIN"

  local uname_m="aarch64" abi="arm64-v8a" release="13" sdk="33" kernel="5.10.100"
  local manu="Google" model="Pixel Test" device="testdev" enforce="Enforcing"
  local id_uid="2000"  # non-root shell uid
  local have_su=0

  case "$profile" in
    arm64-root)   uname_m="aarch64"; abi="arm64-v8a"; have_su=1 ;;
    arm32-noroot) uname_m="armv7l"; abi="armeabi-v7a"; kernel="4.9.200" ;;
    x86_64-noroot) uname_m="x86_64"; abi="x86_64"; manu="Generic" ;;
    old-kernel)   uname_m="aarch64"; abi="arm64-v8a"; kernel="3.18.140"; have_su=1 ;;
    missing-tools) uname_m="aarch64"; abi="arm64-v8a" ;;
  esac

  # getprop mock
  cat >"$MOCK_BIN/getprop" <<EOF
#!/bin/bash
case "\$1" in
  ro.product.manufacturer) echo "$manu" ;;
  ro.product.model) echo "$model" ;;
  ro.product.device) echo "$device" ;;
  ro.build.version.release) echo "$release" ;;
  ro.build.version.sdk) echo "$sdk" ;;
  ro.product.cpu.abi) echo "$abi" ;;
  ro.product.cpu.abilist) echo "$abi" ;;
  ro.build.id) echo "TESTBUILD" ;;
  *) echo "" ;;
esac
EOF

  # uname mock (delegates to real uname except -m/-r)
  cat >"$MOCK_BIN/uname" <<EOF
#!/bin/bash
case "\$1" in
  -m) echo "$uname_m" ;;
  -r) echo "$kernel" ;;
  -n) echo "$model" ;;
  *) /usr/bin/uname "\$@" 2>/dev/null || echo Linux ;;
esac
EOF

  # getenforce mock
  printf '#!/bin/bash\necho "%s"\n' "$enforce" >"$MOCK_BIN/getenforce"

  # id mock (simulate uid)
  cat >"$MOCK_BIN/id" <<EOF
#!/bin/bash
if [ "\$1" = "-u" ]; then echo "$id_uid"; else echo "uid=$id_uid(shell) gid=$id_uid"; fi
EOF

  # su mock (only for rooted profiles)
  if [ "$have_su" = 1 ]; then
    cat >"$MOCK_BIN/su" <<'EOF'
#!/bin/bash
if [ "$1" = "-c" ]; then
  case "$2" in
    id) echo "uid=0(root) gid=0(root)"; exit 0 ;;
    *) exit 0 ;;
  esac
fi
echo "uid=0(root)"; exit 0
EOF
  fi

  # magisk marker for provider detection
  if [ "$have_su" = 1 ]; then
    printf '#!/bin/bash\necho magisk\n' >"$MOCK_BIN/magisk"
  fi

  chmod +x "$MOCK_BIN"/* 2>/dev/null || true

  if [ "$profile" = "missing-tools" ]; then
    # Only expose getprop/uname/id - simulate a bare environment.
    rm -f "$MOCK_BIN/getenforce"
    MOCK_PATH="$MOCK_BIN"
  else
    MOCK_PATH="$MOCK_BIN:$PATH"
  fi
  export MOCK_BIN MOCK_PATH
}

# with_mock: run a function under a mocked PATH.
with_mock() {
  local profile="$1"; shift
  mock_env "$profile"
  local saved="$PATH"
  PATH="$MOCK_PATH"
  "$@"
  local rc=$?
  PATH="$saved"
  return $rc
}
