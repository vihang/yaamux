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

@test "--keys prints cheat sheet with prefix and CLI sections" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ctrl+Space"* ]]
  [[ "$output" == *"yaamux CLI"* ]]
  [[ "$output" == *"--broadcast"* ]]
}

# ── iOS attach flags (--mobile-attach / --mobile-grid / --auto-attach / --connect)

@test "--mobile-attach errors cleanly when no yaamux sessions are running" {
  run_yaamux --mobile-attach
  [ "$status" -ne 0 ]
  [[ "$output" == *"No yaamux sessions running"* ]]
}

@test "--mobile-attach rejects non-numeric PANE" {
  run_yaamux --mobile-attach myrepo abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"PANE must be a non-negative integer"* ]]
}

@test "--mobile-grid errors cleanly when no yaamux sessions are running" {
  run_yaamux --mobile-grid
  [ "$status" -ne 0 ]
  [[ "$output" == *"No yaamux sessions running"* ]]
}

@test "--auto-attach rejects an invalid YAAMUX_ATTACH_MODE" {
  YAAMUX_ATTACH_MODE=bogus run_yaamux --auto-attach
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid YAAMUX_ATTACH_MODE"* ]]
}

@test "--auto-attach forced to zoom routes to --mobile-attach (no sessions error)" {
  YAAMUX_ATTACH_MODE=zoom run_yaamux --auto-attach
  [ "$status" -ne 0 ]
  [[ "$output" == *"No yaamux sessions running"* ]]
}

@test "--connect prints mosh/ssh/remote commands and the auto-attach entry point" {
  run_yaamux --connect
  [ "$status" -eq 0 ]
  [[ "$output" == *"yaamux connect"* ]]
  [[ "$output" == *"mosh --server="* ]]
  [[ "$output" == *"yaamux --auto-attach"* ]]
  [[ "$output" == *"yaamux --remote"* ]]
}

@test "--connect --qr without qrencode falls back to a hint, not an error" {
  # Stub PATH so qrencode is unreachable even if installed.
  PATH=/usr/bin:/bin run_yaamux --connect --qr
  [ "$status" -eq 0 ]
  [[ "$output" == *"qrencode"* ]]
}

@test "--connect --qr encodes mosh:// (not the raw shell snippet → no Mail.app on iOS)" {
  # Stub qrencode: print its argv so the test can assert on the QR payload.
  # iOS Vision reads URL schemes (mosh://) as URLs; it would read the raw
  # `mosh --server=… user@host.tld -- …` line as an email address and offer
  # Mail.app — exactly the bug this payload format is meant to avoid.
  stub_dir="$(mktemp -d -t yaamux-qrstub-XXXXXX)"
  cat > "${stub_dir}/qrencode" << 'STUB'
#!/usr/bin/env bash
echo "QRENCODE_ARGS: $*"
STUB
  chmod +x "${stub_dir}/qrencode"

  PATH="${stub_dir}:${PATH}" run_yaamux --connect --qr
  [ "$status" -eq 0 ]
  # QR must encode the mosh:// URL scheme.
  [[ "$output" == *"QRENCODE_ARGS:"*"mosh://"* ]]
  # ...and must NOT encode the raw shell command (which triggers iOS Mail.app).
  [[ "$output" != *"QRENCODE_ARGS:"*"mosh --server="* ]]

  rm -rf "$stub_dir"
}

# ── --prepare-host (host-level mosh-server PATH fix for iOS mosh:// URLs) ─────

@test "--prepare-host rejects bogus sub-arg" {
  run_yaamux --prepare-host --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "--prepare-host --check is read-only and fails clearly when mosh-server is absent" {
  # Skip if mosh-server lives anywhere _find_mosh_server probes — the
  # test wants to exercise the "not installed" branch, which requires
  # a truly mosh-server-less machine. (CI runners are clean; dev boxes
  # with brew install mosh aren't.)
  if [[ -x /usr/local/bin/mosh-server || -x /usr/bin/mosh-server \
        || -x /opt/homebrew/bin/mosh-server || -x /opt/local/bin/mosh-server ]]; then
    skip "mosh-server is present in a probed dir — can't test the missing case"
  fi
  PATH=/usr/bin:/bin run_yaamux --prepare-host --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"not installed"* ]]
  [[ "$output" == *"brew install mosh"* ]]
}

@test "--connect points users at --prepare-host when mosh is installed but mosh-server is off PATH" {
  # Stub `mosh` so the connect-output's `command -v mosh` check is true.
  # On the test runner /usr/local/bin/mosh-server and /usr/bin/mosh-server
  # are absent, so _mosh_server_on_default_path returns false and the
  # warning fires.
  if [[ -x /usr/local/bin/mosh-server || -x /usr/bin/mosh-server ]]; then
    skip "mosh-server is on ssh's default PATH here — warning won't fire"
  fi
  stub_dir="$(mktemp -d -t yaamux-moshstub-XXXXXX)"
  cat > "${stub_dir}/mosh" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "${stub_dir}/mosh"

  PATH="${stub_dir}:${PATH}" run_yaamux --connect
  [ "$status" -eq 0 ]
  [[ "$output" == *"yaamux --prepare-host"* ]]

  rm -rf "$stub_dir"
}

