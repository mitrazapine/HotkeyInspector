class HotkeyInspector < Formula
  desc "Inspect application shortcuts and configured macOS hotkeys"
  homepage "https://github.com/mitrazapine/HotkeyInspector"
  head "https://github.com/mitrazapine/HotkeyInspector.git", branch: "main"

  depends_on xcode: ["27.0", :build]
  depends_on macos: :golden_gate

  skip_clean "HotkeyInspector.app"

  def install
    xcodebuild "-project", "HotkeyInspector/HotkeyInspector.xcodeproj",
               "-scheme", "HotkeyInspector",
               "-configuration", "Release",
               "-destination", "platform=macOS",
               "-derivedDataPath", buildpath/"build",
               "CODE_SIGN_IDENTITY=-",
               "build"

    prefix.install buildpath/"build/Build/Products/Release/HotkeyInspector.app"
    (bin/"hotkey-inspector").write <<~SH
      #!/bin/bash
      if [ "${1:-}" = "--version" ]; then
        exec /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "#{opt_prefix}/HotkeyInspector.app/Contents/Info.plist"
      fi
      exec /usr/bin/open "#{opt_prefix}/HotkeyInspector.app" --args "$@"
    SH
  end

  test do
    assert_path_exists prefix/"HotkeyInspector.app/Contents/Resources/AppIcon.icns"
    assert_equal "1.0", shell_output("#{bin}/hotkey-inspector --version").strip
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", prefix/"HotkeyInspector.app"
  end
end
