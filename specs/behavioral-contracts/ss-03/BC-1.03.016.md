---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-2-3-deep-panels-r2.md"
subsystem: "SS-03"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.016: Floating Panels Anchor Once on First Present; Non-Activating with Main Window Retaining Key Focus

## Description

The three floating panels (KeyboardPanel, VideoAdjustPanel, ImageEnhancePanel) share the same `present(relativeTo:)` positioning contract: position is set only when the panel is not already visible (`!isVisible`), preventing the panel from jumping away if the user has moved it. All panels are configured as non-activating (`.nonactivatingPanel` style mask, `becomesKeyOnlyIfNeeded = true`, `hidesOnDeactivate = false`) so the main window retains key focus and physical keyboard events continue to reach the target machine.

## Preconditions

- `present(relativeTo anchor: NSWindow)` is called on a floating panel.

## Postconditions

**Panel not currently visible** (`!isVisible`):
- Panel frame top-left is set to `NSPoint(x: anchor.frame.maxX + 12, y: anchor.frame.maxY - 40)`.
- `orderFront(nil)` is called to show the panel.

**Panel already visible** (`isVisible`):
- Frame position is NOT changed.
- `orderFront(nil)` is still called (brings to front if obscured).

## Invariants

- Panel style: `.titled | .closable | .utilityWindow | .nonactivatingPanel`.
- `isFloatingPanel = true`; `level = .floating`.
- `hidesOnDeactivate = false` — panel stays visible when app is deactivated.
- `becomesKeyOnlyIfNeeded = true` — panel takes key focus only when interacting with a text field; otherwise main window keeps key focus.
- `isReleasedWhenClosed = false` — panel is retained in memory on close; re-shown without recreation.

## Edge Cases

- **EC-001** — User moves the panel manually, then `present` is called again: panel stays at user's chosen position (position is not reset because `isVisible == true`).
- **EC-002** — Panel is closed (hidden) and `present` is called again: `!isVisible` is true; panel re-anchors to current main window position (which may have moved).
- **EC-003** — Main window is at the right edge of the screen: panel anchor places it at `maxX + 12`, which may go off-screen. No clamping is performed.
- **EC-004** — Multiple panels open simultaneously: each anchors independently to the same anchor window; they may overlap.

## Canonical Test Vectors

| Scenario | isVisible before | Panel position before | Expected position after |
|----------|-----------------|----------------------|------------------------|
| First open | false | (not set) | anchor.maxX + 12, anchor.maxY - 40 |
| Re-open after move | true | user-moved position | unchanged |
| Re-open after close | false | last-close position | anchor.maxX + 12, anchor.maxY - 40 |

## Error Handling

No errors. `orderFront(nil)` is unconditional.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/ImageEnhancePanel.swift:95-101`; `Sources/occ/VideoAdjustPanel.swift:128-134` |
| Ingest BC | BC-211 (pass-2-3-deep-panels-r2.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Display floating utility panels (keyboard, video adjust, image enhance) anchored to the main window without stealing key focus") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/ImageEnhancePanel.swift`, `Sources/occ/VideoAdjustPanel.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `ImageEnhancePanel.swift:95-101` `func present(relativeTo anchor:) { if !isVisible { setFrameTopLeftPoint(...) }; orderFront(nil) }`; `VideoAdjustPanel.swift:128-134` identical pattern; `ImageEnhancePanel.swift:20-23` panel style flags |
