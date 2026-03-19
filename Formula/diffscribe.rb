# typed: false
# This file is rendered via packaging/homebrew/render.sh. Do not edit manually.

class Diffscribe < Formula
  desc "Ask an LLM to craft helpful commit messages for your staged Git changes."
  homepage "https://github.com/nickawilliams/diffscribe"
  license "BSD-3-Clause"
  version "0.3.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/nickawilliams/diffscribe/releases/download/v0.3.0/diffscribe_0.3.0_darwin_arm64.tar.gz"
      sha256 "68cf1732665c905d1b5dd514079fc3b1da7dbc146ff2296edabd35bfd6418ca2"
    end

    on_intel do
      url "https://github.com/nickawilliams/diffscribe/releases/download/v0.3.0/diffscribe_0.3.0_darwin_x86_64.tar.gz"
      sha256 "9a4ed17f82b657db7d5387a1685b270a6cb4391a04ba61e6fb3ca36f1f8dffa9"
    end
  end

  resource "source" do
    url "https://github.com/nickawilliams/diffscribe/archive/refs/tags/v0.3.0.tar.gz"
    sha256 "96c529366368598723626c7fc113561997298a3b53a3c2613dbd8924f59cb268"
  end

  def install
    if build_from_source?
      odie "The Go toolchain (go 1.21+) is required to build from source." unless Utils.which("go")
      ohai "Building #{binary_name} #{version} from source tarball"
      resource("source").stage do
        ldflags = %W[
          -s -w
          -X github.com/nickawilliams/diffscribe/internal/version.version=#{version}
        ]
        system "go", "build", "-trimpath", "-ldflags", ldflags.join(" "), "-o", buildpath/binary_name, "./"
        bin.install buildpath/binary_name
        install_shared_assets(Pathname.pwd)
      end

      unless (bash_completion/binary_name).exist? &&
             (fish_completion/"#{binary_name}.fish").exist? &&
             (zsh_completion/"_#{binary_name}").exist? &&
             (pkgshare/"oh-my-zsh"/binary_name/"#{binary_name}.plugin.zsh").exist? &&
             (man1/"#{binary_name}.1").exist?
        odie "Source archive for #{binary_name} #{version} is missing expected shared assets (completions/manpage). Rebuild the release artifacts and republish the Homebrew formula."
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

    unless (bash_completion/binary_name).exist? &&
           (fish_completion/"#{binary_name}.fish").exist? &&
           (zsh_completion/"_#{binary_name}").exist? &&
           (pkgshare/"oh-my-zsh"/binary_name/"#{binary_name}.plugin.zsh").exist? &&
           (man1/"#{binary_name}.1").exist?
      odie "Release archive for #{binary_name} #{version} is missing expected shared assets (completions/manpage). Rebuild the release artifacts and republish the Homebrew formula."
    end
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
        zsh_completion.install zsh_completion_path => "_#{binary_name}"
        omz_dir = pkgshare/"oh-my-zsh"/binary_name
        omz_dir.mkpath
        (omz_dir/"#{binary_name}.plugin.zsh").write <<~EOS
          source "#{zsh_completion}/_#{binary_name}"
        EOS
      end
    end

    manpage_path = root/"contrib"/"man"/"#{binary_name}.1"
    man1.install manpage_path if manpage_path.exist?
  end

  def caveats
    out = <<~EOS
      Bash completion:
        #{bash_completion}/#{binary_name}

      Fish completion:
        #{fish_completion}/#{binary_name}.fish

      Zsh completion:
        #{zsh_completion}/_#{binary_name}

      Oh-My-Zsh plugin:
        #{pkgshare}/oh-my-zsh/#{binary_name}/#{binary_name}.plugin.zsh
    EOS

    if build_from_source?
      out += <<~EOS

        `brew install #{full_name}` uses the published macOS binaries.
        You passed --build-from-source, so Homebrew rebuilt #{binary_name} locally.
        Ensure Go 1.21+ stays available if you repeat that workflow.
      EOS
    end

    out
  end

  def binary_name
    "diffscribe"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/#{binary_name} --version")
    assert_predicate bash_completion/binary_name, :exist?
    assert_predicate fish_completion/"#{binary_name}.fish", :exist?
    assert_predicate zsh_completion/"_#{binary_name}", :exist?
    assert_predicate pkgshare/"oh-my-zsh"/binary_name/"#{binary_name}.plugin.zsh", :exist?
    assert_match "source \"#{zsh_completion}/_#{binary_name}\"", (pkgshare/"oh-my-zsh"/binary_name/"#{binary_name}.plugin.zsh").read
  end
end
