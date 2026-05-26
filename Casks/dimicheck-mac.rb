cask "dimicheck-mac" do
  version "0.1.0"
  sha256 "ebe8e4c1c575f2676f0942a9b0ecfb38b7f236de58e45da3db7578a7322321ca"

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
