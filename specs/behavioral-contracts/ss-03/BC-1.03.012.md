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
introduced: v1.1.0
---

# BC-1.03.012: OCR Failure Surfaces and Clears Status (v1.1.0)

## Description

This is the v1.1.0 change contract. In v1.0.0, `recognizeText(in:completion:)` uses `try?` to call `VNImageRequestHandler.perform`, silently discarding any error and never calling the completion closure. This leaves the status bar permanently showing "Reading text..." — a stuck state the user cannot recover from without restarting the app. In v1.1.0, the `perform` call is replaced with a do/catch that calls the completion with a failure result (or directly surfaces the error to the caller) so `handleOCR`'s status message is always updated.

**Current code behavior (v1.0.0 defect):** `try? VNImageRequestHandler(...).perform([request])` — on throw, completion is never called; status stuck at "Reading text..." (Sources/occ/OCR.swift:23).

**Required v1.1.0 behavior:** When `perform` throws, the completion path executes with an error indication so the "Reading text..." status is replaced with an informative error message (e.g., "OCR failed: <reason>") and the UI is unblocked.

## Preconditions

- `recognizeText(in:completion:)` is called with a `CGImage`.
- `VNImageRequestHandler.perform` throws an error (e.g., invalid image, Vision framework error).

## Postconditions

**v1.1.0 (target behavior)**:
- The `perform` call is wrapped in a `do/catch` block (or equivalent error-aware API).
- On catch, the failure is surfaced via an **explicit error channel** — a refactored completion signature passing a `Result<String, Error>` (or a dedicated failure callback). **The empty-string path MUST NOT be reused to signal failure (adversary M1):** collapsing a real Vision error into `""` would make `handleOCR` show "No text found in the selection." for a genuine OCR crash, masking the error.
- `handleOCR` distinguishes three outcomes, each with a distinct status: success → "Copied N characters…"; genuinely-empty recognition → "No text found in the selection."; **failure → a dedicated error message** (e.g. "OCR failed: <reason>").
- The status is no longer stuck at "Reading text...".

**v1.0.0 (defect, for documentation)**:
- `try?` discards the error silently.
- `completion` is never called.
- Status remains "Reading text..." indefinitely.
- No recovery without app restart.

## Invariants

- After any OCR attempt (success, no-text, or failure), the "Reading text..." status is always replaced before the operation is considered complete.
- The UI is never left in a permanently-blocked "Reading text..." state.
- **Failure and genuinely-empty results are distinguishable** at the `handleOCR` layer — a Vision/perform error never presents as the empty-text outcome.

## Edge Cases

- **EC-001** — `perform` throws `VNError.operationFailed`: error is caught; completion fires; status cleared.
- **EC-002** — `perform` throws due to invalid image format: same as EC-001.
- **EC-003** — `perform` succeeds but returns empty observations: existing empty-text path handles it (BC-1.03.003 EC empty); status set to "No text found in the selection."
- **EC-004** — `self` is deallocated before the catch block's main-queue dispatch runs: `guard let self` short-circuits cleanly; no crash; status may not be updated (acceptable — the window is gone).

## Canonical Test Vectors

| Scenario | perform result | Expected status message |
|----------|---------------|------------------------|
| perform succeeds, text found | Success, "hello" | "Copied 5 characters from screen to clipboard." |
| perform succeeds, no text | Success, "" | "No text found in the selection." |
| perform throws (v1.1.0) | Throws VNError | "OCR failed." (or equivalent non-stuck message) |
| perform throws (v1.0.0 defect) | Throws VNError | Status stuck at "Reading text..." (DEFECT) |

## Error Handling

v1.1.0 implementation must use `do { try handler.perform([request]) } catch { /* surface error */ }` in place of `try?`. The catch block must invoke the completion or otherwise ensure the main-thread status update fires.

## Related BCs

- BC-1.03.001: defines the v1.0.0 behavior this contract supersedes (the `try?` defect)
- BC-1.03.003: handleOCR completion paths — must receive an invocation to update status

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/OCR.swift:23` (defect line) |
| Ingest BC | BC-140 (pass-3-deep-app-layer.md, risk noted: "swallowed Vision error stuck status") |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-OCR ("Run Vision OCR on a cropped screen region and copy result to clipboard") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/OCR.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read (defect) + v1.1.0 change specification |
| Key lines | `:23` `try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])` — the `try?` discards errors without calling completion |
