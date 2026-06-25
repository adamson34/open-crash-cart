# Pass 2: Domain Model — OpenCrashCart

## 2a Structural (entities/value types/enums, real fields from source)
Types.swift value types:
- VideoFrame {width:Int, height:Int, pixels:[UInt8] BGRA row-major width*height*4}. Produced by tile decoder snapshot + UVC captureOutput; carried by AdapterEvent.frame.
- HIDKeyEvent {usage:UInt8 (HID; mods 0xE0-0xE7), modifiers:UInt8 (always 0 in practice), isDown:Bool, allReleased:Bool}.
- MouseButtons OptionSet UInt8 {left 1, right 2, middle 4}.
- MouseEvent {buttons:MouseButtons, x:Int16, y:Int16 (abs scaled or relative delta), wheel:Int16, isAbsolute:Bool}.
- KeyboardEmulation enum UInt8 {usb0, ps2 1, sun 2}.
- VideoAdjustment enum String CaseIterable {phase, horizontal, vertical, noise, sharpness}.
- KeyboardLEDs OptionSet {num1, caps2, scroll4}.
- NoVideoReason enum UInt8 {ok0, noSignal1, badMode2, dpmsStandby3, dpmsPowerdown4, noPower5, unstable6, badAuthcode7}.
- AdapterState enum {disconnected, connecting, noVideo(NoVideoReason), live(w,h,hz)}.
- AdapterStatus {state, keyboardOK, keyboardType, leds, fps, bytesPerSecond, adjustments:[VideoAdjustment:Int]}. differs(from:) ignores bytesPerSecond.
- AdapterEvent enum {status(AdapterStatus), frame(VideoFrame), message(String), mediaChanged(name:String?), disconnected(reason:String)}.
- DDCPreset enum Int CaseIterable {1280x1024=0,1024x768=1,1920x1200=2,1920x1080=3} + label.
Identity types:
- DiscoveredDevice {id "bus.address", vendorID, productID, busNumber, address, manufacturer?, product?, serial?, isHighSpeedOrBetter}.
- AdapterModel {id, name, vendorID, productIDs}. AdapterRegistry.known = one StarTech NOTECONS02 (VID 0x152A, PIDs 0x8460 gen-1, 0x8463 gen-2).
- HardwareProfile Codable {id, name, backend, vendorId:String, productIds:[String], firmwareFiles:[String], firmwareDir:String?, builtIn:Bool}; computed vid/pids via parse (hex 0x.. or decimal); matches(vid,pid).
- USBTransportError enum {contextInitFailed, deviceNotFound, openFailed, claimFailed, transferFailed, timeout, disconnected} + description.
VSProtocol: Endpoint {videoIn 0x82, streamIn 0x83, streamOut 0x04, dataIn 0x85, dataOut 0x05}, interface 0, fpgaBlockSize 507. Command enum (24 ASCII bytes). Response enum (15 ASCII bytes). Misc {phase0,posX1,posY2,countCC1 9,countCC2 15}. VSPack: keyEvent/mouseEvent/command packers.
CH9329 frame: 0x57 0xAB 0x00 cmd len data checksum. cmd 0x02 keyboard(8B), 0x04 abs mouse(reportId 0x02, x/y 0..4095), 0x05 rel mouse(reportId 0x01).
VirtualMedia {blockSize 2048(cdrom)/512(disk), blockCount, readOnly, name, handle}. init? fails if missing/zero. read/write/close.
Support: CommandQueue (2-priority NSCondition), AtomicFlag, ByteReader (BE u8/u16/u32), asciiz.

## 2b Behavioral
AdapterState machine (parseStatus): noVideo!=ok→.noVideo; else fpgaLoaded && w,h>0→.live(+setActiveSize); else→.connecting. Initial .disconnected; terminal via disconnect()/died() → .disconnected(reason). UVC sets .live(hz:0) on first frame, never noVideo.
StarTech boot: connect() opens/claims iface0/creates stream/emits "initializing"/warns if not High-Speed/starts Writer,Response,Video,Boot. boot() enqueues (control) getVersions 'v', getStatus 's', startVStream 'g', then load+uploadFPGA. uploadFPGA: 'f'+be16(seq)+be16(len)+507B payload; terminating len-0 block. Device acks fpgaGood 'F'→re-status; heartbeat 'H'→echo.
STATUS parse (35B CC2 misc15 / 29B CC1 misc9): BE fields fpgaLoaded,kbdType,kmOkay,leds,noVideo,w,h,hz,ticks,words,fps,misc[]. adjustments misc[0]phase,1horizontal(signed),2vertical(signed),3noise,4sharpness. bps=words*16*1000/ticks. Emitted only if differs.
Tile codec: 1920×1600 fb, 16×16 tiles (120×100), stride 1920*4. Records: padding (FFFF/FFFF → next 512B boundary), solid (word1&0x4000, word0=RGB565 fill, 4B), raw (4+512B, 256 LE RGB565). tileX=word1&0x7F, tileY=(word1>>7)&0x7F. RGB565→BGRA: B=(px<<3)&0xFF,G=(px>>3)&0xFC,R=(px>>8)&0xF8,A=0xFF. Leftover reassembly across transfers; frame emitted only if a tile written (sawTileSinceEmit). needsKeyframe wired but never set true.
Input: keysDown set; keyDown inserts then sends allReleased=false; keyUp removes then allReleased=keysDown.isEmpty; flagsChanged modifier-only guard; releaseAllKeys on blur. ⌘ unmapped. UVC applyKey maintains modifierByte + ≤6 keys, mouse coalesced.
Virtual media: mount → 'c'+media+le32(blocks)+mediaChanged. ftRead 'A' (le32 start/len → read image → EP0x05 ≤64KiB). ftWrite 'B' (← EP0x85 → write). eject → 'e'+close+mediaChanged(nil). ftStartStop 'G' bits&3==2 → eject.
Firmware: never bundled; search OCC_FIRMWARE_DIR→ProfileStore dir→app-support→vendor; gen≥2 prefers ulcvm.fgz.
DDC/tuning: setDDCPreset 'd'+rawValue+getVersions. miscIndex phase0/horizontal1/vertical2/noise3/sharpness4. setVideoAdjustment 'y'+idx+byte (clamp [-128,255], 2's-comp). save 'u', reset 'z'. autoTuneVideo 'p'+'i'.

## Flagged
- HIDKeyEvent.modifiers always 0 (state event-derived). needsKeyframe dormant. VSProtocol.Misc constants distinct from miscIndex map. STATUS pixPerClk/savedPos/fpgaPowered read-and-discarded.
(Two Mermaid diagrams in full transcript.)
