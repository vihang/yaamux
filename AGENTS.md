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
| `yaamux` | The entire program — including 3 embedded helper scripts | — |
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

# 2. Syntax-check the 3 embedded heredoc scripts (they ship inside yaamux)
python3 - <<'PY'
import re
src = open('yaamux').read()
for tag in ('GUARD_EOF','NOTIFY_EOF','MOBILE_EOF'):
    m = re.search(r"<< '"+tag+r"'\n(.*?)\n"+tag+r"\n", src, re.S)
    open('/tmp/'+tag,'w').write(m.group(1)) if m else print('MISSING', tag)
PY
for t in GUARD_EOF NOTIFY_EOF MOBILE_EOF; do bash -n /tmp/$t && echo "$t ok"; done

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
   `yaamux-mobile-attach.sh`) are embedded as heredocs and written to disk at
   runtime. Do not split them into separate files — install-once portability
   depends on `yaamux` being self-contained.

2. **Stateless / no project pinning.** yaamux must derive the project from
   `git rev-parse --show-toplevel` on every run. Never write a config file
   that hard-codes a repo path. The only persistent config is global and
   optional: `~/.config/yaamux/notify.conf`.

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

8. **Tiled layout.** Pane grid is built by repeated `split-window` +
   `select-layout tiled`. Never hard-code a 2×2 (or any fixed) geometry —
   yaamux supports 1–20 agents.

---

## Code map

The `yaamux` file is ordered top-to-bottom as:

| Section | Responsibility |
|---------|----------------|
| Self-location | `SELF`, `YAAMUX_HOME` — resolve real path through the symlink |
| Project context | `REPO_ROOT`, `SESSION`, `WORKTREES_BASE`, paths |
| Defaults & flags | `DEFAULT_*`, `MAX_AGENTS`, per-agent auto-accept flag vars |
| `agent_*` helpers | `agent_bin` / `agent_icon` / `agent_cmd` — the only type switch |
| Embedded writers | `_write_settings_json` / `_write_guard_hook` / `_write_notify_hook` / `_write_mobile_attach` |
| Lifecycle | `_install_yaamux` / `_update_yaamux` / `_uninstall_yaamux` / `_add_docs` / `_gen_ssh_config` / `_install_launchagent` |
| Remote ops | `_remote_resolve_host` / `_remote_list_raw` / `_remote_print_list` / `_remote_pick_session` / `_remote_attach` / `_remote_dispatch` — back the `--remote` flag |
| Argument parsing | Splits positional (`N` + `PATTERN`) from flags |
| Flag `case` | All `--xxx` commands; each `exit 0`s |
| Start sequence | preflight → hooks → worktrees → tmux build → launch → attach |

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
- [ ] Commit message: imperative mood, scoped — e.g. `yaamux: add --list flag`

---

## Notes for agents

This file is `AGENTS.md` — the canonical project instructions per the
[agents.md standard](https://agents.md/), read by 60+ agent tools (Codex,
Cursor, Aider, Gemini CLI, Copilot, etc.). `CLAUDE.md` is a symlink to it
so Claude Code's discovery still works.

The invariants and development loop above apply identically regardless of
which agent is doing the work.
