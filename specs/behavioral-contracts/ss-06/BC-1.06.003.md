---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "scripts/make-app.sh"
subsystem: "SS-06"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# BC-1.06.003: App Bundle Is Self-Contained, Ad-Hoc Signed, and Quarantine-Clearable

## Description
`scripts/make-app.sh` produces a `dist/OpenCrashCart.app` bundle that embeds its `libusb` dylib inside `Contents/Frameworks/`, rewrites the binary's rpath to `@executable_path/../Frameworks`, and ad-hoc code-signs both the framework and the app itself. The result is a double-clickable macOS application that launches from Finder without needing a separate libusb installation, and that macOS Gatekeeper can clear of quarantine because a valid (ad-hoc) signature is present.

## Preconditions
1. `swift build -c release` has completed successfully, producing `.build/release/occ`.
2. `libusb` is installed at a Homebrew path resolvable by `otool -L`.
3. `codesign` is available (Xcode Command Line Tools).
4. `packaging/Info.plist` exists at the repository root.
5. The script is executed from the repository root (or from `scripts/` — the script `cd`s to root).

## Postconditions
1. `dist/OpenCrashCart.app/Contents/MacOS/occ` is present and executable.
2. `dist/OpenCrashCart.app/Contents/Frameworks/libusb-1.0.0.dylib` is present.
3. The binary's `@rpath` for libusb resolves to `@executable_path/../Frameworks/libusb-1.0.0.dylib` (verified by `otool -l`).
4. `codesign --verify dist/OpenCrashCart.app` exits 0 (valid ad-hoc signature on the app).
5. `codesign --verify dist/OpenCrashCart.app/Contents/Frameworks/libusb-1.0.0.dylib` exits 0.
6. `xattr -d com.apple.quarantine dist/OpenCrashCart.app` can be run without error (quarantine attribute removable).
7. `open dist/OpenCrashCart.app` launches the app without a "damaged or unidentified developer" error when quarantine is cleared.

## Invariants
1. The app bundle contains exactly one copy of libusb — the one extracted at build time; no external dylib path is used at runtime.
2. Ad-hoc signing (`-s -`) is used, not a Developer ID; the signature is valid for local use but will not pass Notarization.
3. The script is idempotent: re-running it removes and recreates `dist/OpenCrashCart.app`.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | libusb not installed | `otool` produces empty output; script errors out at `cp "$DYLIB"` with a non-zero exit (set -e active) |
| EC-002 | Icon generation (`makeicon.swift`) fails | Script continues; `AppIcon.icns` absent; app still launches without a custom icon |
| EC-003 | `dist/` directory does not exist | `mkdir -p` creates it; script succeeds |
| EC-004 | App already exists in `dist/` | `rm -rf "$APP"` removes it cleanly before rebuild |
| EC-005 | Running on Intel Mac | `otool` finds `/usr/local/lib/libusb...`; rpath rewrite succeeds identically |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Clean repo + libusb installed via brew | `dist/OpenCrashCart.app` present; `codesign --verify` exits 0; `otool -L .../occ` shows `@rpath/libusb-1.0.0.dylib` | happy-path |
| Run script twice in succession | Second run produces identical bundle; no file-already-exists error | idempotency |
| `makeicon.swift` Swift error (non-fatal) | Script prints `(icon generation skipped)` and continues to signed bundle | edge (icon skip) |

## Error Handling
The script runs under `set -euo pipefail`; any unexpected non-zero command exits the script immediately. The known graceful exception is icon generation failure, which is wrapped in `if swift ... 2>/dev/null; then ... else echo "(icon generation skipped)"; fi`.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `scripts/make-app.sh:1-54`, `packaging/Info.plist` |
| Ingest BC | (bundle/packaging infrastructure) |
| Stories | TBD |
| Capability Anchor Justification | App bundle self-containment per Pass-0 inventory §Tech Stack (Packaging: scripts/make-app.sh bundles libusb, ad-hoc signs) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `scripts/make-app.sh` |
| Confidence | HIGH (direct code read, complete file) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code (packaging script) |

## Related BCs
- BC-1.06.002 — CI gate that validates the build producing the binary (depends on)

## Architecture Anchors
- `scripts/make-app.sh` — bundle assembly script
- `packaging/Info.plist` — bundle metadata

## Story Anchor
TBD

## VP Anchors
TBD
