---
document_type: behavioral-contract
level: L3
id: BC-1.05.017
title: UVC Mouse Event Coalescing Latest-Wins for Slow Serial
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/UVC/UVCAdapter.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.017: UVC Mouse Event Coalescing Latest-Wins for Slow Serial

## Description

`UVCAdapter.send(mouse:)` implements a latest-wins coalescing strategy to compensate for the CH9329 serial link's limited bandwidth (9600 baud). Rapid mouse events are collapsed so that only the most recent position/state is sent to the device when the serial drain task runs, discarding intermediate positions.

## Preconditions

1. `hasHID == true`.
2. One or more `MouseEvent` values are submitted via `send(mouse:)` from any thread.

## Postconditions

1. `pendingMouse` always holds the most recently submitted `MouseEvent` (latest-wins).
2. Only one `drainMouse` task is in flight on `inputQueue` at any time (`mouseScheduled` gate).
3. When `drainMouse` runs, it consumes `pendingMouse` atomically (under `mouseLock`), sends it to CH9329, then checks for a new pending event; if one arrived during the send it processes it, otherwise it exits (the loop terminates when `pendingMouse == nil`).
4. Intermediate mouse positions submitted between two drain cycles are discarded; only the final position in each cycle is sent.

## Invariants

1. `pendingMouse` and `mouseScheduled` are accessed only under `mouseLock` (NSLock).
2. At most one `drainMouse` dispatch is queued on `inputQueue` at any time.
3. After `drainMouse` sets `mouseScheduled = false`, any subsequent `send(mouse:)` call will schedule a new drain task.
4. No mouse events are dropped from outside the coalescing window; the latest event is always delivered.

## Edge Cases

### EC-001: Single slow mouse event
`send(mouse:)` called once → `drainMouse` scheduled once, sends event, exits. `mouseScheduled = false`.

### EC-002: Rapid burst of mouse events during drain
10 events submitted while `drainMouse` is running → `pendingMouse` is overwritten 9 times; only the 10th event is sent in the next drain iteration.

### EC-003: Mouse event submitted exactly as drainMouse exits
`mouseScheduled` was set to `false` before the new event arrives → a new drain task is scheduled. No event is lost.

### EC-004: Mouse event after disconnect (hasHID=false)
`send(mouse:)` returns immediately before acquiring `mouseLock`. No dispatch to `inputQueue`.

### EC-005: Absolute vs relative coalescing
Coalescing does not distinguish absolute and relative events; the latest event regardless of type replaces the pending event. Mixed absolute/relative bursts may produce surprising behaviour but this is a known limitation of the serial link constraint.

## Canonical Test Vectors

| Scenario | Events submitted | Events sent to CH9329 |
|----------|----------------|----------------------|
| Single event | 1 | 1 |
| 10 rapid events, drain runs after all 10 | 10 | 1 (last one) |
| 10 rapid events, drain runs after 5, then after remaining 5 | 10 | 2 (5th and 10th) |

## Error Handling

NSLock is unfailable. If `inputQueue` is saturated, events queue behind pending CH9329 I/O; `mouseLock` prevents data races on `pendingMouse`.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:141-167` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-036 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:141-167` |
| Confidence | MEDIUM — source code, no unit test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
