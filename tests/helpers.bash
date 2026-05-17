#!/usr/bin/env bash
# Test helpers for yaamux bats suite.

YAAMUX_BIN="${YAAMUX_BIN:-${BATS_TEST_DIRNAME}/../yaamux}"

setup_repo() {
  TEST_REPO="$(mktemp -d -t yaamux-test-XXXXXX)"
  cd "$TEST_REPO"
  git init -q
  git config user.email "test@yaamux.test"
  git config user.name "yaamux-test"
  git commit --allow-empty -q -m "initial"
}

teardown_repo() {
  cd /
  [[ -n "${TEST_REPO:-}" && -d "$TEST_REPO" ]] && rm -rf "$TEST_REPO"
}

# Run yaamux in the test repo's directory.
run_yaamux() {
  run bash "$YAAMUX_BIN" "$@"
}
