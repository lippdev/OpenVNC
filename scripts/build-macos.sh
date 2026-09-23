#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

cargo build --offline
swift build --package-path apps/macos \
    --scratch-path "$PROJECT_ROOT/apps/macos/.build" \
    --cache-path "$PROJECT_ROOT/apps/macos/.build/cache" \
    --disable-sandbox \
    -Xswiftc -module-cache-path -Xswiftc "$PROJECT_ROOT/apps/macos/.build/module-cache" \
    -Xlinker "$PROJECT_ROOT/target/debug/libopenvnc_core.a" \
    -Xlinker -liconv

APP="$PROJECT_ROOT/dist/OpenVNC.app"
mkdir -p "$APP/Contents/MacOS"
cp "$PROJECT_ROOT/apps/macos/.build/debug/OpenVNC" "$APP/Contents/MacOS/OpenVNC"
cp "$PROJECT_ROOT/apps/macos/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'App de desenvolvimento: %s\n' "$APP"
