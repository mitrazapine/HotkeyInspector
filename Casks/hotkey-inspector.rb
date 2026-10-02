cask "hotkey-inspector" do
  version :latest
  sha256 :no_check

  url "https://github.com/mitrazapine/HotkeyInspector/archive/refs/heads/main.tar.gz"
  name "Hotkey Inspector"
  desc "Inspect application shortcuts and configured macOS hotkeys"
  homepage "https://github.com/mitrazapine/HotkeyInspector"

  depends_on macos: :golden_gate

  installer script: {
    executable: "/bin/bash",
    args:       ["#{staged_path}/HotkeyInspector-main/script/build_for_homebrew.sh", staged_path.to_s],
  }

  app "HotkeyInspector.app"

  caveats <<~EOS
    Builds from source. A full installation of Xcode 27 or later is required.
    Grant Accessibility for menu reading and Input Monitoring for the optional monitor.
  EOS
end
