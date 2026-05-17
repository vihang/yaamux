# Release runbook — yaamux

Manual steps to take v0.1.0 from local to `brew install`-able. Done once, then
the GitHub Actions release workflow takes over for subsequent versions.

## Prerequisites

- GitHub account `vihang` (or substitute yours throughout).
- `gh` CLI authenticated: `gh auth status` should pass.
- A clean working tree in `~/Code/yaamux` (this repo).

## Step 1 — Initialize git and push yaamux repo

The repo isn't under git yet. Initialize and push.

```bash
cd ~/Code/yaamux
git init
git add -A
git commit -m "yaamux v0.1.0 — minimal foundation"
gh repo create vihang/yaamux --public --source=. --remote=origin --push
```

## Step 2 — Create the Homebrew tap repo

```bash
# Empty repo with a Formula/ dir
mkdir -p /tmp/homebrew-tap/Formula
cp ~/Code/yaamux/Formula/yaamux.rb /tmp/homebrew-tap/Formula/
cd /tmp/homebrew-tap
git init
git add -A
git commit -m "Initial: yaamux formula"
gh repo create vihang/homebrew-tap --public --source=. --remote=origin --push
```

## Step 3 — Tag v0.1.0 and let CI compute the SHA

```bash
cd ~/Code/yaamux
git tag v0.1.0
git push --tags
```

The release workflow (`.github/workflows/release.yml`) will:
1. Create the GitHub Release with auto-generated notes
2. Compute the tarball SHA256
3. If `TAP_PAT` secret is set on yaamux repo, open a formula-bump PR against
   `vihang/homebrew-tap` with the correct URL + SHA

If `TAP_PAT` isn't set, do step 4 manually instead.

## Step 4 — (Manual fallback) Bump the formula SHA

```bash
SHA="$(curl -sL https://github.com/vihang/yaamux/archive/refs/tags/v0.1.0.tar.gz \
  | sha256sum | awk '{print $1}')"

cd /tmp/homebrew-tap
sed -i.bak \
  -e "s|REPLACE_WITH_TARBALL_SHA256|$SHA|" \
  Formula/yaamux.rb
rm Formula/yaamux.rb.bak
git commit -am "yaamux: v0.1.0"
git push
```

## Step 5 — Smoke test

```bash
brew tap vihang/tap
brew install yaamux
yaamux --version    # → "yaamux 0.1.0 (brew)"
yaamux --help       # → usage text

# Test in a throwaway repo
mkdir -p /tmp/yaamux-shakedown && cd /tmp/yaamux-shakedown
git init -q && git commit --allow-empty -q -m init
yaamux --init
yaamux 2   # opens tmux with 2 claude panes
```

If anything is wrong, fix locally, bump VERSION, tag a new patch version, and
the release workflow re-runs.

## Step 6 — Optional: set up TAP_PAT for future auto-bumps

1. Create a fine-grained PAT with `Contents: write` on `vihang/homebrew-tap`.
2. Add it as a secret named `TAP_PAT` to `vihang/yaamux`.
3. Next `git tag v*` push will auto-open a bump PR against the tap.

## Releases after v0.1.0

```bash
# 1. Bump VERSION + update YAAMUX.md and AGENTS.md changelog/roadmap
echo "0.1.1" > VERSION
# 2. Commit
git commit -am "release: v0.1.1"
git tag v0.1.1
git push --tags
# 3. CI handles the rest (or do step 4 manually)
```
