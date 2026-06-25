---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.006: Harness Test Exists Verifying Firmware Search-Directory Order (Ingest BC-052)

## Description
A test section must exist in `occ-tests` that verifies the firmware search-directory priority order: profile-specified directory first, then `OCC_FIRMWARE_DIR` environment variable, then the application's persistent store directory, then `~/Library/Application Support/<vendor>`, then the vendor install directory. The test does not need to perform real filesystem I/O for every path — it must verify the ordering logic by inspecting the resolved search-path list returned before any file open is attempted. This is a v1.1.0 test-backfill requirement.

## Preconditions
1. A test function (e.g., `runFirmwareTests(_:)`) is registered in `main.swift`.
2. `StarTechFirmware` (or its search-path builder) is accessible from the `occ-tests` target.
3. The test can inject a mock profile and environment variable values to control path resolution.

## Postconditions
1. The test asserts that when a profile directory is set, it appears first in the resolved search list.
2. The test asserts that when `OCC_FIRMWARE_DIR` is set (and no profile dir), the env-var path appears first.
3. The test asserts the fallback order ends with: app-support directory, then vendor directory.
4. All path-order assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. The search-directory list is deterministic given the same profile + environment at call time.
2. No actual firmware file I/O is performed during the path-order portion of this test; path construction is pure.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Profile dir set | Profile dir is index 0 in search list |
| EC-002 | No profile dir, `OCC_FIRMWARE_DIR` set | Env-var path is index 0 |
| EC-003 | Neither profile dir nor env var | Store dir is index 0 |
| EC-004 | All defaults (no profile, no env, no store) | App-support dir, then vendor dir |
| EC-005 | Profile dir set AND `OCC_FIRMWARE_DIR` set | Profile dir wins (index 0); env-var is index 1 |

## Canonical Test Vectors
| Input | Expected search path[0] | Category |
|-------|------------------------|----------|
| `profile.firmwareDir = "/custom"` | `"/custom"` | happy-path (profile priority) |
| `OCC_FIRMWARE_DIR=/env/fw` (no profile dir) | `"/env/fw"` | happy-path (env-var priority) |
| No profile dir, no env var | store directory path | happy-path (store fallback) |
| All empty/defaults | `[storeDir, appSupportDir, vendorDir]` last three entries | happy-path (full fallback chain) |

## Error Handling
If firmware is not found in any directory, the existing `notFound` error lists all searched paths (per Pass-3 BC-053). This test does not need to cover the `notFound` error path — it covers only directory-order logic.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift` (search-path construction, exact lines TBD) |
| Ingest BC | BC-052 ("firmware search order (profile→env→store→app-support→vendor)") — opencrashcart-pass-3-behavioral-contracts.md |
| Stories | TBD |
| Capability Anchor Justification | Firmware search-directory ordering per Pass-3 BC-052 (MEDIUM confidence, code control-flow) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift` |
| Confidence | MEDIUM (code control-flow; no pre-existing test) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-052) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift` — firmware discovery implementation

## Story Anchor
TBD

## VP Anchors
TBD
