---
document_type: behavioral-contract
level: L3
version: "1.1"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-06"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.007: Harness Test Exists Verifying STATUS bps Formula and State Derivation (Ingest BC-084)

## Description
A test section must exist in `occ-tests` that verifies two pure computations from StarTech STATUS message parsing: (1) the bytes-per-second formula `bytesPerSecond = ticks > 0 ? Double(words) * 16.0 * 1000.0 / Double(ticks) : 0` (StarTechAdapter.swift:394); and (2) the `AdapterState` derivation from the parsed STATUS fields (`noVideo`, `fpgaLoaded`, `width`, `height`, `hz`). The `parseStatus` function itself is `private`; the fix is to extract both computations as pure public functions. The valid states are `.live(width:height:hz:)`, `.connecting`, and `.noVideo(NoVideoReason)` — there is no `.noSignal` state (prior spec drafts were wrong). This is a v1.1.0 test-backfill requirement.

## Preconditions
1. A test function (e.g., `runStatusParseTests(_:)`) is registered in `main.swift`.
2. **Public-API delta required — two extractions:**
   - `public static func computeBytesPerSecond(words: UInt32, ticks: UInt16) -> Double` extracted from `StarTechAdapter` (or a public support type). Implements: `ticks > 0 ? Double(words) * 16.0 * 1000.0 / Double(ticks) : 0`.
   - `public static func deriveState(fpgaLoaded: UInt8, noVideo: UInt8, width: Int, height: Int, hz: Int) -> AdapterState` extracted from the state-derivation logic at `StarTechAdapter.swift:378-386`. Implements: if `NoVideoReason(rawValue: noVideo) != .ok` → `.noVideo(reason)`; else if `fpgaLoaded != 0 && width > 0 && height > 0` → `.live(width:height:hz:)`; else → `.connecting`.
3. `AdapterState` and `NoVideoReason` are already `public` (defined in `Sources/OCCKit/Adapter/Types.swift:73-83`).

## Postconditions
1. `computeBytesPerSecond(words:ticks:)` satisfies:
   - `words=500, ticks=1000` → `500.0 * 16.0 * 1000.0 / 1000.0 = 8000.0`
   - `words=0, ticks=0` → `0.0`
   - `words=100, ticks=0` → `0.0` (ticks=0 guard)
   - `words=1000, ticks=2000` → `8000.0`
2. `deriveState(fpgaLoaded:noVideo:width:height:hz:)` satisfies:
   - `fpgaLoaded=1, noVideo=0, width=1920, height=1080, hz=60` → `.live(width:1920, height:1080, hz:60)`
   - `fpgaLoaded=0, noVideo=0, width=0, height=0, hz=0` → `.connecting`
   - `fpgaLoaded=1, noVideo=<non-.ok raw value>, width=any, height=any, hz=any` → `.noVideo(reason)`
3. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. Both functions are pure: no device I/O, no mutable state, no `private` access required.
2. The state set is exactly `{.disconnected, .connecting, .noVideo(NoVideoReason), .live(width:height:hz:)}` — `.noSignal` is NOT a valid state in this codebase.
3. The bps formula constant `16.0 * 1000.0` is derived from the source at `StarTechAdapter.swift:394` and must not be changed without updating this contract.
4. `ticks == 0` always produces `0.0` (guard prevents division by zero).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `ticks = 0`, any `words` | `computeBytesPerSecond` returns `0.0` |
| EC-002 | `words = 0`, `ticks > 0` | Returns `0.0` |
| EC-003 | `ticks = 1` (minimum non-zero) | Returns `Double(words) * 16000.0` |
| EC-004 | `fpgaLoaded = 0` (FPGA not loaded) | `deriveState` returns `.connecting` regardless of width/height/hz |
| EC-005 | `noVideo` raw value maps to `.ok` | State determined by `fpgaLoaded` + dimensions |
| EC-006 | `noVideo` raw value maps to non-`.ok` `NoVideoReason` | Returns `.noVideo(reason)` regardless of dimensions |
| EC-007 | `fpgaLoaded = 1`, `width = 0` | Returns `.connecting` (not `.live` because width not positive) |

## Canonical Test Vectors
| Function | Input | Expected Output | Category |
|----------|-------|----------------|----------|
| `computeBytesPerSecond` | `words=500, ticks=1000` | `8000.0` | happy-path |
| `computeBytesPerSecond` | `words=1000, ticks=2000` | `8000.0` | happy-path |
| `computeBytesPerSecond` | `words=100, ticks=0` | `0.0` | edge (ticks=0 guard) |
| `computeBytesPerSecond` | `words=0, ticks=0` | `0.0` | edge |
| `deriveState` | `fpgaLoaded=1, noVideo=0, width=1920, height=1080, hz=60` | `.live(width:1920, height:1080, hz:60)` | happy-path |
| `deriveState` | `fpgaLoaded=0, noVideo=0, width=0, height=0, hz=0` | `.connecting` | happy-path |
| `deriveState` | `fpgaLoaded=1, noVideo=<non-.ok>, width=1920, height=1080, hz=60` | `.noVideo(reason)` | edge (noVideo set) |
| `deriveState` | `fpgaLoaded=1, noVideo=0, width=0, height=0, hz=0` | `.connecting` | edge (zero dimensions) |

## Error Handling
Both functions are total (no throws, no crashes). Short-buffer handling is in `parseStatus` (which returns early on unexpected size) — that is outside scope of this contract, which covers only the extracted pure computations.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:394` (bps formula); `:378-386` (state derivation); `Sources/OCCKit/Adapter/Types.swift:73-83` (`AdapterState`, `NoVideoReason` definitions) |
| Ingest BC | BC-084 ("STATUS parse 29/35B; bps formula; state derivation; on-change emit") — opencrashcart-pass-3-behavioral-contracts.md |
| Public-API delta | Extract `public static func computeBytesPerSecond(words:ticks:) -> Double` and `public static func deriveState(fpgaLoaded:noVideo:width:height:hz:) -> AdapterState` |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — STATUS message parsing and state derivation per Pass-3 BC-084; capability ID assigned in the architecture phase |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` |
| Confidence | HIGH (formula and state logic read directly from lines 378-394) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-084) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:378-394` — state derivation and bps formula
- `Sources/OCCKit/Adapter/Types.swift:73-83` — `AdapterState` and `NoVideoReason` enum definitions

## Story Anchor
TBD

## VP Anchors
TBD
