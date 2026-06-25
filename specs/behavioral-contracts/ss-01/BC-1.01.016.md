---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.016: CommandQueue — Input-Before-Control Priority Drain

## Description
`CommandQueue` is a two-lane priority queue: `.input` (key and mouse events) and `.control` (status polls, FPGA blocks, boot commands). `take()` always drains the input queue entirely before dequeuing from the control queue. This ensures typing and mouse input remain responsive even during lengthy FPGA bitstream uploads or frequent status polls.

## Preconditions
1. `CommandQueue` is initialized and not closed.
2. One or more messages have been enqueued at either priority.
3. A single writer thread calls `take()` in a loop.

## Postconditions
1. `take()` returns the oldest `.input` message if `inputQ` is non-empty.
2. `take()` returns the oldest `.control` message only when `inputQ` is empty.
3. `take()` blocks (waits on `NSCondition`) when both queues are empty and not closed.
4. `take()` returns `nil` when the queue is closed and both queues are drained.

## Invariants
1. Input messages always precede control messages at the point of consumption, regardless of enqueue order.
2. Within each priority lane, FIFO ordering is maintained.
3. `close()` unblocks all waiting `take()` callers via `broadcast`.
4. Messages enqueued after `close()` are silently dropped (enqueue no-ops when `closed == true`).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Both queues empty, not closed | `take()` blocks |
| EC-002 | Only control queue has messages | `take()` returns first control message |
| EC-003 | Input enqueued while taking control | Next `take()` returns the input message |
| EC-004 | `close()` called while blocked on `take()` | `take()` returns nil |
| EC-005 | Enqueue after close | Message dropped; no signal |
| EC-006 | Empty message (`[]`) enqueued | Dropped by `guard !message.isEmpty` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Enqueue control("A"), then input("B"), then take() | Returns "B" (input first) | happy-path |
| Enqueue control("A"), take(), take() | First: "A"; second: blocks (empty) | happy-path |
| Close with pending items | `take()` returns remaining items then nil | edge case |

## Error Handling
- No errors thrown from any queue operation.
- Thread safety guaranteed by `NSCondition` wrapping all state access.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift:6-45 |
| Ingest BC | BC-037 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechSupport.swift |
|------|-------------------------------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / documentation |
