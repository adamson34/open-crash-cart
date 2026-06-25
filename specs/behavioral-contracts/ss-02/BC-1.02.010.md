---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-behavioral-contracts.md
subsystem: SS-02
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.010: STATUS Parse — State Derivation (live / noVideo / connecting) and bps/fps Computation

## Description

`parseStatus` in `StarTechAdapter` decodes the 29-byte (CC1) or 35-byte (CC2) STATUS response from the device and derives `AdapterState` and `AdapterStatus`. The state machine has three outcomes: `.noVideo(reason)` when `noVideo != .ok`, `.live(w, h, hz)` when the FPGA is loaded and dimensions are positive, and `.connecting` otherwise. Bytes-per-second is computed as `words * 16 * 1000 / ticks`. The status event is emitted only when the new status differs from the last emitted status.

## Preconditions

- `args` is either 29 or 35 bytes (CC1 or CC2 STATUS response).
- All fields are big-endian as packed by the device.
- `ByteReader` reads fields sequentially; the read order is: fpgaLoaded(u8), fpgaPowered(u8, discarded), kbdType(u8), kmOkay(u8), leds(u8), noVideo(u8), w(u16), h(u16), hz(u8), pixPerClk(u8, discarded), savedPos(u8, discarded), ticks(u16), words(u32), fps(u8), misc[miscLen].

## Postconditions

**State derivation:**
- If `NoVideoReason(rawValue: noVideo) != nil && reason != .ok` → `state = .noVideo(reason)`.
- Else if `fpgaLoaded != 0 && w > 0 && h > 0` → `state = .live(width: w, height: h, hz: hz)` AND `decoder.setActiveSize(width: w, height: h)` is called.
- Else → `state = .connecting`.

**bps computation:**
- `bytesPerSecond = ticks > 0 ? Double(words) * 16.0 * 1000.0 / Double(ticks) : 0.0`.

**fps:** directly from STATUS byte (device-reported).

**adjustments:**
- `misc[0]` → `.phase` (unsigned Int)
- `misc[1]` → `.horizontal` (signed: `>= 128 ? Int(b) - 256 : Int(b)`)
- `misc[2]` → `.vertical` (signed)
- `misc[3]` → `.noise` (unsigned)
- `misc[4]` → `.sharpness` (unsigned)

**Emission:**
- `AdapterEvent.status(status)` is emitted only if `status.differs(from: lastStatus)`.
- `differs` ignores `bytesPerSecond` (StarTechAdapter.swift:430-434).

## Invariants

- A STATUS with unexpected byte count (not 29 or 35) is silently discarded (early return).
- `bytesPerSecond` changes do NOT trigger re-emission.
- `decoder.setActiveSize` is called only on the `.live` path, never on `.noVideo` or `.connecting`.
- `pixPerClk`, `savedPos`, and `fpgaPowered` are read from the buffer but their values are discarded.

## Edge Cases

| EC-ID  | Scenario                              | Expected Outcome                                      |
|--------|---------------------------------------|-------------------------------------------------------|
| EC-047 | noVideo=1 (noSignal), fpgaLoaded=1    | state=.noVideo(.noSignal) — noVideo takes priority    |
| EC-048 | fpgaLoaded=0, w=1280, h=1024          | state=.connecting (fpgaLoaded gate)                   |
| EC-049 | fpgaLoaded=1, w=0, h=1024             | state=.connecting (w=0 gate)                          |
| EC-050 | fpgaLoaded=1, w=1920, h=1080, noVideo=0 | state=.live(1920,1080,hz) + setActiveSize called    |
| EC-051 | ticks=0                               | bytesPerSecond=0.0 (divide-by-zero guard)             |
| EC-052 | STATUS 28 bytes (unexpected)          | Silently discarded, no emission                       |
| EC-053 | Same status twice                     | Second emission suppressed (differs=false)            |

## Canonical Test Vectors

| fpgaLoaded | noVideo | w    | h    | hz | ticks | words | Expected state        | bps formula   | Category |
|------------|---------|------|------|----|-------|-------|-----------------------|---------------|----------|
| 1          | 0       | 1920 | 1080 | 60 | 1000  | 500   | .live(1920,1080,60)  | 500*16*1000/1000=8000 | happy-path |
| 0          | 0       | 1920 | 1080 | 60 | 1000  | 500   | .connecting           | 8000          | edge |
| 1          | 1       | 1920 | 1080 | 60 | 1000  | 500   | .noVideo(.noSignal)   | 8000          | edge |
| 1          | 0       | 1920 | 1080 | 60 | 0     | 500   | .live(1920,1080,60)   | 0.0           | edge (ticks=0) |

## Error Handling

- Unexpected STATUS length: silently discarded with `return` (StarTechAdapter.swift:352).
- Unknown `noVideo` rawValue: `NoVideoReason(rawValue:)` returns nil → falls through to `.live`/`.connecting` check.
- Unknown `kbdType` rawValue: `KeyboardEmulation(rawValue:) ?? .usb` — defaults to USB.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:347-401 |
| Ingest BC                       | BC-084 (opencrashcart-pass-3-behavioral-contracts.md:74) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — STATUS parse + state derivation; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:347-401 |
| Confidence       | MEDIUM (code-only; STATUS parsing is untested per pass-3-behavioral-contracts.md:78) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
