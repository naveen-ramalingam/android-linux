#!/usr/bin/env bash
# test-config.sh - Config save/load round-trip and state machine.
. "$(dirname "$0")/helpers.sh"
. "$LIB_DIR/common.sh"

printf 'Config + state\n'

LINUX_BASE="$TEST_TMP/base"
LINUX_ROOT="$LINUX_BASE/rootfs"
DISTRO="debian"
INSTALL_MODE="proot"
SSH_PORT="2222"
DESKTOP="none"
VNC_PORT="5901"
AUTO_START="0"
DNS="1.1.1.1"
BACKUP_DIR="$LINUX_BASE/backups"
LINUX_USER="android"

config_save
assert_true bash -c "[ -f \"$ANDROID_LINUX_CONFIG_FILE\" ]" "config file written"

# Reload in a clean variable set
unset LINUX_BASE LINUX_ROOT DISTRO INSTALL_MODE
config_load
assert_eq "$TEST_TMP/base" "$LINUX_BASE" "LINUX_BASE round-trips"
assert_eq "proot" "$INSTALL_MODE" "INSTALL_MODE round-trips"
assert_eq "2222" "$SSH_PORT" "SSH_PORT round-trips"

# State machine
LINUX_BASE="$TEST_TMP/base2"; mkdir -p "$LINUX_BASE"
state_set DETECTED
assert_eq "DETECTED" "$(state_get)" "state DETECTED persisted"
state_set READY
assert_eq "READY" "$(state_get)" "state advances to READY"

test_summary
