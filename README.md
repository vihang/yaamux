<div align="center">

```
   ██╗   ██╗███╗   ███╗██╗  ██╗
   ╚██╗ ██╔╝████╗ ████║╚██╗██╔╝
    ╚████╔╝ ██╔████╔██║ ╚███╔╝
     ╚██╔╝  ██║╚██╔╝██║ ██╔██╗
      ██║   ██║ ╚═╝ ██║██╔╝ ██╗
      ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝
   yaamux · parallel AI agents · one tmux grid · drive from anywhere
```

**Spawn N AI agents in parallel — for any task you'd give to an AI. Drive them from your laptop, phone, or iPad.**

One bash file · one tmux session per repo · zero ceremony.

[![CI](https://github.com/vihang/yaamux/actions/workflows/ci.yml/badge.svg)](https://github.com/vihang/yaamux/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](#license)
[![Single file](https://img.shields.io/badge/single--file-bash-89e051.svg)](./yaamux)
[![Version](https://img.shields.io/badge/version-v0.4.0-7c3aed.svg)](./VERSION)

🤖 Claude Code · ✦ Gemini CLI · 🐙 GitHub Copilot CLI · ⬡ Codex CLI · ◉ opencode

</div>

---

## ✨ What's new

<table>
<tr>
<td width="50%" valign="top">

### 💬 **Pilot mode** &nbsp;<sub>v0.4</sub>
Talk to one agent. It drives the rest. No new API key — uses whatever agent CLI you already have.

`Ctrl+Space + P` &nbsp;·&nbsp; `ymx --pilot-toggle`

</td>
<td width="50%" valign="top">

### 🎛 **Control Panel** &nbsp;<sub>v0.3</sub>
Live dashboard pane: every yaamux session, every pane's health, notifications, hotkey menu.

`Ctrl+Space + p` &nbsp;·&nbsp; `ymx --toggle-panel`

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🛠 **`git` window** &nbsp;<sub>v0.3.1</sub>
lazygit + delta + bat in a dedicated window. Plus `--watch-pr`, `--auto-merge`, `--ci-status`, `--diff` — backed by `gh` / `glab` / `tea`.

`Ctrl+Space + G`

</td>
<td width="50%" valign="top">

### 🪟 **Background panels** &nbsp;<sub>v0.3</sub>
Run a build / test-watcher / dev server without blocking. Output captured to disk — resume from a byte offset hours later.

`ymx --bg <name> "<cmd>"`

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🧭 **Agents know where they are** &nbsp;<sub>v0.3.1</sub>
Per-pane `YAAMUX_*` env vars + a Claude Code skill auto-installed by `--init`. Agents discover their tools without being told.

`ymx --agent-brief`

</td>
<td width="50%" valign="top">

### 🧱 **Pluggable forge** &nbsp;<sub>v0.3.1</sub>
PR / CI flags auto-detect your git host. Works on **GitHub** (full), **GitLab** (create + merge), **Gitea** (create). Override with `YAAMUX_FORGE`.

`ymx --pr N` &nbsp;·&nbsp; `--ci-status` &nbsp;·&nbsp; `--diff N`

</td>
</tr>
</table>

---

## 🎯 The problem

You want to:

- 🧠 Run **4 agents working different angles** of the same task — draft four versions of a proposal, explore four hypotheses against the same dataset, or refactor a module four different ways. Keep the winner.
- 🛋️ Check in from your **couch, phone, or kitchen**, not just the desk you started at.
- 🔔 Get a **push notification** the moment an agent needs your input.
- 👆 Tap that notification and land in **the exact pane that needs you**.

Today that's a stack: a workspace tool, a tmux config, a worktree script, an SSH wrapper, a mobile client setup, a push rig.

**yaamux is the single bash file that wires all of it together.**

---

## 🚀 30-second install

```bash
brew tap vihang/tap && brew install yaamux
```

Installs both `yaamux` and the 3-char alias `ymx` — same script, same flags. The rest of this README uses `ymx` for brevity.

> Not on Homebrew? `git clone https://github.com/vihang/yaamux ~/.yaamux && ~/.yaamux/yaamux --install`

## ⚡ 30-second first run

```bash
cd ~/your/repo
ymx --init                 # scaffolds AGENTS.md + skill + .yaamux/config + .worktreeinclude
ymx 4                      # 4 Claude agents · 4 worktrees · 1 tiled tmux grid
```

You land in a session that looks like this:

```
┌─────────────────────────┬─────────────────────────┐
│ 🤖 agent-1  claude      │ 🤖 agent-2  claude      │
│ > drafting Section 3…   │ > reconciling Q4 data…  │
│                         │                         │
├─────────────────────────┼─────────────────────────┤
│ 🤖 agent-3  claude      │ 🎛  control-panel       │
│ > refactoring auth…     │ ✓ run    [1] agent-1    │
│                         │ ✓ run    [2] agent-2    │
│                         │ ✓ run    [3] agent-3    │
│                         │ menu · r R z s c 1-9 q  │
└─────────────────────────┴─────────────────────────┘
              session: yaamux-yourrepo
```

`Ctrl+Space + d` to detach — agents keep running. Reattach later with `ymx --attach`. List every yaamux session across every repo on this box with `ymx --list`.

---

## 💬 Pilot mode — drive the agent grid by chat

Press `Ctrl+Space + P`. The Control Panel pane flips into a chat with an installed agent CLI (`claude` today; opencode/gemini/codex/copilot accepted explicitly). It reads your natural language and drives the other panes via the existing `--send` / `--send-stdin` / `--broadcast` / `--restart` flags.

```
┌─────────────────────────┬─────────────────────────┐
│ 🤖 agent-1  claude      │ 🤖 agent-2  claude      │
│ > implementing auth…    │ > writing unit tests…   │
│                         │                         │
├─────────────────────────┼─────────────────────────┤
│ 🤖 agent-3  claude      │ 💬 pilot · claude       │
│ > drafting docs…        │ you: "ask 2 to test    │
│                         │       the auth flow"    │
│                         │ pilot: yaamux --send 2  │
│                         │   "test the auth flow"  │
│                         │ ✓ sent                  │
└─────────────────────────┴─────────────────────────┘
```

- 🔑 **No API key.** The agent CLI's own auth handles billing and tokens.
- 🛡️ **Destructive ops popup-confirm.** `--broadcast`, `--restart`, `--kill`, `--clean` from the pilot pop a `tmux display-popup` y/N before running. `--yes` bypasses for scripted batches.
- 🧠 **`--send-stdin N`** is the safe form for forwarding user text — preserves `"`, `$`, backticks, newlines.

```bash
ymx --pilot-toggle               # flip Control Panel: dashboard ↔ pilot
ymx --pilot-show codex           # explicit backend (no orchestrator framing yet)
ymx --pilot-backend opencode     # pin a default (persists per repo)
ymx --pilot-supported            # list installed backends
```

---

## 🎛 Control Panel pane

The right-hand pane in your session. Live status, no extra window.

| Section          | What it shows                                                       |
|------------------|---------------------------------------------------------------------|
| **Sessions**     | Every running `yaamux-*` session on this machine                    |
| **Panes**        | Per-agent state: `✓ run` `⚠ idle` `✗ dead` `! notif`                |
| **Notifications**| Last 10 push events with timestamp + agent name                     |
| **Menu**         | One-key actions: restart, zoom, sync, jump, pilot, hide             |

**Layout adapts automatically.** Odd-N agents → panel tiles as one more pane. Even-N agents → panel becomes a right-column sidebar. Narrow terminals fall back to tile mode. Override with `CONTROL_PANEL_MODE=tile|sidebar|auto`.

```bash
ymx --toggle-panel               # show / hide (persists in .yaamux/state)
ymx --panel-show / --panel-hide  # explicit
```

**Permanent status-line indicator.** Every pane shows up as a chip in tmux's status-right whether the panel is visible or not — `[1✓] [2⚠] [3✗] [4!]`. `Ctrl+Space + N` jumps to agent N; focusing a pane clears its `!` badge.

---

## 🛠 `git` window — lazygit + PR/CI flags

`Ctrl+Space + G` opens a dedicated tmux window running **lazygit** in your repo root. Branches, worktrees, staging, diffs, file viewing — closest in-terminal analogue to the Claude Code sidebar.

```
┌── tmux window: git ────────────────────────────────────┐
│ ┌─ Status ─────┐ ┌─ Files ───────────────┐             │
│ │ ● main       │ │  M src/auth.ts        │             │
│ │   worktrees… │ │ ?? notes.md           │             │
│ └──────────────┘ └───────────────────────┘             │
│ ┌─ Local branches ──┐ ┌─ Diff ───────────┐             │
│ │ * main             │ │ delta-highlighted │             │
│ │   worktree/agent-1 │ │ syntax-aware …   │             │
│ │   worktree/agent-2 │ │                  │             │
│ └────────────────────┘ └──────────────────┘             │
└────────────────────────────────────────────────────────┘
```

Plus CLI flags for the loops you'd otherwise script around `gh`:

```bash
ymx --pr 2 "title"           # push + open PR (gh / glab / tea — auto-detected)
ymx --pr 2 "title" --merge   # …and enable auto-merge after CI passes
ymx --watch-pr 2             # block until CI completes (pass / fail)
ymx --auto-merge 2           # enable auto-merge on an existing PR
ymx --ci-status              # table of CI status across every pane's PR
ymx --ci-status 2            # one pane's CI status
ymx --diff 2                 # diff agent 2's branch vs origin/main (delta)
```

Diffs from any shell inside the session are auto-piped through `delta`; pagers use `bat`. No global gitconfig changes.

**Pluggable forge.** All flags route through a `forge_*` dispatch family — auto-detected from `git remote get-url origin`, or set `YAAMUX_FORGE=github|gitlab|gitea`. GitHub is fully wired; GitLab supports create + merge; Gitea supports create.

---

## 🪟 Background panels — long-running shell jobs

Don't block an agent on a watcher. Spawn a captured pane in the `bg` window:

```bash
ymx --bg watch  "pnpm test --watch"
ymx --bg build  "make ci"
ymx --bg server "pnpm dev"
```

Tail from anywhere — even from inside another agent's shell:

```bash
ymx --bg-tail watch                  # read so-far; learns OFFSET=12345
ymx --bg-tail watch --from 12345     # resume from where you left off
ymx --bg-tail build --follow         # block until done — prints STATUS=done RC=0
ymx --bg-list                        # NAME STATUS RC PANE STARTED CMD
ymx --bg-kill watch                  # SIGINT, then SIGKILL; log preserved
```

Status flows: `running` → `done` (rc=0) · `failed` (rc≠0) · `killed` (rc=130). Detection is via a per-panel sentinel — no race even on commands that exit faster than the captured shell can attach.

---

## 🧭 Agents know where they are

Every agent pane is spawned with situational env vars baked in. **No more agents asking "what tools do I have?"** — they can read it from their own shell:

```bash
$ echo "I am agent ${YAAMUX_AGENT_NUMBER} of ${YAAMUX_AGENT_TOTAL}, type ${YAAMUX_AGENT_TYPE}"
I am agent 2 of 4, type claude

$ yaamux --agent-brief --format text
yaamux agent brief (v0.4.0)

Situational context:
  agent:    agent-2 (2/4)
  type:     claude
  session:  yaamux-myapp
  mode:     safe
  pilot:    (none)

Commands you can use:
  read / inspect:
    yaamux --list          list yaamux sessions on this machine
    yaamux --status        per-pane health snapshot
    …
  coordinate with siblings:
    yaamux --send N "..."  send a prompt to sibling agent N
    yaamux --send-stdin N  send STDIN literally (safe for "$ ` \n)
    yaamux --exec N "..."  synchronous run-and-wait
    …
```

**The brief is drift-guarded.** A bats test fails CI if a new yaamux flag ships without a corresponding entry — agents can't go out of date with the script.

**Claude Code skill.** `ymx --init` symlinks `skills/yaamux/SKILL.md` into your repo's `.claude/skills/yaamux/`. Claude Code's skill loader picks it up automatically — agents get the orchestrator recipe without anyone telling them to read anything.

**Safe mode.** `YAAMUX_AGENT_MODE=safe` is set in every agent pane. Destructive flags (`--kill`, `--clean`, `--install`, `--uninstall`, `--install-service`) refuse to run from an agent shell with a clear message pointing the agent at the operator. Pilot mode runs as `YAAMUX_AGENT_MODE=pilot` instead (so it can drive destructive ops, popup-confirmed).

---

## 🧬 Why git-first?

yaamux uses `git worktree` under the hood — not because your work is code, but because git solves the hardest part of running N agents at once: **structure**.

- **Each agent gets its own clean workspace.** A worktree is just an isolated directory tied to a branch. No file clobbering. No "wait, which agent edited this?".
- **Full history of every draft.** Whether the file is prose, a spreadsheet, a config, or code, git tracks every revision. Roll back, diff against another agent's version, or cherry-pick the best paragraph from pane 2 into pane 4.
- **Merge or discard, your call.** Pick the winning result and `git merge` it back. Throw the rest away with `ymx --clean`. Or keep all four branches as parallel drafts.

*If your work lives in files, git can version it — and yaamux can fan it out across N agents.*

---

## ⚡ Drive them from anywhere

**One install, four ways to attach:**

```
                              ┌── 💻 laptop  ── ymx --remote work
                              │
                              ├── 📱 iPhone  ── scan QR → Blink Shell → one pane zoomed
   ☁️  your machine  ─────────┤
                              ├── 📲 iPad    ── grid across all your running repos
                              │
                              └── 🔔 push    ── ntfy notif → tap → SSH'd into the right pane
```

**No setup beyond SSH + (optionally) mosh.** No agents to run. No web dashboard. The transport is just SSH; the magic is the bash that wraps it.

### 💻 From a laptop — `ymx --remote`

```bash
ymx --remote work                       # pick a session interactively, attach
ymx --remote work myapp                 # attach directly to yaamux-myapp
ymx --remote work --list                # show what's running (table)
ymx --remote work --status              # windows / panes — no attach
ymx --remote work --zoom 2              # attach with pane 2 zoomed
ymx --remote work --mosh                # sleep-safe + LTE↔WiFi handoff
```

`work` is a one-word alias you save in `~/.config/yaamux/hosts.conf`:

```conf
# yaamux remote host aliases
work    vihang@work.tail-scale.net
phone   user@my-phone-ssh-host
```

The remote box only needs `tmux` (and `mosh-server` if you pass `--mosh`) — **yaamux itself is not required on the remote.**

### 📱 From a phone — the QR trick

Inside any running yaamux session, hit `Ctrl+Space + Q`:

```
   ██████ ▄▄ █ ▄ █  ▄▄ ██████
   █ ▀▀ █ ▀█▄▀▀▄▄▀ █▄▀ █ ▀▀ █
   █ ██ █ █▀█▄ ▄▀▄▀ ▀▀ █ ██ █
   ▀▀▀▀▀▀ █ █ █ █ █ █ █ ▀▀▀▀▀▀
              (full QR)
```

Open the iOS Camera, scan, **tap** — Blink Shell (or Prompt 3 / Termius) opens with the mosh connection ready. Run `yaamux --auto-attach` and the phone gets the right UI automatically. The QR encodes `mosh://user@host` so iOS routes the scan as a URL (one-tap "Open in Blink") instead of misreading it as an email address.

### 🤖 Auto-route by terminal width — `--auto-attach`

| Terminal width | UI                                   | Best for     |
|----------------|--------------------------------------|--------------|
| `< 100` cols   | **one pane zoomed**                  | iPhone       |
| `100–179` cols | **grid across all running repos**    | iPad 11"/13" |
| `≥ 180` cols   | **full tmux attach**                 | desktop      |

Override with `YAAMUX_ATTACH_MODE=zoom|grid|full|auto`.

### 📲 iPad grid — `--mobile-grid`

Builds an umbrella tmux session with one window per running `yaamux-<repo>` (real linked windows — changes propagate live). Tap-to-focus enabled.

```
┌─ tab: app-A ─┬─ tab: app-B ─┬─ tab: docs ─┬─ tab: infra ─┐
│ ┌────┬────┐  │  ┌────┬────┐ │ ┌────┬────┐ │ ┌────┬────┐  │
│ │ ag │ ag │  │  │ ag │ ag │ │ │ ag │ ag │ │ │ ag │ ag │  │
│ ├────┼────┤  │  ├────┼────┤ │ ├────┼────┤ │ ├────┼────┤  │
│ │ ag │ ag │  │  │ ag │ ag │ │ │ ag │ ag │ │ │ ag │ ag │  │
│ └────┴────┘  │  └────┴────┘ │ └────┴────┘ │ └────┴────┘  │
└──────────────┴──────────────┴─────────────┴──────────────┘
```

### 🔔 Push notifications — `ymx --setup-notify`

Wires up **ntfy** push delivery and a **Blink Shell deep link**. When an agent needs your input, the notification fires; **tapping it opens Blink, mosh'es in, and zooms to the exact pane.**

> Push fires for Claude panes today. Other agents flash the tmux activity highlight; cross-agent push is on the roadmap.

---

## 🎛 Pick your agents

Positional form: `ymx [N] [type ...]`. Types: `claude` · `gemini` · `copilot` · `codex` · `opencode`. Max 20.

```bash
ymx                              # 4 Claude (default)
ymx 6                            # 6 Claude
ymx 4 claude                     # 4 agents — e.g. four drafts of a memo
ymx claude gemini codex          # 3 panes — one of each
ymx 8 claude gemini              # 8 panes — cycled: c,g,c,g,c,g,c,g
ymx 1 codex                      # single Codex agent
ymx --yolo 4 claude              # full permission bypass (trust the task!)
```

---

## 🥷 Pro moves

### Publish a finished result

When pane 2 is done, its output is already a real git branch in a real folder — share it however you'd share any file: copy it out, push the branch, open the folder, attach the doc to an email.

```bash
cd ../yourrepo-worktrees/agent-2 && git push origin HEAD   # plain git
ymx --pr 2                                                 # forge-aware: push + open PR
ymx --pr 2 "Fix #123 race" --merge                         # …and auto-merge once checks pass
ymx --watch-pr 2                                           # block until CI completes
```

### Headless: send-prompt-and-collect-output

```bash
ymx --exec 1 "summarize today's 40 customer emails" 300
ymx --exec 1 "summarize TODO comments in src/" 300
```

Injects the prompt into pane 1, polls until idle (300 s timeout), prints the result. Great for orchestration scripts.

### Broadcast & sync

```bash
ymx --broadcast "reread the brief and tighten the intro"   # same prompt → every pane
ymx --sync                                                  # toggle keystroke sync
```

### Hand a pane to your editor

```bash
ymx --vscode 1                   # stops pane 1's agent, opens its worktree in VS Code
```

Resume the conversation via **Claude Code panel → Session History** or `claude --resume`. History is shared on disk under `~/.claude/projects/`.

### Bring your context into the worktrees

Anything in `.worktreeinclude` is **copied** into every worktree on creation — `.env*` files, a reference dataset, a style guide, a draft outline, a system prompt. Edits stay isolated per pane. Single source of truth instead?

```bash
ymx --link-env 4 claude          # symlink .env* instead of copy
```

### Heal a dead pane

```bash
ymx --restart 2                  # restart pane 2
ymx --restart-dead -y            # restart every dead/idle pane (no prompt)
```

### See what's alive everywhere

```bash
ymx --list                       # table — all yaamux sessions across all repos
ymx --list --json                # …same, JSON for scripting
ymx --status                     # health of this repo's session
```

---

## ⌨️ Keys (prefix = `Ctrl+Space`)

| Keys                    | Action                                                  |
|-------------------------|---------------------------------------------------------|
| `Ctrl+Space` + arrows   | Move between panes                                      |
| `Ctrl+Space` + `Space`  | Zoom / unzoom current pane (ergonomic alias)            |
| `Ctrl+Space` + `Z`      | Zoom / unzoom current pane                              |
| `Ctrl+Space` + `W`      | Window list (agents · git · remote-srv · logs)          |
| `Ctrl+Space` + `[`      | Scroll mode (`q` exits, `/` searches, `y`/Enter copies) |
| `Ctrl+Space` + `S`      | Toggle keystroke sync across panes                      |
| `Ctrl+Space` + `r`      | Restart agent in current pane                           |
| `Ctrl+Space` + `R`      | Restart all dead/idle agents (confirms)                 |
| `Ctrl+Space` + `L`      | Clear screen + scrollback                               |
| `Ctrl+Space` + `d`      | Detach (agents keep running) — tmux default             |
| `Ctrl+Space` + `1`-`9`  | Jump to agent pane N (skips control-panel)              |
| `Ctrl+Space` + `p`      | **Toggle Control Panel pane** (show/hide)               |
| `Ctrl+Space` + `P`      | **Pilot chat** — flip the Control Panel pane            |
| `Ctrl+Space` + `G`      | **`git` window** — lazygit · branches · staging · PRs   |
| `Ctrl+Space` + `C`      | **Connect popup** (mosh / ssh / `--remote` lines)       |
| `Ctrl+Space` + `Q`      | **QR popup** — scan with iOS Camera                     |
| `Ctrl+Space` + `?`      | Cheat sheet (popup)                                     |
| `Ctrl+Space` + `/`      | List every tmux binding                                 |
| Mouse click             | Focus a pane                                            |

Run `ymx --keys` from any shell for the same cheat sheet — no tmux needed.

> **macOS:** `Ctrl+Space` may be your input-source switcher. Disable under *System Settings → Keyboard → Keyboard Shortcuts → Input Sources.*

---

## 📖 Command reference

<details><summary><b>Click for the full table</b></summary>

| Command                                             | What it does                                                         |
|-----------------------------------------------------|----------------------------------------------------------------------|
| `ymx [N] [types...]`                                | Start (or attach if the repo's session exists)                       |
| `ymx --init [--with-docs] [--copy-skill]`           | Scaffold `AGENTS.md` + skill symlink + `.yaamux/config` + `.worktreeinclude` |
| `ymx --list [--json]`                               | List yaamux sessions across all repos                                |
| `ymx --attach` / `--kill` / `--clean` [`--force`]   | Session lifecycle                                                    |
| `ymx --status`                                      | Health check for the current repo                                    |
| `ymx --layout main\|tiled\|even`                    | Override the auto-picked pane layout                                 |
| `ymx --zoom N` / `--vscode N`                       | Focus pane N / hand it to VS Code                                    |
| `ymx --send N "x"` / `--broadcast "x"`              | Inject a prompt into one pane / every pane                           |
| `ymx --send-stdin N`                                | Send STDIN literally to pane N (pilot's preferred form)              |
| `ymx --exec N "x" [timeout]`                        | Headless: send, wait for idle, return output (default 5 min)         |
| **Pilot**                                           |                                                                      |
| `ymx --pilot-toggle`                                | Flip Control Panel pane between dashboard and pilot chat             |
| `ymx --pilot-show [BACKEND]` / `--pilot-hide`       | Explicit enter/leave (claude / opencode / gemini / codex / copilot)  |
| `ymx --pilot-backend BACKEND` / `--pilot-supported` | Persist default backend / list installed backends                    |
| **Panel**                                           |                                                                      |
| `ymx --toggle-panel` / `--panel-show` / `--panel-hide` | Control Panel pane visibility                                      |
| **Forge / PR / CI**                                 |                                                                      |
| `ymx --pr N [title] [--merge]`                      | Push pane N's branch + open PR (`gh` / `glab` / `tea`)               |
| `ymx --watch-pr N` / `--auto-merge N`               | Watch CI / enable auto-merge on pane N's PR                          |
| `ymx --ci-status [N]` / `--diff N`                  | CI status / branch diff vs `origin/main`                             |
| **Background panels**                               |                                                                      |
| `ymx --bg <name> "<cmd>"`                           | Spawn a captured background panel                                    |
| `ymx --bg-tail <name> [--from N] [--follow]`        | Read panel output (resumes from byte offset)                         |
| `ymx --bg-list [--json]` / `--bg-kill <name>`       | List / stop                                                          |
| **Heal / restart**                                  |                                                                      |
| `ymx --restart N` / `--restart-dead [-y]`           | Heal panes                                                           |
| `ymx --logs` / `--sync`                             | Live-log window / toggle keystroke sync                              |
| **Discoverability**                                 |                                                                      |
| `ymx --agent-brief [--format text\|json\|markdown]` | Curated CLI surface + situational context for agents                 |
| **Modifiers**                                       |                                                                      |
| `ymx --yolo …` / `--link-env …` / `--yes …`         | Bypass-prompt / symlink-env / bypass-pilot-popup                     |
| **Notifications + service**                         |                                                                      |
| `ymx --setup-notify`                                | ntfy push + Blink deep links                                         |
| `ymx --ssh-config` / `--install-service`            | Re-emit ssh config / install macOS LaunchAgent                       |
| **Remote / mobile**                                 |                                                                      |
| `ymx --remote <host> [args]` / `--remote-hosts`     | Drive a remote host's sessions over SSH/mosh / list aliases          |
| `ymx --auto-attach`                                 | Attach with UI picked by terminal width                              |
| `ymx --mobile-attach [repo] [pane]` / `--mobile-grid` | iPhone (one pane zoomed) / iPad (umbrella session)                 |
| `ymx --connect [--qr]`                              | Print exact mosh/ssh/`--remote` lines (optional QR)                  |
| **Self-management**                                 |                                                                      |
| `ymx --version` / `--keys` / `--help`               | Version / cheat-sheet / inline help                                  |
| `ymx --install` / `--update` / `--uninstall`        | Manage the symlink under `~/.local/bin`                              |

</details>

Full reference (every flag, every nuance): [YAAMUX.md](./YAAMUX.md).

---

## 🧠 Mental model

yaamux is **stateless**. Every invocation resolves the current repo with `git rev-parse` and derives everything from there. **One binary serves every repo.**

*Each pane is an agent. Each agent has its own folder. That folder is a real git branch.*

```
your-repo/                        ← main checkout
your-repo-worktrees/              ← siblings of your repo
  ├─ agent-1/   worktree/agent-1  ── 🤖 pane 1
  ├─ agent-2/   worktree/agent-2  ── 🤖 pane 2
  ├─ agent-3/   worktree/agent-3  ── ✦  pane 3
  └─ agent-4/   worktree/agent-4  ── ⬡  pane 4
                                       │
                                       └── tmux session: yaamux-yourrepo
```

| Thing                       | Where it lives                                          |
|-----------------------------|---------------------------------------------------------|
| The `yaamux` binary         | `$(brew --prefix)/bin/yaamux` (or `~/.local/bin`)       |
| Per-project defaults        | `<repo>/.yaamux/config`                                 |
| Per-project worktrees       | `<repo>/../<repo>-worktrees/agent-N`                    |
| Per-project hooks/logs      | `<repo>/.claude/`                                       |
| Agent instructions          | `<repo>/AGENTS.md` — where you tell agents about your project; per [agents.md](https://agents.md/) |
| Claude Code skill           | `<repo>/.claude/skills/yaamux/` → symlinked from `skills/yaamux/SKILL.md` |
| Env copy list               | `<repo>/.worktreeinclude`                               |
| tmux session                | `yaamux-<repo-name>` (one per repo, no collisions)      |
| Host aliases                | `~/.config/yaamux/hosts.conf`                           |
| Notify config               | `~/.config/yaamux/notify.conf`                          |
| Pilot prompt                | `~/.config/yaamux/pilot-prompt.md` (auto-written)       |

Pick the winner with `git merge worktree/agent-2` (or `ymx --pr N` if you're shipping). Throw the rest away with `ymx --clean` — it skips dirty worktrees; `--force` removes everything.

---

## 🛡 Safety & cost

**Default mode is SAFE** — agents still prompt for risky operations. Add `--yolo` (or `YAAMUX_YOLO=1`) to fully bypass prompts. **Only do that on code you trust.**

| Agent     | SAFE (default)                     | YOLO (`--yolo`)                                |
|-----------|------------------------------------|------------------------------------------------|
| `claude`  | _(no flag)_                        | `--dangerously-skip-permissions`               |
| `gemini`  | `--approval-mode auto_edit`        | `--yolo`                                       |
| `copilot` | `--allow-tool 'shell(git:*)'`      | `--allow-all-tools`                            |
| `codex`   | `--full-auto` (keeps sandbox)      | `--dangerously-bypass-approvals-and-sandbox`   |
| `opencode`| _(no flag)_                        | _(no flag)_                                    |

**Layered defenses:**

1. **`yaamux-guard.sh` hook** blocks `rm -rf /`, `mkfs`, `dd of=/dev/…` etc. for Claude panes. Other agents use their own permission systems. Blocked attempts log to `.claude/logs/blocked.log`.
2. **Safe mode** (`YAAMUX_AGENT_MODE=safe`) is exported into every agent shell. yaamux itself refuses `--kill`, `--clean`, `--install`, `--uninstall`, `--install-service` when called from an agent shell — with a clear error pointing the agent at the operator.
3. **Pilot popup-confirm** — destructive ops invoked by a pilot pop a tmux `display-popup` y/N to the human before running. Outside the pilot's tty, so it can't eat the keystroke.

**Cost.** Each agent burns real tokens against your account. 4 Claude agents at $0.03–0.10/min add up to **$20–50/hour** if continuously active. Detach + `--kill` when done. Check provider dashboards (claude.ai/usage, etc.).

---

## ✅ Requirements

`tmux` 3.2+ · `git` · `python3` · `curl` · at least one agent CLI (`claude`, `gemini`, `codex`, `copilot`, `opencode`).

Bundled by the Homebrew formula: `tmux`, `git`, `python@3`, `mosh`, `qrencode`, `lazygit`, `gh`, `git-delta`, `bat`. If you install via `--install` (git clone) instead, grab those yourself — yaamux degrades gracefully (the `git` window is skipped without `lazygit`; PR flags fail with a clear error without the relevant forge CLI; diffs and file viewing fall back to plain output without `delta` / `bat`).

Always optional: `tailscale` (zero-config networking).

yaamux checks everything on launch and prints the install command for anything missing.

---

## 🩺 Troubleshooting

| Symptom                                                    | Fix                                                                                              |
|------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| `'<agent>' not found`                                      | Install the CLI, or change the agent type                                                        |
| `command not found: yaamux`                                | `brew install vihang/tap/yaamux`, or `~/.yaamux/yaamux --install` + `~/.local/bin` on `PATH`     |
| `gh CLI not found` (during `--pr`)                         | `brew install gh && gh auth login` (or `glab` / `tea` for GitLab / Gitea)                        |
| Pilot says "no pilot backend installed"                    | Install `claude` (the wired backend), or pass `--pilot-show <backend>` explicitly                |
| Pilot popup never appears (destructive op silently aborts) | tmux 3.2+ required for `display-popup` — `tmux -V`                                               |
| Worktree skipped by `--clean`                              | It has uncommitted/unpushed work — commit, push, or `--clean --force`                            |
| `Ctrl+Space` does nothing                                  | Disable the macOS input-source shortcut                                                          |
| mosh won't connect                                         | Open UDP 60000-61000, or use Tailscale                                                           |
| `NoMoshServerArgs` / mosh-server not found                 | Use the `mosh --server='…' user@host -- …` line from yaamux's launch banner (bakes the PATH fix) |
| Session already running                                    | `--attach` to join, or `--kill` then restart                                                     |
| A pane died                                                | `ymx --restart N` (or `Ctrl+Space + r`)                                                          |
| Agent shell refuses `--kill` / `--clean`                   | Working as intended (safe mode); run from your own shell outside the session                     |

---

## 🤝 Contributing

yaamux is intentionally a **single bash file** — read [`yaamux`](./yaamux) end-to-end in ~30 minutes and you've read the whole project.

- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — friendly onboarding: clone → dev loop → first PR.
- **[AGENTS.md](./AGENTS.md)** — strict operating manual: invariants, architecture, definition of done (canonical per the [agents.md](https://agents.md/) standard; `CLAUDE.md` is a symlink to it).

Tests: `bats tests/yaamux.bats`. CI runs `bash -n`, embedded-heredoc lint, `shellcheck`, and the bats suite on every PR across Ubuntu and macOS.

**Especially-welcome PRs:**

- 🧱 New forge backends (Bitbucket, Codeberg, …) — fill in the `forge_*` family
- 🤖 New agent types — four functions: `agent_bin` / `agent_icon` / `agent_cmd` / `agent_idle_pattern`
- 💬 Pilot orchestrator framing for non-claude backends (codex / gemini / copilot / opencode)
- 🖥️ Platform fixes (WSL, paths with spaces, BSD utils)
- 📲 Mobile snippets for other terminals (Termius, iSH, …)
- 📚 Non-coding workflow examples (writing, research, ops) for the docs

---

## License

MIT © [Vihang Patel](https://github.com/vihang)