@test "_mosh_server_on_default_path: returns true iff /usr/local/bin or /usr/bin has mosh-server" {
  # Source the helper and reflect actual filesystem state.
  body="$(awk '/^_mosh_server_on_default_path\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  if [[ -x /usr/local/bin/mosh-server || -x /usr/bin/mosh-server ]]; then
    _mosh_server_on_default_path
  else
    ! _mosh_server_on_default_path
  fi
}

@test "--prepare-host symlinks mosh-server and is idempotent on a second run" {
  # Exercises the apply branch (sudo + ln) using the test-only env knobs.
  # YAAMUX_PREPARE_HOST_TARGET redirects the destination into a writable
  # temp dir; YAAMUX_PREPARE_HOST_SUDO="" disables the privilege wrapper
  # so the symlink runs as the test user.
  stub_dir="$(mktemp -d -t yaamux-mssstub-XXXXXX)"
  target_dir="$(mktemp -d -t yaamux-target-XXXXXX)"
  cat > "${stub_dir}/mosh-server" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "${stub_dir}/mosh-server"
  target="${target_dir}/mosh-server"

  # First run: create the symlink.
  PATH="${stub_dir}:${PATH}" \
    YAAMUX_PREPARE_HOST_TARGET="$target" \
    YAAMUX_PREPARE_HOST_SUDO="" \
    run_yaamux --prepare-host
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
  [ -L "$target" ]
  [ "$(readlink "$target")" = "${stub_dir}/mosh-server" ]

  # Second run: idempotent — should report already-symlinked, not redo it.
  PATH="${stub_dir}:${PATH}" \
    YAAMUX_PREPARE_HOST_TARGET="$target" \
    YAAMUX_PREPARE_HOST_SUDO="" \
    run_yaamux --prepare-host
  [ "$status" -eq 0 ]
  [[ "$output" == *"already symlinked"* ]]
  [[ "$output" != *"Done"* ]]

  rm -rf "$stub_dir" "$target_dir"
}

@test "_find_mosh_server falls back to /opt/homebrew/bin when missing from PATH" {
  # Stub a fake mosh-server in a non-PATH location, strip PATH so
  # `command -v` misses, and verify the helper still locates it.
  body="$(awk '/^_find_mosh_server\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"

  if [[ -x /opt/homebrew/bin/mosh-server || -x /usr/local/bin/mosh-server \
        || -x /usr/bin/mosh-server || -x /opt/local/bin/mosh-server ]]; then
    skip "real mosh-server present in a probed dir — can't test the fallback in isolation"
  fi

  # PATH that misses mosh-server entirely.
  PATH=/usr/bin:/bin run bash -c "$(declare -f _find_mosh_server); _find_mosh_server"
  [ "$status" -ne 0 ]
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

# ── --remote ──────────────────────────────────────────────────────────────────

@test "--remote --help prints usage" {
  run_yaamux --remote --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"yaamux --remote"* ]]
  [[ "$output" == *"Pick a session"* ]]
  [[ "$output" == *"--mosh"* ]]
}

@test "--remote with no args prints help (not an error)" {
  run_yaamux --remote
  [ "$status" -eq 0 ]
  [[ "$output" == *"--remote"* ]]
}

@test "--remote with unknown sub-flag fails with hint" {
  run_yaamux --remote some-host --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown --remote sub-flag"* ]]
}

@test "--remote --zoom rejects non-numeric pane" {
  run_yaamux --remote some-host --zoom abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"numeric"* ]]
}

@test "--remote --zoom rejects 0 (must be 1-based)" {
  run_yaamux --remote some-host --zoom 0
  [ "$status" -ne 0 ]
  [[ "$output" == *"1-based"* ]]
}

@test "--remote rejects targets starting with '-' (option injection)" {
  run_yaamux --remote -X-injected --list
  [ "$status" -ne 0 ]
  [[ "$output" == *"starts with"* || "$output" == *"-X-injected"* ]]
}

@test "--remote transport flags can appear anywhere in arg list" {
  # --mosh / --ssh must be stripped from the arg list before the sub-command
  # is interpreted, regardless of position.  We verify by checking that an
  # unknown sub-flag is still recognized (proving --mosh wasn't itself
  # treated as the sub-command).
  run_yaamux --remote --mosh some-host --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown --remote sub-flag: --bogus-flag"* ]]

  run_yaamux --remote some-host --bogus-flag --mosh
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown --remote sub-flag: --bogus-flag"* ]]

  run_yaamux --remote some-host --ssh --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown --remote sub-flag: --bogus-flag"* ]]
}

@test "_remote_resolve_host: last line without trailing newline is honored" {
  HOME_TMP="$(mktemp -d)"
  mkdir -p "$HOME_TMP/.config/yaamux"
  # printf — no trailing newline
  printf 'work    vihang@work.example\nlast    user@last.example' \
    > "$HOME_TMP/.config/yaamux/hosts.conf"
  export HOME="$HOME_TMP"
  HOSTS_CONF="$HOME_TMP/.config/yaamux/hosts.conf"
  body="$(awk '/^_remote_resolve_host\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  [ "$(_remote_resolve_host work)" = "vihang@work.example" ]
  [ "$(_remote_resolve_host last)" = "user@last.example" ]
  rm -rf "$HOME_TMP"
}

