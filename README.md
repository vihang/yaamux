<div align="center">

# yaamux

**Spawn N AI coding agents in parallel. Drive them from your laptop, phone, or iPad.**

One bash file · one tmux session per repo · zero ceremony.

[![CI](https://github.com/vihang/yaamux/actions/workflows/ci.yml/badge.svg)](https://github.com/vihang/yaamux/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](#license)
[![Single file](https://img.shields.io/badge/single--file-bash-89e051.svg)](./yaamux)

🤖 Claude Code · ✦ Gemini CLI · 🐙 GitHub Copilot CLI · ⬡ Codex CLI

</div>

---

## The problem

You want to:

- 🧠 Run **4 agents working different angles** of the same task — and merge the winner.
- 🛋️ Check in from your **couch, phone, or kitchen**, not just the desk you started at.
- 🔔 Get a **push notification** the moment an agent needs your input.
- 👆 Tap that notification and land in **the exact pane that needs you**.

Today that's a stack: a workspace tool, a tmux config, a worktree script, an SSH wrapper, a mobile client setup, a push rig.

**yaamux is the single bash file that wires all of it together.**

---

## 30-second install

```bash
brew tap vihang/tap && brew install yaamux
```

Installs both `yaamux` and the 3-char alias `ymx` — same script, same flags. The rest of this README uses `ymx` for brevity.

> Not on Homebrew? `git clone https://github.com/vihang/yaamux ~/.yaamux && ~/.yaamux/yaamux --install`

## 30-second first run

```bash
cd ~/your/repo
ymx --init                 # scaffolds AGENTS.md + .yaamux/config + .worktreeinclude
ymx 4                      # 4 Claude agents · 4 worktrees · 1 tiled tmux grid
```

You land in a session that looks like this:

```
┌─────────────────────────┬─────────────────────────┐
│ 🤖 agent-1  claude      │ 🤖 agent-2  claude      │
│ > writing tests…        │ > refactoring auth…     │
│                         │                         │
├─────────────────────────┼─────────────────────────┤
│ 🤖 agent-3  claude      │ 🤖 agent-4  claude      │
│ > tracking a bug…       │ > drafting PR copy…     │
│                         │                         │
└─────────────────────────┴─────────────────────────┘
              session: yaamux-yourrepo
```

`Ctrl+Space + d` to detach — agents keep running. Reattach later with `ymx --attach`. List every yaamux session across every repo on this box with `ymx --list`.

---

## ⚡ Control them from anywhere

This is yaamux's superpower. **One install, four ways to attach:**

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

### From a laptop — `ymx --remote`

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

### From a phone — the QR trick 📲

Inside any running yaamux session, hit `Ctrl+Space + Q`:

```
   ██████ ▄▄ █ ▄ █  ▄▄ ██████
   █ ▀▀ █ ▀█▄▀▀▄▄▀ █▄▀ █ ▀▀ █
   █ ██ █ █▀█▄ ▄▀▄▀ ▀▀ █ ██ █
   ▀▀▀▀▀▀ █ █ █ █ █ █ █ ▀▀▀▀▀▀
              (full QR)
```

Open the iOS Camera, scan, **tap** — Blink Shell (or Prompt 3 / Termius) opens with the mosh connection ready to go. Once you're at the shell, run `yaamux --auto-attach` and the phone gets the right UI automatically.

The QR encodes `mosh://user@host` so iOS routes the scan as a URL (one-tap "Open in Blink") instead of misreading `user@host.tld` as an email address. The full `mosh --server='…' -- yaamux --auto-attach` line — with the Homebrew PATH fix baked in — is still printed *above* the QR for desktop copy/paste, and it's the recommended path if you hit `NoMoshServerArgs` from a bare scan (the URL scheme can't carry the `--server` arg).

### Auto-route by terminal width — `--auto-attach`

One Blink snippet works on every device:

```bash
mosh --server='export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"; exec mosh-server' \
     user@host -- yaamux --auto-attach
```

| Terminal width | UI                                   | Best for     |
|----------------|--------------------------------------|--------------|
| `< 100` cols   | **one pane zoomed**                  | iPhone       |
| `100–179` cols | **grid across all running repos**    | iPad 11"/13" |
| `≥ 180` cols   | **full tmux attach**                 | desktop      |

Override with `YAAMUX_ATTACH_MODE=zoom|grid|full|auto`.

### iPad grid — `--mobile-grid`

```bash
ymx --mobile-grid
```

Builds an umbrella tmux session with one window per running `yaamux-<repo>` (real windows, linked in via `tmux link-window` — changes propagate live). Tap-to-focus enabled.

```
┌─ tab: app-A ─┬─ tab: app-B ─┬─ tab: docs ─┬─ tab: infra ─┐
│ ┌────┬────┐  │  ┌────┬────┐ │ ┌────┬────┐ │ ┌────┬────┐  │
│ │ ag │ ag │  │  │ ag │ ag │ │ │ ag │ ag │ │ │ ag │ ag │  │
│ ├────┼────┤  │  ├────┼────┤ │ ├────┼────┤ │ ├────┼────┤  │
│ │ ag │ ag │  │  │ ag │ ag │ │ │ ag │ ag │ │ │ ag │ ag │  │
│ └────┴────┘  │  └────┴────┘ │ └────┴────┘ │ └────┴────┘  │
└──────────────┴──────────────┴─────────────┴──────────────┘
```

### Push notifications — `--setup-notify` 🔔

```bash
ymx --setup-notify
```

Wires up **ntfy** push delivery and a **Blink Shell deep link**. When an agent needs your input, the notification fires; **tapping it opens Blink, mosh'es in, and zooms to the exact pane.**

(Push fires for Claude panes today. Other agents flash the tmux activity highlight; cross-agent push is on the roadmap.)

---

## 🎛️ Pick your agents

Positional form: `ymx [N] [type ...]`. Types: `claude` · `gemini` · `copilot` · `codex`. Max 20.

```bash
ymx                              # 4 Claude (default)
ymx 6                            # 6 Claude
ymx claude gemini codex          # 3 panes — one of each
ymx 8 claude gemini              # 8 panes — cycled: c,g,c,g,c,g,c,g
ymx 1 codex                      # single Codex agent
ymx --yolo 4 claude              # full permission bypass (trust the code!)
```

---

## 🥷 Pro moves

### Ship a PR from a pane

```bash
ymx --pr 2                       # push pane 2's branch + open PR via gh
ymx --pr 2 "Fix #123 race" --merge
```

### Headless: send-prompt-and-collect-output

```bash
ymx --exec 1 "summarize TODO comments in src/" 300
```

Injects the prompt into pane 1, polls until idle (300 s timeout), prints the result. Great for orchestration scripts.

### Broadcast & sync

```bash
ymx --broadcast "rebase onto main and run tests"   # same prompt → every pane
ymx --sync                                          # toggle keystroke sync
```

### Hand a pane to VS Code

```bash
ymx --vscode 1                   # stops pane 1's agent, opens its worktree in Code
```

Resume the conversation via **Claude Code panel → Session History** or `claude --resume`. History is shared on disk under `~/.claude/projects/`.

### Bring your env into the worktrees

`.env*` (and anything in `.worktreeinclude`) is **copied** into every worktree on creation. Edits stay isolated. Want a single source of truth instead?

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
| `Ctrl+Space` + `Z`      | Zoom / unzoom current pane                              |
| `Ctrl+Space` + `W`      | Window list (agents · remote-srv · logs)                |
| `Ctrl+Space` + `[`      | Scroll mode (`q` exits, `/` searches, `y`/Enter copies) |
| `Ctrl+Space` + `S`      | Toggle keystroke sync across panes                      |
| `Ctrl+Space` + `r`      | Restart agent in current pane                           |
| `Ctrl+Space` + `R`      | Restart all dead/idle agents (confirms)                 |
| `Ctrl+Space` + `L`      | Clear screen + scrollback                               |
| `Ctrl+Space` + `d`      | Detach (agents keep running) — tmux default             |
| `Ctrl+Space` + `C`      | **Connect-commands popup** (mosh · ssh · `--remote`)    |
| `Ctrl+Space` + `Q`      | **QR popup** — scan with iOS Camera, opens `mosh://` in Blink / Prompt / Termius |
| `Ctrl+Space` + `?`      | Cheat sheet (popup)                                     |
| `Ctrl+Space` + `/`      | List every tmux binding                                 |
| Mouse click             | Focus a pane                                            |

Run `ymx --keys` from any shell for the same cheat sheet — no tmux needed.

> **macOS:** `Ctrl+Space` may be your input-source switcher. Disable under
> *System Settings → Keyboard → Keyboard Shortcuts → Input Sources.*

---

## 📖 Command reference

| Command                                             | What it does                                                         |
|-----------------------------------------------------|----------------------------------------------------------------------|
| `ymx [N] [types...]`                                | Start (or attach if the repo's session exists)                       |
| `ymx --init [--with-docs]`                          | Scaffold `AGENTS.md` + `.yaamux/config` + `.worktreeinclude`         |
| `ymx --list [--json]`                               | List yaamux sessions across all repos                                |
| `ymx --attach` / `--kill` / `--clean` [`--force`]   | Session lifecycle                                                    |
| `ymx --status`                                      | Health check for the current repo                                    |
| `ymx --layout main\|tiled\|even`                    | Override the auto-picked pane layout                                 |
| `ymx --zoom N` / `--vscode N`                       | Focus pane N / hand it to VS Code                                    |
| `ymx --send N "x"` / `--broadcast "x"`              | Inject a prompt into one pane / every pane                           |
| `ymx --exec N "x" [timeout]`                        | Headless: send, wait for idle, return output (default 5 min)         |
| `ymx --pr N [title] [--merge]`                      | Push pane N's branch + open PR via `gh`                              |
| `ymx --restart N` / `--restart-dead [-y]`           | Heal panes                                                           |
| `ymx --logs` / `--sync`                             | Live-log window / toggle keystroke sync                              |
| `ymx --yolo …` / `--link-env …`                     | Modifiers — combine with positional args                             |
| `ymx --setup-notify`                                | ntfy push + Blink deep links                                         |
| `ymx --ssh-config`                                  | (Re)generate the `~/.ssh/config` host block                          |
| `ymx --install-service`                             | macOS LaunchAgent — auto-start this repo's agents on login           |
| `ymx --remote <host> [args]`                        | Drive a remote host's sessions over SSH/mosh                         |
| `ymx --remote-hosts`                                | List host aliases from `~/.config/yaamux/hosts.conf`                 |
| `ymx --auto-attach`                                 | Attach with UI picked by terminal width                              |
| `ymx --mobile-attach [repo] [pane]`                 | iPhone: one pane zoomed                                              |
| `ymx --mobile-grid`                                 | iPad: umbrella session across every running repo                     |
| `ymx --connect [--qr]`                              | Print exact mosh/ssh/`--remote` lines (optional QR)                  |
| `ymx --keys`                                        | Print in-tmux + CLI cheat sheet                                      |
| `ymx --version` / `--install` / `--update` / `--uninstall` | Self-management                                               |

Full reference (every flag, every nuance): [YAAMUX.md](./YAAMUX.md).

---

## 🧠 The mental model

yaamux is **stateless**. Every invocation resolves the current repo with `git rev-parse` and derives everything from there. **One binary serves every repo.**

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
| Agent instructions          | `<repo>/AGENTS.md` (per [agents.md](https://agents.md/))|
| Env copy list               | `<repo>/.worktreeinclude`                               |
| tmux session                | `yaamux-<repo-name>` (one per repo, no collisions)      |
| Host aliases                | `~/.config/yaamux/hosts.conf`                           |
| Notify config               | `~/.config/yaamux/notify.conf`                          |

Merge work back with normal git (`git merge worktree/agent-2`) or `ymx --pr N`. `ymx --clean` skips dirty worktrees; `ymx --clean --force` removes everything.

---

## 🛡️ Safety & cost

**Default mode is SAFE** — agents still prompt for risky operations. Add `--yolo` (or `YAAMUX_YOLO=1`) to fully bypass prompts. **Only do that on code you trust.**

| Agent     | SAFE (default)                     | YOLO (`--yolo`)                                |
|-----------|------------------------------------|-----------------------------------------------|
| `claude`  | _(no flag)_                        | `--dangerously-skip-permissions`              |
| `gemini`  | `--approval-mode auto_edit`        | `--yolo`                                      |
| `copilot` | `--allow-tool 'shell(git:*)'`      | `--allow-all-tools`                           |
| `codex`   | `--full-auto` (keeps sandbox)      | `--dangerously-bypass-approvals-and-sandbox`  |

A `yaamux-guard.sh` hook blocks `rm -rf /`, `mkfs`, `dd of=/dev/…` etc. **for Claude panes** (other agents use their own permission systems). Blocked attempts log to `.claude/logs/blocked.log`.

**Cost.** Each agent runs against your real account. 4 Claude agents at $0.03–0.10/min add up to **$20–50/hour** if continuously active. Detach + `--kill` when you're done. Check provider dashboards (claude.ai/usage, etc.).

---

## ✅ Requirements

`tmux` 3.2+ · `git` · `python3` · `curl` · at least one agent CLI (`claude`, `gemini`, `codex`, `copilot`).

Bundled by the Homebrew formula: `tmux`, `git`, `python@3`, `mosh`, `qrencode`. If you install via `--install` (git clone) instead, grab `mosh` and `qrencode` yourself for `--remote --mosh` and `--connect --qr`.

Always optional: `gh` (for `--pr`) · `tailscale` (zero-config networking).

yaamux checks everything on launch and prints the install command for anything missing.

---

## 🩺 Troubleshooting

| Symptom                                                    | Fix                                                                                              |
|------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| `'<agent>' not found`                                      | Install the CLI, or change the agent type                                                        |
| `command not found: yaamux`                                | `brew install vihang/tap/yaamux`, or `~/.yaamux/yaamux --install` + `~/.local/bin` on `PATH`     |
| `gh CLI not found` (during `--pr`)                         | `brew install gh && gh auth login`                                                               |
| Worktree skipped by `--clean`                              | It has uncommitted/unpushed work — commit, push, or `--clean --force`                            |
| `Ctrl+Space` does nothing                                  | Disable the macOS input-source shortcut                                                          |
| mosh won't connect                                         | Open UDP 60000-61000, or use Tailscale                                                           |
| `NoMoshServerArgs` / mosh-server not found                 | Use the `mosh --server='…' user@host -- …` line from yaamux's launch banner (bakes the PATH fix) |
| Session already running                                    | `--attach` to join, or `--kill` then restart                                                     |
| A pane died                                                | `ymx --restart N` (or `Ctrl+Space + r`)                                                          |

---

## 🤝 Contributing

yaamux is intentionally a **single bash file** — read [`yaamux`](./yaamux) end-to-end in ~20 minutes and you've read the whole project.

- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — friendly onboarding: clone → dev loop → first PR.
- **[AGENTS.md](./AGENTS.md)** — strict operating manual: invariants, architecture, definition of done (canonical per the [agents.md](https://agents.md/) standard; `CLAUDE.md` is a symlink to it).

Tests: `bats tests/yaamux.bats`. CI runs `bash -n`, embedded-heredoc lint, `shellcheck`, and the bats suite on every PR across Ubuntu and macOS.

Especially-welcome PRs:

- New agent types (just three functions: `agent_bin` / `agent_icon` / `agent_cmd`)
- Platform fixes (WSL, paths with spaces, BSD utils)
- Mobile snippets for other terminals (Termius, iSH, …)

---

## License

MIT © [Vihang Patel](https://github.com/vihang)
