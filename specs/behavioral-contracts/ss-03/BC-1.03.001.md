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

# BC-1.03.001: OCR Recognition Runs Off-Main Thread with Accurate Level and No Language Correction

## Description

The `recognizeText(in:completion:)` function dispatches Vision OCR work to a background queue (`DispatchQueue.global(qos: .userInitiated)`), uses `.accurate` recognition level, and disables `usesLanguageCorrection`. The off-main dispatch prevents UI freezes during recognition. Language correction is disabled because server screens contain IP addresses, paths, and commands that autocorrect would mangle.

## Preconditions

- A `CGImage` is passed to `recognizeText(in:completion:)`.
- The call may be made from any thread.

## Postconditions

- Recognition executes on a global background queue, not the main thread.
- `VNRecognizeTextRequest.recognitionLevel` is set to `.accurate`.
- `VNRecognizeTextRequest.usesLanguageCorrection` is `false`.
- The `completion` closure is called with the recognized string (possibly empty) if `VNImageRequestHandler.perform` succeeds.
- If `perform` throws, `try?` silently discards the error and the `completion` is **never called** — the caller receives no callback and any "Reading text..." status message remains indefinitely (known defect; addressed in BC-1.03.012).

## Invariants

- Recognition level is always `.accurate`; the `.fast` level is never used.
- Language correction is always `false`.
- The completion block always runs on the background queue (callers must dispatch to main for UI updates).

## Edge Cases

- **EC-001** — `perform` throws (e.g., invalid image format): `try?` discards the error, completion is not called, status is stuck at "Reading text…". This is a known defect tracked in BC-1.03.012.
- **EC-002** — Image contains no text: `observations` is empty; `text` is an empty string `""`; completion is called with `""`.
- **EC-003** — Very large image: recognition still runs off-main; no timeout guard exists.

## Canonical Test Vectors

| Scenario | Input | Expected Outcome |
|----------|-------|-----------------|
| Happy path — text present | CGImage of rendered "Hello World" text | completion called with "Hello World" (or equivalent) |
| No text | CGImage of solid color | completion called with "" |
| perform silently fails | Stub `VNImageRequestHandler.perform` to throw | completion not called; no crash |

## Error Handling

- `VNImageRequestHandler.perform` errors are swallowed by `try?`. No propagation occurs.
- The caller (`handleOCR`) is not notified of failures (see BC-1.03.012 for the v1.1.0 fix contract).

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/OCR.swift:7-25` |
| Ingest BC | BC-140 (pass-3-deep-app-layer.md) |
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
| Key lines | `:8` `DispatchQueue.global(qos: .userInitiated).async`; `:21` `request.recognitionLevel = .accurate`; `:22` `request.usesLanguageCorrection = false`; `:23` `try? VNImageRequestHandler(...).perform([request])` |
