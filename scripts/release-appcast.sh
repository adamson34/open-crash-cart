#!/bin/bash
# Sign a release archive with the Sparkle EdDSA key and (re)generate the appcast feed.
#
# Usage:  scripts/release-appcast.sh <path-to-OpenCrashCart.zip> [--dev]
#           --dev   tag this update for the 'dev' channel, so only users who enabled
#                   "Receive dev (beta) builds" in Settings are offered it.
#
# generate_appcast reads the private signing key from your login Keychain automatically
# (created by `generate_keys`), signs the archive, and writes/updates appcast.xml.
#
# The zips + appcast.xml land in dist/updates/. Publish that folder to GitHub Pages (repo
# root of the Pages site) so it is served at the SUFeedURL in packaging/Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

ZIP="${1:?usage: release-appcast.sh <path-to-OpenCrashCart.zip> [--dev]}"
CHANNEL_ARGS=()
[ "${2:-}" = "--dev" ] && CHANNEL_ARGS=(--channel dev)

# Keep this in sync with SUFeedURL's host in packaging/Info.plist.
PAGES_URL="https://adamson34.github.io/open-crash-cart"
REPO_URL="https://github.com/adamson34/open-crash-cart"
UPDATES_DIR="$ROOT/dist/updates"

GEN="$(find "$ROOT/.build/artifacts" -type f -name generate_appcast -perm -u+x -print -quit)"
[ -n "$GEN" ] || { echo "✗ generate_appcast not found — run 'swift build' first."; exit 1; }

mkdir -p "$UPDATES_DIR"
cp "$ZIP" "$UPDATES_DIR/"

echo "▸ Signing + generating appcast${CHANNEL_ARGS:+ (channel: dev)}…"
"$GEN" \
    --download-url-prefix "$PAGES_URL/" \
    --link "$REPO_URL" \
    "${CHANNEL_ARGS[@]}" \
    "$UPDATES_DIR"

echo "✓ appcast written to dist/updates/appcast.xml"
echo "  Publish the contents of dist/updates/ (appcast.xml + *.zip) to GitHub Pages so it is"
echo "  served at $PAGES_URL/appcast.xml"
