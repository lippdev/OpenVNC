#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -d node_modules/@novnc/novnc ] || [ ! -d node_modules/esbuild ]; then
    printf 'Dependências do visualizador ausentes. Execute npm ci --ignore-scripts primeiro.\n' >&2
    exit 1
fi
node scripts/build-viewer.mjs
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
mkdir -p "$APP/Contents/Resources/Viewer"
cp -R "$PROJECT_ROOT/target/viewer/." "$APP/Contents/Resources/Viewer/"
cp "$PROJECT_ROOT/apps/macos/.build/debug/OpenVNC" "$APP/Contents/MacOS/OpenVNC"
cp "$PROJECT_ROOT/apps/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
codesign --force --sign - "$APP"
printf 'App de desenvolvimento: %s\n' "$APP"
