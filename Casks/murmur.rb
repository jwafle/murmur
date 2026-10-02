cask "murmur" do
  version "0.0.2"
  sha256 "ca05215570524157e702ac28045201700ea88f17c9a0f764be3504b48f0fb98a"

  url "https://github.com/jwafle/murmur/releases/download/v#{version}/Murmur.dmg"
  name "Murmur"
  desc "Native macOS local dictation app"
  homepage "https://github.com/jwafle/murmur"

  depends_on arch: :arm64
  depends_on macos: ">= :tahoe"

  app "Murmur.app"

  caveats <<~EOS
    Murmur needs Microphone permission and Accessibility permission for its
    global shortcut and simulated paste. Grant these in System Settings.
  EOS

  zap trash: ["~/Library/Application Support/Murmur"]
end