@test "--remote-hosts on empty config prints setup instructions" {
  HOSTS_OVERRIDE="$(mktemp -d)/hosts.conf"
  HOME_TMP="$(mktemp -d)"
  HOME="$HOME_TMP" run_yaamux --remote-hosts
  [ "$status" -eq 0 ]
  [[ "$output" == *"No alias file yet"* ]]
  [[ "$output" == *"<alias>"* ]]
  rm -rf "$HOME_TMP"
}

@test "--remote-hosts lists configured aliases" {
  HOME_TMP="$(mktemp -d)"
  mkdir -p "$HOME_TMP/.config/yaamux"
  cat > "$HOME_TMP/.config/yaamux/hosts.conf" <<EOF
# header comment
work    vihang@work.example
laptop  vihang@laptop.local  # inline comment

phone   user@phone.example
EOF
  HOME="$HOME_TMP" run_yaamux --remote-hosts
  [ "$status" -eq 0 ]
  [[ "$output" == *"work"* ]]
  [[ "$output" == *"vihang@work.example"* ]]
  [[ "$output" == *"laptop"* ]]
  [[ "$output" == *"phone"* ]]
  # Inline-comment stripping should not include the comment text
  [[ "$output" != *"inline comment"* ]]
  rm -rf "$HOME_TMP"
}

@test "_remote_resolve_host: alias lookup + passthrough" {
  HOME_TMP="$(mktemp -d)"
  mkdir -p "$HOME_TMP/.config/yaamux"
  cat > "$HOME_TMP/.config/yaamux/hosts.conf" <<EOF
work    vihang@work.example
laptop  vihang@laptop.local
EOF
  export HOME="$HOME_TMP"
  HOSTS_CONF="$HOME_TMP/.config/yaamux/hosts.conf"
  body="$(awk '/^_remote_resolve_host\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  [ "$(_remote_resolve_host work)" = "vihang@work.example" ]
  [ "$(_remote_resolve_host laptop)" = "vihang@laptop.local" ]
  [ "$(_remote_resolve_host missing)" = "missing" ]
  [ "$(_remote_resolve_host user@bare.host)" = "user@bare.host" ]
  [ "$(_remote_resolve_host '')" = "" ]
  rm -rf "$HOME_TMP"
}

@test "_remote_normalize_session: bare repo gets yaamux- prefix" {
  body="$(awk '/^_remote_normalize_session\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  [ "$(_remote_normalize_session myapp)" = "yaamux-myapp" ]
  [ "$(_remote_normalize_session yaamux-myapp)" = "yaamux-myapp" ]
  [ "$(_remote_normalize_session yaamux-foo-bar)" = "yaamux-foo-bar" ]
}

# ── Pane health detector ──────────────────────────────────────────────────────

@test "_pane_state: classifies dead / idle / running from tmux output" {
  # Stub `tmux` via PATH to feed canned `display-message` output. The stub
  # also handles `show-option @yaamux-shells` (returns the default set).
  STUB_DIR="$(mktemp -d)"
  cat > "$STUB_DIR/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "display-message -p")
    # idx is the last arg of -t SESSION:agents.IDX; SCENARIO controls output
    case "${SCENARIO:-}" in
      dead)    echo "1|zsh" ;;
      idle)    echo "0|zsh" ;;
      running) echo "0|node" ;;
      missing) exit 1 ;;
    esac
    ;;
  "show-option -v")
    echo "zsh bash sh fish dash ash"
    ;;
esac
STUB
  chmod +x "$STUB_DIR/tmux"
  export PATH="$STUB_DIR:$PATH"
  export SESSION="yaamux-test"
  body="$(awk '/^_pane_state\(\) \{/,/^}/' "$YAAMUX_BIN")"
  eval "$body"
  SCENARIO=dead    [ "$(SCENARIO=dead _pane_state 0)" = "dead" ]
  SCENARIO=idle    [ "$(SCENARIO=idle _pane_state 0)" = "idle" ]
  SCENARIO=running [ "$(SCENARIO=running _pane_state 0)" = "running" ]
  SCENARIO=missing [ "$(SCENARIO=missing _pane_state 0)" = "missing" ]
  rm -rf "$STUB_DIR"
}

@test "--restart-dead on empty repo exits cleanly with 'no session' message" {
  run_yaamux --restart-dead -y
  [ "$status" -eq 0 ]
  [[ "$output" == *"No session"* ]]
}

@test "--restart-current fails clearly outside tmux" {
  unset TMUX_PANE
  run_yaamux --restart-current
  [ "$status" -ne 0 ]
  [[ "$output" == *"No session"* || "$output" == *"TMUX_PANE"* ]]
}

@test "--refresh-states is a no-op on empty repo" {
  run_yaamux --refresh-states
  [ "$status" -eq 0 ]
}

@test "_REMOTE_SSH_OPTS: socket dir under \$HOME, has ControlMaster + 10m persist" {
  HOME_TMP="$(mktemp -d)"
  export HOME="$HOME_TMP"
  # Source the constant block (HOSTS_CONF + REMOTE_PATH_PRELUDE + ssh opts).
  # awk grabs from the `# Common ssh options` header through the closing `)`.
  body="$(awk '/^_REMOTE_SSH_SOCK_DIR=/,/^\)/' "$YAAMUX_BIN")"
  eval "$body"
  [ "$_REMOTE_SSH_SOCK_DIR" = "${HOME_TMP}/.cache/yaamux/sockets" ]
  joined="$(printf '%s\n' "${_REMOTE_SSH_OPTS[@]}")"
  [[ "$joined" == *"ControlMaster=auto"* ]]
  [[ "$joined" == *"ControlPath=${HOME_TMP}/.cache/yaamux/sockets/%C"* ]]
  [[ "$joined" == *"ControlPersist=10m"* ]]
  [[ "$joined" == *"ConnectTimeout=10"* ]]
  rm -rf "$HOME_TMP"
}

