cask "dimicheck-mac" do
  version "0.1.0"
  sha256 "ba0381e04c63eb5944208adeb276f186fc75874cd418ef96f24e7c6eb8a1bd01"

  url "https://github.com/DimiCheck/Dimicheck-mac/releases/download/v#{version}/DimiCheck-Mac-#{version}.dmg",
      verified: "github.com/DimiCheck/Dimicheck-mac/"
  name "DimiCheck Mac"
  desc "Menu bar companion app for DimiCheck"
  homepage "https://dimicheck.com/mac.html"

  app "DimiCheck Mac.app"

  zap trash: [
    "~/Library/Preferences/com.dimicheck.mac.plist",
  ]
end
