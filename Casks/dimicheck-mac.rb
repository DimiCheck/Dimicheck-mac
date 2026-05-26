cask "dimicheck-mac" do
  version "0.1.0"
  sha256 "8fc4c7f4f9a5740b38488323dc147560fdbafc09fdbf6bf1febca3c8bb65f5fd"

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
