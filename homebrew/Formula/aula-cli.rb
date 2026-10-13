class AulaCli < Formula
  desc "macOS driver and CLI suite for the Aula F108 Pro mechanical keyboard"
  homepage "https://github.com/meitar/aula-driver"
  url "https://github.com/meitar/aula-driver/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "6a826209e9fe36ecf5ad8476a33412c9b22fc82675cb8433643d72baf2134004"
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
