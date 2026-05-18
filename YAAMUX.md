# YAAMUX.md — Agents Multiplexer

Full usage guide for `yaamux`. Spawn N AI coding agents in parallel, one per git
worktree, in a tiled tmux grid — manageable locally and from any device.

---

## Install once, use everywhere

```bash
brew tap vihang/tap && brew install yaamux          # recommended
# or, from a clone:
git clone https://github.com/vihang/yaamux ~/.yaamux
~/.yaamux/yaamux --install                          # symlinks yaamux → ~/.local/bin
```

Both `yaamux` and `ymx` (3-char alias) are installed — same script, same flags.
Use either; this guide uses `yaamux` for clarity.

yaamux holds no project state — every run resolves the current repo with
`git rev-parse` and derives everything from there. One binary serves all repos.

| yaamux command | Action |
|--------------|--------|
| `yaamux --version` | Print version + install source (`brew` / `git@SHA` / `unknown`) |
| `yaamux --install` | Symlink `yaamux` into `~/.local/bin` (git installs only) |
| `yaamux --update` | `brew upgrade yaamux` if brewed, else `git pull` the repo |
| `yaamux --uninstall` | Remove the symlink (repo + project files untouched) |
| `yaamux --init [--with-docs]` | Scaffold AGENTS.md + `.yaamux/config` + `.worktreeinclude` |
| `yaamux --add-docs` | Copy this `YAAMUX.md` into the current repo |

---

## Starting agents

Run from any git repo. Positional form: `yaamux [N] [type ...]`.

```bash
yaamux                          # 4 Claude agents (default)
yaamux 6                        # 6 Claude agents
yaamux claude gemini codex      # 3 agents — one of each (N = arg count)
yaamux 8 claude gemini          # 8 agents — types cycled: c,g,c,g,c,g,c,g
yaamux 1 codex                  # single Codex agent
```

- First arg numeric → that's **N**. Following args are a type pattern, cycled to fill N.
- First arg a type → types are literal, **N** = number of args.
- No args → 4 Claude agents.
- Valid types: `claude` `gemini` `copilot` `codex`. Max 20 agents.

Each repo gets its own tmux session: **`yaamux-<repo-name>`**. Run yaamux in
multiple repos simultaneously without collision.

---

## Commands

