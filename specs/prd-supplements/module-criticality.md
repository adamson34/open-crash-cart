---
document_type: prd-supplement-module-criticality
level: L3
status: draft
traces_to: prd.md
---

# Module Criticality — OpenCrashCart

Criticality drives review depth, test-coverage requirement, and holdout density. No financial/PII
data flows here, so "CRITICAL" maps to **data-integrity + device-safety on a live target**.

| Module | Criticality | Rationale | Test requirement |
|--------|-------------|-----------|------------------|
| `Input/HIDKeymap`, `Input/HIDTyping`, key-safety (VideoView keyDown/Up/flagsChanged/releaseAllKeys) | **CRITICAL** | A stuck/stray key on a live production host is the highest-harm failure (REL-01..04). | Full coverage; v1.1.0 keeps these test-pinned. |
| `Adapters/StarTech/VSProtocol`, `StarTechTileDecoder` | **CRITICAL** | Wire framing + codec correctness; a wrong byte mis-drives the target or corrupts video. | Test-pinned (existing); keyframe self-heal added (BC-1.02.018). |
| `Adapters/UVC/CH9329`, `SerialPort` | **HIGH** | HID injection over serial; wrong frame = wrong input on target. | CH9329 framing test-pinned; coalescing test backfill (BC-1.06.008). |
| `Adapters/StarTech/StarTechAdapter` (transport, boot, virtual media) | **HIGH** | 3-thread transport + FPGA upload + disk-image read/write integrity. | Backfill virtual-media + STATUS-parse tests (BC-1.06.005/007). |
| `USB/USBDevice`, `USBEnumeration` | **HIGH** | libusb error mapping decides fatal-vs-transient; mis-map drops or hangs sessions. | Backfill rc→error-mapping test (BC-1.06.004). |
| `Adapter/ProfileStore`, `HardwareProfile`, `AdapterRegistry`, `AdapterFactory` | **HIGH** | Device identity + persisted config + the v1.1.0 single-source-of-truth fix (BC-1.04.020). | Profile tests pinned; registry-derivation test on the fix. |
| `occ/AppController` (session lifecycle + menus) | **HIGH** | Owns connect/disconnect/rescan; the P1.1 Disconnect fix lives here (BC-1.01.034). | Add coverage for the userDisconnected flag. |
| `Adapters/StarTech/StarTechFirmware`, `Util/Gunzip` | **MEDIUM** | Firmware location/inflate; failure degrades (skip), not unsafe. | gunzip pinned; firmware-search test backfill (BC-1.06.006). |
| `occ/VideoView` (render + mouse mapping + OCR selection) | **MEDIUM** | Display + pointer mapping; errors are cosmetic/usability, not target-unsafe. | Letterbox-mapping coverage desirable. |
| `occ/OCR`, `occ/Recorder` | **MEDIUM** | Read-only capture features; OCR stuck-status fix is a UX bug (BC-1.03.012). | OCR-failure path test on the fix. |
| `occ/SettingsWindow` | **MEDIUM** | Profile editing/firmware import; validation gaps are recoverable. | Validation coverage desirable. |
| `occ/{Theme, ToolbarStrip, StatusBar, KeyboardPanel, VideoAdjustPanel, ImageEnhancePanel, PlaceholderView}` | **LOW** | Cosmetic/chrome; failures are visual. | Smoke-level only. |
| `packaging/`, `scripts/make-app.sh`, `.github/workflows/ci.yml` | **LOW** | Build/release; covered by the CI gate (BC-1.06.002/003). | CI green. |

## Coverage policy (BC-1.06.010)
Every v1.1.0 change BC (the four P1 fixes + six test-backfill requirements) ships with a harness test
that **fails on pre-fix code and passes on post-fix code** (red-green gate). CRITICAL/HIGH modules
require a test for any changed behavior; MEDIUM require a test for the specific fix; LOW are smoke-level.
