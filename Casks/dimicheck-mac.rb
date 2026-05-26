cask "dimicheck-mac" do
  version "0.1.0"
  sha256 "afa4d03fd1e157c7e454fb44f120b5781bd902005d95d755cd35724b833bb72d"

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
