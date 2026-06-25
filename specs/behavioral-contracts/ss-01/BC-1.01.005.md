---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-01"
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.005: STATUS Packet Parse, State Derivation, and On-Change Emit

## Description
When the response loop receives a STATUS command, `parseStatus` decodes a 29-byte (CC1) or 35-byte (CC2) big-endian packet into an `AdapterStatus` struct, derives the `AdapterState`, and emits a `.status` event only if the new status differs from the last emitted one. The bytes-per-second computation uses the formula `words * 16 * 1000 / ticks` where words is a 32-bit count and ticks is a 16-bit millisecond counter; the result is zero when ticks == 0. Video adjustments are decoded from the misc bytes using signed interpretation for horizontal and vertical offsets.

## Preconditions
1. `parseStatus` is called from the response thread with the args slice (packet minus the command byte).
2. `args.count` is either 29 or 35; any other length causes an immediate return with no event.
3. `lastStatus` holds the previous emitted status (zero-valued at session start).

## Postconditions
1. CC1 (29 bytes): `miscLen = 9` bytes are decoded for adjustments.
2. CC2 (35 bytes): `miscLen = 15` bytes are decoded for adjustments.
3. State derivation:
   a. If `NoVideoReason(rawValue: noVideo) != .ok` → `state = .noVideo(reason)`.
   b. Else if `fpgaLoaded != 0 && w > 0 && h > 0` → `state = .live(width:w, height:h, hz:hz)`; `decoder.setActiveSize` is called.
   c. Otherwise → `state = .connecting`.
4. `bytesPerSecond = Double(words) * 16.0 * 1000.0 / Double(ticks)` when `ticks > 0`; `0.0` when `ticks == 0`.
5. `adjustments[.horizontal]` and `adjustments[.vertical]` use signed byte decoding: value ≥ 128 → `Int(value) - 256`.
6. `adjustments[.phase]`, `.noise`, `.sharpness` use unsigned decoding.
7. A `.status(status)` event is emitted if and only if `status.differs(from: lastStatus)`.
8. When emitted, `lastStatus` is updated to the new status.

## Invariants
1. Events are only emitted on change; a repeated identical STATUS packet produces no event.
2. `decoder.setActiveSize` is called only when state transitions to `.live`.
3. `adjustments` may be empty if `misc.count == 0`.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `args.count == 28` (wrong size) | Return immediately; no event, no state change |
| EC-002 | `ticks == 0` | `bytesPerSecond = 0.0`; no division-by-zero |
| EC-003 | Status identical to last | No `.status` event emitted |
| EC-004 | `fpgaLoaded == 0` but `w > 0, h > 0` | State = `.connecting` (FPGA must be loaded for live) |
| EC-005 | `noVideo` byte is non-zero known reason | State = `.noVideo(reason)` regardless of fpgaLoaded/w/h |
| EC-006 | `misc[1] == 200` (signed -56) | `adjustments[.horizontal] = 200 - 256 = -56` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| 29-byte args: fpgaLoaded=1, w=1920, h=1080, hz=60, ticks=1000, words=6000 | state=.live(1920,1080,60), bps=96000.0, status event emitted | happy-path |
| 35-byte args: identical to previous parse | No event emitted | edge case (dedup) |
| 29-byte args: noVideo=1 (non-zero) | state=.noVideo(reason); no decoder.setActiveSize call | edge case |
| 29-byte args but only 28 bytes passed | Return immediately; lastStatus unchanged | error |

## Error Handling
- Wrong packet length: silent return, no event, no state mutation.
- No exceptions are thrown from `parseStatus`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:347-401 |
| Ingest BC | BC-084 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion / type constraint |
