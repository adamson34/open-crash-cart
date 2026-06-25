---
document_type: behavioral-contract
level: L3
version: "1.1"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/USB/USBDevice.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.004: Harness Test Exists Verifying USB libusb Return-Code to USBTransportError Mapping (Ingest BC-021)

## Description
A test named `testUSBReturnCodeMapping` (or equivalent) must exist in the `occ-tests` harness and pass. The test exercises a pure public function `USBDevice.mapLibusbResult(_:) -> USBTransportError?` that maps raw `libusb_error` integer return codes to the project's `USBTransportError` domain. The mapping is: rc `0` → `nil` (no error); rc `-7` (`LIBUSB_ERROR_TIMEOUT`) → `.timeout`; rc `-4` (`LIBUSB_ERROR_NO_DEVICE`) → `.disconnected`; any other non-zero value → `.transferFailed(rc)`. This is a v1.1.0 test-backfill requirement; the mapping logic existed in v1.0.0 (inside `private func check(_:)`) but had no harness coverage and used the wrong error type name in prior spec drafts.

## Preconditions
1. `Sources/occ-tests/` contains a file (e.g., `USBTests.swift`) registering a test function via a call from `main.swift`.
2. **Public-API delta required:** `USBDevice` in `Sources/OCCKit/USB/USBDevice.swift` must expose a new `public static func mapLibusbResult(_ rc: Int32) -> USBTransportError?` that encapsulates the logic currently in `private func check(_:)` (lines 120-127). The existing `check` may delegate to it internally. Without this extraction the `occ-tests` target (plain `import OCCKit`, no `@testable`) cannot invoke the mapping logic.
3. The error type under test is `USBTransportError` (defined at `USBDevice.swift:4-23`), NOT a type called `USBError` (which does not exist in the codebase).

## Postconditions
1. A test section (e.g., `t.section("USB return-code mapping")`) executes inside `occ-tests`.
2. Assertions verify:
   - `mapLibusbResult(0)` returns `nil` (no error / success).
   - `mapLibusbResult(-7)` returns `.timeout`.
   - `mapLibusbResult(-4)` returns `.disconnected`.
   - `mapLibusbResult(-1)` (LIBUSB_ERROR_IO, representative "other") returns `.transferFailed(-1)`.
   - `mapLibusbResult(-99)` (arbitrary unrecognised negative) returns `.transferFailed(-99)`.
3. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. The mapping is a pure function of the integer rc; no device I/O occurs in the test.
2. The error type is `USBTransportError` — no type alias or renamed enum may be introduced solely to satisfy this contract.
3. The test must remain passing on every subsequent push (CI gate enforced by BC-1.06.002).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | rc = 0 | Returns `nil` (success) |
| EC-002 | rc = -7 | Returns `USBTransportError.timeout` |
| EC-003 | rc = -4 | Returns `USBTransportError.disconnected` |
| EC-004 | rc = -1 | Returns `USBTransportError.transferFailed(-1)` |
| EC-005 | rc = -99 (arbitrary unknown negative) | Returns `USBTransportError.transferFailed(-99)` (catch-all) |
| EC-006 | rc = 1 (positive, not libusb convention) | Returns `USBTransportError.transferFailed(1)` (non-zero catch-all) |

## Canonical Test Vectors
| Input (libusb rc) | Expected Result | Category |
|-------------------|----------------|----------|
| `0` | `nil` | happy-path (success) |
| `-7` | `USBTransportError.timeout` | happy-path (timeout) |
| `-4` | `USBTransportError.disconnected` | happy-path (disconnect) |
| `-1` | `USBTransportError.transferFailed(-1)` | edge (known LIBUSB_ERROR_IO) |
| `-99` | `USBTransportError.transferFailed(-99)` | edge (unrecognised code) |

## Error Handling
If this test does not exist or fails, `swift run occ-tests` exits 1, blocking CI. The absence of this test in v1.0.0 is the gap being closed; shipping v1.1.0 without this test present is a policy violation (see BC-1.06.010).

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/USB/USBDevice.swift:120-127` (private `check` function containing the mapping), `USBDevice.swift:4-23` (`USBTransportError` enum definition) |
| Ingest BC | BC-021 (opencrashcart-pass-3-behavioral-contracts.md: "libusb rc map: 0 ok, -7 timeout, -4 disconnected, else transferFailed. HIGH constants") |
| Public-API delta | Extract `public static func mapLibusbResult(_ rc: Int32) -> USBTransportError?` from existing `private func check(_:)` |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — USB error mapping per Pass-3 BC-021; capability ID to be assigned after capabilities.md is updated |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/USB/USBDevice.swift` |
| Confidence | HIGH (constants at lines 30-31; mapping at lines 120-127, Pass-3 BC-021) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code constants (return-code map) |

## Related BCs
- BC-1.06.001 — harness infrastructure this test runs within (depends on)
- BC-1.06.010 — coverage policy requiring this test ships with v1.1.0 (depends on)

## Architecture Anchors
- `Sources/OCCKit/USB/USBDevice.swift` — libusb rc mapping implementation (`private func check`, lines 120-127)
- `Sources/occ-tests/` — test target where new test file is added

## Story Anchor
TBD

## VP Anchors
TBD
