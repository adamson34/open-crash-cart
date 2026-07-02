#!/bin/bash
# Build OpenCrashCart.app — a self-contained, double-clickable macOS app bundle.
# Bundles libusb + Sparkle inside Contents/Frameworks, generates an icon, writes Info.plist,
# and code-signs so it launches from Finder.
#
# Signing identity defaults to ad-hoc (-). For a distributable/notarizable build, pass a
# Developer ID:  OCC_SIGN_ID="Developer ID Application: Your Name (TEAMID)" scripts/make-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/dist/OpenCrashCart.app"
SIGN_ID="${OCC_SIGN_ID:--}"                       # "-" = ad-hoc
SIGN_FLAGS=(--force -s "$SIGN_ID")
[ "$SIGN_ID" != "-" ] && SIGN_FLAGS+=(--options runtime --timestamp)   # hardened runtime for notarization

echo "▸ Building release binary…"
swift build -c release >/dev/null

echo "▸ Assembling bundle at dist/OpenCrashCart.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$ROOT/.build/release/occ" "$APP/Contents/MacOS/occ"
cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"

echo "▸ Bundling libusb…"
DYLIB="$(otool -L "$APP/Contents/MacOS/occ" | awk '/libusb/{print $1; exit}')"
cp "$DYLIB" "$APP/Contents/Frameworks/libusb-1.0.0.dylib"
chmod u+w "$APP/Contents/Frameworks/libusb-1.0.0.dylib"
install_name_tool -id @rpath/libusb-1.0.0.dylib "$APP/Contents/Frameworks/libusb-1.0.0.dylib"
install_name_tool -change "$DYLIB" @rpath/libusb-1.0.0.dylib "$APP/Contents/MacOS/occ"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/occ"

echo "▸ Generating icon…"
if swift "$ROOT/packaging/makeicon.swift" /tmp/occ-icon.png 2>/dev/null; then
    ICONSET=/tmp/OpenCrashCart.iconset
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z "$s" "$s" /tmp/occ-icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z "$d" "$d" /tmp/occ-icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
else
    echo "  (icon generation skipped)"
fi

echo "▸ Code-signing (ad-hoc)…"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/libusb-1.0.0.dylib"

echo "▸ Bundling Sparkle.framework…"
SPARKLE_FW="$(find "$ROOT/.build/artifacts" -type d -path '*/Sparkle.xcframework/macos-*/Sparkle.framework' -print -quit)"
if [ -n "$SPARKLE_FW" ]; then
    ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
    FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
    # Sign inside-out: nested helpers first, then the framework.
    codesign "${SIGN_FLAGS[@]}" "$FW/XPCServices/Downloader.xpc"
    codesign "${SIGN_FLAGS[@]}" "$FW/XPCServices/Installer.xpc"
    codesign "${SIGN_FLAGS[@]}" "$FW/Autoupdate"
    codesign "${SIGN_FLAGS[@]}" "$FW/Updater.app"
    codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
else
    echo "  ⚠ Sparkle.framework not found under .build/artifacts — run 'swift build' first."
    echo "    Auto-update will be unavailable in this bundle."
fi

# Sign the app last so its seal covers the embedded frameworks.
codesign "${SIGN_FLAGS[@]}" "$APP"

echo "✓ Built $APP"
echo "  Open with:  open dist/OpenCrashCart.app    (or double-click it in Finder)"
