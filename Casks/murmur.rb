cask "murmur" do
  version :latest
  sha256 :no_check

  url "https://github.com/jwafle/murmur/releases/latest/download/Murmur.dmg"
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
