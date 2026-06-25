---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/USB/USBDevice.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.004: Harness Test Exists Verifying USB libusb Return-Code to Error Mapping (Ingest BC-021)

## Description
A test named `testUSBReturnCodeMapping` (or equivalent) must exist in the `occ-tests` harness and pass. The test exercises the mapping from raw `libusb_error` integer return codes to the project's `USBError` domain: `0` maps to success (no error thrown), `-7` (`LIBUSB_ERROR_TIMEOUT`) maps to `USBError.timeout`, `-4` (`LIBUSB_ERROR_NO_DEVICE`) maps to `USBError.disconnected`, and any other negative value maps to `USBError.transferFailed`. This is a v1.1.0 test-backfill requirement; the mapping existed in v1.0.0 code but had no harness coverage.

## Preconditions
1. `Sources/occ-tests/` contains a file (e.g., `USBTests.swift`) registering a test function via `runUSBTests(_:)` called from `main.swift`.
2. The `OCCKit` USB layer exposes a testable mapping function or its logic is invocable from the test target.

## Postconditions
1. A section labeled (e.g.) `"USB return-code mapping"` executes inside `occ-tests`.
2. Assertions verify:
   - rc `0` → no error / `nil` error result.
   - rc `-7` → `USBError.timeout`.
   - rc `-4` → `USBError.disconnected`.
   - rc `-1` (LIBUSB_ERROR_IO, representative "other") → `USBError.transferFailed`.
   - rc `-99` (arbitrary unrecognised value) → `USBError.transferFailed`.
3. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. The mapping is a pure function of the integer rc; no device I/O occurs in the test.
2. The test must remain passing on every subsequent push (CI gate enforced by BC-1.06.002).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | rc = 0 | Maps to success (no error) |
| EC-002 | rc = -7 | Maps to `USBError.timeout` |
| EC-003 | rc = -4 | Maps to `USBError.disconnected` |
| EC-004 | rc = -1 | Maps to `USBError.transferFailed` |
| EC-005 | rc = -99 (arbitrary unknown negative) | Maps to `USBError.transferFailed` (catch-all) |

## Canonical Test Vectors
| Input (libusb rc) | Expected `USBError` | Category |
|-------------------|---------------------|----------|
| `0` | `nil` (success) | happy-path |
| `-7` | `USBError.timeout` | happy-path |
| `-4` | `USBError.disconnected` | happy-path |
| `-1` | `USBError.transferFailed` | edge (known LIBUSB_ERROR_IO) |
| `-99` | `USBError.transferFailed` | edge (unrecognised code) |

## Error Handling
If this test does not exist or fails, `swift run occ-tests` exits 1, blocking CI. The absence of this test in v1.0.0 is the gap being closed; shipping v1.1.0 without this test present is a policy violation (see BC-1.06.010).

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/USB/USBDevice.swift` (rc mapping constants, exact lines TBD pending read) |
| Ingest BC | BC-021 (opencrashcart-pass-3-behavioral-contracts.md: "libusb rc map: 0 ok, -7 timeout, -4 disconnected, else transferFailed. HIGH constants") |
| Stories | TBD |
| Capability Anchor Justification | USB error mapping per Pass-3 BC-021 (HIGH confidence, constant-grounded) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/USB/USBDevice.swift` |
| Confidence | HIGH (constants, Pass-3 BC-021) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code constants (return-code map) |

## Related BCs
- BC-1.06.001 — harness infrastructure this test runs within (depends on)
- BC-1.06.010 — coverage policy requiring this test ships with v1.1.0 (depends on)

## Architecture Anchors
- `Sources/OCCKit/USB/USBDevice.swift` — libusb rc mapping implementation
- `Sources/occ-tests/` — test target where new test file is added

## Story Anchor
TBD

## VP Anchors
TBD
