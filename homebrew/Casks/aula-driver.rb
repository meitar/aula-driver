cask "aula-driver" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256"

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
end