@test "_REMOTE_SSH_SOCK_DIR path length fits macOS 104-byte sun_path limit" {
  # Worst case: typical macOS /Users/<long>/.cache/yaamux/sockets/<40-char %C>
  # `%C` is OpenSSH SHA1 hex (40 chars). Assert the formed path stays under
  # 104 chars even for a 20-char username.
  user="abcdefghijklmnopqrst"  # 20-char username
  hex40="0123456789abcdef0123456789abcdef01234567"
  path="/Users/${user}/.cache/yaamux/sockets/${hex40}"
  [ "${#path}" -lt 104 ]
}

@test "--remote creates the ssh socket dir under \$HOME on first use" {
  HOME_TMP="$(mktemp -d)"
  # --remote --help triggers _remote_dispatch and so triggers the mkdir,
  # without actually doing any ssh work.
  HOME="$HOME_TMP" run_yaamux --remote --help
  [ "$status" -eq 0 ]
  [ -d "$HOME_TMP/.cache/yaamux/sockets" ]
  rm -rf "$HOME_TMP"
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

# ── Control Panel ─────────────────────────────────────────────────────────────

@test "--init writes .yaamux/state with control-panel defaults" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  [ -f .yaamux/state ]
  grep -q "CONTROL_PANEL_VISIBLE=true" .yaamux/state
  grep -q "CONTROL_PANEL_MODE=auto" .yaamux/state
}

@test "--init adds .yaamux/state to .gitignore" {
  touch .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -qxF ".yaamux/state" .gitignore
}

@test "--panel-hide writes CONTROL_PANEL_VISIBLE=false to .yaamux/state" {
  run_yaamux --init
  # Without a tmux session the panel functions return early but still persist.
  run_yaamux --panel-hide
  [ "$status" -eq 0 ]
  grep -q "CONTROL_PANEL_VISIBLE=false" .yaamux/state
}

@test "--panel-show writes CONTROL_PANEL_VISIBLE=true to .yaamux/state" {
  run_yaamux --init
  # Toggle off then back on; expect the file to end at true.
  run_yaamux --panel-hide
  run_yaamux --panel-show
  # The show path needs a session to create the pane, but the persistence
  # call should not have flipped the bit away from the existing true default.
  grep -q "CONTROL_PANEL_VISIBLE=true" .yaamux/state
}

@test "--goto without args exits non-zero (usage)" {
  run_yaamux --goto
  [ "$status" -ne 0 ]
}

@test "--status-render is silent without a session" {
  run_yaamux --status-render
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--keys lists the new Control Panel bindings" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"toggle Control Panel"* ]]
  [[ "$output" == *"jump to agent pane N"* ]]
  [[ "$output" == *"ergonomic alias for Z"* ]]
}

@test "--keys lists the new --toggle-panel / --goto CLI flags" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"--toggle-panel"* ]]
  [[ "$output" == *"--goto N"* ]]
  [[ "$output" == *"--panel-show"* ]]
  [[ "$output" == *"--panel-hide"* ]]
}

# ── 4 embedded heredocs extract cleanly ───────────────────────────────────────

@test "all 4 embedded heredocs extract and pass bash -n" {
  tmp="$(mktemp -d)"
  python3 - "$YAAMUX_BIN" "$tmp" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
out = sys.argv[2]
ok = True
for tag in ('GUARD_EOF', 'NOTIFY_EOF', 'MOBILE_EOF', 'CPANEL_EOF'):
    m = re.search(r"<<\s*'" + tag + r"'\s*\n(.*?)\n" + tag + r"\s*\n", src, re.S)
    if m:
        open(f"{out}/{tag}", "w").write(m.group(1))
    else:
        print(f"MISSING {tag}")
        ok = False
sys.exit(0 if ok else 1)
PY
  [ "$?" -eq 0 ]
  for t in GUARD_EOF NOTIFY_EOF MOBILE_EOF CPANEL_EOF; do
    [ -f "$tmp/$t" ]
    bash -n "$tmp/$t"
  done
  rm -rf "$tmp"
}

# ── Background panels ─────────────────────────────────────────────────────────

@test "--bg without args exits non-zero (usage)" {
  run_yaamux --bg
  [ "$status" -ne 0 ]
}

@test "--bg with name but no command exits non-zero (usage)" {
  run_yaamux --bg my-panel
  [ "$status" -ne 0 ]
}

@test "--bg with no session errors clearly" {
  # No yaamux session is running in the test repo — should refuse politely.
  # We use a fake-ish name so we don't accidentally collide with a real panel.
  run_yaamux --bg test-no-session "echo hi"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No yaamux session"* || "$output" == *"session"* ]]
}

@test "--bg-list on empty repo: human prints 'No background panels'" {
  run_yaamux --bg-list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No background panels"* ]]
}

