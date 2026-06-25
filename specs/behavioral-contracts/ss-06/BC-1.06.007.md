---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.007: Harness Test Exists Verifying STATUS Message Parse, State Derivation, and bps Formula (Ingest BC-084)

## Description
A test section must exist in `occ-tests` that verifies StarTech STATUS message parsing for both the 29-byte (gen-1) and 35-byte (gen-2) wire formats. The test must cover: (1) correct field extraction from raw bytes; (2) adapter state derivation from parsed STATUS fields (e.g., active vs idle vs no-signal); and (3) the bits-per-second formula applied to the raw rate field. This is a v1.1.0 test-backfill requirement; the parsing existed in v1.0.0 code with no harness coverage.

## Preconditions
1. A test function (e.g., `runStatusParseTests(_:)`) is registered in `main.swift`.
2. The STATUS parse function or type is accessible from `occ-tests`.
3. Golden-byte arrays for 29-byte (gen-1) and 35-byte (gen-2) STATUS messages are embedded in the test.

## Postconditions
1. Parsing a valid 29-byte STATUS message extracts all fields correctly (specific field values verified by test vectors below).
2. Parsing a valid 35-byte STATUS message extracts all fields correctly.
3. State derivation from a "no signal" STATUS byte pattern produces `AdapterState.noSignal` (or equivalent).
4. State derivation from an "active video" STATUS byte pattern produces `AdapterState.live` (or equivalent).
5. The bps formula: `bps = rawRate * <multiplier>` (exact multiplier confirmed from source) produces the expected integer for a known rawRate input.
6. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. STATUS parse is a pure function of the byte buffer; no device I/O occurs in this test.
2. The 29-byte and 35-byte variants share the same field layout for the first 29 bytes; gen-2 adds 6 extra fields.
3. The bps multiplier is a fixed constant embedded in `StarTechSupport.swift`; it must not be changed without updating this test.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | 29-byte buffer (gen-1) | Parsed fully; no out-of-bounds access |
| EC-002 | 35-byte buffer (gen-2) | Parsed fully including extra 6 bytes |
| EC-003 | Buffer shorter than 29 bytes | Parse returns `nil` or throws; does not crash |
| EC-004 | rawRate = 0 | bps = 0 |
| EC-005 | rawRate at maximum (0xFF or 0xFFFF depending on field width) | bps = maxRawRate * multiplier (no overflow check needed for test) |
| EC-006 | STATUS byte pattern indicating no signal | `state == .noSignal` (or `.disconnected`) |
| EC-007 | STATUS byte pattern indicating active stream | `state == .live` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Golden 29-byte gen-1 STATUS (constructed from source constants) | All fields match expected values; state and bps correct | happy-path |
| Golden 35-byte gen-2 STATUS | All fields match including gen-2 extras | happy-path |
| rawRate field = 100 in golden buffer | `bps == 100 * <multiplier>` | happy-path (bps formula) |
| STATUS indicating no-signal state | `state == .noSignal` | edge (state derivation) |
| Buffer of 28 bytes | Returns nil or error; no crash | error |

## Error Handling
Short buffers must not cause index-out-of-bounds crashes. The test should verify that parsing a short buffer produces a safe `nil` or error result, not a runtime crash.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` (STATUS parse, state derivation, bps formula — exact lines TBD) |
| Ingest BC | BC-084 ("STATUS parse 29/35B; bps formula; state derivation; on-change emit") — opencrashcart-pass-3-behavioral-contracts.md |
| Stories | TBD |
| Capability Anchor Justification | STATUS message parsing and state derivation per Pass-3 BC-084 (MEDIUM confidence, code control-flow) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` |
| Confidence | MEDIUM (code control-flow; no pre-existing test) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-084) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` — STATUS parsing implementation

## Story Anchor
TBD

## VP Anchors
TBD
