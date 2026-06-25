# Behavioral Contract Index — OpenCrashCart

**Source:** product-brief.md · **Status:** draft · **Total:** 124 contracts across 6 subsystems

Each contract is one file under `ss-NN/BC-S.SS.NNN.md`. Numbering: `BC-1.SS.NNN` (S=PRD section 1, SS=subsystem, NNN sequential).
v1.1.0 change contracts (the P1 fixes) carry **`introduced: v1.1.0`**; all others formalize existing v1.0.0 behavior.

## SS-01: Session & Connection Lifecycle (HIGH)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.01.001 | StarTech Generation Derivation from PID | v1.0.0 |
| BC-1.01.002 | StarTech connect() Ordering — Open, Claim, Threads, Boot | v1.0.0 |
| BC-1.01.003 | StarTech Boot Handshake Sequence — v, s, g then FPGA | v1.0.0 |
| BC-1.01.004 | Response Dispatch and Heartbeat Echo | v1.0.0 |
| BC-1.01.005 | STATUS Packet Parse, State Derivation, and On-Change Emit | v1.0.0 |
| BC-1.01.006 | StarTech Disconnect and died() Teardown | v1.0.0 |
| BC-1.01.007 | USB Device Open by Bus+Address, else deviceNotFound | v1.0.0 |
| BC-1.01.008 | libusb Return Code to Error Mapping | v1.0.0 |
| BC-1.01.009 | bulkRead Returns Transferred-Byte Prefix with Default Timeouts | v1.0.0 |
| BC-1.01.010 | Disconnected Guard Before Transfer and Idempotent close() | v1.0.0 |
| BC-1.01.011 | gunzip Round-Trip with windowBits 47 | v1.0.0 |
| BC-1.01.012 | gunzip Error Mapping — initFailed and inflateFailed | v1.0.0 |
| BC-1.01.013 | Firmware Search-Directory Order | v1.0.0 |
| BC-1.01.014 | FPGA File Selection — Profile vs Generation, notFound Error | v1.0.0 |
| BC-1.01.015 | FPGA Upload — 'f' Command, 507-Byte Framing, Length-0 Terminator | v1.0.0 |
| BC-1.01.016 | CommandQueue — Input-Before-Control Priority Drain | v1.0.0 |
| BC-1.01.017 | Virtual Media Geometry — ISO 2048 RO / IMG 512 RW | v1.0.0 |
| BC-1.01.018 | Block Read Zero-Pads Short and Closed Reads | v1.0.0 |
| BC-1.01.019 | Write No-Op on RO/Closed and Idempotent close() | v1.0.0 |
| BC-1.01.020 | FT Virtual Media Wire Commands — 'c', 'A', 'B', 'G' | v1.0.0 |
| BC-1.01.021 | tryConnect Idempotent Guard | v1.0.0 |
| BC-1.01.022 | No-Device Cleans State and Shows noAdapter | v1.0.0 |
| BC-1.01.023 | connecting Flag Spans Entire Async Handshake | v1.0.0 |
| BC-1.01.024 | Connect-Fail Full Reset | v1.0.0 |
| BC-1.01.025 | 2-Second Rescan as Sole Auto-Reconnect Driver | v1.0.0 |
| BC-1.01.026 | OCC_SECONDS Environment Variable Triggers Auto-Quit | v1.0.0 |
| BC-1.01.027 | applicationWillTerminate Cancels Task and Fire-and-Forget Disconnect | v1.0.0 |
| BC-1.01.028 | .disconnected Event Re-Arms Rescan and Resets didAutoSize | v1.0.0 |
| BC-1.01.029 | Live Status Auto-Sizes Window Exactly Once Per Session | v1.0.0 |
| BC-1.01.030 | Device Adjustments Cached Not Pushed to Live Sliders | v1.0.0 |
| BC-1.01.031 | UVC Menu Connect Tears Down Prior Adapter First | v1.0.0 |
| BC-1.01.032 | UVC Submenu Lazily Populated on Open | v1.0.0 |
| BC-1.01.033 | Reconnect Triggers Immediate Rediscovery; Disconnect Leaves Rescan Running (Current Defect) | v1.0.0 |
| BC-1.01.034 | Disconnect Stays Disconnected (v1.1.0 — userDisconnected Flag) | v1.1.0 |
| BC-1.01.035 | Settings onChange Triggers menuReconnect | v1.0.0 |
| BC-1.01.036 | Ctrl-Alt-Del / Windows 0xE3 / Escape 0x29 Direct Chords | v1.0.0 |
| BC-1.01.037 | Paste Gated on Non-Empty Clipboard | v1.0.0 |
| BC-1.01.038 | Type-Text Empty-Field Allowed vs Paste Non-Empty Asymmetry | v1.0.0 |
| BC-1.01.039 | On-Screen Chord Key Ordering — Down, Key, Up, Reversed Mods | v1.0.0 |
| BC-1.01.040 | Relative Mouse Toggle Tri-Sync — State, Menu, View, Status | v1.0.0 |

