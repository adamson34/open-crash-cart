---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-deep-app-layer.md"
subsystem: "SS-03"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.004: OCR Entry Requires a Live Session

## Description

The `copyTextFromScreen()` method in `AppController` guards on `isLive` before initiating OCR. If the adapter is not currently showing live video, the OCR flow is rejected with a status message and the region-selection UI is never started.

## Preconditions

- `copyTextFromScreen()` is invoked (via menu item `menuOCR` or keyboard shortcut Cmd+Shift+C).

## Postconditions

**Not live** (`isLive == false`):
- `statusBar.setMessage("Connect to a live target before using OCR.")` is called.
- `videoView.beginRegionSelection()` is NOT called.
- No UI changes to the video view.

**Live** (`isLive == true`):
- `statusBar.setMessage("Drag to select the text to copy (Esc to cancel)…")` is called.
- `videoView.beginRegionSelection()` is called, starting the crosshair selection mode.

## Invariants

- OCR region selection never begins unless `isLive` is `true`.
- The status message accurately reflects which path was taken.

## Edge Cases

- **EC-001** — Session goes offline after `isLive` check but before `beginRegionSelection` completes: selection starts; if `lastImage` becomes nil, `finishSelection` yields a nil image, and `handleOCR` receives nil (treated as cancel — see BC-1.03.003).
- **EC-002** — Adapter is connected but no frame has arrived yet (`isLive == true`, `lastImage == nil`): selection starts; on mouseUp `finishSelection` guard on `lastImage` fails, passes nil to `onRegionSelected`, cancel path executes.

## Canonical Test Vectors

| Scenario | isLive | Expected status message | beginRegionSelection called? |
|----------|--------|------------------------|------------------------------|
| Not live | false | "Connect to a live target before using OCR." | No |
| Live | true | "Drag to select the text to copy (Esc to cancel)…" | Yes |

## Error Handling

No errors are thrown. The guard is a no-op guard with early return.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/AppController.swift:639-646` |
| Ingest BC | BC-143 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Run Vision OCR on a cropped screen region and copy result to clipboard") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/AppController.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:640` `guard isLive else {`; `:641` `statusBar.setMessage("Connect to a live target before using OCR.")`; `:644` `statusBar.setMessage("Drag to select the text to copy…")`; `:645` `videoView.beginRegionSelection()` |
