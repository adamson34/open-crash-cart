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
# BC-1.06.009: Harness Test Exists Verifying Command-Queue Input-Before-Control Priority (Ingest BC-037)

## Description
A test section must exist in `occ-tests` that verifies `CommandQueue` drain order: when both input events (keyboard, mouse) and control commands (FPGA commands, status polls) are simultaneously queued, input events are drained first before any control command is sent. This priority ensures human input latency is minimised. This is a v1.1.0 test-backfill requirement; the priority logic existed in v1.0.0 code with no harness coverage.

## Preconditions
1. A test function (e.g., `runCommandQueueTests(_:)`) is registered in `main.swift`.
2. `CommandQueue` (or the equivalent queue struct) is accessible from `occ-tests` without requiring a live USB device.
3. The test can enqueue a mix of input and control items and observe the drain order via an in-memory sink.

## Postconditions
1. When one control command and one input event are enqueued simultaneously, the input event is dequeued first.
2. When N input events and M control commands are enqueued simultaneously, all N input events are dequeued before any of the M control commands.
3. After all input events are drained, control commands are drained in their original enqueue order.
4. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. Input-before-control ordering is stable: relative order within the input tier and within the control tier is preserved (FIFO within each tier).
2. `CommandQueue` does not reorder two items of the same tier.
3. An empty queue drain produces no output.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Only input events queued | All input events drained in FIFO order; no control commands emitted |
| EC-002 | Only control commands queued | All control commands drained in FIFO order |
| EC-003 | Input + control interleaved (A-ctrl, B-input, C-ctrl, D-input) | Drain order: B-input, D-input, A-ctrl, C-ctrl |
| EC-004 | Empty queue | Drain returns immediately; nothing emitted |
| EC-005 | Single item (input) | Drained as-is |
| EC-006 | Single item (control) | Drained as-is |

## Canonical Test Vectors
| Input (enqueue order) | Expected drain order | Category |
|-----------------------|---------------------|----------|
| Enqueue: ctrl-1, input-1, ctrl-2, input-2 | Drain: input-1, input-2, ctrl-1, ctrl-2 | happy-path |
| Enqueue: input-1, input-2, input-3 | Drain: input-1, input-2, input-3 | happy-path (input-only FIFO) |
| Enqueue: ctrl-1, ctrl-2, ctrl-3 | Drain: ctrl-1, ctrl-2, ctrl-3 | happy-path (control-only FIFO) |
| Empty queue | Drain: nothing | edge (empty) |

## Error Handling
`CommandQueue` does not produce errors during drain. A test assertion mismatch (wrong drain order) increments `Harness.failed` and causes `exit(1)`.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` (CommandQueue implementation, exact lines TBD) |
| Ingest BC | BC-037 ("CommandQueue input drained before control") — opencrashcart-pass-3-behavioral-contracts.md |
| Stories | TBD |
| Capability Anchor Justification | Command-queue priority ordering per Pass-3 BC-037 (MEDIUM confidence, code control-flow) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` |
| Confidence | MEDIUM (code control-flow; no pre-existing test) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-037) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.008 — mouse coalescing test (peer input-layer test)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` — CommandQueue implementation

## Story Anchor
TBD

## VP Anchors
TBD
