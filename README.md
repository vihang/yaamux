# yaamux — Agents Multiplexer

Spawn N AI coding agents in parallel, one per git worktree, in a tiled tmux
grid. Manage them locally or from any device. **One bash file. Install once,
use in every repo.**

Supported agents: **Claude Code · Gemini CLI · GitHub Copilot CLI · Codex CLI**

```bash
brew tap vihang/tap && brew install yaamux   # Homebrew (recommended)
# or: git clone https://github.com/vihang/yaamux ~/.yaamux && ~/.yaamux/yaamux --install
```

Both `yaamux` and `ymx` (3-char alias) are installed — same script, same flags.
Examples in this README use `yaamux`; substitute `ymx` if you prefer fewer keystrokes.

---

## Why another amux?

There are at least six tools called "amux" on GitHub. yaamux is the
**single-file Bash** one — read it end-to-end in 20 minutes, install
anywhere, no toolchain required.

| Project | Lang | Surface | Best for |
|---|---|---|---|
| **vihang/yaamux** (this) | Bash, 1 file | CLI + tmux + push | Daily multi-agent work; phone-remote-ready |
| smtg-ai/claude-squad | Go | Custom TUI | Heavy multi-Claude session management |
| nwiizo/ccswarm | Rust | TUI | Container-isolated Claude swarms |
| BloopAI/vibe-kanban | Rust + TS | Web Kanban | Task-board-driven dev (sunsetting) |
| mixpeek/amux | Python + PWA | Web dashboard + iOS PWA | Self-hosted control plane |
| andyrewlee/amux | Go | TUI | Workspace-first multi-agent |
| weill-labs/amux | Go | Custom VT emulator + JSON API | Agents driving terminals |
| tobi/amux | TypeScript | Run-tail CLI | Agent-side tmux usage |

If you want a polished Go TUI or a web kanban, those exist. If you want **the
smallest, most auditable thing that runs N agent CLIs in parallel inside tmux**
— that's yaamux.

---

## First run (under 2 minutes)

```bash
brew tap vihang/tap && brew install yaamux
cd ~/some/repo
yaamux --init        # writes AGENTS.md, .yaamux/config, .worktreeinclude, .gitignore entries
yaamux 2             # boots 2 claude agents in a tiled tmux grid
# Ctrl+Space + D     # detach (agents keep running)
yaamux --list        # see all yaamux sessions across all your repos
```

---

## Quick command reference

| Command | Action |
|---------|--------|
| `yaamux [N] [types...]` | Start N agents (default 4 Claude) |
| `yaamux --init [--with-docs]` | Scaffold AGENTS.md + `.yaamux/config` + `.worktreeinclude` |
| `yaamux --list [--json]` | List yaamux sessions across all repos |
| `yaamux --status` | Health check for current repo's session |
| `yaamux --attach` / `--kill` / `--clean` [`--force`] | Session lifecycle |
| `yaamux --layout main\|tiled\|even` | Override default pane layout |
| `yaamux --zoom N` / `--vscode N` | Focus / hand pane N to VS Code |
| `yaamux --send N "x"` / `--broadcast "x"` | Send prompts to panes |
| `yaamux --exec N "x" [timeout]` | Headless: send, wait for idle, return output |
| `yaamux --pr N [title] [--merge]` | Push pane N's branch + open PR (`gh`) |
| `yaamux --restart N` / `--logs` / `--sync` | Manage running agents |
| `yaamux --yolo …` | Run agents with full permission bypass |
| `yaamux --link-env …` | Symlink `.env*` into worktrees (default: copy) |
| `yaamux --setup-notify` | Phone push notifications via ntfy |
| `yaamux --version` / `--install` / `--update` / `--uninstall` | Lifecycle |

Full details: see [YAAMUX.md](./YAAMUX.md).

---

## Permissions, cost, and what you're opting into

**By default, agents run in their CLI's "safe" mode** — meaning Claude / Gemini /
Codex / Copilot will still prompt for risky operations. Add `--yolo` (or set
`YAAMUX_YOLO=1`) to bypass all permission prompts. With `--yolo`, agents can
run any shell command without asking. **Only do this on code you trust.**

**Cost.** Each agent runs against your real account (Claude Pro/Max, Gemini API,
GitHub Copilot subscription, etc.). 4 Claude agents at $0.03–0.10/min add up to
**$20–50/hour** if continuously active. Monitor usage at the provider dashboards
(claude.ai/usage etc.). Detach (`Ctrl+Space + D`) and `--kill` when you're done.

---

## Why install-once works

yaamux holds no project state. Every run resolves the current repo with
`git rev-parse`, then derives everything from there:

| Thing | Where it lives |
|-------|----------------|
| The `yaamux` command | `$(brew --prefix)/bin/yaamux` (or `~/.yaamux/yaamux` for git installs) |
| Per-project defaults | `<repo>/.yaamux/config` (committable, gitignored optional) |
| Per-project worktrees | `<repo>/../<repo>-worktrees/agent-N` |
| Per-project hooks/logs | `<repo>/.claude/` |
| Agent instructions | `<repo>/AGENTS.md` (canonical per [agents.md](https://agents.md/)) |
| Env copy list | `<repo>/.worktreeinclude` |
| tmux session | `yaamux-<repo-name>` (one per repo, no collisions) |
| Global notify config | `~/.config/yaamux/notify.conf` |

One binary, one source of truth. `brew upgrade yaamux` to update.

---

## Repo layout

```
yaamux/
├── yaamux                     ← the script (the entire program)
├── VERSION                    ← 0.1.0
├── YAAMUX.md                  ← full usage guide
├── README.md                  ← this file
├── AGENTS.md                  ← developer/agent guide (CLAUDE.md → symlink)
├── tests/                     ← bats-core integration test suite
└── .github/workflows/ci.yml   ← syntax + shellcheck + bats matrix
```

---

## Requirements

`tmux` (3.2+ recommended), `git`, `python3` (for path/JSON helpers), `curl`,
and at least one agent CLI installed (`claude`, `gemini`, `codex`, `copilot`).

Optional: `gh` (for `--pr`), `mosh` + `tailscale` (for phone-remote use).

yaamux checks everything on startup and prints install commands for anything
missing.

---

## License

MIT © [Vihang Patel](https://github.com/vihang)
