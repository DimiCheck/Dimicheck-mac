cask "dimicheck-mac" do
  version "0.1.1"
  sha256 "afe640f7b6c2525f1bb88723c355e013d610829ea818c118c32124a5b0d92963"

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
