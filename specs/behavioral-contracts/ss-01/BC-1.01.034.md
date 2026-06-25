---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/AppController.swift"
subsystem: "SS-01"
lifecycle_status: active
introduced: v1.1.0
---
# Behavioral Contract BC-1.01.034: Disconnect Stays Disconnected (v1.1.0 — userDisconnected Flag)

## Description
This contract specifies the corrected v1.1.0 behavior for `menuDisconnect`. Currently (BC-1.01.033, defect), clicking Disconnect causes auto-reconnect within 2 seconds because the rescan timer keeps firing `tryConnect()`. The fix introduces a `userDisconnected: Bool` flag. When set, `tryConnect()` returns immediately without attempting discovery. The flag is cleared only by explicit user action: clicking Reconnect or selecting a UVC device. The `.disconnected` adapter event handler (BC-1.01.028) does NOT clear the flag, so an externally-caused disconnect while `userDisconnected=true` stays disconnected.

Note: the current codebase (Sources/occ/AppController.swift) does NOT yet contain `userDisconnected`. The evidence for the DEFECT is HIGH confidence (BC-1.01.033 code analysis); this contract describes the desired post-fix behavior with HIGH specification confidence.

## Preconditions
1. `userDisconnected: Bool` field exists on `AppController`.
2. `menuDisconnect()` is called by the user.

## Postconditions (menuDisconnect, v1.1.0)
1. Teardown, in order: **`eventTask?.cancel()`** (the current code only sets `eventTask=nil` without cancelling — adversary H1; `menuConnectUVC` already cancels, so this aligns the two paths), adapter disconnect (fire-and-forget), `adapter=nil`, `eventTask=nil`, `connecting=false`, `didAutoSize=false`, `showPlaceholder(.noAdapter)`.
2. `userDisconnected = true` is set.
3. `tryConnect()` entry guard expanded: returns immediately if `adapter == nil && !connecting` is not sufficient alone — also returns if `userDisconnected == true`.
4. **Stale-event isolation (adversary H1):** a connect `Task` launched microseconds before Disconnect (still mid-`await adapter.connect()`), or a late `.disconnected` emitted by the torn-down adapter, MUST NOT mutate session state or re-show video. `handle(_:)` ignores any event whose originating adapter is not the current `adapter` — e.g. via an adapter identity/generation token captured when the consuming `Task` starts. Cancelling `eventTask` (PC#1) plus this identity guard together guarantee no post-Disconnect video re-show.

## Postconditions (flag clearance)
1. `menuReconnect()`: sets `userDisconnected = false` before calling `tryConnect()`.
2. `menuConnectUVC(_:)`: sets `userDisconnected = false` before connecting.
3. `.disconnected` event handler: does NOT clear `userDisconnected` — stays intentionally disconnected.

## Invariants
1. `userDisconnected = true` persists until an explicit Connect/Reconnect action.
2. The 2-second rescan timer fires normally; it is suppressed only at the `tryConnect()` guard.
3. Once `userDisconnected = true`, no automatic reconnection occurs regardless of device presence.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | User disconnects, waits 10s, device still present | No reconnect; placeholder stays `.noAdapter` |
| EC-002 | Device cable pulled while `userDisconnected=true` | `.disconnected` event received; state unchanged (already noAdapter) |
| EC-003 | User clicks Reconnect after Disconnect | `userDisconnected=false`; immediate tryConnect() |
| EC-004 | User selects UVC device after Disconnect | `userDisconnected=false`; UVC session starts |
| EC-005 | App launch (first connect): `userDisconnected=false` | Normal auto-connect at launch |
| EC-006 | Connect Task in flight when Disconnect clicked | `eventTask` cancelled; the in-flight task's events are ignored (identity guard); no video shown |
| EC-007 | Torn-down adapter emits a late `.disconnected` after Disconnect | Ignored by `handle(_:)` (not the current adapter); state stays `.noAdapter` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| User clicks Disconnect, device present, waits 5s | No reconnect; `.noAdapter` shown throughout | happy-path (v1.1.0) |
| User clicks Disconnect then Reconnect | Reconnects immediately | happy-path (v1.1.0) |
| Device disconnects externally while `userDisconnected=true` | Stays on `.noAdapter`; no reconnect | edge case |

## Error Handling
No errors introduced by the flag. All existing error paths unchanged.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:397-407 (current defect evidence) |
| Ingest BC | BC-112 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | high (defect evidence); high (specification) |
| Extraction Date | 2026-06-25 |
| Evidence Type | inferred (desired post-fix behavior) |