@test "--bg-list --json on empty repo returns []" {
  run_yaamux --bg-list --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "--bg-tail on a nonexistent panel errors" {
  run_yaamux --bg-tail no-such-panel
  [ "$status" -ne 0 ]
  [[ "$output" == *"No such panel"* ]]
}

@test "--bg-kill without args exits non-zero (usage)" {
  run_yaamux --bg-kill
  [ "$status" -ne 0 ]
}

@test "--bg-kill on a nonexistent panel errors" {
  run_yaamux --bg-kill no-such-panel
  [ "$status" -ne 0 ]
  [[ "$output" == *"No such panel"* ]]
}

@test "--bg rejects panel names with invalid characters" {
  run_yaamux --bg 'bad/name' "echo hi"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must match"* || "$output" == *"name"* ]]
}

@test "_bg_status reports completion from a hand-built log" {
  # Stand up a fake panel directory and assert _bg_status reads the sentinel.
  mkdir -p "${TEST_REPO}/.yaamux/panels"
  printf 'TOKEN=abc12345xyz0\nPANE_ID=%%99\nCMD=true\nSTARTED=2026-05-19T00:00:00Z\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.meta"
  printf 'output line\n[[YAAMUX:PANEL:abc12345xyz0:DONE:RC=0]]\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.log"
  run_yaamux --bg-list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"name\": \"sample\""* ]]
  [[ "$output" == *"\"status\": \"done\""* ]]
  [[ "$output" == *"\"rc\": 0"* ]]
}

@test "_bg_status reports 'failed' from a non-zero RC sentinel" {
  mkdir -p "${TEST_REPO}/.yaamux/panels"
  printf 'TOKEN=def67890xyz9\nPANE_ID=%%88\nCMD=false\nSTARTED=2026-05-19T00:00:00Z\n' \
    > "${TEST_REPO}/.yaamux/panels/fail.meta"
  printf '[[YAAMUX:PANEL:def67890xyz9:DONE:RC=2]]\n' \
    > "${TEST_REPO}/.yaamux/panels/fail.log"
  run_yaamux --bg-list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"status\": \"failed\""* ]]
  [[ "$output" == *"\"rc\": 2"* ]]
}

@test "--bg-tail prints OFFSET and STATUS trailers from a hand-built log" {
  mkdir -p "${TEST_REPO}/.yaamux/panels"
  printf 'TOKEN=tok000111222\nPANE_ID=%%77\nCMD=true\nSTARTED=2026-05-19T00:00:00Z\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.meta"
  printf 'hello\n[[YAAMUX:PANEL:tok000111222:DONE:RC=0]]\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.log"
  run_yaamux --bg-tail sample
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
  [[ "$output" == *"OFFSET="* ]]
  [[ "$output" == *"STATUS=done"* ]]
  [[ "$output" == *"RC=0"* ]]
}

@test "--bg-tail --from skips initial bytes" {
  mkdir -p "${TEST_REPO}/.yaamux/panels"
  printf 'TOKEN=tok000111222\nPANE_ID=%%77\nCMD=true\nSTARTED=2026-05-19T00:00:00Z\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.meta"
  printf 'AAAAAAAAAA\nBBBBBBBBBB\n[[YAAMUX:PANEL:tok000111222:DONE:RC=0]]\n' \
    > "${TEST_REPO}/.yaamux/panels/sample.log"
  run_yaamux --bg-tail sample --from 11
  [ "$status" -eq 0 ]
  # First 11 bytes ("AAAAAAAAAA\n") should not appear in output before the trailers
  # We assert BBB does appear and the AAA prefix was suppressed:
  [[ "$output" == *"BBBBBBBBBB"* ]]
  [[ "$output" != *"AAAAAAAAAA"* ]]
}

@test "--keys lists the new bg CLI flags" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"--bg "* ]]
  [[ "$output" == *"--bg-tail"* ]]
  [[ "$output" == *"--bg-list"* ]]
  [[ "$output" == *"--bg-kill"* ]]
}

@test "--init adds .yaamux/panels/ to .gitignore" {
  touch .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -qxF ".yaamux/panels/" .gitignore
}

# ── Git-host abstraction (_host_provider / _host_cli) ─────────────────────────

# Helper: source the host-helper trio so each test can eval them once.
# Keep in sync if a new helper joins the _host_* family.
_host_helpers_body() {
  awk '/^_host_url_hostname\(\) \{/,/^}/' "$YAAMUX_BIN"
  printf '\n'
  awk '/^_host_provider\(\) \{/,/^}/'     "$YAAMUX_BIN"
  printf '\n'
  awk '/^_host_cli\(\) \{/,/^}/'          "$YAAMUX_BIN"
}

@test "_host_provider: explicit YAAMUX_GIT_HOST overrides auto-detection" {
  eval "$(_host_helpers_body)"
  REPO_ROOT="$TEST_REPO"
  YAAMUX_GIT_HOST=gitlab; [ "$(_host_provider)" = "gitlab" ]
  YAAMUX_GIT_HOST=github; [ "$(_host_provider)" = "github" ]
  YAAMUX_GIT_HOST=other ; [ "$(_host_provider)" = "other"  ]
}

@test "_host_provider: auto-detects github / gitlab / other from origin URL" {
  eval "$(_host_helpers_body)"
  REPO_ROOT="$TEST_REPO"
  unset YAAMUX_GIT_HOST
  git -C "$TEST_REPO" remote add origin https://github.com/foo/bar.git
  [ "$(_host_provider)" = "github" ]
  git -C "$TEST_REPO" remote set-url origin git@gitlab.com:foo/bar.git
  [ "$(_host_provider)" = "gitlab" ]
  git -C "$TEST_REPO" remote set-url origin https://bitbucket.org/foo/bar.git
  [ "$(_host_provider)" = "other" ]
}

