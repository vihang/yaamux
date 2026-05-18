<div align="center">

# Contributing to yaamux

**You don't need to learn a build system. You need to read one bash file.**

The whole project is [`yaamux`](./yaamux) — ~2 000 lines of bash, no
toolchain, no build step. Runtime needs only `bash`, `tmux`, `git`,
`python3`, and `curl`. If you can write a shell script, you can ship a
feature here.

</div>

---

## 🧭 Project ethos

Three values guide every change. Internalise these and your first PR will land:

1. **Single file.** `yaamux` is the entire program. Helper scripts ship as quoted
   heredocs *inside* it. We do not add a `src/` directory. We do not adopt a
   build step. Install-once portability is the whole point.
2. **Stateless.** Every run resolves the current repo with `git rev-parse`.
   No global config file ever hard-codes a path. One binary serves every repo
   on the box.
3. **Boring tools.** Bash, tmux, git, python3, curl. That's it. New runtime
   dependencies require an explicit decision — open an issue first.

If a change would break any of these, it needs a conversation before code.

> **The strict version** of this ruleset — every invariant, every "do not
> touch this" — lives in [AGENTS.md](./AGENTS.md). Read it before you push.
> This file is the friendly onboarding; AGENTS.md is the rulebook.

---

## 🚀 Get hacking in 60 seconds

```bash
git clone https://github.com/vihang/yaamux ~/code/yaamux
cd ~/code/yaamux
./yaamux --version                            # should print the version + (git@SHA)

# Set up a throwaway repo to test against
mkdir -p /tmp/yaamux-dev && cd /tmp/yaamux-dev
git init -q && git commit -q --allow-empty -m init
~/code/yaamux/yaamux --help                   # sanity check
~/code/yaamux/yaamux 2                        # spawn 2 agents (detach with Ctrl+Space + d, then --kill)
```

You're now editing `~/code/yaamux/yaamux` and running it against
`/tmp/yaamux-dev`. No symlinks, no install, no PATH games.

---

## 🧱 What's in the box

```
yaamux/
├── yaamux                     ← the script (the entire program — ~2 000 LOC)
├── VERSION                    ← semver string read by --version
├── README.md                  ← user-facing landing page
├── YAAMUX.md                  ← full end-user usage guide
├── AGENTS.md                  ← strict developer/agent operating manual
├── CLAUDE.md                  ← symlink → AGENTS.md
├── CONTRIBUTING.md            ← this file (friendly contributor guide)
├── tests/
│   ├── yaamux.bats            ← bats-core integration suite
│   └── helpers.bash           ← test harness (setup_repo / run_yaamux / …)
└── .github/workflows/
    ├── ci.yml                 ← bash -n + heredoc check + shellcheck + bats
    ├── auto-tag.yml           ← tags release on VERSION bump
    └── release.yml            ← publishes release artifacts
```

**No `src/`, no `package.json`, no `Makefile`, no `Cargo.toml`.** This is the
deliverable surface — what you see is what ships.

---

## 🗺️ Anatomy of `yaamux`

The script is ordered top-to-bottom in this shape. Knowing this map = knowing
where to put your change:

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Self-location           SELF, YAAMUX_HOME — resolve through      │
│                            the symlink                              │
│ 2. Project context         REPO_ROOT, SESSION, WORKTREES_BASE       │
│ 3. Defaults & flags        DEFAULT_*, MAX_AGENTS, *_FLAGS_SAFE/YOLO │
│ 4. agent_* helpers         agent_bin · agent_icon · agent_cmd       │
│                            → the only place that branches on type   │
│ 5. Embedded writers        _write_settings_json / _guard_hook /     │
│                            _notify_hook / _mobile_attach            │
│ 6. Lifecycle               _install_yaamux / _update / _uninstall / │
│                            _add_docs / _gen_ssh_config /            │
│                            _install_launchagent                     │
│ 7. Remote ops              _remote_resolve_host / _remote_list_raw /│
│                            _remote_print_list / _remote_pick_session│
│                            _remote_attach / _remote_dispatch        │
│                            → back --remote                          │
│ 8. Pane health             _pane_state / _refresh_pane_states /     │
│                            _restart_pane / _triage_prompt           │
│                            → back --restart-* / attach-time triage  │
│ 9. Argument parsing        Splits positional (N + PATTERN) from     │
│                            flags. Flags always start with `--`.     │
│ 10. Flag `case` block      Every --xxx command. Each exits cleanly. │
│ 11. Start sequence         preflight → hooks → worktrees → tmux     │
│                            build → launch → attach                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔁 The development loop

