#!/usr/bin/env bats

load helpers

setup() {
  setup_repo
}

teardown() {
  teardown_repo
}

# ── Read-only / metadata flags ─────────────────────────────────────────────────

@test "--version prints VERSION-file contents with a source tag" {
  run_yaamux --version
  [ "$status" -eq 0 ]
  expected="$(cat "$(dirname "$YAAMUX_BIN")/VERSION")"
  [[ "$output" == "yaamux ${expected}"* ]]
  [[ "$output" == *"(git@"* || "$output" == *"(brew)" || "$output" == *"(unknown)" ]]
}

@test "--help prints usage header" {
  run_yaamux --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"yaamux"*"Agents Multiplexer"* ]]
}

@test "--list with no sessions reports empty (human)" {
  run_yaamux --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No yaamux sessions"* ]]
}

@test "--list --json with no sessions returns []" {
  run_yaamux --list --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# ── --init ────────────────────────────────────────────────────────────────────

@test "--init writes AGENTS.md, .yaamux/config, .worktreeinclude" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  [ -f AGENTS.md ]
  [ -L CLAUDE.md ]
  [ "$(readlink CLAUDE.md)" = "AGENTS.md" ]
  [ -f .yaamux/config ]
  [ -f .worktreeinclude ]
}

@test "--init AGENTS.md template contains agents.md reference" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "agents.md" AGENTS.md
}

@test "--init .yaamux/config has expected default keys" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "YAAMUX_DEFAULT_PATTERN" .yaamux/config
  grep -q "YAAMUX_DEFAULT_COUNT" .yaamux/config
  grep -q "YAAMUX_DEFAULT_BASE" .yaamux/config
}

@test "--init .worktreeinclude contains .env*" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "^\.env\*" .worktreeinclude
}

@test "--init is idempotent — does not clobber user content" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  echo "USER OWN CONTENT" > AGENTS.md
  echo "YAAMUX_DEFAULT_COUNT=8" > .yaamux/config
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "USER OWN CONTENT" AGENTS.md
  grep -q "YAAMUX_DEFAULT_COUNT=8" .yaamux/config
}

@test "--init renames standalone CLAUDE.md to AGENTS.md" {
  echo "# Legacy CLAUDE.md content" > CLAUDE.md
  run_yaamux --init
  [ "$status" -eq 0 ]
  [ -f AGENTS.md ]
  [ -L CLAUDE.md ]
  grep -q "Legacy CLAUDE.md content" AGENTS.md
}

@test "--init appends entries to existing .gitignore" {
  touch .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -qxF ".claude/logs/" .gitignore
  grep -qxF "../$(basename "$TEST_REPO")-worktrees/" .gitignore
}

@test "--init does not create .gitignore if absent" {
  rm -f .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  [ ! -f .gitignore ]
}

@test "--init does not duplicate .gitignore entries on second run" {
  touch .gitignore
  run_yaamux --init
  run_yaamux --init
  count="$(grep -cxF ".claude/logs/" .gitignore)"
  [ "$count" = "1" ]
}

# ── --clean ───────────────────────────────────────────────────────────────────

@test "--clean --force on empty repo exits cleanly" {
  run_yaamux --clean --force
  [ "$status" -eq 0 ]
}

@test "--clean on empty repo exits cleanly" {
  run_yaamux --clean
  [ "$status" -eq 0 ]
}

# ── --pr preflight ────────────────────────────────────────────────────────────

@test "--pr fails clearly when gh is missing" {
  # Prepend an empty mocks dir to PATH that shadows gh with a non-existent script
  mocks="$(mktemp -d)"
  # Don't put gh in mocks — PATH=mocks should make gh undiscoverable IF we also
  # blank the standard PATH locations. Easier: directly test that --pr requires gh.
  # Skip if gh actually exists in PATH on the test runner.
  if command -v gh &>/dev/null; then
    skip "gh is installed; can't test missing-gh error path here"
  fi
  run_yaamux --pr 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"gh"* ]]
}

# ── Layout function (unit test via source) ────────────────────────────────────

@test "_layout_for: N picks expected layout" {
  # Source only the _layout_for function body
  body="$(awk '/^_layout_for\(\) \{/,/^}/' "$YAAMUX_BIN")"
  warn() { :; }  # _layout_for calls warn on bad override
  eval "$body"
  [ "$(_layout_for 1)" = "tiled" ]
  [ "$(_layout_for 2)" = "even-horizontal" ]
  [ "$(_layout_for 3)" = "main-vertical" ]
  [ "$(_layout_for 4)" = "tiled" ]
  [ "$(_layout_for 5)" = "main-vertical" ]
  [ "$(_layout_for 6)" = "main-vertical" ]
  [ "$(_layout_for 7)" = "tiled" ]
  [ "$(_layout_for 5 main)" = "main-vertical" ]
  [ "$(_layout_for 3 even)" = "even-horizontal" ]
  [ "$(_layout_for 4 tiled)" = "tiled" ]
}

# ── YOLO mode ─────────────────────────────────────────────────────────────────

@test "agent_flags picks YOLO when YAAMUX_YOLO=1" {
  # Extract the flag-vars block, drop its trailing "GREEN=" line via POSIX sed,
  # then append the function. (BSD head lacks -n -1.)
  body="$(awk '/^# ── Per-agent auto-accept/,/^GREEN=/' "$YAAMUX_BIN" | sed '$d')"
  body+=$'\n'"$(awk '/^agent_flags\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  YAAMUX_YOLO=1; [ "$(agent_flags claude)" = "--dangerously-skip-permissions" ]
  YAAMUX_YOLO=0; [ "$(agent_flags claude)" = "" ]
  YAAMUX_YOLO=1; [ "$(agent_flags gemini)" = "--yolo" ]
  YAAMUX_YOLO=0; [ "$(agent_flags gemini)" = "--approval-mode auto_edit" ]
}
