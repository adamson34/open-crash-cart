# Pass 5: Convention & Pattern Catalog — OpenCrashCart

Unusually disciplined for its size; most patterns "consistent" or "mostly".

## 1. Naming
- OCC/OCCKit/occ three-tier: OCCKit (lib module), occ (app exe+folder), occ-<verb> (CLIs), OCC_ (env prefix). Consistent.
- Env prefix OCC_ on all 6 overrides; read-with-fallback idiom. Consistent.
- PascalCase types, one primary type/file, backend prefix (StarTech*); protocol suffixes -ing/-Actions/-Input. Minor "support" aggregations (Types, ToolbarStrip, StarTechSupport) intentional.
- Protocol bytes named by function + ASCII annotation (getStatus=0x73 // 's'); VSPack echoes Python struct.pack.

## 2. Module organization
- Adapter/ (singular = abstractions) vs Adapters/ (plural = concretes) — the load-bearing split, strictly honored.
- One-backend-per-folder, self-contained. (Leak: USBDevice.close references VSProtocol.interfaceNumber.)
- Protocol + default-extension: CrashCartAdapter declares full surface; extension supplies no-op defaults + shared typeText/sendKeyPress/sendCtrlAltDel. Central extensibility mechanism.
- Factory/Registry/ProfileStore separation (construction / compiled catalogue / user JSON). Dual-match redundancy.
- CrashCartAdapter seam: UI holds only `any CrashCartAdapter`, never a concrete backend. Respected.

## 3. Concurrency (model area — 4 stratified mechanisms)
- @unchecked Sendable + manual NSLock/NSCondition for all 9 shared-state classes; uniform lock();defer{unlock()}.
- Dedicated named Threads (1MiB) for blocking libusb loops via startThread; poll AtomicFlag running.
- AsyncStream<AdapterEvent> + Continuation + emit() for device→UI; consumed in @MainActor Task.
- DispatchQueue for AVFoundation/serial (UVC captureQueue/inputQueue); @MainActor for all UI; MainActor.assumeIsolated bridges timer/notif callbacks.
- nonisolated(unsafe) used exactly twice (AVCaptureSession start/stop), both justified. Consistent.

## 4. Error handling
- Typed enum: Error, CustomStringConvertible per subsystem (USBTransportError, USBError, GzipError, UVCError, FirmwareError); C codes wrapped never leaked.
- Throwing init for libusb transport; init? optional for local resources (SerialPort/CH9329/VirtualMedia). Principled split.
- do/catch in transport loops: disconnected→died, timeout/other→continue (identical in all 3 loops).
- Graceful degradation: UVC view-only without CH9329; FPGA-skip; best-effort USB strings; try? for non-critical persistence.

## 5. C interop
- systemLibrary modulemap shims (Clibusb direct header, Czlib shim.h). Identical structure.
- Pointer idioms: OpaquePointer handles, withUnsafeMutableBufferPointer for transfers/zlib, withCString for paths, defer for every C cleanup. ~20 sites confined to USB/serial/gzip leaves.
- Foundation.close qualification (all 3 POSIX-close sites).
- Struct-packed [UInt8] wire format with manual BE helpers + ByteReader + mod-256 checksum. No Data overlay tricks.

## 6. Comments/docs
- High /// density, intent-first; no undocumented file.
- Reverse-engineering provenance + clean-room notes (signature convention): every RE'd surface points to a spec doc + asserts clean-room. Load-bearing for legal posture.
- Phase markers ("Phase 1 smoke test", "Phase 3 will return decoded frames") — scattered but non-contradictory.
- // MARK: sectioning in files >150 LOC.

## 7. Tests
- Hand-rolled Harness (section/expect/expectEqual/finish->Never exit(1)); one run<Area>Tests(t) free function per file.
- Pure-logic focus (packing, codec, keymap, typing, profiles, gunzip); no USB/AVFoundation/AppKit exercised (deliberate boundary; injectable decoder enables hardware-free decode tests).
- Byte-exact assertions with computed expectations; CI via swift run occ-tests.

## 8. UI
- Floating NSPanel (.floating) for all aux tools (VideoAdjust, ImageEnhance, Keyboard, HoverTip).
- Theme singleton (@MainActor) centralizes colors/metrics/padding; ~all UI reads Theme.shared.
- ToolbarButton factory + declarative (symbol,tooltip,selector) assembly.
- @MainActor delegate protocols (ToolbarActions 15 methods, VideoViewInput 2) held weak; @objc thunks forward selectors.
- AppKit idioms: required init?(coder:) fatalError, wantsLayer, autolayout activate([]).

## 9. Inconsistencies (minor)
1. Dual device-matching source of truth (AdapterRegistry vs ProfileStore); same StarTech model hardcoded in 3 places (Registry.known, ProfileStore.builtIns, StarTechAdapter.model) → PID change needs 3 edits.
2. StarTech specific (VSProtocol.interfaceNumber) leaks into generic USBDevice.close.
3. Two loadFPGABitstream/two locate overloads (profile vs generation) — mild redundancy.
4. VideoAdjustment.sharpness maps to MISC index 4 documented "flatness" — vocabulary drift.
5. A few UI styles bypass Theme (HoverTip bubble, inline hover whites).
6. VSProtocol.Misc vs StarTechAdapter.miscIndex — two parallel MISC encodings.

## Summary: ~two dozen consistently-applied conventions. Standouts: (a) 4-way layered concurrency, (b) Adapter/ vs Adapters/ seam + protocol-default extensibility, (c) systematic RE-provenance/clean-room comments.
