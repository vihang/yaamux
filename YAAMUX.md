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
| `--toggle-panel` | Show/hide the Control Panel pane (persists via `.yaamux/state`) |
| `--panel-show` / `--panel-hide` | Explicit show/hide of the Control Panel pane |
| `--goto N` | Focus the Nth agent pane (skips control-panel pane) |
| `--bg <name> "<cmd>"` | Spawn a background panel running `<cmd>` — see "Background panels" |
| `--bg-tail <name> [--from N] [--follow]` | Read a panel's log from byte offset `N`; `--follow` streams until completion |
| `--bg-list [--json]` | List background panels with status, RC, log size |
| `--bg-kill <name>` | Stop a running panel (preserves the log on disk for `--bg-tail`) |
| `--logs` | Jump to the live-logs window |
| `--sync` | Toggle synchronize-panes (keystrokes → all panes) |
| `--yolo` | Modifier: launch agents with full permission bypass |
| `--link-env` | Modifier: symlink `.env*` into worktrees (default: copy) |
| `--setup-notify` | Configure ntfy push + Blink Shell deep links |
| `--ssh-config` | (Re)generate the `~/.ssh/config` host block |
| `--install-service` | macOS LaunchAgent — auto-start this repo's agents on login |
| `--remote <host> [args]` | Drive a remote host's yaamux sessions — see below |
| `--remote-hosts` | List host aliases from `~/.config/yaamux/hosts.conf` |
| `--auto-attach` | Attach with UI auto-picked by terminal width (iPhone / iPad / desktop) |
| `--mobile-attach [repo] [pane]` | Attach with one pane zoomed (iPhone-friendly) |
| `--mobile-grid` | Build the iPad umbrella session across every yaamux- session |
| `--connect [--qr]` | Print exact connect commands (+ optional QR encoding `mosh://user@host` for one-tap open in Blink / Prompt / Termius) |
| `--prepare-host [--check]` | One-time: symlink `mosh-server` into `/usr/local/bin` so iOS clients opening the QR'd `mosh://` URL find it (macOS Homebrew hosts only — `--check` is read-only) |
| `--keys` | Print the in-tmux key & CLI cheat sheet (also opens in-session via `Ctrl+Space + ?`) |
| `--help` / `--version` | Inline help / version + install source |

The `--yolo` and `--link-env` modifiers combine with positional args
(e.g., `yaamux --yolo 4 claude` or `yaamux 2 --link-env`). Equivalent
env vars: `YAAMUX_YOLO=1`, `YAAMUX_LINK_ENV=1`.

### `--list --json` schema (integration contract)

`yaamux --list --json` emits an array of objects, one per yaamux-* tmux
session running on this machine. **This schema is stable across the v0.x
series — additive only; existing keys will not be removed or renamed
without a major version bump.** Integrations can depend on it.

```json
[
  {
    "session": "yaamux-myapp",
    "agents":  4,
    "attached": true,
    "repo":    "/Users/vihang/Code/myapp"
  }
]
```

| Key | Type | Notes |
|-----|------|-------|
| `session` | string | Full tmux session name (`yaamux-<project>`); use as `-t <session>` target |
| `agents`  | int    | Count of `@yaamux-role=agent` panes in the `agents` window. Excludes the Control Panel pane. Falls back to total pane count for pre-v0.2 sessions that lack the role tag. |
| `attached` | bool  | `true` iff at least one tmux client is currently attached to this session |
| `repo`     | string | Absolute path to the repo root, read from the session's `@yaamux-repo` user-option |

Empty result is the literal string `[]`. Exit code is `0` in both cases —
"no sessions" is not an error.

Example consumer (pick the first attached session and zoom pane 1):

```bash
sess=$(yaamux --list --json | jq -r '.[] | select(.attached) | .session' | head -1)
[[ -n "$sess" ]] && yaamux --zoom 1
```

Per-pane state inside a session is not yet part of `--list --json`; see
`yaamux --status` for the human-readable form (a structured `--status --json`
is on the roadmap).

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
| `Ctrl+Space` + `Space` | Zoom / unzoom current pane (ergonomic alias for `Z`) |
| `Ctrl+Space` + `Z` | Zoom / unzoom current pane |
| `Ctrl+Space` + `W` | Window list (agents / remote-srv / logs) |
| `Ctrl+Space` + `[` | Enter scroll mode (`q` to exit, `/` to search) |
| &nbsp;&nbsp;↳ `y` or `Enter` | (in scroll mode) Copy selection → system clipboard |
| `Ctrl+Space` + `S` | Toggle sync mode |
| `Ctrl+Space` + `r` | Restart the agent in the current pane |
| `Ctrl+Space` + `R` | Restart every dead / idle agent (confirms) |
| `Ctrl+Space` + `L` | Clear screen + scrollback (fixes a garbled pane) |
| `Ctrl+Space` + `p` | Toggle Control Panel pane (show/hide; persists) |
| `Ctrl+Space` + `1`-`9` | Jump to agent pane N (skips control-panel) |
| `Ctrl+Space` + `d` | Detach (agents keep running) — tmux default |
| `Ctrl+Space` + `C` | Connect-commands popup (mosh / ssh / `--remote` lines) |
| `Ctrl+Space` + `Q` | QR popup encoding `mosh://user@host` — scan with iOS Camera, opens in Blink / Prompt / Termius |
| `Ctrl+Space` + `?` | Cheat sheet (popup — `q` to close) |
| `Ctrl+Space` + `/` | List all tmux key bindings |
| Mouse click | Focus a pane |