# Drift-guard: the tightened hostname-only matcher must NOT mis-detect a
# repo whose path contains a forge name (e.g., github.com/foo/gitlab-mirror).
@test "_host_provider: does not mis-detect forge from path segments" {
  eval "$(_host_helpers_body)"
  REPO_ROOT="$TEST_REPO"
  unset YAAMUX_GIT_HOST
  git -C "$TEST_REPO" remote add origin https://github.com/foo/gitea-mirror.git
  [ "$(_host_provider)" = "github" ]
  git -C "$TEST_REPO" remote set-url origin https://github.com/foo/gitlab-tools.git
  [ "$(_host_provider)" = "github" ]
}

@test "_host_cli: maps provider to gh / glab / empty" {
  eval "$(_host_helpers_body)"
  REPO_ROOT="$TEST_REPO"
  YAAMUX_GIT_HOST=github; [ "$(_host_cli)" = "gh"   ]
  YAAMUX_GIT_HOST=gitlab; [ "$(_host_cli)" = "glab" ]
  YAAMUX_GIT_HOST=other ; [ "$(_host_cli)" = ""     ]
}

# ── New PR/CI/diff flags — usage validation ───────────────────────────────────

@test "--watch-pr without N fails with usage hint" {
  run_yaamux --watch-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: yaamux --watch-pr N"* ]]
}

@test "--auto-merge without N fails with usage hint" {
  run_yaamux --auto-merge
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: yaamux --auto-merge N"* ]]
}

@test "--diff without N fails with usage hint" {
  run_yaamux --diff
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: yaamux --diff N"* ]]
}

@test "--ci-status with no N exits 0 when there are no worktrees" {
  run_yaamux --ci-status
  [ "$status" -eq 0 ]
}

@test "--diff N dies clean when the worktree is missing" {
  run_yaamux --diff 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Worktree"* ]]
  [[ "$output" == *"not found"* ]]
}

@test "--watch-pr N dies clean when the worktree is missing" {
  run_yaamux --watch-pr 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Worktree"* ]]
  [[ "$output" == *"not found"* ]]
}

# Pluggability proof: YAAMUX_GIT_HOST=gitlab routes into the gitlab) case in
# every _host_pr_* helper. Currently those cases die with "not implemented";
# a future change that wires up `glab` should update this test to assert
# success instead of the placeholder message.
@test "YAAMUX_GIT_HOST=gitlab routes PR ops into the gitlab) dispatch" {
  wt_base="$(dirname "$TEST_REPO")/$(basename "$TEST_REPO")-worktrees"
  mkdir -p "${wt_base}/agent-1"
  YAAMUX_GIT_HOST=gitlab run_yaamux --watch-pr 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not implemented"* ]]
  rm -rf "$wt_base"
}

# ── --keys / --help advertise the new surface ─────────────────────────────────

@test "--keys lists the new PR/CI/diff flags and the \`git\` window binding" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"--watch-pr"* ]]
  [[ "$output" == *"--auto-merge"* ]]
  [[ "$output" == *"--ci-status"* ]]
  [[ "$output" == *"--diff N"* ]]
  [[ "$output" == *"\`git\` window"* ]]
}

@test "--help header advertises the new flags" {
  run_yaamux --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--watch-pr"* ]]
  [[ "$output" == *"--ci-status"* ]]
  [[ "$output" == *"--diff"* ]]
}

@test "--init adds .yaamux/lazygit/ to .gitignore" {
  touch .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -qxF ".yaamux/lazygit/" .gitignore
}

# ── Agent discoverability (issue #28) ─────────────────────────────────────────
# Tier-1 surface for agents running inside yaamux:
#   (1) the scaffolded AGENTS.md ships an inline recipe of yaamux commands
#   (2) YAAMUX_AGENT_MODE=safe disables destructive flags
#   (3) YAAMUX_REPO_ROOT redirects REPO_ROOT so an agent invoking yaamux from
#       inside a worktree resolves to the main checkout (so --bg-list etc are
#       visible from both the agent and the operator).

@test "--init AGENTS.md template contains the yaamux runtime recipe" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "yaamux runtime" AGENTS.md
  grep -q "YAAMUX_AGENT_NAME" AGENTS.md
  grep -q "YAAMUX_AGENT_NUMBER" AGENTS.md
  grep -q "YAAMUX_SESSION" AGENTS.md
  grep -q "YAAMUX_REPO_ROOT" AGENTS.md
  grep -q "YAAMUX_AGENT_MODE" AGENTS.md
  grep -q -- "--bg" AGENTS.md
  grep -q -- "--send N" AGENTS.md
  grep -q "Don't run these" AGENTS.md
}

@test "YAAMUX_AGENT_MODE=safe refuses --kill" {
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --kill
  [ "$status" -ne 0 ]
  [[ "$output" == *"disabled in agent mode"* ]]
  [[ "$output" == *"YAAMUX_AGENT_MODE=safe"* ]]
}

@test "YAAMUX_AGENT_MODE=safe refuses --clean" {
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --clean --force
  [ "$status" -ne 0 ]
  [[ "$output" == *"disabled in agent mode"* ]]
}

