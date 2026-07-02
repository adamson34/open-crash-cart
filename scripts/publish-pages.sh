#!/bin/bash
# Publish the generated Sparkle appcast + release archives to the gh-pages branch, which
# GitHub Pages serves at the SUFeedURL host (https://adamson34.github.io/open-crash-cart/).
#
# Run scripts/release-appcast.sh first to populate dist/updates/. Then:
#   scripts/publish-pages.sh
#
# It checks out gh-pages in a throwaway worktree under .build/, overlays the appcast + any
# archives from dist/updates/, commits, and pushes. Existing files (index.html, past releases)
# are preserved — this only adds/updates, never deletes published archives.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BRANCH="gh-pages"
WORKTREE="$ROOT/.build/gh-pages"
UPDATES_DIR="$ROOT/dist/updates"
FEED_URL="https://adamson34.github.io/open-crash-cart/appcast.xml"

[ -f "$UPDATES_DIR/appcast.xml" ] || {
    echo "✗ $UPDATES_DIR/appcast.xml not found — run scripts/release-appcast.sh first."; exit 1; }

echo "▸ Fetching ${BRANCH}…"
git fetch -q origin "$BRANCH"

# Fresh worktree checkout of gh-pages (lives under .build/, which is git-ignored).
git worktree remove --force "$WORKTREE" 2>/dev/null || true
git worktree prune
rm -rf "$WORKTREE"
git worktree add -q --force -B "$BRANCH" "$WORKTREE" "origin/$BRANCH"
cleanup() { git worktree remove --force "$WORKTREE" 2>/dev/null || true; }
trap cleanup EXIT

echo "▸ Overlaying appcast + archives…"
cp "$UPDATES_DIR/appcast.xml" "$WORKTREE/"
find "$UPDATES_DIR" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.dmg' -o -name '*.delta' \) \
    -exec cp {} "$WORKTREE/" \;
touch "$WORKTREE/.nojekyll"

git -C "$WORKTREE" add -A
if git -C "$WORKTREE" diff --cached --quiet; then
    echo "✓ Nothing changed — feed already up to date."
    exit 0
fi
git -C "$WORKTREE" commit -q -m "Publish appcast update ($(date -u +%Y-%m-%dT%H:%MZ))"
git -C "$WORKTREE" push -q origin "$BRANCH"

echo "✓ Published to $BRANCH"
echo "  Live shortly at $FEED_URL"
