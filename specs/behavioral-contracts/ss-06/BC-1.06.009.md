---
document_type: behavioral-contract
level: L3
version: "1.1"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.009: Harness Test Exists Verifying Command-Queue Input-Before-Control Priority (Ingest BC-037)

## Description
A test section must exist in `occ-tests` that verifies `CommandQueue` drain order: when both input events (keyboard, mouse) and control commands (FPGA commands, status polls) are simultaneously queued, input events are drained first before any control command is sent. This priority ensures human input latency is minimised. The `CommandQueue` type and its `Priority` enum are `internal` in `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` (lines 6-7); the drain logic (`take()` at lines 28-37) is already correct. The only fix needed is a visibility change — the behavior contract is unchanged. This is a v1.1.0 test-backfill requirement.

## Preconditions
1. A test function (e.g., `runCommandQueueTests(_:)`) is registered in `main.swift`.
2. **Public-API delta required:** Promote `CommandQueue` (`final class`, line 6) and `Priority` (`enum`, line 7) in `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` from `internal` to `public`. No behavioral change to `enqueue`, `take`, or `close` is needed — only the access modifier. Without this promotion the `occ-tests` target (plain `import OCCKit`, no `@testable`) cannot construct or call `CommandQueue`.
3. The test can enqueue a mix of `.input` and `.control` items and observe drain order by calling `take()` repeatedly on an in-memory queue instance (no USB device required).

## Postconditions
1. When one control command and one input event are enqueued, `take()` returns the input event first.
2. When N input events and M control commands are enqueued simultaneously, all N input events are returned by `take()` before any of the M control commands.
3. After all input events are drained, control commands are drained in their original enqueue order (FIFO within tier).
4. `take()` on an empty, non-closed queue blocks; test drives this via a non-blocking drain pattern (close the queue after enqueuing, then drain until nil).
5. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. Input-before-control ordering is stable: relative order within the input tier and within the control tier is preserved (FIFO within each tier).
2. `CommandQueue` does not reorder two items of the same tier.
3. An empty, closed queue drain (after `close()`) produces `nil` on the first `take()`.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Only input events queued | All input events drained in FIFO order; `take()` returns nil after last |
| EC-002 | Only control commands queued | All control commands drained in FIFO order |
| EC-003 | Input + control interleaved (A-ctrl, B-input, C-ctrl, D-input) | Drain order: B-input, D-input, A-ctrl, C-ctrl |
| EC-004 | Empty queue, closed | First `take()` returns nil immediately |
| EC-005 | Single item (input) | Drained as-is |
| EC-006 | Single item (control) | Drained as-is |

## Canonical Test Vectors
| Input (enqueue order) | Expected drain order | Category |
|-----------------------|---------------------|----------|
| Enqueue: ctrl-1, input-1, ctrl-2, input-2; then close | Drain: input-1, input-2, ctrl-1, ctrl-2, nil | happy-path |
| Enqueue: input-1, input-2, input-3; then close | Drain: input-1, input-2, input-3, nil | happy-path (input-only FIFO) |
| Enqueue: ctrl-1, ctrl-2, ctrl-3; then close | Drain: ctrl-1, ctrl-2, ctrl-3, nil | happy-path (control-only FIFO) |
| Close without enqueuing | First `take()` → nil | edge (empty closed) |

## Error Handling
`CommandQueue` does not produce errors during drain. A test assertion mismatch (wrong drain order) increments `Harness.failed` and causes `exit(1)`. Note: `take()` is a blocking call — tests must `close()` the queue before the drain loop to avoid deadlock.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift:6-7` (`CommandQueue` and `Priority` declarations, `internal`); `:14-25` (`enqueue`); `:28-37` (`take` — input-before-control logic) |
| Ingest BC | BC-037 ("CommandQueue input drained before control") — opencrashcart-pass-3-behavioral-contracts.md |
| Public-API delta | Promote `CommandQueue` and `Priority` from `internal` to `public` in `StarTechSupport.swift:6-7` — no behavioral change |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — command-queue priority ordering per Pass-3 BC-037; capability ID to be assigned after capabilities.md is updated |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift` |
| Confidence | HIGH (take() logic read directly at lines 28-37) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-037) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.008 — mouse coalescing test (peer input-layer test)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift:6-37` — `CommandQueue` and `Priority` implementation

## Story Anchor
TBD

## VP Anchors
TBD
