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
# Behavioral Contract BC-1.01.026: OCC_SECONDS Environment Variable Triggers Auto-Quit

## Description
If the `OCC_SECONDS` environment variable is set to a valid `Double`, a one-shot timer is scheduled at app launch that calls `NSApp.terminate(nil)` unconditionally after the specified number of seconds. This is an automation/testing escape hatch; it fires regardless of connection state.

## Preconditions
1. `applicationDidFinishLaunching` has been called.
2. `OCC_SECONDS` is set in the process environment to a string parseable as `Double`.

## Postconditions
1. `Timer.scheduledTimer(withTimeInterval: secs, repeats: false)` is scheduled.
2. After `secs` seconds, `NSApp.terminate(nil)` is called unconditionally.
3. If `OCC_SECONDS` is absent or not parseable as `Double`, no quit timer is created.

## Invariants
1. The quit timer fires exactly once.
2. It is unconditional — no check for connection state, recording state, etc.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `OCC_SECONDS` not set | No quit timer |
| EC-002 | `OCC_SECONDS="abc"` (non-numeric) | `Double("abc") == nil`; no quit timer |
| EC-003 | `OCC_SECONDS="0"` | Timer fires immediately (next run loop tick) |
| EC-004 | App is recording when timer fires | `NSApp.terminate` triggers `applicationWillTerminate`; BC-1.01.027 governs cleanup |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `OCC_SECONDS=5` | App terminates 5 seconds after launch | happy-path |
| `OCC_SECONDS` not set | App runs indefinitely | edge case |
| `OCC_SECONDS=notanumber` | No quit timer; app runs indefinitely | edge case |

## Error Handling
No errors. The timer fires silently.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:130-134 |
| Ingest BC | BC-105 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