## SS-02: Video Pipeline & Decoder Resilience (HIGH)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.02.001 | Tile Record Header Bit-Field Extraction (tileX / tileY / solid) | v1.0.0 |
| BC-1.02.002 | Solid-Fill Tile RGB565 to BGRA Conversion (4-Byte Record) | v1.0.0 |
| BC-1.02.003 | Raw Tile 516-Byte Record with RGB565 Green Channel (G=0xFC) | v1.0.0 |
| BC-1.02.004 | Absolute Framebuffer Addressing into 1920-Wide Buffer | v1.0.0 |
| BC-1.02.005 | FFFF/FFFF Padding Record Advances to Next 512-Byte Boundary | v1.0.0 |
| BC-1.02.006 | Partial Record Reassembly Across USB Transfers (Incomplete Returns Nil) | v1.0.0 |
| BC-1.02.007 | Frame Emitted Only When at Least One Tile Written (sawTileSinceEmit Gate) | v1.0.0 |
| BC-1.02.008 | Out-of-Range Tile Coordinates Skipped and Record Consumed | v1.0.0 |
| BC-1.02.009 | setActiveSize Clamps to [1, Max] and Crops Output Frame | v1.0.0 |
| BC-1.02.010 | STATUS Parse — State Derivation (live / noVideo / connecting) and bps/fps Computation | v1.0.0 |
| BC-1.02.011 | VideoView Default frameSize 1024x768 | v1.0.0 |
| BC-1.02.012 | makeCGImage BGRA noneSkipFirst | byteOrder32Little, nearest Magnification | v1.0.0 |
| BC-1.02.013 | Display Pipeline Raw vs Enhanced (layer.contents Path) | v1.0.0 |
| BC-1.02.014 | Absolute Mouse Letterbox-Aware Pixel Mapping Clamped to [0, dim-1] | v1.0.0 |
| BC-1.02.015 | Relative Mouse Mode Rounded Clamped Int16 Deltas | v1.0.0 |
| BC-1.02.016 | Mouse Buttons from pressedMouseButtons Global State, Wheel ±1/0 | v1.0.0 |
| BC-1.02.017 | Mouse Suppressed During OCR Region Selection | v1.0.0 |
| BC-1.02.018 | Decoder Requests Keyframe on Desync (v1.1.0 — Corrects Dormant Defect) | v1.1.0 |

