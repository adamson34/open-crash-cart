---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-deep-app-layer.md
subsystem: SS-03
capability: CAP-OCR
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.002: OCR Observations Ordered Top-to-Bottom Then Left-to-Right with 0.012-Band Grouping

## Description

After Vision recognition completes, observations are sorted into reading order before being joined into the output string. The sort uses a 0.012-unit midY band tolerance to group observations on the same line, then orders by ascending midX within a band. Vision's coordinate origin is bottom-left, so descending midY maps to top-to-bottom in screen space.

## Preconditions

- `VNRecognizeTextRequest` has completed and returned an array of `VNRecognizedTextObservation` results.

## Postconditions

- Observations whose `boundingBox.midY` values differ by more than `0.012` are ordered by descending `midY` (top of screen first).
- Observations whose `boundingBox.midY` values differ by `0.012` or less are treated as the same line and ordered by ascending `midX` (left to right).
- Each observation contributes `topCandidates(1).first?.string`; observations with no candidates are dropped via `compactMap`.
- All retained strings are joined with `"\n"` separator.
- The resulting string is passed to the `completion` closure.

## Invariants

- Band tolerance is exactly `0.012` (normalized, not pixels).
- Only the top-ranked candidate per observation is used.
- Join separator is always `"\n"`.
- Observations with empty candidate lists are silently dropped.

## Edge Cases

- **EC-001** — Two observations on the same visual line with midY difference exactly 0.012: treated as the same line (boundary is `> 0.012`, not `>= 0.012`), ordered left-to-right.
- **EC-002** — Two observations with midY difference 0.0121: treated as different lines, higher observation comes first.
- **EC-003** — Single observation: no sorting needed; result is that observation's top candidate string.
- **EC-004** — Zero observations: `ordered` is empty; `text` is `""`; completion called with `""`.
- **EC-005** — Observation with no candidates: dropped by `compactMap`; no nil crash.

## Canonical Test Vectors

| Scenario | Observations (midY, midX) | Expected Output |
|----------|--------------------------|----------------|
| Two-line layout | A(midY=0.8, midX=0.2)="Hello", B(midY=0.2, midX=0.3)="World" | "Hello\nWorld" |
| Same-line two words | A(midY=0.5, midX=0.1)="foo", B(midY=0.505, midX=0.6)="bar" | "foo\nbar" (same line, left→right) |
| Empty observations | [] | "" |

## Error Handling

No errors are raised by the sorting step; it is pure data transformation on the Vision results array.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/OCR.swift:11-19` |
| Ingest BC | BC-141 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-OCR ("Run Vision OCR on a cropped screen region and copy result to clipboard") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/OCR.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:12-17` sort closure; `:13` `abs(a.boundingBox.midY - b.boundingBox.midY) > 0.012`; `:14` `a.boundingBox.midY > b.boundingBox.midY`; `:16` `a.boundingBox.midX < b.boundingBox.midX`; `:18` `.joined(separator: "\n")` |
