---
name: yaamux
description: Use when you are running inside a yaamux session (detect via the YAAMUX_SESSION env var or a .yaamux/ directory in the repo root). Helps coordinate with sibling agents in adjacent worktrees, start non-blocking background work, list/inspect panels, and open PRs. Skip for tmux work outside a yaamux session.
---

# yaamux

You are an AI coding agent running inside a **yaamux** session — a tmux
multiplexer that spawns N agents in parallel, one per git worktree.
This skill teaches you how to use yaamux's CLI to coordinate with your
siblings instead of working in isolation.

## Are you in a yaamux session?

You are if any of these is true:

- `$YAAMUX_SESSION` is set in your shell environment (the canonical signal)
- The repo root contains a `.yaamux/` directory
- `yaamux --status` exits zero

If none hold, do not use these commands — they assume yaamux state.

## Your situational context

When you are in a session, the following env vars describe your position:

| Var | Meaning |
|-----|---------|
| `YAAMUX_AGENT_NAME`   | your worktree name (e.g. `agent-3`) |
| `YAAMUX_AGENT_NUMBER` | your 1-based ordinal (e.g. `3`) |
| `YAAMUX_AGENT_TOTAL`  | total agents in this session |
| `YAAMUX_AGENT_TYPE`   | `claude` · `gemini` · `copilot` · `codex` · `opencode` |
| `YAAMUX_SESSION`      | tmux session name (e.g. `yaamux-myapp`) |
| `YAAMUX_PANE_ID`      | tmux pane id (e.g. `%23`) |
| `YAAMUX_REPO_ROOT`    | absolute path of the main checkout |
| `YAAMUX_VERSION`      | yaamux version string |
| `YAAMUX_AGENT_MODE`   | `safe` while you are an agent · `pilot` inside the orchestrator pane · destructive flags refused while `safe` |
| `YAAMUX_PILOT_ACTIVE` | backend name (e.g. `claude`) if a pilot is driving this session — unset when the panel is in dashboard mode |

Sibling agents live in worktrees `agent-1` … `agent-${YAAMUX_AGENT_TOTAL}`
next to the parent of `YAAMUX_REPO_ROOT`. Your own pwd is your worktree.

## Recipes

### Look around before you start

```bash
yaamux --status              # who's alive in this session, what state
yaamux --list --json         # other yaamux sessions on this machine
yaamux --bg-list             # background panels already running
```

### Run a long task without blocking your shell

If a build / test-watch / dev-server takes more than ~30 seconds and you
do not need to read its output line-by-line as it runs, put it in a
**background panel**. Each panel is a dedicated tmux pane with its output
captured to disk:

```bash
yaamux --bg ci "pnpm test --run"            # start
yaamux --bg-tail ci --follow                # block until done
# ...output...
# OFFSET=12345
# STATUS=done
# RC=0
```

To poll instead of block:

```bash
yaamux --bg-tail ci                         # read so-far, learn OFFSET
# later:
yaamux --bg-tail ci --from 12345            # resume from where you left off
```

Stop a panel before it finishes (e.g. a runaway dev-server):

```bash
yaamux --bg-kill ci                         # Ctrl-C, then tmux kill-pane if still alive
```

Status values: `running` · `done` (rc=0) · `failed` (rc≠0) · `killed`
(SIGINT, rc=130) · `unknown`. The log is preserved on disk after a kill,
so `--bg-tail` still works after the panel ends.

### Hand work to a sibling agent

When agent N is the right one to handle something (e.g. they own a
different feature area), send them the prompt directly instead of
doing it yourself in your worktree:

```bash
yaamux --send 2 "Run the integration tests against the auth module"
```

When the prompt is user-supplied or contains `"`, `$`, backticks, or
newlines, use the literal-stdin variant — it dodges shell-quoting bugs:

```bash
printf '%s' "$user_text" | yaamux --send-stdin 2
```

For a synchronous request — send and wait for the agent to go idle:

```bash
yaamux --exec 3 "Summarize the diff in your branch" 120
```

`--exec` polls the target pane for that agent's idle pattern, with a
timeout in seconds (default 60).

### If a pilot is active

The Control Panel pane can be flipped from its dashboard view into a
**pilot chat** — an orchestrator agent CLI (claude / opencode / gemini /
codex / copilot) talking to the human and driving the agent panes via
the same `--send` / `--send-stdin` / `--broadcast` / `--restart` flags.

Detect a running pilot from your own pane:

```bash
yaamux --agent-brief --format json | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("pilot_active") or "(none)")'
# or, directly:
tmux show-option -v -t "$YAAMUX_SESSION" @yaamux-pilot-active 2>/dev/null
```

If a pilot IS active and you receive a `--send` / `--send-stdin` prompt
that reads like another agent typed it, treat it as the human's intent
forwarded through the pilot — respond as if a human asked you directly.
You don't need to talk to the pilot yourself; it talks to you.

### Open a PR for your work

When your worktree is ready:

```bash
yaamux --pr "$YAAMUX_AGENT_NUMBER" "feat: ship the new auth flow"
# add --merge to enable auto-merge after CI:
yaamux --pr "$YAAMUX_AGENT_NUMBER" "..." --merge
```

This pushes your branch (`worktree/<your-agent-name>`) and opens a PR via
the auto-detected forge CLI (`gh` / `glab` / `tea` — overridable with
`$YAAMUX_FORGE`).

### After the PR is open — CI + diff helpers

```bash
yaamux --watch-pr   "$YAAMUX_AGENT_NUMBER"   # block until CI completes (pass / fail)
yaamux --auto-merge "$YAAMUX_AGENT_NUMBER"   # enable auto-merge (squash) on the existing PR
yaamux --ci-status                           # table of CI status across every pane's PR
yaamux --ci-status  "$YAAMUX_AGENT_NUMBER"   # just one pane's CI status
yaamux --diff       "$YAAMUX_AGENT_NUMBER"   # diff your branch vs origin/main (delta-highlighted)
```

`--watch-pr` is the right call when you've kicked off a PR and want to
block until checks complete before doing follow-up work. Don't poll
`--ci-status` in a loop — `--watch-pr` already wraps `gh pr checks --watch`
properly.

## Do not run these

`YAAMUX_AGENT_MODE=safe` is set in your shell — yaamux refuses these
flags so a curious agent cannot tear down its own session:

- `yaamux --kill` — kills the session you are inside
- `yaamux --clean` / `--clean --force` — removes worktrees (including yours)
- `yaamux --install` / `--uninstall` / `--install-service` — host config

If you genuinely need one of these to run, ask the operator (the human
who started yaamux) to run it from their own shell outside the session.

Operator-surface flags you don't need to invoke yourself (they're for
the human who runs yaamux): `--init`, `--add-docs`, `--update`,
`--prepare-host`, `--setup-notify`, `--ssh-config`, `--connect`,
`--auto-attach`, `--mobile-attach`, `--mobile-grid`, `--remote`,
`--remote-hosts`, `--toggle-panel`, `--panel-show` / `--panel-hide`,
`--pilot-toggle` / `--pilot-show` / `--pilot-hide` / `--pilot-backend`.

## Reference

- `yaamux --agent-brief` — emits this brief programmatically (also
  `--format text` and `--format json`).
- `yaamux --keys` — full CLI cheat sheet, including flags this skill
  intentionally omits (control-panel / mobile-attach / remote ops are
  operator surfaces).
- Long-form docs: `YAAMUX.md` at the repo root.
