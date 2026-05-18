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
3. If `TAP_PAT` secret is set on yaamux repo, copy the source `Formula/yaamux.rb`
   into `vihang/homebrew-tap`, patch in the tagged URL + SHA, open a bump PR,
   and auto-merge it (squash + delete branch). The full formula is copied so
   any dep/test changes in the template flow through — only `url` and `sha256`
   are substituted.

If `TAP_PAT` isn't set, do step 4 manually instead.

To re-run for an existing tag (e.g. backfill), trigger the workflow manually:
`gh workflow run release.yml -f tag=v0.1.2`.

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

## Step 6 — Set up TAP_PAT for auto-bumps

Without this secret, the release workflow still tags and creates a GitHub
release, but the homebrew tap stays stale and you have to bump it by hand.

1. **Create the PAT** at https://github.com/settings/personal-access-tokens/new
   - Resource owner: `vihang`
   - Repository access: **Only select repositories** → `vihang/homebrew-tap`
   - Repository permissions:
     - `Contents`: **Read and write**
     - `Pull requests`: **Read and write**
   - Expiration: pick a date you'll remember to rotate (1 year is fine).
   - Copy the token (`github_pat_…`) immediately — it's shown only once.

2. **Add it as a secret to `vihang/yaamux`**:
   ```bash
   gh secret set TAP_PAT --repo vihang/yaamux
   # paste the token when prompted
   ```
   Or via the UI: Settings → Secrets and variables → Actions → New repository
   secret → name `TAP_PAT`, value = the PAT.

3. **(Optional) Enable auto-merge** on `vihang/homebrew-tap` if you've set up
   branch protection: Settings → General → "Allow auto-merge". On personal
   repos without protection the workflow merges the PR immediately, so this
   only matters if you add required checks later.

4. **Verify** by triggering a backfill against an existing tag:
   ```bash
   gh workflow run release.yml --repo vihang/yaamux -f tag=v0.1.2
   gh run watch --repo vihang/yaamux
   ```
   You should see a `bump-yaamux-v0.1.2` PR appear and merge on the tap.

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