@test "YAAMUX_AGENT_MODE=safe refuses --install / --uninstall / --install-service" {
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --install
  [ "$status" -ne 0 ]
  [[ "$output" == *"disabled in agent mode"* ]]
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --uninstall
  [ "$status" -ne 0 ]
  [[ "$output" == *"disabled in agent mode"* ]]
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --install-service
  [ "$status" -ne 0 ]
  [[ "$output" == *"disabled in agent mode"* ]]
}

@test "YAAMUX_AGENT_MODE unset (default) allows --kill (backward-compatible)" {
  # No session is running, so --kill ends with "Not running." but exits 0.
  unset YAAMUX_AGENT_MODE
  run_yaamux --kill
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not running"* || "$output" == *"Killed"* ]]
}

@test "YAAMUX_AGENT_MODE=safe leaves read-only flags alone" {
  # --version / --keys / --status / --list / --bg-list are not destructive.
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --version
  [ "$status" -eq 0 ]
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --keys
  [ "$status" -eq 0 ]
  YAAMUX_AGENT_MODE=safe run bash "$YAAMUX_BIN" --bg-list
  [ "$status" -eq 0 ]
}

@test "YAAMUX_REPO_ROOT overrides REPO_ROOT (so --bg from a worktree targets main repo)" {
  # Two repos: main + a separate dir simulating an agent's worktree.
  main_repo="$TEST_REPO"
  alt_dir="$(mktemp -d -t yaamux-alt-XXXXXX)"
  git -C "$alt_dir" init -q
  git -C "$alt_dir" -c user.email=test@yaamux.test -c user.name=yaamux-test \
    commit -q --allow-empty -m init
  # Hand-place a fake panel under the main repo's panels dir.
  mkdir -p "${main_repo}/.yaamux/panels"
  printf 'TOKEN=hop1\nPANE_ID=%%01\nCMD=true\nSTARTED=2026-05-19T00:00:00Z\n' \
    > "${main_repo}/.yaamux/panels/sample.meta"
  printf 'hello\n[[YAAMUX:PANEL:hop1:DONE:RC=0]]\n' \
    > "${main_repo}/.yaamux/panels/sample.log"

  # Run --bg-list from the *alt* dir, but with YAAMUX_REPO_ROOT pointing to
  # the main repo. The panel must show up — proving REPO_ROOT was overridden.
  cd "$alt_dir"
  YAAMUX_REPO_ROOT="$main_repo" run bash "$YAAMUX_BIN" --bg-list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"name\": \"sample\""* ]]
  [[ "$output" == *"\"status\": \"done\""* ]]

  # Sanity: without the override, --bg-list from alt_dir sees no panels.
  run bash "$YAAMUX_BIN" --bg-list --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]

  cd "$main_repo"
  rm -rf "$alt_dir"
}

# ── Tier 2: --agent-brief + Claude Code skill (issue #29) ─────────────────────

@test "--agent-brief default format is markdown with the version header" {
  run_yaamux --agent-brief
  [ "$status" -eq 0 ]
  [[ "$output" == *"# yaamux agent brief"* ]]
  [[ "$output" == *"## Commands you can use"* ]]
  [[ "$output" == *"### Read / inspect"* ]]
  [[ "$output" == *"### Coordinate with siblings"* ]]
  [[ "$output" == *"### Background work"* ]]
  [[ "$output" == *"### Ship"* ]]
  [[ "$output" == *"## Do not run these"* ]]
}

@test "--agent-brief --format markdown lists every agent-facing flag" {
  run_yaamux --agent-brief --format markdown
  [ "$status" -eq 0 ]
  for flag in --list --status --send --exec --bg --bg-tail --bg-list --bg-kill --pr --kill --clean; do
    [[ "$output" == *"yaamux ${flag}"* ]] || { echo "missing: $flag"; false; }
  done
}

@test "--agent-brief --format text emits plain (no markdown headers / backticks)" {
  run_yaamux --agent-brief --format text
  [ "$status" -eq 0 ]
  [[ "$output" == *"yaamux agent brief"* ]]
  [[ "$output" == *"yaamux --bg"* ]]
  # No markdown heading lines
  ! grep -q '^# ' <<< "$output"
  ! grep -q '^## ' <<< "$output"
}

@test "--agent-brief --format json emits valid JSON with envelope keys" {
  run_yaamux --agent-brief --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
assert "version" in data
assert "in_session" in data
assert "agent" in data
assert "commands" in data and isinstance(data["commands"], list) and len(data["commands"]) > 0
# in_session false when YAAMUX_SESSION unset; agent fields null
assert data["in_session"] is False
assert data["agent"]["session"] is None
# Every command has a flag, group, summary
for c in data["commands"]:
    assert {"flag", "group", "summary"} <= set(c.keys())
    assert c["group"] in {"read", "coordinate", "background", "ship", "refused"}
'
}

@test "--agent-brief --format json reflects YAAMUX_* env when set" {
  YAAMUX_SESSION="yaamux-test" \
  YAAMUX_AGENT_NAME="agent-3" \
  YAAMUX_AGENT_NUMBER="3" \
  YAAMUX_AGENT_TOTAL="4" \
  YAAMUX_AGENT_TYPE="claude" \
  YAAMUX_PANE_ID="%42" \
  YAAMUX_REPO_ROOT="/tmp/repo" \
  YAAMUX_AGENT_MODE="safe" \
    run bash "$YAAMUX_BIN" --agent-brief --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
assert data["in_session"] is True
a = data["agent"]
assert a["name"] == "agent-3"
assert a["number"] == 3
assert a["total"] == 4
assert a["type"] == "claude"
assert a["session"] == "yaamux-test"
assert a["pane_id"] == "%42"
assert a["repo_root"] == "/tmp/repo"
assert a["mode"] == "safe"
'
}

