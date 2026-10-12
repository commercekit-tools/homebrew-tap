class Commercekit < Formula
  desc "SAP Commerce developer tools for terminals and CI"
  homepage "https://commercekit.tools"
  version "0.1.0-preview.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-darwin-arm64.tar.gz"
      sha256 "097704b2750b906daf87f6309ca96a825d4058fd3fce85ad7523561db69d82bf"
    end

    on_intel do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-darwin-x64.tar.gz"
      sha256 "d8307276978b745bf3d86eb1b6d164f23b304cc2c82a75e301f7e4fead2927de"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-linux-arm64.tar.gz"
      sha256 "914d5acad10351e21f426b93b2c95f97aa8a9afc1284a550343aead09ff86fb9"
    end

    on_intel do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-linux-x64.tar.gz"
      sha256 "d01dd1bc45b39125ddc642b84163ceb24239a6a3ff9c80f69efe2e4939187d0b"
    end
  end

  def install
    bin.install "commercekit"
    pkgshare.install "LICENSE", "THIRD_PARTY_NOTICES", "README.txt"
  end

  def caveats
    message = <<~EOS
      CommerceKit CLI #{version} is a developer preview.
      Release artifacts are SHA-256 verified by Homebrew.
      Documentation: https://commercekit.tools
    EOS

    if OS.mac?
      message += <<~EOS

        The macOS binary is unsigned and is not Apple-notarized.
      EOS
    end

    message
  end

  test do
    assert_equal "#{version}\n", shell_output("#{bin}/commercekit --version")
    system bin/"commercekit", "cron", "explain", "0 0 2 * * ?"
  end
end
