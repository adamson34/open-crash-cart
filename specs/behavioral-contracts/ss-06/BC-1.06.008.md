---
document_type: behavioral-contract
level: L3
version: "1.1"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/UVC/UVCAdapter.swift"
subsystem: "SS-06"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.008: Harness Test Exists Verifying CH9329 Mouse Coalescing Latest-Wins via Pure MouseCoalescer (Ingest BC-036)

## Description
A test section must exist in `occ-tests` that verifies CH9329 mouse event coalescing: when multiple mouse events are stored before the next drain, only the most-recently-stored event is returned (latest-wins). Earlier stored events are silently discarded. The coalescing logic lives in `UVCAdapter` (NOT `StarTechAdapter`) — specifically `private var pendingMouse: MouseEvent?` at `UVCAdapter.swift:45`, set unconditionally in `send(mouse:)` at line 144 and drained by `drainMouse()` at lines 151-156. Prior spec drafts misattributed this to `StarTechAdapter`, whose `send(mouse:)` simply enqueues per-event without coalescing. The real adapter wraps the coalescing behind an async `inputQueue` (DispatchQueue) and a CH9329 gate, making it untestable synchronously as-is. The fix is to extract a pure synchronous `MouseCoalescer` type. This is a v1.1.0 test-backfill requirement.

## Preconditions
1. A test function (e.g., `runInputCoalescingTests(_:)`) is registered in `main.swift`.
2. **Public-API delta required:** Extract a new `public final class MouseCoalescer` with:
   - `public func store(_ event: MouseEvent)` — unconditionally overwrites `pendingMouse`.
   - `public func drain() -> MouseEvent?` — returns and clears `pendingMouse`; returns `nil` if nothing pending.
   Both operations are synchronous and thread-safe (NSLock internally). `UVCAdapter` replaces its `pendingMouse: MouseEvent?` stored property with an instance of `MouseCoalescer`. The async `inputQueue` dispatch and CH9329 gate remain in `UVCAdapter`; they are outside scope of this BC.
3. The test operates on `MouseCoalescer` directly — no serial port, no DispatchQueue, no CH9329, no `UVCAdapter` instance required.

## Postconditions
1. When `store(A)`, `store(B)`, `store(C)` are called in sequence, `drain()` returns `C`.
2. After draining `C`, a second call to `drain()` returns `nil`.
3. `drain()` on a freshly constructed `MouseCoalescer` (nothing stored) returns `nil`.
4. `store(A)` followed immediately by `drain()` returns `A`; subsequent `drain()` returns `nil`.
5. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. Coalescing is latest-wins: each `store` call unconditionally overwrites the previous pending event.
2. `drain()` is destructive: calling it twice returns the event on the first call and `nil` on the second.
3. `MouseCoalescer` is a pure synchronous object — no DispatchQueue, no async work, no CH9329 dependency.
4. The real `UVCAdapter` wraps `MouseCoalescer` behind its `inputQueue` for thread safety at the adapter level — that wrapper behavior is not tested by this BC.
5. Mouse coalescing is independent of keyboard events (keyboard events are not coalesced in either adapter).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Single event stored, then drained | Returns that event; second drain returns nil |
| EC-002 | Two events stored before drain | Only the second event is returned |
| EC-003 | Ten events stored before drain | Only the tenth event is returned |
| EC-004 | Drain, then store new event, then drain | Second drain returns the new event (no stale carry-over) |
| EC-005 | Nothing stored, drain called | Returns nil (no spurious event) |

## Canonical Test Vectors
| Input sequence | Expected `drain()` result | Category |
|---------------|--------------------------|----------|
| `store(MouseEvent(x:10,y:20))`, `store(MouseEvent(x:30,y:40))`, `store(MouseEvent(x:50,y:60))`, then `drain()` | `MouseEvent(x:50, y:60)` | happy-path (latest-wins) |
| After above drain, call `drain()` again | `nil` | happy-path (destructive drain) |
| Fresh coalescer, `drain()` | `nil` | edge (empty) |
| `store(A)`, `drain()` → A, `store(B)`, `drain()` → B | Each drain returns its respective event | happy-path (per-flush independence) |

## Error Handling
`MouseCoalescer` does not throw. A test assertion failure (wrong event or non-nil when nil expected) increments `Harness.failed` and causes `exit(1)`.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:44-45` (`mouseLock`, `pendingMouse` — the coalescing state); `:141-148` (`send(mouse:)` — unconditional overwrite); `:151-156` (`drainMouse()` — read-and-clear) |
| Ingest BC | BC-036 ("mouse coalescing latest-wins") — opencrashcart-pass-3-behavioral-contracts.md |
| Public-API delta | Extract `public final class MouseCoalescer` with `store(_:)` and `drain() -> MouseEvent?`; anchor is `UVCAdapter`, NOT `StarTechAdapter` |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — mouse coalescing behavior per Pass-3 BC-036; capability ID assigned in the architecture phase |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift` |
| Confidence | HIGH (coalescing state and logic read directly from lines 44-45, 141-156) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BC-036) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.009 — command-queue priority test (peer input-layer test)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:44-156` — coalescing state and drain logic (source of extraction)
- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift` — does NOT coalesce mouse events; per-event enqueue only

## Story Anchor
TBD

## VP Anchors
TBD
