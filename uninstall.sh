#!/usr/bin/env bash
# uninstall.sh - Convenience wrapper that delegates to the CLI's safe uninstall.
# Removes only the AndroidLinux installation. Android is never modified.

set -Eeuo pipefail

SELF_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ -x "$SELF_DIR/bin/android-linux" ]; then
  exec "$SELF_DIR/bin/android-linux" uninstall "$@"
elif command -v android-linux >/dev/null 2>&1; then
  exec android-linux uninstall "$@"
else
  printf '[x] Could not find the android-linux CLI. Nothing removed.\n' >&2
  exit 1
fi
