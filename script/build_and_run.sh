#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HotkeyInspector"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/HotkeyInspectorLocal"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
xcodebuild -project "$ROOT_DIR/HotkeyInspector/HotkeyInspector.xcodeproj" \
  -scheme "$APP_NAME" -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" build

case "$MODE" in
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry)
    /usr/bin/open "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify)
    /usr/bin/open "$APP_BUNDLE"
    sleep 2
    pgrep -x "$APP_NAME"
    ;;
  run) /usr/bin/open "$APP_BUNDLE" ;;
esac
