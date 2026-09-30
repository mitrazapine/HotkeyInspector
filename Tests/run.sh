#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/hotkey-inspector-tests.XXXXXX)
xcrun swiftc -module-cache-path "$test_dir/ModuleCache" \
    HotkeyInspector/HotkeyInspector/Hotkey.swift \
    HotkeyInspector/HotkeyInspector/MenuSelectionCopy.swift \
    HotkeyInspector/HotkeyInspector/SystemHotkey.swift \
    Tests/HotkeyTests.swift Tests/SystemHotkeyTests.swift \
    -o "$test_dir/HotkeyTests"
"$test_dir/HotkeyTests"
