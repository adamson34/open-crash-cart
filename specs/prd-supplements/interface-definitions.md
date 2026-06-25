---
document_type: prd-supplement-interface-definitions
level: L3
status: draft
traces_to: prd.md
---

# Interface Definitions — OpenCrashCart

## 1. Core library export: the `CrashCartAdapter` seam
Every backend conforms to this; the UI/CLIs depend only on it + the value types.

```
protocol CrashCartAdapter: AnyObject, Sendable {
  static var model: AdapterModel { get }
  static func canDrive(_ device: DiscoveredDevice) -> Bool
  func connect() async throws -> AsyncStream<AdapterEvent>
  func disconnect() async
  func send(key: HIDKeyEvent)
  func send(mouse: MouseEvent)
  // default no-op extension: requestKeyframe, autoTuneVideo, mountMedia, ejectMedia,
  //   setVideoAdjustment, saveVideoAdjustment, resetVideoAdjustment, setDDCPreset
  // convenience extension: typeText, sendKeyPress, sendCtrlAltDel
}
```

### Value types (Types.swift)
- `VideoFrame { width, height, pixels:[UInt8] BGRA }`
- `HIDKeyEvent { usage:UInt8, modifiers:UInt8, isDown:Bool, allReleased:Bool }`
- `MouseEvent { buttons:MouseButtons, x:Int16, y:Int16, wheel:Int16, isAbsolute:Bool }`
- `AdapterState { disconnected | connecting | noVideo(NoVideoReason) | live(w,h,hz) }`
- `AdapterStatus { state, keyboardOK, keyboardType, leds, fps, bytesPerSecond, adjustments }`
- `AdapterEvent { status | frame | message | mediaChanged(name:) | disconnected(reason:) }`
- `DDCPreset` (4 cases rv 0..3), `VideoAdjustment { phase, horizontal, vertical, noise, sharpness }`

### Factory / discovery
- `makeAdapter(for: DiscoveredDevice, profile: HardwareProfile) -> (any CrashCartAdapter)?`
  (selects on `profile.backend`; `"dmtz-vsp"` → StarTech). **v1.1.0 (BC-1.04.020):** registry/model
  derive from the built-in profile.
- `discoverProfiledDevices() -> [(DiscoveredDevice, HardwareProfile)]`
- UVC is reached via the app menu only (`UVCAdapter(deviceID:)`), not `makeAdapter` (documented asymmetry).

## 2. CLI commands
- **`occ-probe`** — enumerate USB, print VID/PID/bus/addr/product/serial/link-speed + recognized
  backend; warns on Full-Speed ("video will be slow"). Exit 0.
- **`occ-connect`** — discover + connect a StarTech adapter, print the event stream live (unbuffered);
  honors `OCC_SECONDS` auto-stop (default 20s); errors to stderr, non-zero exit. (StarTech only — no UVC.)
- **`occ-tests`** — dependency-free harness; `exit(1)` on any failure (CI gate).

## 3. App command surface (menu / toolbar)
Connection: Reconnect ⌘⇧R, Disconnect, Connect UVC Device (dynamic), Mount/Eject ISO, Record ⌘⇧E,
Snapshot ⌘S, OCR ⌘⇧C. Keyboard: On-Screen ⌘K, Paste ⌘⇧V, Type Text, Ctrl-Alt-Del, Windows key
(0xE3), Escape (0x29). Video: Refresh ⌘R, Auto-Tune, Adjustments, Image Enhancement, DDC submenu.
View: Fit, Actual, Fullscreen ⌘⌃F, Relative Mouse, padding ⌘+/⌘−/⌘0.

## 4. Configuration surface
- **Env vars:** `OCC_FIRMWARE_DIR`, `OCC_PADDING`, `OCC_SECONDS`, `OCC_CH9329_PORT`, `OCC_CH9329_BAUD` (default 9600).
- **Files:** `~/Library/Application Support/OpenCrashCart/profiles.json` (Codable HardwareProfile list),
  `…/firmware/` (BYO bitstreams), UserDefaults `OpenCrashCartPadding`.
- **Wire (StarTech VSP):** bulk EP 0x82 video / 0x83 response / 0x04 command / 0x85,0x05 data; ASCII
  command/response bytes; big-endian payloads; FPGA block 507B.
- **Wire (CH9329):** `0x57 0xAB 0x00 <cmd> <len> <data> <checksum=sum&0xFF>`; cmd 0x02 keyboard / 0x04 abs / 0x05 rel.

## 5. Hardware profile (JSON shape)
```
{ "id", "name", "backend", "vendorId" (hex or decimal),
  "productIds": [...], "firmwareFiles": [...], "firmwareDir"?, "builtIn": bool }
```
