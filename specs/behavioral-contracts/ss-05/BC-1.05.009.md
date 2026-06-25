---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Input/HIDTyping.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.009: HID Typing Strokes US-ASCII Shift Logic

## Description

`HIDTyping.strokes(for:)` converts a Swift `String` into an array of `(usage: UInt8, shift: Bool)` tuples using a US-ASCII keyboard layout. Uppercase letters use the same HID usage as their lowercase counterpart with `shift=true`. Shifted punctuation and number-row symbols similarly share the base key's usage with `shift=true`. The complete "Hi!" sequence demonstrates the multi-character pipeline.

## Preconditions

1. The input `text` is a Swift `String` (any Unicode string is accepted; non-mappable characters are silently skipped).

## Postconditions

1. Returns `[(UInt8, Bool)]` with one entry per mappable character, in input order.
2. Lowercase letters a–z: usage 0x04–0x1D, `shift=false`.
3. Uppercase letters A–Z: same usages 0x04–0x1D, `shift=true`.
4. Digit `1` → `(0x1E, false)`; symbol `!` → `(0x1E, true)`.
5. Space → `(0x2C, false)`.
6. Newline `\n` or carriage return `\r` → `(0x28, false)` (Enter key).
7. "Hi!" → `[(0x0B, true), (0x0C, false), (0x1E, true)]` (H=shift+h, i=i, !=shift+1) — test-pinned.
8. Tab `\t` → `(0x2B, false)`.

## Invariants

1. The layout is US-ASCII only; no locale or system keyboard layout affects the output.
2. Shift state is encoded per-stroke; the caller must generate separate key-down/key-up events for the Shift modifier around the key press.
3. The function is stateless — repeated calls produce identical output for identical input.

## Edge Cases

### EC-001: Unmapped characters skipped
Non-ASCII characters such as `é` and `€` produce no entries in the output array. `strokes(for: "é€")` → `[]`. Test-pinned.

### EC-002: Mixed ASCII and non-ASCII
`strokes(for: "aé")` → `[(0x04, false)]` — only the ASCII character is emitted.

### EC-003: Empty string
`strokes(for: "")` → `[]`.

### EC-004: All-shift sequence
`strokes(for: "A!")` → `[(0x04, true), (0x1E, true)]` — both strokes require Shift.

### EC-005: Newline variants
Both `\n` (LF) and `\r` (CR) map to `(0x28, false)`. CRLF sequences produce two Enter strokes.

## Canonical Test Vectors

| Input | Expected (encoded as usage*2 + shiftBit) | Notes |
|-------|------------------------------------------|-------|
| `"a"` | `[0x08]` (0x04*2+0) | Lowercase a — test-pinned (TypingTests.swift:11) |
| `"A"` | `[0x09]` (0x04*2+1) | Uppercase A — test-pinned (TypingTests.swift:12) |
| `"1"` | `[0x3C]` (0x1E*2+0) | Digit 1 — test-pinned (TypingTests.swift:13) |
| `"!"` | `[0x3D]` (0x1E*2+1) | Shifted 1 — test-pinned (TypingTests.swift:14) |
| `" "` | `[0x58]` (0x2C*2+0) | Space — test-pinned (TypingTests.swift:15) |
| `"\n"` | `[0x50]` (0x28*2+0) | Enter — test-pinned (TypingTests.swift:16) |
| `"Hi!"` | `[0x17, 0x18, 0x3D]` (0x0B*2+1, 0x0C*2, 0x1E*2+1) | Full sequence — test-pinned (TypingTests.swift:18) |
| `"é€"` | `[]` | Unmapped chars skipped — test-pinned (TypingTests.swift:19) |

## Error Handling

No failure mode; unmapped characters are silently skipped via `compactMap`.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Input/HIDTyping.swift:6-42` |
| Test file:line | `Sources/occ-tests/TypingTests.swift:11-19` |
| Ingest BC | BC-033, BC-034 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Input/HIDTyping.swift:6-42` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
