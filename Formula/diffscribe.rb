# typed: false
# This file is rendered via packaging/homebrew/render.sh. Do not edit manually.

class Diffscribe < Formula
  desc "Ask an LLM to craft helpful Conventional Commit messages for your staged Git changes."
  homepage "https://github.com/nickawilliams/diffscribe"
  license "BSD-3-Clause"
  version "0.1.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/nickawilliams/diffscribe/releases/download/v0.1.0/diffscribe_0.1.0_darwin_arm64.tar.gz"
      sha256 "60d4c614b0713c68cce6a203607249839ad8d7bce7a5b52d8668ebd84e116f6d"
    end

    on_intel do
      url "https://github.com/nickawilliams/diffscribe/releases/download/v0.1.0/diffscribe_0.1.0_darwin_x86_64.tar.gz"
      sha256 "cbed0d48071fdaa0bd08345331db290dffa11ad29cbf4711379bf5db3523b93f"
    end
  end

  resource "source" do
    url "https://github.com/nickawilliams/diffscribe/releases/download/v0.1.0/diffscribe_0.1.0_source.tar.gz"
    sha256 "627a5dae5ca11696ca79dfa9b787645ab8becb10e5d2921e331417073d6d5967"
  end

  def install
    if build_from_source?
      odie "The Go toolchain (go 1.21+) is required to build from source." unless Utils.which("go")
      ohai "Building #{binary_name} #{version} from source tarball"
      resource("source").stage do
        ldflags = %W[
          -s -w
          -X github.com/rogwilco/diffscribe/internal/version.version=#{version}
        ]
        system "go", "build", "-trimpath", "-ldflags", ldflags.join(" "), "-o", buildpath/binary_name, "./"
        bin.install buildpath/binary_name
        install_shared_assets(Pathname.pwd)
      end
    else
      install_prebuilt_payload
    end
  end

  def build_from_source?
    ARGV.include?("--build-from-source")
  end

  def install_prebuilt_payload
    payload_root = if (buildpath/binary_name).exist?
      buildpath
    else
      buildpath.children.select do |child|
        child.directory? && child.basename.to_s != ".brew_home"
      end.find do |child|
        (child/binary_name).exist?
      end
    end

    odie "Unable to locate the extracted payload (expected to find #{binary_name})" unless payload_root

    bin.install payload_root/binary_name
    install_shared_assets(payload_root)
  end

  def install_shared_assets(root)
    completions_root = if (root/"completions").directory?
      root/"completions"
    elsif (root/"contrib"/"completions").directory?
      root/"contrib"/"completions"
    end

    if completions_root
      bash_completion_path = completions_root/"bash"/"#{binary_name}.bash"
      zsh_completion_path = completions_root/"zsh"/"#{binary_name}.zsh"
      fish_completion_path = completions_root/"fish"/"#{binary_name}.fish"

      bash_completion.install bash_completion_path => binary_name if bash_completion_path.exist?
      fish_completion.install fish_completion_path if fish_completion_path.exist?

      if zsh_completion_path.exist?
        (pkgshare/"oh-my-zsh"/binary_name).install zsh_completion_path => "#{binary_name}.plugin.zsh"
      end
    end

    manpage_path = root/"contrib"/"man"/"#{binary_name}.1"
    man1.install manpage_path if manpage_path.exist?
  end

  def caveats
    return unless build_from_source?

    <<~EOS
      `brew install #{full_name}` uses the published macOS binaries.
      You passed --build-from-source, so Homebrew rebuilt #{binary_name} locally.
      Ensure Go 1.21+ stays available if you repeat that workflow.
    EOS
  end

  def binary_name
    "diffscribe"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/#{binary_name} --version")
  end
end