Run `yaamux --keys` from any shell for the same cheat sheet (no tmux needed).

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
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
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
yaamux --connect --qr         # …plus an ANSI QR encoding mosh://user@host — iOS Camera opens it
                              #   in Blink / Prompt 3 / Termius with one tap (qrencode bundled by brew formula)
```

Inside any running yaamux session, two prefix keybindings open a popup with the
same output — no need to drop to a shell:

| Key | Shows |
|-----|-------|
| `Ctrl+Space C` | Connect commands (mosh, ssh, `--remote`) |
| `Ctrl+Space Q` | QR encoding `mosh://user@host` — scan with iOS Camera, opens in Blink / Prompt / Termius |

`prefix Q` is the fastest way to onboard a phone: scan with the iOS Camera app,
tap the result, and Blink Shell (or Prompt 3 / Termius) opens with the mosh
connection ready. Once you're at the remote shell, run `yaamux --auto-attach`
to get the right UI for your device (zoom on iPhone, grid on iPad, full grid
on a tablet held in landscape with a tiny font).

The QR encodes `mosh://user@host` rather than the full shell snippet. iOS Vision
recognizes URL schemes over email-address patterns, so the scan offers a one-tap
"Open in <terminal>" action instead of misreading `user@host.tld` as an email
and offering Mail.app. The trade-off: a URL scheme can't carry the
`--server='export PATH=…; exec mosh-server'` PATH fix that the full snippet does.
If the QR scan hits `NoMoshServerArgs` (typical on macOS Homebrew hosts where
`mosh-server` sits in `/opt/homebrew/bin`, off SSH's default PATH), run the
one-shot fix on the host:

```bash
yaamux --prepare-host           # symlinks mosh-server into /usr/local/bin (sudo)
yaamux --prepare-host --check   # read-only — reports whether the fix is needed
```

Equivalent manual command if you'd rather not run yaamux for it:
`sudo ln -s "$(command -v mosh-server)" /usr/local/bin/mosh-server`.

yaamux also detects the broken PATH at startup and prints the same hint, and
`--connect`/`Ctrl+Space C` warns before showing the QR so you fix it once
before scanning.

**Cross-device handoff from iPad/phone**: the popup bindings also work *inside*
the iPad's mobile-grid and the iPhone's mob-`$$` sessions (those sessions set
the `Ctrl+Space` prefix to match the yaamux defaults). So you can already be
attached from your iPad, hit `Ctrl+Space Q`, and your phone scans the same QR
to attach itself — or `Ctrl+Space C` to copy the line and AirDrop it.

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
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
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
with `Ctrl+Space + d`.

```bash
yaamux --mobile-attach                # auto-pick the only yaamux- session
yaamux --mobile-attach myapp          # attach to yaamux-myapp
yaamux --mobile-attach myapp 2        # ...with pane 2 zoomed (0-based)
yaamux --mobile-attach                # multi-session: prompts with picker
```

Use as the body of a Blink Shell / Prompt 3 snippet for one-tap access:

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
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
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- yaamux --mobile-grid
```

Navigation inside the umbrella:

| Action | Keys / gesture |
|--------|----------------|
| Next / prev repo | `Ctrl+Space n` / `Ctrl+Space p` |
| Focus an agent (within the current repo) | Tap (mouse on) or `Ctrl+Space` + arrows |
| Zoom focused agent | `Ctrl+Space Z` |
| Repo picker | `Ctrl+Space w` (tmux choose-window) |
| Detach | `Ctrl+Space d` |

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

Helper scripts (`yaamux-notify.sh`, `yaamux-mobile-attach.sh`,
`yaamux-cpanel.sh`) are generated automatically and self-heal if missing.

Every notification is also appended to
`${XDG_CACHE_HOME:-~/.cache}/yaamux/notifications.log` as JSON-Lines (last
500 kept) — the Control Panel TUI tails this file for its feed, and the
bottom status-line indicator badges the pane that's awaiting attention.

---

## Control Panel

By default yaamux mounts a **Control Panel pane** alongside the agents — a
TUI dashboard showing every local yaamux session, the current session's
per-pane state, a feed of recent notifications, and a one-key command
menu. Toggle it with `Ctrl+Space + p` (the visible/hidden choice is
remembered in `.yaamux/state`).

Layout adapts to the number of agents:

| `N` agents | Mode | Why |
|------------|------|-----|
| Odd (1, 3, 5, …) | **tile** — panel is one more pane in the tiled grid | Total panes is even, tiles cleanly |
| Even (2, 4, 6, …) | **sidebar** — panel is a right column at 30% width | Agent grid stays balanced |

Force a mode by setting `CONTROL_PANEL_MODE=tile`, `sidebar`, or `auto`
in `.yaamux/state` (per-repo) or `~/.config/yaamux/control-panel.conf`
(global default — per-repo wins). On narrow terminals (cols below
`YAAMUX_CPANEL_MIN_COLS`, default 120) sidebar mode auto-falls back to
tile.

**Inside the Control Panel pane:**

| Key | Action |
|-----|--------|
| `Tab` | Cycle section focus: panes → sessions → notifications |
| `j` / `k` / arrows | Move selection in the focused section |
| `Enter` | Default action — switch-client to selected session, focus selected pane |
| `1`-`9` | Jump to agent pane N |
| `r` | Restart the selected pane (`--restart N`) |
| `R` | Restart all dead/idle (`--restart-dead -y`) |
| `z` | Toggle zoom on the selected pane |
| `s` | Toggle synchronize-panes for the agents window |
| `h` / `q` | Hide the panel (`--panel-hide`) |
| `?` | Show / hide in-panel help |

**Permanent bottom indicator.** Whether the panel is visible or not, the
tmux status-right shows one chip per agent pane — `[1✓]` running, `[2⚠]`
idle, `[3✗]` dead, `[4!]` notification pending (magenta). `Ctrl+Space + N`
jumps straight to agent pane `N`, so an unread notification is one chord
away. Focusing a pane clears its `!` badge.

---

## Background panels

Long-running shell commands (dev servers, test watchers, builds, log tails)
belong somewhere they won't block an agent and won't get scrolled off-screen.
**Background panels** are non-agent tmux panes in a dedicated `bg` window
whose output is captured to disk, so any agent — or the user, hours later —
can resume reading from a byte offset.

```bash
# From anywhere inside the repo (including an agent's own pane):
yaamux --bg watch "pnpm test --watch"
yaamux --bg build "make ci"

# Tail from the start, then learn the next offset:
yaamux --bg-tail watch
# ...output...
# OFFSET=4096
# STATUS=running

# Resume from where you left off:
yaamux --bg-tail watch --from 4096

# Block until it finishes:
yaamux --bg-tail build --follow
# ...streamed output...
# OFFSET=12345
# STATUS=done
# RC=0

yaamux --bg-list
# NAME    STATUS  RC  PANE   STARTED               CMD
# watch   running -   %23    2026-05-19T14:23:01Z  pnpm test --watch
# build   done    0   %24    2026-05-19T14:00:00Z  make ci

yaamux --bg-kill watch
```

**How completion is detected.** Each panel runs the user's command wrapped
in a one-liner that emits a unique-per-panel sentinel
`[[YAAMUX:PANEL:<token>:DONE:RC=<n>]]` on the controlling tty after the
command returns. `tmux pipe-pane` captures the sentinel into the log, and
`--bg-tail` / `--bg-list` grep for it. The token (12 random characters,
stored in the panel's `.meta` file) is per-panel so even commands whose
output happens to contain a literal `[[YAAMUX:PANEL:` won't false-positive.

**Storage.** Per-repo, gitignored:

```
<repo>/.yaamux/panels/<name>.log    raw output, append-only
<repo>/.yaamux/panels/<name>.meta   TOKEN, PANE_ID, CMD, STARTED
```

`--kill` preserves these files (so `--bg-tail` still works on the next
session start); `--clean` removes them alongside the worktrees.

**Status values:** `running`, `done` (exit 0), `failed` (non-zero), `killed`
(SIGINT, rc=130), `unknown`.

**Use from within an agent pane.** Agents inside the main `agents` window
can call any of these flags from their own shell — that's the whole point.
A common pattern: agent A starts a dev server with `--bg`, agent B
periodically `--bg-tail`s it to look for errors and reacts.

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
<repo>/.yaamux/state            ← Control Panel visibility/mode (mutable; gitignored)
<repo>/.yaamux/panels/          ← Background panel logs + meta (mutable; gitignored)
<repo>/.worktreeinclude         ← which gitignored files to copy into worktrees
<repo>/.gitignore               ← appended with .claude/logs/, ../<repo>-worktrees/, .yaamux/state, .yaamux/panels/
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
~/.local/bin/yaamux-cpanel.sh      ← Control Panel TUI
~/.config/yaamux/notify.conf       ← after --setup-notify
~/.config/yaamux/control-panel.conf ← optional global panel defaults (per-repo wins)
~/.cache/yaamux/notifications.log  ← JSON-Lines feed (last 500 kept)
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
| `NoMoshServerArgs` / mosh-server not found (iOS QR scan / bare `mosh user@host`) | Run `yaamux --prepare-host` on the host once (sudo — symlinks mosh-server into `/usr/local/bin`). The full `mosh --server='…' user@host -- …` line still works as a per-call workaround |
| Session already running | `--attach` to join, or `--kill` then restart |
| A pane died | `yaamux --restart N` |
