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
# Behavioral Contract BC-1.01.032: UVC Submenu Lazily Populated on Open

## Description
The UVC device submenu (`uvcMenu`) is populated lazily via `NSMenuDelegate.menuNeedsUpdate(_:)`: when the menu is about to open, all items are removed and replaced with the current list of discovered UVC devices. If no devices are found, a single disabled "No UVC devices found" item is shown. Items are never pre-populated; the list is always fresh at open time.

## Preconditions
1. `uvcMenu.delegate == self` (set in `installMenuBar`).
2. The user opens the "Connect UVC Device" submenu.

## Postconditions
1. `menu.removeAllItems()` is called at the start of each update.
2. `discoverUVCDevices()` is called to get the current device list.
3. If empty: one disabled "No UVC devices found" item is added.
4. If non-empty: one enabled `NSMenuItem` per device is added with `representedObject = device.id`.
5. The action for each item is `#selector(menuConnectUVC(_:))`.

## Invariants
1. The menu always reflects the device state at the moment it opens.
2. Stale device entries from a previous open are never shown.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | No UVC devices present | Single disabled "No UVC devices found" item |
| EC-002 | Device removed between two opens | Not shown at second open |
| EC-003 | Multiple UVC devices | One item per device, all enabled |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| 2 UVC devices present | Menu shows 2 enabled items with device names | happy-path |
| 0 UVC devices | Menu shows 1 disabled "No UVC devices found" | edge case |

## Error Handling
No errors. `discoverUVCDevices()` failures produce an empty list.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:200-216 |
| Ingest BC | BC-111 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
