#!/usr/bin/env bash
# Code coverage for the occ-tests suite over the OCCKit core library.
#
# Hardware-I/O paths (USB transport, UVC capture) and the AppKit UI need real devices / a running
# app, so they aren't unit-testable here — coverage focuses on OCCKit's pure logic (codec, wire
# protocol, HID mapping, profiles, firmware resolution, gzip).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --enable-code-coverage
BIN=.build/debug/occ-tests
COV=.build/debug/codecov
mkdir -p "$COV"

LLVM_PROFILE_FILE="$COV/occ-tests.profraw" "$BIN" >/dev/null
xcrun llvm-profdata merge -sparse "$COV/occ-tests.profraw" -o "$COV/occ-tests.profdata"

# Exclude the test sources, the AppKit UI, the CLIs, and build artifacts from the report.
IGNORE='(occ-tests|Sources/occ/|occ-probe|occ-connect|\.build)'

xcrun llvm-cov report "$BIN" -instr-profile="$COV/occ-tests.profdata" -ignore-filename-regex="$IGNORE"

TOTAL=$(xcrun llvm-cov export "$BIN" -instr-profile="$COV/occ-tests.profdata" \
        -ignore-filename-regex="$IGNORE" -summary-only \
        | python3 -c 'import sys,json; print("%.1f" % json.load(sys.stdin)["data"][0]["totals"]["lines"]["percent"])')
echo ""
echo "OCCKit line coverage: ${TOTAL}%"

# When running in GitHub Actions, surface the number on the run page.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "### Code coverage (OCCKit core): **${TOTAL}%** lines" >> "$GITHUB_STEP_SUMMARY"
fi