| Command | Action |
|---------|--------|
| `yaamux [N] [types...]` | Start (or attach if the repo's session exists) |
| `--init [--with-docs]` | Scaffold AGENTS.md + `.yaamux/config` + `.worktreeinclude` |
| `--list [--json]` | List yaamux sessions across all repos |
| `--attach` | Re-attach to this repo's session |
| `--kill` | Stop the session (worktrees kept) |
| `--clean` [`--force`] | Remove clean worktrees; `--force` removes dirty ones too |
| `--status` | Health check: session, panes, worktrees, notifications |
| `--layout main\|tiled\|even` | Override the auto-picked pane layout |
| `--zoom N` | Attach with pane N zoomed full-screen |
| `--vscode N` | Hand pane N's session to VS Code for interactive dev |
| `--send N "x"` | Inject a prompt into pane N without attaching |
| `--exec N "x" [timeout]` | Headless: send, poll for idle, return output (5min default) |
| `--broadcast "x"` | Send the same prompt to every pane |
| `--pr N [title] [--merge]` | Push pane N's branch + open PR via `gh` |
| `--restart N` | Restart pane N (relaunches its agent type) |
| `--restart-dead [-y]` | Restart every pane whose agent has exited or died (`-y` skips confirm) |
| `--logs` | Jump to the live-logs window |
| `--sync` | Toggle synchronize-panes (keystrokes → all panes) |
| `--yolo` | Modifier: launch agents with full permission bypass |
| `--link-env` | Modifier: symlink `.env*` into worktrees (default: copy) |
| `--setup-notify` | Configure ntfy push + Blink Shell deep links |
| `--ssh-config` | (Re)generate the `~/.ssh/config` host block |
| `--install-service` | macOS LaunchAgent — auto-start this repo's agents on login |
| `--remote <host> [args]` | Drive a remote host's yaamux sessions — see below |
| `--remote-hosts` | List host aliases from `~/.config/yaamux/hosts.conf` |
| `--help` / `--version` | Inline help / version + install source |

The `--yolo` and `--link-env` modifiers combine with positional args
(e.g., `yaamux --yolo 4 claude` or `yaamux 2 --link-env`). Equivalent
env vars: `YAAMUX_YOLO=1`, `YAAMUX_LINK_ENV=1`.

---

## tmux layout & navigation

yaamux picks a layout based on N: 2=side-by-side, 3/5/6=one-driver-plus-others,
4=2×2 grid, 7+=tiled grid. Override with `--layout main|tiled|even`.

```
window "agents"      window "remote-srv"    window "logs"
 tiled grid of N      Claude Remote          tiled grid of N
 agent panes          Control server         log tails
                      (Claude panes only)
```

Prefix is **Ctrl+Space**.

| Keys | Action |
|------|--------|
| `Ctrl+Space` + arrows | Move between panes |
| `Ctrl+Space` + `Z` | Zoom / unzoom current pane |
| `Ctrl+Space` + `W` | Window list (agents / remote-srv / logs) |
| `Ctrl+Space` + `[` | Scroll mode (`q` to exit) |
| `Ctrl+Space` + `y` | Copy selection → system clipboard |
| `Ctrl+Space` + `S` | Toggle sync mode |
| `Ctrl+Space` + `r` | Restart the agent in the current pane |
| `Ctrl+Space` + `R` | Restart every dead / idle agent (confirms) |
| `Ctrl+Space` + `L` | Clear screen + scrollback (fixes a garbled pane) |
| `Ctrl+Space` + `D` | Detach (agents keep running) |
| Mouse click | Focus a pane |

> macOS: `Ctrl+Space` may be the input-source switcher. Disable it under
> System Settings → Keyboard → Keyboard Shortcuts → Input Sources.

---

## Remote access

### Universal — every agent type

```bash
mosh user@host -- tmux attach -t yaamux-<repo>      # preferred
ssh  user@host -t 'tmux attach -t yaamux-<repo>'    # fallback
```

`yaamux --ssh-config` writes a `Host yaamux` block to `~/.ssh/config`.
mosh survives sleep, network drops, and LTE↔WiFi handoffs — ideal for phones.

If plain `mosh` errors with **`NoMoshServerArgs - Did not find mosh server
startup message`**, your remote ssh can't find `mosh-server` (typical on a
stock macOS desktop — Homebrew installs to `/opt/homebrew/bin` which isn't on
ssh's non-interactive PATH). Use the form yaamux prints at launch — it bakes a
`--server=` PATH prelude so it works everywhere:

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- tmux attach -t yaamux-<repo>
```

`yaamux --remote --mosh` and the line in yaamux's launch banner already use
this form, so the copy-paste from yaamux's own output is the easiest path.

### Drive remote sessions with `--remote`

If yaamux is installed on your laptop **and** the agents run on another box,
`--remote` wraps the SSH+tmux dance and adds a session picker, status, and
per-pane zoom. The remote needs `tmux` (and `mosh-server` + `sh` if you pass
`--mosh`); yaamux itself does not have to be installed there.

```bash
yaamux --remote user@host                     # pick a session interactively & attach
yaamux --remote user@host myapp               # direct attach to yaamux-myapp
yaamux --remote user@host --list              # what's running (table)
yaamux --remote user@host --list --json       # ...same, JSON
yaamux --remote user@host --status            # windows / panes — no attach
yaamux --remote user@host --status myapp      # ...for one specific session
yaamux --remote user@host --zoom 2            # attach with pane 2 zoomed (phone-friendly)
yaamux --remote user@host --zoom 2 myapp      # ...for a specific session
yaamux --remote user@host --mosh              # use mosh transport (sleep-safe)
yaamux --remote-hosts                         # show host aliases configured locally
```

If multiple sessions are running, `--remote <host>` shows a numbered table and
prompts; on a single session it auto-attaches. `--mosh` may appear anywhere in
the arg list (or set `YAAMUX_MOSH=1` in your shell rc to make mosh the default).
Transport flags only affect attach/zoom — `--list` and `--status` are one-shot
queries and always run over ssh.

SSH calls share a connection via ControlMaster (socket under `$TMPDIR`, 60s
persist), so a password (if used) is prompted once per `yaamux --remote`
invocation rather than once per list/attach call.

The remote tmux is invoked with `TERM=xterm-256color` so terminals whose own
terminfo isn't installed on the remote (Ghostty, Kitty, WezTerm, …) don't fail
with `missing or unsuitable terminal`. Override with `YAAMUX_REMOTE_TERM=…` if
you've installed your terminal's terminfo on the remote and want full parity.

#### Host aliases

Save shortcuts in `~/.config/yaamux/hosts.conf` — one per line, whitespace-separated:

```
# yaamux remote host aliases
work    vihang@work.tail-scale.net
laptop  vihang@laptop.local
phone   user@my-phone-ssh-host
```

Then: `yaamux --remote work --list`, `yaamux --remote laptop --zoom 1`, etc.
`yaamux --remote-hosts` prints the table with the file path.

### iPhone / iPad apps

| App | Purpose |
|-----|---------|
| **Blink Shell** | Full terminal + mosh (one-time purchase) |
| **Prompt 3** (Panic) | SSH + snippets (one-time purchase) |
| **Code App** (thebaselab) | SSH + git + Monaco editor (free) |
| **Claude app** | Drive Claude sessions — Code tab (free) |
| **ntfy** | Push notifications (free) |
| **Tailscale** | Zero-config networking (free) |

### Show the connect commands (`--connect`, `prefix C`, QR)

Anyone (you, a teammate, your phone) can copy the exact line they need to reach
your host's yaamux sessions:

```bash
yaamux --connect              # prints mosh / ssh / --remote commands for this host
yaamux --connect --qr         # …plus an ANSI QR of the mosh snippet (brew install qrencode)
```

Inside any running yaamux session, two prefix keybindings open a popup with the
same output — no need to drop to a shell:

| Key | Shows |
|-----|-------|
| `Ctrl+Space C` | Connect commands (mosh, ssh, `--remote`) |
| `Ctrl+Space Q` | QR code of the mosh snippet (requires `qrencode`) |

`prefix Q` is the fastest way to onboard a phone: scan with the iOS Camera app,
tap the result, paste into Blink Shell. The QR encodes the full
`mosh --server='…' user@host -- yaamux --auto-attach` line — so once scanned,
the iPad/iPhone gets the right UI automatically (zoom on iPhone, grid on iPad,
full grid on a tablet held in landscape with a tiny font).

### One snippet for every device (`--auto-attach`)

`yaamux --auto-attach` reads the client terminal's width and routes to the
right UI — so a single Blink Shell / Prompt 3 snippet works on iPhone, iPad,
and desktop without thinking:

| Terminal width | Routes to | Best for |
|---|---|---|
| `< 100` cols | `--mobile-attach` (1 pane zoomed) | iPhone |
| `100–179` cols | `--mobile-grid` (multi-repo grid, mouse on) | iPad 11" / 13" |
| `≥ 180` cols | regular `tmux attach` (full grid) | desktop / laptop |

Recommended Blink / Prompt 3 snippet body — works from any iOS device:

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- yaamux --auto-attach
```

`yaamux --remote <host>` from a laptop keeps doing bare `tmux attach` → full
desktop experience, so the two paths give you what you'd expect without
mode-juggling.

Override the auto-pick when needed:

```bash
# Force a mode at the call site
mosh ... -- env YAAMUX_ATTACH_MODE=zoom yaamux --auto-attach
ssh -t user@host 'YAAMUX_ATTACH_MODE=grid yaamux --auto-attach'

# Valid: zoom | grid | full | auto (default)
```

If you prefer the picker behavior explicitly, the underlying flags
(`--mobile-attach`, `--mobile-grid`, `tmux attach -t yaamux-<repo>`) all still
work directly.

### iOS-friendly attach (`--mobile-attach`)

A 4-pane tiled grid is unreadable on a phone. `yaamux --mobile-attach` spins up
an ephemeral grouped tmux session with one pane zoomed, so the screen shows a
single agent at a time — switch agents with `Ctrl+Space` + arrow keys, detach
with `Ctrl+Space + D`.

```bash
yaamux --mobile-attach                # auto-pick the only yaamux- session
yaamux --mobile-attach myapp          # attach to yaamux-myapp
yaamux --mobile-attach myapp 2        # ...with pane 2 zoomed (0-based)
yaamux --mobile-attach                # multi-session: prompts with picker
```

Use as the body of a Blink Shell / Prompt 3 snippet for one-tap access:

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- yaamux --mobile-attach
```

yaamux's launch banner prints this exact line — easiest to copy from there.
Set up one snippet per repo with the repo name appended, or one generic snippet
that uses the picker when several sessions are running.

### iPad-friendly multi-repo grid (`--mobile-grid`)

An iPad 11-inch (and larger) has the screen real estate for the full 2×2 agent
grid, so the iPhone "force-zoom one pane" approach loses information.
`yaamux --mobile-grid` builds a single umbrella tmux session with one window
per running `yaamux-<repo>` (linked in via `tmux link-window` — they are the
real agents windows, changes propagate live in both directions), `mouse on`
for tap-to-focus, no forced zoom.

```bash
yaamux --mobile-grid                  # umbrella across every running yaamux- session
```

From Blink / Prompt 3 on iPad (mosh, sleep-safe):

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- yaamux --mobile-grid
```

Navigation inside the umbrella:

| Action | Keys / gesture |
|--------|----------------|
| Next / prev repo | `Ctrl+Space n` / `Ctrl+Space p` |
| Focus an agent (within the current repo) | Tap (mouse on) or `Ctrl+Space` + arrows |
| Zoom focused agent | `Ctrl+Space Z` |
| Repo picker | `Ctrl+Space w` (tmux choose-window) |
| Detach | `Ctrl+Space D` |

The umbrella is named `mobile-grid` (no `yaamux-` prefix — won't show up in
`--list` or the `--mobile-attach` picker) and is rebuilt fresh on every call,
so just re-run `--mobile-grid` after starting new yaamux sessions to pick them
up. Repo labels in the tab list come from a per-window `@yaamux-repo` user
option (so the underlying window name stays `agents` and every other yaamux
helper that targets `${SESSION}:agents` keeps working). Killing the umbrella
leaves the underlying yaamux sessions untouched.

Tradeoffs:
- **Mouse mode** hijacks native iPad text selection inside panes. In Blink,
  hold Option to fall back to native select; Prompt 3 has an equivalent
  modifier in its keyboard preferences.
- **Rebuild on session changes** — `--mobile-grid` snapshots the running
  yaamux sessions at the time it's invoked. Re-run to refresh.

### Per-agent native remote

| Agent | Remote path |
|-------|-------------|
| `claude` | claude.ai/code + Claude iOS app (`--remote-control`) |
| `copilot` | GitHub Mobile app (`--remote`) |
| `codex` | `codex --remote` TUI (needs app-server) |
| `gemini` | mosh/Blink only — no native remote |

---

## Push notifications

```bash
yaamux --setup-notify
```

Configures **ntfy** push delivery and a **Blink Shell deep link** — one tap on
the notification opens Blink, SSHes in, and zooms to the exact pane needing
attention. Optional Slack webhook for parallel desktop alerts.

Push fires for **Claude panes only** (uses Claude's hook system). For other
agents, the tmux activity highlight (orange window tab) flags new output.

Helper scripts (`yaamux-notify.sh`, `yaamux-mobile-attach.sh`) are generated
automatically and self-heal if missing.

---

## VS Code handoff

For UI-heavy work (React / Next.js + FastAPI) with inline diffs and live preview:

```bash
yaamux --vscode 1
```

Stops pane 1's agent (a session runs in one process at a time), opens that
worktree in VS Code. Resume the conversation there via **Claude Code panel →
Session History → Local tab**, or `claude --resume` in the integrated terminal.
History is shared on disk (`~/.claude/projects/`).

Run dev servers in VS Code's own terminals:

```
npm run dev                 # Next.js  → localhost:3000
uvicorn main:app --reload   # FastAPI  → localhost:8000
```

Use `@terminal:<name>` in a prompt so Claude reads dev-server logs directly.

---

## The worktree model

Each agent works in an isolated git worktree:

```
your-repo/                          ← main checkout
your-repo-worktrees/
├── agent-1/   branch: worktree/agent-1
├── agent-2/   branch: worktree/agent-2
└── …          (one per agent)
```

`.env*` files (and anything else in `.worktreeinclude`) from the repo root
are **copied** into every worktree on creation. Edits to one agent's copy
don't leak into others or back into the main repo. Pass `--link-env` (or
set `YAAMUX_LINK_ENV=1`) for the legacy symlink behavior if you want a
single source of truth.

Merge work back with normal git (`git merge worktree/agent-2`) or
`yaamux --pr N` to open a PR via `gh`. `yaamux --clean` skips worktrees with
uncommitted / unpushed changes; `yaamux --clean --force` removes everything.

---

## Auto-accept flags

Each agent type has two flag profiles: **SAFE** (default — agent still
prompts on risky operations) and **YOLO** (full bypass — no human in the
loop). Switch to YOLO with `yaamux --yolo …` or `YAAMUX_YOLO=1`.

| Agent | SAFE (default) | YOLO (with `--yolo`) |
|-------|---------------|----------------------|
| `claude` | _(no flag)_ | `--dangerously-skip-permissions` |
| `gemini` | `--approval-mode auto_edit` | `--yolo` |
| `copilot` | `--allow-tool 'shell(git:*)'` | `--allow-all-tools` |
| `codex` | `--full-auto` (keeps sandbox) | `--dangerously-bypass-approvals-and-sandbox` |

Edit the `*_FLAGS_SAFE` / `*_FLAGS_YOLO` variables near the top of `yaamux`
to taste. **Only use `--yolo` on code you trust** — agents can run any
shell command without asking.

---

## Safety

- `yaamux-guard.sh` blocks destructive shell patterns (`rm -rf /`, `mkfs`,
  `dd of=/dev/…`) — but **only for Claude panes**. Other agents use their own
  permission systems. Blocked attempts log to `.claude/logs/blocked.log`.
- Auto-accept means no human in the loop per action — run agents on code you
  trust, or use the softer flags / a container.

---

## Files yaamux creates

After `yaamux --init`:
```
<repo>/AGENTS.md                ← canonical agent instructions (agents.md spec)
<repo>/CLAUDE.md                ← symlink → AGENTS.md (for Claude Code)
<repo>/.yaamux/config           ← per-project defaults
<repo>/.worktreeinclude         ← which gitignored files to copy into worktrees
<repo>/.gitignore               ← appended with .claude/logs/ and ../<repo>-worktrees/
```

After first `yaamux N [...]` run:
```
<repo>/.claude/
├── settings.json
├── hooks/yaamux-guard.sh
├── hooks/yaamux-notify.sh         ← after --setup-notify
└── logs/agent-*.log, blocked.log
~/.local/bin/yaamux                ← if installed via --install (not via brew)
~/.local/bin/yaamux-mobile-attach.sh ← after --setup-notify
~/.config/yaamux/notify.conf       ← after --setup-notify
~/.ssh/config                      ← yaamux host block appended
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `'<agent>' not found` | Install the CLI, or change the agent type |
| `command not found: yaamux` | `brew install vihang/tap/yaamux`, or `~/.yaamux/yaamux --install` + `~/.local/bin` on PATH |
| `gh CLI not found` (during `--pr`) | `brew install gh && gh auth login` |
| Worktree skipped by `--clean` | It has uncommitted/unpushed work. Commit/push, or use `--clean --force` |
| Claude Remote Control fails | Unset `ANTHROPIC_API_KEY`; run `claude auth login` |
| `Ctrl+Space` does nothing | Disable the macOS input-source shortcut |
| mosh won't connect | Open UDP 60000-61000, or use Tailscale |
| `NoMoshServerArgs` / mosh-server not found | Copy the `mosh --server='…' user@host -- …` line from yaamux's launch banner — it bakes the PATH fix in |
| Session already running | `--attach` to join, or `--kill` then restart |
| A pane died | `yaamux --restart N` |