## SS-03: Screen OCR & Capture (MEDIUM)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.03.001 | OCR Recognition Runs Off-Main Thread with Accurate Level and No Language Correction | v1.0.0 |
| BC-1.03.002 | OCR Observations Ordered Top-to-Bottom Then Left-to-Right with 0.012-Band Grouping | v1.0.0 |
| BC-1.03.003 | handleOCR Trims Result and Copies to Clipboard Only on Non-Empty; Cancel and Empty Have Distinct Status Messages | v1.0.0 |
| BC-1.03.004 | OCR Entry Requires a Live Session | v1.0.0 |
| BC-1.03.005 | OCR Region Selection Produces Clamped Floor/Ceil Pixel Crop of Raw Frame; Drag Under 3pt or Crop Under 4px Yields Nil | v1.0.0 |
| BC-1.03.006 | Esc Cancels OCR Selection; All Keyboard Events Are Swallowed During Selection Mode | v1.0.0 |
| BC-1.03.007 | snapshotPNG Returns PNG Data from Raw lastImage | v1.0.0 |
| BC-1.03.008 | Recorder Drops Size-Mismatch Frames to Prevent File Corruption | v1.0.0 |
| BC-1.03.009 | Recorder Lazy Session Start on First Accepted Frame with Real-Time PTS at Timescale 600 | v1.0.0 |
| BC-1.03.010 | Recorder init Fails Closed When AVAssetWriter or canAdd Fail | v1.0.0 |
| BC-1.03.011 | Recorder finish Short-Circuits with frameCount=0 When Never Started; Record Start Requires isLive and Non-Zero frameSize.width | v1.0.0 |
| BC-1.03.012 | OCR Failure Surfaces and Clears Status (v1.1.0) | v1.1.0 |
| BC-1.03.013 | Image Enhancement Is Display-Only; Snapshot and OCR Always Use the Raw Frame | v1.0.0 |
| BC-1.03.014 | ImageEnhancePanel Emits Normalized ÷100 ImageEnhancement Values and Reset Emits Default | v1.0.0 |
| BC-1.03.015 | VideoAdjustPanel Tick-Quantized Integer-Only Sliders with Deduplication and apply() Syncs Without Emit | v1.0.0 |
| BC-1.03.016 | Floating Panels Anchor Once on First Present; Non-Activating with Main Window Retaining Key Focus | v1.0.0 |

## SS-04: Device Identity & Hardware Profiles (HIGH)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.04.001 | HardwareProfile VID/PID String Parsing — Hex or Decimal, Default 0 | v1.0.0 |
| BC-1.04.002 | HardwareProfile.matches() — Fail-Closed VID+PID Conjunction | v1.0.0 |
| BC-1.04.003 | HardwareProfile JSON Round-Trip Fidelity and Equatable Conformance | v1.0.0 |
| BC-1.04.004 | HardwareProfile Two-Tier Firmware Location — Profile Override vs. Store Directory | v1.0.0 |
| BC-1.04.005 | ProfileStore Seed and Self-Heal — Missing/Corrupt vs. Empty-Array Distinction | v1.0.0 |
| BC-1.04.006 | ProfileStore.remove() — Built-In Profiles Are Non-Deletable | v1.0.0 |
| BC-1.04.007 | ProfileStore.upsert() — ID-Keyed Replace-or-Append Write-Through | v1.0.0 |
| BC-1.04.008 | ProfileStore.firmwareDirectory — Immediate-Persist Setter and NSLock-Guarded Accessors | v1.0.0 |
| BC-1.04.009 | ProfileStore.writeToDisk() — Pretty+SortedKeys JSON, Silent Write Failure | v1.0.0 |
| BC-1.04.010 | SettingsWindow — Empty Name Aborts Profile Save | v1.0.0 |
| BC-1.04.011 | SettingsWindow — CSV Field Parsing, Firmware Default, and Profile Construction | v1.0.0 |
| BC-1.04.012 | SettingsWindow — New vs. Edit Profile Provenance (ID, Backend, builtIn) | v1.0.0 |
| BC-1.04.013 | SettingsWindow — Built-In Profiles Are Non-Deletable in UI | v1.0.0 |
| BC-1.04.014 | SettingsWindow — Live USB Presence Dot, Graceful Enumeration Failure | v1.0.0 |
| BC-1.04.015 | SettingsWindow — Firmware Import: Copy into App Support and Repoint Store Directory | v1.0.0 |
| BC-1.04.016 | DDCPreset — 4-Case Enum with rawValue 0..3 | v1.0.0 |
| BC-1.04.017 | setDDCPreset — Fire-and-Forget with getVersions Side Effect, Not Persisted | v1.0.0 |
| BC-1.04.018 | MISC Video Adjustment — Encode, Clamp [-128..255], Save, and Reset | v1.0.0 |
| BC-1.04.019 | Theme.padding — Dual-Clamp State Machine: Env/UserDefaults/Adjust/Reset with Persist and onChange | v1.0.0 |
| BC-1.04.020 | Single Source of Truth for Device Matching — AdapterRegistry and StarTechAdapter Derive from Built-In HardwareProfile (v1.1.0) | v1.1.0 |

