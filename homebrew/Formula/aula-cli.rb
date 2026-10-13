class AulaCli < Formula
  desc "macOS driver and CLI suite for the Aula F108 Pro mechanical keyboard"
  homepage "https://github.com/meitar/aula-driver"
  url "https://github.com/meitar/aula-driver/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256"
  license "MIT"
  head "https://github.com/meitar/aula-driver.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox", "--product", "aula-cli"
    bin.install ".build/release/aula-cli"
  end

  test do
    assert_match "Aula F108 Pro macOS Companion CLI", shell_output("#{bin}/aula-cli help")
  end
end
