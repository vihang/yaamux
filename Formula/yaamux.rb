# Homebrew formula for yaamux.
#
# Source of truth: vihang/yaamux Formula/yaamux.rb. Auto-bumped into
# vihang/homebrew-tap on every `v*` tag, substituting the tagged URL
# and tarball SHA256.
#
# Test locally before tagging:
#   brew install --build-from-source ./Formula/yaamux.rb
#   yaamux --version    # → yaamux <VERSION> (brew)

class Yaamux < Formula
  desc "Spawn N AI coding agents in parallel git worktrees in a tiled tmux grid"
  homepage "https://github.com/vihang/yaamux"
  url "https://github.com/vihang/yaamux/archive/refs/tags/v0.1.5.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "MIT"

  depends_on "tmux"
  depends_on "git"
  depends_on "python@3"
  depends_on "mosh"   # for `--remote --mosh` and the mobile-attach deep link

  def install
    bin.install "yaamux"
    bin.install_symlink bin/"yaamux" => "ymx"   # 3-char alias
    doc.install "YAAMUX.md", "README.md", "AGENTS.md"
    pkgshare.install "VERSION"
  end

  test do
    assert_match "yaamux #{version}", shell_output("#{bin}/yaamux --version")
    assert_match "yaamux #{version}", shell_output("#{bin}/ymx --version")
    assert_match "Agents Multiplexer", shell_output("#{bin}/yaamux --help")
  end
end
