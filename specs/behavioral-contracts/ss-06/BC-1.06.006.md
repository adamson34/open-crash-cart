---
document_type: behavioral-contract
level: L3
version: "1.1"
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
A test section must exist in `occ-tests` that verifies the full 7-tier firmware search-directory priority order. The real implementation (`StarTechFirmware.searchDirectories`, lines 32-47) calls `ProfileStore.shared` — an un-mockable singleton reading real user paths — making it untestable as-is from `occ-tests`. The fix is to extract a pure, injectable function that the real `searchDirectories` delegates to. The test then calls the pure function with injected values and asserts the exact 7-tier ordering. This is a v1.1.0 test-backfill requirement.

## Preconditions
1. A test function (e.g., `runFirmwareTests(_:)`) is registered in `main.swift`.
2. **Public-API delta required:** Extract a new `public static func firmwareSearchPaths(profileDir: String?, env: String?, storeDir: String?, appSupportDir: String, vendorPaths: [String]) -> [String]` from `StarTechFirmware` in `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift`. The existing `static func searchDirectories(extra:)` must be refactored to call this pure function with its live inputs (`ProcessInfo.processInfo.environment["OCC_FIRMWARE_DIR"]`, `ProfileStore.shared.firmwareDirectory`, `ProfileStore.shared.applicationSupportFirmwareDir`). Without this extraction the `occ-tests` target cannot test path ordering without touching the filesystem or `ProfileStore.shared`.
3. The test injects all path inputs directly; no filesystem access and no `ProfileStore.shared` call occurs in the test path.

## Postconditions
The pure `firmwareSearchPaths(profileDir:env:storeDir:appSupportDir:vendorPaths:)` function returns paths in exactly this 7-tier order (matching `StarTechFirmware.swift:32-47`):

| Tier | Input parameter | Condition |
|------|----------------|-----------|
| 1 | `profileDir` | included if non-nil and non-empty |
| 2 | `env` (`OCC_FIRMWARE_DIR`) | included if non-nil and non-empty |
| 3 | `storeDir` (`ProfileStore.shared.firmwareDirectory`) | included if non-nil and non-empty |
| 4 | `appSupportDir` (`ProfileStore.shared.applicationSupportFirmwareDir`) | always included |
| 5 | `/Applications/USB Crash Cart Adapter.app/Contents/Resources/data` | always included (from `vendorPaths[0]`) |
| 6 | `~/data` | always included (from `vendorPaths[1]`) |
| 7 | `~/Library/Application Support/USB Crash Cart Adapter/data` | always included (from `vendorPaths[2]`) |

Assertions verified by test:
1. When `profileDir = "/custom"`, it appears at index 0 in the result.
2. When `env = "/env/fw"` and `profileDir = nil`, the env path appears at index 0.
3. When `profileDir = "/custom"` AND `env = "/env/fw"`, profileDir is index 0 and env is index 1.
4. The last three entries are always the three vendor paths (indexes -3, -2, -1).
5. The full canonical 7-element vector (all inputs provided) matches the exact order above.
6. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. The search-directory list is deterministic given the same injected inputs.
2. No filesystem I/O, no `ProcessInfo` access, and no `ProfileStore.shared` access occur in the pure function.
3. The real `searchDirectories(extra:)` is the only caller of `firmwareSearchPaths` with live inputs; tests call it with injected values only.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `profileDir` is non-nil, non-empty | Profile dir is index 0 in result |
| EC-002 | `profileDir` nil, `env` non-nil | Env path is index 0 |
| EC-003 | `profileDir` nil, `env` nil, `storeDir` non-nil | Store dir is index 0 |
| EC-004 | All optional inputs nil/empty | Result is `[appSupportDir] + vendorPaths` (4 items) |
| EC-005 | `profileDir` AND `env` both set | Profile dir wins index 0; env is index 1 |
| EC-006 | `storeDir` is empty string | Excluded from result (same as nil) |

## Canonical Test Vectors
| profileDir | env | storeDir | appSupportDir | vendorPaths | Expected result (ordered list) |
|-----------|-----|----------|--------------|-------------|-------------------------------|
| `"/custom"` | `"/env/fw"` | `"/store"` | `"/appsup"` | `["/app/data","~/data","~/lib/data"]` | `["/custom","/env/fw","/store","/appsup","/app/data","~/data","~/lib/data"]` |
| `nil` | `"/env/fw"` | `"/store"` | `"/appsup"` | `["/app/data","~/data","~/lib/data"]` | `["/env/fw","/store","/appsup","/app/data","~/data","~/lib/data"]` |
| `nil` | `nil` | `nil` | `"/appsup"` | `["/app/data","~/data","~/lib/data"]` | `["/appsup","/app/data","~/data","~/lib/data"]` |
| `"/custom"` | `nil` | `nil` | `"/appsup"` | `["/app/data","~/data","~/lib/data"]` | `["/custom","/appsup","/app/data","~/data","~/lib/data"]` |

## Error Handling
If firmware is not found in any directory, the existing `notFound` error lists all searched paths (per Pass-3 BC-053). This test covers only directory-order logic via the pure extracted function; not-found error behavior is outside scope.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift:32-47` (`searchDirectories` — full 7-tier implementation); `:37` (`ProfileStore.shared` singleton — un-mockable, motivating extraction) |
| Ingest BC | BC-052 ("firmware search order (profile→env→store→app-support→vendor)") — opencrashcart-pass-3-behavioral-contracts.md |
| Public-API delta | Extract `public static func firmwareSearchPaths(profileDir:env:storeDir:appSupportDir:vendorPaths:) -> [String]` from `searchDirectories(extra:)` |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — firmware search-directory ordering per Pass-3 BC-052; capability ID to be assigned after capabilities.md is updated |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift` |
| Confidence | HIGH (7 tiers read directly from lines 32-47) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-052) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift:32-47` — firmware discovery implementation

## Story Anchor
TBD

## VP Anchors
TBD
