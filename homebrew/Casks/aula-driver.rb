cask "aula-driver" do
  version "1.0.2"
  sha256 "600ec4a0aa0a8c51e844dbad522af6500193e64adb889a169ac47ed5dd870a02"

  url "https://github.com/meitar/aula-driver/releases/download/v#{version}/AulaDriverApp-v#{version}.zip"
  name "Aula Driver"
  desc "macOS companion driver app for Aula F108 Pro mechanical keyboard"
  homepage "https://github.com/meitar/aula-driver"

  depends_on macos: :ventura

  app "AulaDriverApp.app"

  zap trash: [
    "~/Library/Application Support/com.aulakit.driver",
    "~/Library/Preferences/com.aulakit.driver.plist",
  ]

  caveats <<~EOS
    If macOS blocks opening "#{appdir}/AulaDriverApp.app" due to Apple Gatekeeper:
      xattr -dr com.apple.quarantine "#{appdir}/AulaDriverApp.app"
    Or install directly without quarantine:
      brew install --cask --no-quarantine meitar/tap/aula-driver
  EOS
end
