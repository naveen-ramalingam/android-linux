#!/usr/bin/env bash
# run-all.sh - Run every tests/test-*.sh script.
set -u
TESTS_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
total_fail=0
total_pass=0
for t in "$TESTS_DIR"/test-*.sh; do
  printf '\n==== %s ====\n' "$(basename "$t")"
  if bash "$t"; then
    printf '  => SUITE OK\n'
  else
    printf '  => SUITE FAILED\n'
    total_fail=$((total_fail+1))
  fi
done
printf '\n================\n'
if [ "$total_fail" -eq 0 ]; then
  printf 'ALL TEST SUITES PASSED\n'
else
  printf '%d suite(s) failed\n' "$total_fail"
  exit 1
fi