## SS-05: Input & UVC/CH9329 Backend (HIGH)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.05.001 | VSP keyEvent Wire Framing | v1.0.0 |
| BC-1.05.002 | VSP mouseEvent Absolute Big-Endian Framing | v1.0.0 |
| BC-1.05.003 | VSP Mouse Button Bitmask Encoding | v1.0.0 |
| BC-1.05.004 | VSP Bare Command Packing | v1.0.0 |
| BC-1.05.005 | VSP USB Bulk Endpoint Address Map | v1.0.0 |
| BC-1.05.006 | HID Keymap macOS-to-USB-HID Usage Translation | v1.0.0 |
| BC-1.05.007 | Command Key Suppression and Right-Command Omission | v1.0.0 |
| BC-1.05.008 | HID Modifier Usage Range Detection | v1.0.0 |
| BC-1.05.009 | HID Typing Strokes US-ASCII Shift Logic | v1.0.0 |
| BC-1.05.010 | CH9329 Wire Frame Structure and Checksum | v1.0.0 |
| BC-1.05.011 | CH9329 Keyboard Report Pad-to-6 Keys | v1.0.0 |
| BC-1.05.012 | CH9329 Absolute Mouse Coordinate Scaling 0..4095 | v1.0.0 |
| BC-1.05.013 | CH9329 Relative Mouse Signed Byte Encoding | v1.0.0 |
| BC-1.05.014 | CH9329 Serial Port Discovery and Environment Override | v1.0.0 |
| BC-1.05.015 | UVC Adapter View-Only Mode Without CH9329 | v1.0.0 |
| BC-1.05.016 | UVC Input State Modifier Byte and 6KRO Key Tracking | v1.0.0 |
| BC-1.05.017 | UVC Mouse Event Coalescing Latest-Wins for Slow Serial | v1.0.0 |
| BC-1.05.018 | VideoView Command-Modified Press Suppression and KeyUp Forwarding | v1.0.0 |
| BC-1.05.019 | VideoView flagsChanged isModifier Guard Prevents Stray A Keystroke | v1.0.0 |
| BC-1.05.020 | VideoView releaseAllKeys on Focus Loss and resignFirstResponder | v1.0.0 |

## SS-06: Quality Gates & Test Coverage (MEDIUM)

| BC ID | Title | Introduced |
|-------|-------|-----------|
| BC-1.06.001 | Dependency-Free Harness Executes as `occ-tests` and Exits Non-Zero on Any Failure | v1.0.0 |
| BC-1.06.002 | CI Gate Runs `swift build` Then `swift run occ-tests` on Push/PR to main and dev | v1.0.0 |
| BC-1.06.003 | App Bundle Is Self-Contained, Ad-Hoc Signed, and Quarantine-Clearable | v1.0.0 |
| BC-1.06.004 | Harness Test Exists Verifying USB libusb Return-Code to Error Mapping (Ingest BC-021) | v1.1.0 |
| BC-1.06.005 | Harness Test Exists Verifying Virtual-Media Block Math Including Zero-Pad and RO Guard (Ingest BC-060..062) | v1.1.0 |
| BC-1.06.006 | Harness Test Exists Verifying Firmware Search-Directory Order (Ingest BC-052) | v1.1.0 |
| BC-1.06.007 | Harness Test Exists Verifying STATUS Message Parse, State Derivation, and bps Formula (Ingest BC-084) | v1.1.0 |
| BC-1.06.008 | Harness Test Exists Verifying CH9329 Mouse Coalescing Latest-Wins (Ingest BC-036) | v1.1.0 |
| BC-1.06.009 | Harness Test Exists Verifying Command-Queue Input-Before-Control Priority (Ingest BC-037) | v1.1.0 |
| BC-1.06.010 | Every v1.1.0 Change BC Ships with a Harness Test Verifying the Corrected Behavior | v1.1.0 |