Run after every edit to `yaamux`. Five things, in order:

1. `bash -n yaamux` — syntax-check the main script
2. **Embedded-heredoc extract & lint** — see the canonical snippet in [AGENTS.md → Development loop](./AGENTS.md#development-loop)
3. `shellcheck yaamux`
4. `bats tests/yaamux.bats`
5. Smoke test in a throwaway repo (`git init` → `yaamux 2` → `--status` → `--kill` → `--clean`)

CI runs steps 1–4 — keeping the snippets in AGENTS.md as the single source of truth means they can't drift.

Install deps once: `brew install shellcheck bats-core tmux` (mac) or
`sudo apt-get install -y shellcheck bats tmux` (ubuntu).

---

## 🧩 Cookbook — common contributions

### Add a new agent type

This is the cleanest "small PR" — three functions, one map entry.

1. **Pick a name and icon** (single unicode glyph; see existing icons).
2. **Edit three functions only** (Section 4 of the script map):
   - `agent_bin <type>`   → CLI binary name (e.g., `mycli`)
   - `agent_icon <type>`  → emoji/glyph used in pane titles
   - `agent_cmd <type>`   → the exec line, both SAFE and YOLO flag variants
3. **Add safe & yolo flag vars** at the top alongside `*_FLAGS_SAFE` / `*_FLAGS_YOLO`.
4. **Update three docs:**
   - The valid-types list in [YAAMUX.md](./YAAMUX.md)
   - The agent icons line in [README.md](./README.md)
   - The auto-accept table in **both** [YAAMUX.md](./YAAMUX.md) and [README.md](./README.md)
5. **Add a bats test** that spawns 1 agent of that type and asserts pane title.
6. **Run the dev loop above.**

Nothing else in the script should branch on agent type. If your change needs
an `if [[ "$type" == "mycli" ]]` anywhere outside `agent_*`, stop and rethink.

### Add a new `--flag`

1. **Add the `case` branch** in Section 10 (the `case` block). Each branch
   should do its work and `exit 0` — flags are one-shot commands.
2. **Add it to `--help`** (the comment block near lines ~15–40).
3. **Update the summary footer** if relevant.
4. **Document it** in [YAAMUX.md](./YAAMUX.md) (Commands table at minimum).
5. **Add a row to [README.md](./README.md)'s command reference** if it's
   user-facing.
6. **Add a bats test** that exercises the happy path.

### Add a new in-tmux key binding

When you add a `tmux bind-key -T prefix …` line in the start sequence:

- ✅ Add a row to `_print_keys()` ("In-session keys" section).
- ✅ Add a row to the shortcuts table in [YAAMUX.md](./YAAMUX.md).
- ✅ Add a row to the keybindings table in [README.md](./README.md).

> The `Ctrl+Space + ?` popup is the user's only in-session reference — an
> unlisted binding is effectively undiscoverable.

### Edit an embedded heredoc helper

The three helpers — `yaamux-guard.sh`, `yaamux-notify.sh`,
`yaamux-mobile-attach.sh` — live inside `yaamux` as **quoted** heredocs
(`<< 'GUARD_EOF'` etc.). Quoting is load-bearing:

- ✅ With `'GUARD_EOF'`, inner `$` and `$()` are stored verbatim and expand at
  the helper's runtime — which is what you want.
- ❌ Unquoted `GUARD_EOF` would expand `$` at install time. Helpers break
  silently.

When you edit one of them:

1. Make the change inside the heredoc.
2. The dev-loop step 2 above will extract it and `bash -n` it. Re-run.
3. Run the bats suite. Tests touching `--init` / `--setup-notify` exercise the
   extraction path.

---

## 🧪 Tests

We use [bats-core](https://github.com/bats-core/bats-core).

```bash
bats tests/yaamux.bats                 # run the whole suite
bats tests/yaamux.bats -f "--version"  # filter by test-name substring
bats tests/yaamux.bats --print-output-on-failure
```

[`tests/helpers.bash`](./tests/helpers.bash) sets up a throwaway git repo per
test and provides `run_yaamux`, `setup_repo`, `teardown_repo`. Look at the
existing tests in [`tests/yaamux.bats`](./tests/yaamux.bats) for the patterns.

**A change without a test review is not done.** Either:

- Add a test for the new behavior, or
- Note explicitly in the PR why a test isn't practical (e.g., relies on an
  agent CLI being installed in CI).

---

## 🤖 CI matrix

[`.github/workflows/ci.yml`](./.github/workflows/ci.yml) runs on every pull
request and on every push to `main`, across **Ubuntu** and **macOS** — open
the PR to see CI on a feature branch:

| Step                          | Blocking? |
|-------------------------------|-----------|
| `bash -n yaamux`              | ✅ yes    |
| Embedded-heredoc syntax check | ✅ yes    |
| `shellcheck yaamux`           | ⚠️  no — until backlog item #1 lands |
| `bats tests/yaamux.bats`      | ✅ yes    |

If CI is red on a fresh PR, it's almost always one of:

- Whitespace-only diff to a heredoc that subtly changed an `EOF` delimiter
- An unquoted variable (`set -u` is on)
- A test that assumed an agent CLI was installed in CI (none are — agents are
  user-installed)

---

## ✅ Definition of done

The full PR checklist lives in [AGENTS.md → Definition of done](./AGENTS.md#definition-of-done-any-change). Keeping it in one place means it can't go stale here. Skim it before you open the PR, copy it into the PR body, and tick what applies.

The headline items: **dev-loop steps 1–4 pass**, no AGENTS.md invariant broken, docs updated in lockstep with behaviour (YAAMUX.md for flags, README.md for user-facing surface, both keybindings tables if you added one), and a bats test (or a one-line note on why a test isn't practical).

---

## ✍️ Conventions

Follow the canonical [AGENTS.md → Conventions](./AGENTS.md#conventions) — internal functions prefixed `_`, status output via `log` / `warn` / `die` / `header` (never raw `echo`), fully-qualified tmux targets, 2-space indent, `"${x:-}"` everywhere `x` might be unset (`set -u` is on), and imperative-scoped commit messages like `yaamux: add --foo flag`.

---

## 🌱 Good first PRs

Pulled from the **Open backlog** section of [AGENTS.md](./AGENTS.md):

1. **shellcheck cleanup** — Resolve every `shellcheck yaamux` finding so we
   can flip CI to blocking. Add `# shellcheck disable=` only where a fix
   isn't possible, with a one-line justification.
2. **Spaces-in-path hardening** — Audit unquoted expansions; verify a repo
   whose path contains spaces still works end-to-end.
3. **WSL / Windows audit** — Inventory `realpath`, `pbcopy`, `osascript`,
   path assumptions. Even a "here's what would have to change" issue is
   useful.
4. **Mobile snippets for other clients** — Termius, iSH, etc. Same idea as
   the existing Blink / Prompt 3 snippets in [YAAMUX.md](./YAAMUX.md).
5. **A new agent type** — `opencode` is on the v0.2 roadmap.

The **v0.2 roadmap** (controller mode, council/pipeline/vote/pair patterns,
TUI keybinding layer, shared context layer, GitHub-issue-queue dev mode,
watchdog/auto-recovery, cost tracking, `--watch-pr` CI loop, `--serve` web UI,
`--container` sandbox, pre-warm pane) is bigger — open an issue to discuss
scope before starting.

---

## 🐛 Reporting bugs

Useful bug reports include:

- yaamux version: `yaamux --version`
- Install source (homebrew / git clone)
- OS + version (`sw_vers` / `lsb_release -a`)
- tmux version (`tmux -V`)
- The exact command and the full output (`set -x` output is gold)
- Whether `bash -n yaamux` and the smoke test both pass for you

Open at https://github.com/vihang/yaamux/issues.

---

## 🤗 Code of conduct

Be kind. Critique code, not people. Assume the contributor read AGENTS.md and
is trying their best — and ask, don't tell, when something looks off.

We don't have a long formal CoC document; if a situation needs one, we'll
adopt [Contributor Covenant](https://www.contributor-covenant.org/) and update
this section.

---

## 📜 License

By contributing, you agree your work is released under the project's
[MIT License](./LICENSE).

Thank you for making yaamux better. 💛