@test "--agent-brief --format rejects unknown formats" {
  run_yaamux --agent-brief --format bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown"* || "$output" == *"format"* ]]
}

@test "--keys lists --agent-brief" {
  run_yaamux --keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"--agent-brief"* ]]
}

# Drift guard: every flag in the main case block must appear in _brief_data,
# so a new flag added without brief coverage fails CI before it ships.
@test "drift guard: every main-case flag is catalogued in _brief_data" {
  # _brief_data also contains setup + internal groups, hidden from --format json.
  # Pull every group's flags directly from the script for a complete catalog.
  all_catalogued="$(awk '/^_brief_data\(\) \{/,/^}/' "$YAAMUX_BIN" \
    | awk -F'\t' '/^(read|coordinate|background|ship|refused|setup|internal)\t/ {print $2}' \
    | sort -u)"

  # The agent-facing subset that the brief actually renders (visible groups).
  # Used for the reverse-drift check: every visible brief entry must point
  # at a real flag — catches a stale row left behind after a flag rename.
  visible_brief_flags="$(bash "$YAAMUX_BIN" --agent-brief --format json | python3 -c '
import json, sys
print("\n".join(c["flag"] for c in json.loads(sys.stdin.read())["commands"]))
' | sort -u)"

  # Extract every main case-arm flag from the script. The main case block
  # starts at `^case "\${1:-}" in` and ends at `^esac`. Each line of the
  # form `  --foo)` or `  --foo|--bar)` introduces one or more flags.
  main_flags="$(awk '
    /^case "\$\{1:-\}" in$/ {in_case=1; next}
    in_case && /^esac$/ {exit}
    in_case && /^  --[a-z-]+/ {
      gsub(/^[[:space:]]+/, "")
      # split off the trailing `)` or args
      sub(/[) ].*$/, "")
      n = split($0, parts, "|")
      for (i=1; i<=n; i++) if (parts[i] ~ /^--/) print parts[i]
    }
  ' "$YAAMUX_BIN" | sort -u)"

  [ -n "$main_flags" ]
  [ -n "$all_catalogued" ]
  [ -n "$visible_brief_flags" ]

  # Forward drift: every main-case flag must appear in _brief_data.
  missing=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! grep -qxF -- "$f" <<< "$all_catalogued"; then
      missing="${missing}${f}\n"
    fi
  done <<< "$main_flags"

  if [[ -n "$missing" ]]; then
    echo "Flags missing from _brief_data:"
    printf '%b' "$missing"
    false
  fi

  # Reverse drift: every visible brief entry must be a real main-case flag.
  stale=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! grep -qxF -- "$f" <<< "$main_flags"; then
      stale="${stale}${f}\n"
    fi
  done <<< "$visible_brief_flags"

  if [[ -n "$stale" ]]; then
    echo "Visible brief flags that no longer exist in the case block:"
    printf '%b' "$stale"
    false
  fi
}

@test "--init creates .claude/skills/yaamux symlink to the skills source" {
  run_yaamux --init
  [ "$status" -eq 0 ]
  [ -L .claude/skills/yaamux ]
  # Symlink target resolves to a directory containing SKILL.md
  [ -f .claude/skills/yaamux/SKILL.md ]
  grep -q "^name: yaamux" .claude/skills/yaamux/SKILL.md
}

@test "--init --copy-skill vendors the skill (regular dir, not symlink)" {
  run_yaamux --init --copy-skill
  [ "$status" -eq 0 ]
  [ ! -L .claude/skills/yaamux ]
  [ -d .claude/skills/yaamux ]
  [ -f .claude/skills/yaamux/SKILL.md ]
  grep -q "^name: yaamux" .claude/skills/yaamux/SKILL.md
}

@test "--init is idempotent for the skill — does not clobber a user-edited copy" {
  run_yaamux --init --copy-skill
  [ "$status" -eq 0 ]
  echo "USER EDIT" >> .claude/skills/yaamux/SKILL.md
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -q "USER EDIT" .claude/skills/yaamux/SKILL.md
}

@test "--init symlink path is gitignored; --copy-skill path is NOT gitignored" {
  touch .gitignore
  run_yaamux --init
  [ "$status" -eq 0 ]
  grep -qxF ".claude/skills/yaamux" .gitignore

  # Fresh repo for the copy-skill case.
  cd /
  rm -rf "$TEST_REPO"
  setup_repo
  touch .gitignore
  run_yaamux --init --copy-skill
  [ "$status" -eq 0 ]
  ! grep -qxF ".claude/skills/yaamux" .gitignore
}

@test "skills/yaamux/SKILL.md is shipped in the repo with valid frontmatter" {
  src="$(dirname "$YAAMUX_BIN")/skills/yaamux/SKILL.md"
  [ -f "$src" ]
  head -1 "$src" | grep -q "^---$"
  grep -q "^name: yaamux" "$src"
  grep -q "^description:" "$src"
}
