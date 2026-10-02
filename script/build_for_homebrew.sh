#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE_DIR="${1:?Homebrew staging directory is required}"
BUILD_DIR="$(mktemp -d /private/tmp/hotkey-inspector-build.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT

# A full Xcode installation is required for SwiftUI and the macOS 27 SDK.
xcodebuild -project "$ROOT_DIR/HotkeyInspector/HotkeyInspector.xcodeproj" \
  -scheme HotkeyInspector -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" CODE_SIGN_IDENTITY=- build

ditto "$BUILD_DIR/Build/Products/Release/HotkeyInspector.app" "$STAGE_DIR/HotkeyInspector.app"
codesign --verify --deep --strict "$STAGE_DIR/HotkeyInspector.app"
