class Commercekit < Formula
  desc "SAP Commerce developer tools for terminals and CI"
  homepage "https://commercekit.tools"
  version "0.1.0-preview.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-darwin-arm64.tar.gz"
      sha256 "264c476c3a6ae0174ec2659f1e1c90b30b0942b78ae2a1e2e970465ec0b1c6eb"
    end

    on_intel do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-darwin-x64.tar.gz"
      sha256 "afa2a6c9dc1cb7c43570929ee0faf679065ee3cf259fe606ff502fe41e037407"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-linux-arm64.tar.gz"
      sha256 "e96da85d977c987a7ae03d5260cb7f1171855bee142fe74e150df28870d79999"
    end

    on_intel do
      url "https://github.com/commercekit-tools/cli/releases/download/cli-v#{version}/commercekit-v#{version}-linux-x64.tar.gz"
      sha256 "623c0c9cc803e2c11ea9a4aa12a0dc37cf7ba0d73403b48f395d1cd0f6bf245a"
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
