---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.008: Harness Test Exists Verifying CH9329 Mouse Coalescing Latest-Wins (Ingest BC-036)

## Description
A test section must exist in `occ-tests` that verifies CH9329 mouse event coalescing: when multiple mouse events are enqueued before the next USB flush, only the most-recently-enqueued event's position and button state are transmitted (latest-wins). Earlier enqueued events in the same flush window are silently discarded. This is a v1.1.0 test-backfill requirement; the coalescing logic existed in v1.0.0 with no harness coverage.

## Preconditions
1. A test function (e.g., `runInputCoalescingTests(_:)`) is registered in `main.swift`.
2. The mouse coalescing mechanism (a stored property that overwrites on each enqueue) is testable in isolation from the serial port / USB hardware.
3. The test can enqueue multiple `MouseEvent` values and inspect the coalesced result without performing real I/O.

## Postconditions
1. When three `MouseEvent` values are enqueued (A, B, C), only event C is observed in the pending-send state.
2. Events A and B are not present in any pending buffer after C is enqueued.
3. A `flush()` (or equivalent drain call) sends exactly one mouse packet derived from event C.
4. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. Coalescing is latest-wins: each new event unconditionally overwrites the previous pending event.
2. An enqueued mouse event that is never followed by a flush is never transmitted; the coalesced state persists until the next flush.
3. Mouse coalescing is independent of keyboard events (keyboard events are not coalesced).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Single event enqueued, then flushed | That event is transmitted as-is |
| EC-002 | Two events enqueued before flush | Only the second event is transmitted |
| EC-003 | Ten events enqueued before flush | Only the tenth event is transmitted |
| EC-004 | Event enqueued, flushed, then new event enqueued | Second flush transmits the new event (no stale coalescing from prior flush) |
| EC-005 | No events enqueued | Flush sends nothing (no spurious mouse packet) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Enqueue `MouseEvent(x:10, y:20)`, `MouseEvent(x:30, y:40)`, `MouseEvent(x:50, y:60)` | Pending state = `MouseEvent(x:50, y:60)` | happy-path (latest-wins) |
| Enqueue one event, flush, enqueue another event, flush | Each flush transmits exactly the one event enqueued since the last flush | happy-path (per-flush coalescing) |
| No events enqueued, flush | No mouse packet emitted | edge (empty flush) |

## Error Handling
Mouse coalescing does not produce errors. A test assertion failure (wrong event transmitted) increments `Harness.failed` and causes `exit(1)`.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` or `Sources/OCCKit/Adapters/UVC/CH9329.swift` (coalescing write, exact lines TBD) |
| Ingest BC | BC-036 ("mouse coalescing latest-wins") — opencrashcart-pass-3-behavioral-contracts.md |
| Stories | TBD |
| Capability Anchor Justification | Mouse coalescing behavior per Pass-3 BC-036 (MEDIUM confidence, code control-flow) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` (primary); `Sources/OCCKit/Adapters/UVC/CH9329.swift` (UVC path) |
| Confidence | MEDIUM (code control-flow; no pre-existing test) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-036) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.009 — command-queue priority test (peer input-layer test)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` — adapter coalescing logic
- `Sources/OCCKit/Adapters/UVC/CH9329.swift` — UVC CH9329 coalescing

## Story Anchor
TBD

## VP Anchors
TBD
