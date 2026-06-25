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
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.029: Live Status Auto-Sizes Window Exactly Once Per Session

## Description
When a `.status` event with state `.live` is received, the window is auto-sized to fit the reported video resolution exactly once per session, controlled by the `didAutoSize` latch. Subsequent `.live` status events (e.g., resolution changes during a session) do not resize the window. The latch is reset on disconnect (BC-1.01.028) and on UVC connect (BC-1.01.031), so each new session gets one auto-size.

## Preconditions
1. A `.status(status)` event is received with `status.state == .live(width:, height:, hz:)`.
2. `didAutoSize` may be true or false.

## Postconditions
1. `showVideo()` is called (idempotent).
2. `window.title = liveTitle(status)` (e.g., "OpenCrashCart — 1920×1080").
3. If `!didAutoSize`: `didAutoSize = true` and `resizeToVideo(width:height:)` is called.
4. If `didAutoSize == true`: no resize; title update only.

## Invariants
1. Auto-resize happens at most once per session (per `didAutoSize` latch).
2. `resizeToVideo` respects screen bounds (scales down if video larger than 92% of screen).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | First `.live` status | `didAutoSize=true`; window resized |
| EC-002 | Second `.live` status (same session) | `didAutoSize` already true; no resize |
| EC-003 | Resolution change mid-session | Title updated; no resize |
| EC-004 | Video larger than 92% of screen | `resizeToVideo` scales down to fit |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| First `.live(1920,1080,60)` | Window sized for 1920×1080; `didAutoSize=true` | happy-path |
| Second `.live(1920,1080,60)` | No resize; title updated | edge case |
| `.live(3840,2160,60)` on 1440p screen | Window scaled to ~92% of screen height | edge case |

## Error Handling
No errors from auto-size; layout is best-effort.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:256-259, 603-624 |
| Ingest BC | BC-108 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
