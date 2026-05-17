# Homebrew formula for yaamux.
#
# This file should live in the `vihang/homebrew-tap` repository at
# `Formula/yaamux.rb`. It's committed here as a template that the v0.1.0
# release workflow (.github/workflows/release.yml) will copy + sha-bump into
# that tap repo via a PR.
#
# Test locally before tagging:
#   brew install --build-from-source ./Formula/yaamux.rb
#   yaamux --version    # → yaamux 0.1.0 (brew)

class Yaamux < Formula
  desc "Spawn N AI coding agents in parallel git worktrees in a tiled tmux grid"
  homepage "https://github.com/vihang/yaamux"
  url "https://github.com/vihang/yaamux/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "MIT"

  depends_on "tmux"
  depends_on "git"
  depends_on "python@3"

  def install
    bin.install "yaamux"
    doc.install "YAAMUX.md", "README.md", "AGENTS.md"
    pkgshare.install "VERSION"
  end

  test do
    assert_match "yaamux 0.1.0", shell_output("#{bin}/yaamux --version")
    assert_match "Agents Multiplexer", shell_output("#{bin}/yaamux --help")
  end
end
