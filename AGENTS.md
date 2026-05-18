# AGENTS.md — yaamux development guide

Operating manual for any agent (Claude Code, Codex, Copilot, Cursor, Gemini CLI,
Aider, etc.) developing **yaamux**. Read this fully before making changes.

This file is the canonical project instructions per the [agents.md](https://agents.md/)
standard. `CLAUDE.md` is a symlink to it for Claude Code's discovery convention.

---

## What yaamux is

A single-file Bash tool that spawns N AI coding agents in parallel — one per
git worktree, in a tiled tmux grid — manageable locally and remotely. It is
**stateless** and **install-once**: one symlinked binary serves every repo.

- Language: Bash (`set -euo pipefail`), targets Bash 4+ / macOS & Linux.
- Runtime deps: `tmux`, `git`, `python3`, `curl`. No build step.
- ~600 lines, one file: `yaamux`.

---

## Repo structure

| File | Purpose | Keep in sync? |
|------|---------|---------------|
| `yaamux` | The entire program — including 4 embedded helper scripts | — |
| `YAAMUX.md` | End-user usage guide | Yes — update on any UX/flag change |
| `README.md` | Install instructions for the yaamux repo | Yes — update on install-flow change |
| `AGENTS.md` | This file — developer/agent guide (CLAUDE.md → symlink) | Yes — update on architecture change |
| `VERSION` | Semver string read by `--version` | Yes — bump on release |
| `tests/yaamux.bats` | bats-core integration test suite | Yes — keep current with new flags |
| `.github/workflows/ci.yml` | CI: bash -n, heredoc check, shellcheck, bats | Yes — keep matrix in sync |

There is intentionally **no `src/`, no build, no package manifest**. The
deliverable is the `yaamux` file itself.

---

## Development loop

After **every** edit to `yaamux`:

```bash
# 1. Syntax-check the main script
bash -n yaamux

# 2. Syntax-check the 4 embedded heredoc scripts (they ship inside yaamux)
rm -f /tmp/{GUARD,NOTIFY,MOBILE,CPANEL}_EOF
python3 - <<'PY'
import re, sys
src = open('yaamux').read()
ok = True
for tag in ('GUARD_EOF', 'NOTIFY_EOF', 'MOBILE_EOF', 'CPANEL_EOF'):
    m = re.search(r"<<\s*'" + tag + r"'\s*\n(.*?)\n" + tag + r"\s*\n", src, re.S)
    if m:
        open('/tmp/' + tag, 'w').write(m.group(1))
    else:
        print('MISSING', tag); ok = False
if not ok: sys.exit(1)
PY
for t in GUARD_EOF NOTIFY_EOF MOBILE_EOF CPANEL_EOF; do [[ -f /tmp/$t ]] && bash -n /tmp/$t && echo "$t ok"; done

# 3. Lint (install: brew install shellcheck)
shellcheck yaamux

# 4. Smoke test in a throwaway git repo
mkdir -p /tmp/yaamux-test && cd /tmp/yaamux-test && git init -q && git commit -q --allow-empty -m init
/path/to/yaamux 2 claude claude     # opens tmux; verify 2 panes, then:
/path/to/yaamux --status
/path/to/yaamux --kill
/path/to/yaamux --clean
```

A change is not done until steps 1–3 pass and the doc files are updated.

---

## Architecture — invariants that must NOT break

These are deliberate design decisions. Do not "improve" them without an
explicit instruction to do so.

1. **Single file.** The helper scripts (`yaamux-guard.sh`, `yaamux-notify.sh`,
   `yaamux-mobile-attach.sh`, `yaamux-cpanel.sh`) are embedded as heredocs and
   written to disk at runtime. Do not split them into separate files —
   install-once portability depends on `yaamux` being self-contained.

2. **Stateless / no project pinning.** yaamux must derive the project from
   `git rev-parse --show-toplevel` on every run. Never write a config file
   that hard-codes a repo path. Persistent config is opt-in and lives at
   well-known paths: global at `~/.config/yaamux/{notify,control-panel}.conf`
   and `~/.config/yaamux/hosts.conf`; per-repo at `<repo>/.yaamux/config`,
   `<repo>/.yaamux/state`, and `<repo>/.yaamux/panels/<name>.{log,meta}`
   (all gitignored).

3. **Session per repo.** `SESSION="yaamux-${PROJECT_NAME}"`. Never use a fixed
   session name — it would collide across repos.

4. **Embedded heredocs use quoted delimiters.** `<< 'GUARD_EOF'` etc. The
   inner `$` and `$()` must be stored verbatim and expand at runtime. If you
   switch to an unquoted delimiter the embedded scripts break silently.

5. **Strict mode.** `set -euo pipefail` is on. Every variable that may be
   unset must use `${x:-}`. Every command that may fail acceptably must end
   `|| true`.

6. **Argument parsing contract.** Positional args (agent types / count) are
   distinguished from flags by `[[ "${1:0:2}" != "--" ]]`. Flags always start
   with `--`. Do not add bare-word subcommands.

7. **Agent-agnostic.** Adding/removing an agent type means editing exactly
   three functions: `agent_bin`, `agent_icon`, `agent_cmd`. Nothing else
   should branch on agent type.

   The same rule applies to the **git host**. Every call into a host CLI
   (`gh`, `glab`, …) goes through the `_host_*` dispatch family
   (`_host_provider`, `_host_cli`, `_host_pr_create`, `_host_pr_url`,
   `_host_pr_checks_watch`, `_host_pr_merge_auto`, `_host_pr_ci_status`).
   Adding GitLab support = filling in the `gitlab)` case in each — never
   inline `gh` or `glab` outside this family. Auto-detection reads
   `git remote get-url origin`; override with `$YAAMUX_GIT_HOST`.

8. **Tiled layout.** Pane grid is built by repeated `split-window` +
   `select-layout tiled`. Never hard-code a 2×2 (or any fixed) geometry —
   yaamux supports 1–20 agents.

9. **Per-pane role tag.** Every pane in the `agents` window carries a
   `@yaamux-role` user-option — `agent` for an agent pane, `control-panel`
   for the optional Control Panel TUI pane. Background panels (which live
   in a separate `bg` window, not `agents`) carry `@yaamux-role=background`.
   Every loop that iterates the agents window must filter on this option
   so the control-panel pane is never restarted, broadcast-to, or counted
   as an agent. Loops that target a specific window by name
   (`${SESSION}:agents` vs `${SESSION}:bg`) are naturally isolated by
   window — only cross-window helpers (e.g. `_list_sessions`, the Control
   Panel TUI's session view) need to be aware of the third role value.
   The `_agent_pane_idx N` helper resolves the user-facing 1-based agent
   number to the actual tmux `pane_index`; use it in every `--send N`,
   `--restart N`, `--zoom N`, `--exec N` site. The agent name (`agent-N`)
   is stored per-pane on `@yaamux-agent`; read that rather than computing
   it from a tmux index, which is unstable across layout modes.

10. **Background panels = non-agent, non-blocking shell processes.** They
    live in the `bg` window (lazy-created on first `--bg`), one pane per
    panel. Output is captured to `${REPO_ROOT}/.yaamux/panels/<name>.log`
    via `tmux pipe-pane`; completion is detected by a per-panel sentinel
    `[[YAAMUX:PANEL:<token>:DONE:RC=<n>]]` emitted on stdout after the
    command returns. The token is 12 random chars, stored per-panel in
    `<name>.meta`, so consumers grep for exactly the right line — even
    commands whose output happens to contain `[[YAAMUX:PANEL:` literally
    won't false-positive. Status is computed on-the-fly from the log; we
    do NOT mirror it into a stored field that could go stale.

---

## Code map

The `yaamux` file is ordered top-to-bottom as:

| Section | Responsibility |
|---------|----------------|
| Self-location | `SELF`, `YAAMUX_HOME` — resolve real path through the symlink |
| Project context | `REPO_ROOT`, `SESSION`, `WORKTREES_BASE`, paths |
| Defaults & flags | `DEFAULT_*`, `MAX_AGENTS`, per-agent auto-accept flag vars |
| `agent_*` helpers | `agent_bin` / `agent_icon` / `agent_cmd` — the only agent-type switch |
| `_host_*` helpers | `_host_provider` / `_host_cli` / `_host_pr_*` — the only git-host switch (PR/CI ops) |
| Embedded writers | `_write_settings_json` / `_write_guard_hook` / `_write_notify_hook` / `_write_mobile_attach` / `_write_cpanel` |
| Lifecycle | `_install_yaamux` / `_update_yaamux` / `_uninstall_yaamux` / `_add_docs` / `_gen_ssh_config` / `_install_launchagent` / `_prepare_host_mosh` (host-level mosh-server PATH fix for `mosh://` URLs) |
| Remote ops | `_remote_resolve_host` / `_remote_list_raw` / `_remote_print_list` / `_remote_pick_session` / `_remote_attach` / `_remote_dispatch` — back the `--remote` flag |
| Pane health | `_pane_state` / `_refresh_pane_states` / `_restart_pane` / `_triage_prompt` / `_remote_triage_prompt` — back `--restart-current` / `--restart-dead` / `--refresh-states` and the attach-time triage. All filter on `@yaamux-role` |
| Pane addressing | `_agent_pane_idx N` (1-based agent → tmux `pane_index`), `_panel_pane_idx`, `_agent_count` — the canonical way to resolve "agent N" in a panel-aware layout |
| Control Panel | `_cpanel_show` / `_cpanel_hide` / `_cpanel_toggle` / `_cpanel_self_heal` / `_save_panel_state` / `_status_render` / `_goto_pane` — back `--toggle-panel` / `--panel-show` / `--panel-hide` / `--cpanel` / `--status-render` / `--goto N` |
| Background panels | `_bg_spawn` / `_bg_tail` / `_bg_list` / `_bg_kill` / `_bg_status` / `_bg_ensure_window` / `_bg_save_meta` / `_bg_read_meta` / `_bg_gen_token` / `_bg_validate_name` — back `--bg` / `--bg-tail` / `--bg-list` / `--bg-kill` |
| Argument parsing | Splits positional (`N` + `PATTERN`) from flags |
| Flag `case` | All `--xxx` commands; each `exit 0`s |
| Start sequence | preflight → hooks → worktrees → tmux build (incl. parity-based panel pane) → launch → attach |

---

## Conventions

- Internal functions are prefixed `_`. Public-ish helpers (`agent_*`) are not.
- Output uses `log` / `warn` / `die` / `header` — never raw `echo` for status.
- All tmux targets are fully qualified: `"${SESSION}:window.pane"`.
- Indentation: 2 spaces. No tabs.
- Keep lines under ~100 chars where practical.
- User-facing strings: concise, lowercase-leaning, no emoji except the agent
  icons already defined.
- When adding a flag: add it to the `case` block, the `--help` header comment
  block (lines ~15–40), the summary footer if relevant, and `YAAMUX.md`.
- When adding a tmux key binding (any new `tmux bind-key -T prefix …` line in
  the start sequence): also add a row to `_print_keys()` (`In-session keys`
  section) and to the shortcuts table in `YAAMUX.md`. The `Ctrl+Space + ?`
  popup is the user's only in-session reference — a binding that isn't listed
  there is effectively undiscoverable.

---

## Testing checklist (manual, until a suite exists)

| Scenario | Command | Expect |
|----------|---------|--------|
| Default | `yaamux` | 4 Claude panes, tiled |
| Count only | `yaamux 6` | 6 Claude panes |
| Mixed types | `yaamux claude gemini codex` | 3 panes, correct icons |
| Cycled | `yaamux 8 claude gemini` | 8 panes alternating |
| Bounds | `yaamux 0` / `yaamux 99` | Clean error, no tmux session |
| Missing CLI | `yaamux gemini` w/o gemini installed | Lists install cmd, exits |
| Lifecycle | `--attach` / `--kill` / `--clean` | Session + worktree handling |
| Per-pane | `--send 2 "x"` / `--restart 2` / `--zoom 2` | Targets correct pane |
| Multi-repo | `yaamux` in repo A and repo B | Two sessions, no collision |
| Install | `--install` then `yaamux` from elsewhere | Resolves new repo correctly |

---

## Roadmap

Shipped in v0.1 (see `tests/yaamux.bats` + CHANGELOG section in YAAMUX.md):
`--init` · `--list` · `--exec` · `--pr` · `--layout` · `--version` · `--yolo`
· `--link-env` · `--clean` staleness-aware · `.yaamux/config` defaults
· AGENTS.md scaffolding · smart-default layout · status-line polish ·
bats suite · GitHub Actions CI · Homebrew tap · `--remote <host>` /
`--remote-hosts` (cross-machine session access via SSH/mosh, with picker,
saved aliases at `~/.config/yaamux/hosts.conf`, and per-pane zoom).

Deferred to v0.2+ (see `/Users/vihang/.claude/plans/cached-sleeping-jellyfish.md`
Roadmap section R1–R12): controller mode · council/pipeline/vote/pair
patterns · TUI keybinding layer · opencode 5th agent type · shared
context layer with per-agent adapters · GitHub-issue-queue dev mode ·
watchdog/auto-recovery · cost tracking · `--watch-pr` CI loop · `--serve`
web UI · `--container` sandbox · pre-warm pane.

Open backlog (small / platform / hygiene items not yet in v0.2 roadmap):

1. **shellcheck-clean.** Resolve all `shellcheck yaamux` findings; add a
   `# shellcheck disable=` with justification only where unavoidable.
   (CI runs shellcheck non-blocking until this lands.)
2. **WSL/Windows support.** Audit `realpath`, `pbcopy`, `osascript`, paths.
3. **Spaces-in-path hardening.** Audit all unquoted expansions for repos whose
   path contains spaces.
4. **Health watcher** — subsumed by R7 (failure-handling + observability) in the
   v0.2 roadmap; could move forward earlier if pain emerges.
5. **Cross-agent notifications** — subsumed by R8 in the v0.2 roadmap.

---

## Definition of done (any change)

- [ ] `bash -n yaamux` passes
- [ ] All 3 embedded scripts extract and `bash -n` clean
- [ ] `shellcheck yaamux` has no new findings
- [ ] Smoke-tested in a throwaway git repo (start → status → kill → clean)
- [ ] No invariant (section above) violated
- [ ] `YAAMUX.md` updated if behavior/flags changed
- [ ] `README.md` updated if install flow changed
- [ ] `AGENTS.md` updated if architecture changed
- [ ] If a new tmux key binding was added: `_print_keys()` and the
      `YAAMUX.md` shortcuts table both list it
- [ ] Commit message: imperative mood, scoped — e.g. `yaamux: add --list flag`

---

## Notes for agents

This file is `AGENTS.md` — the canonical project instructions per the
[agents.md standard](https://agents.md/), read by 60+ agent tools (Codex,
Cursor, Aider, Gemini CLI, Copilot, etc.). `CLAUDE.md` is a symlink to it
so Claude Code's discovery still works.

The invariants and development loop above apply identically regardless of
which agent is doing the work.
