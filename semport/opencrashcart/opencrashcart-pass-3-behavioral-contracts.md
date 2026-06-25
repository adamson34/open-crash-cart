# Pass 3: Behavioral Contracts — OpenCrashCart

Decoder identity (confirmed): PlaceholderVideoDecoder's "no pixel decoding yet" comment is STALE; StarTechTileDecoder is the real default decoder (StarTechAdapter.init default param, all tile tests construct it, docs/CODEC.md:73). HIGH.

Confidence: HIGH=test-pinned or unambiguous constant; MEDIUM=code control-flow, no test; LOW=docs/comments only.

## Protocol packing (HIGH, tests)
- BC-001 keyEvent: VSPack.keyEvent → [0x6B,usage,mods,down,allUp]. (ProtocolTests:6-7)
- BC-002 mouseEvent abs: → [0x6D,abs,buttons,be16 x,be16 y,be16 wheel]; -5→0xFFFB. (ProtocolTests:9-11)
- BC-003 button bitmask right|middle=6. (ProtocolTests:13-15)
- BC-004 command → single ASCII byte (s=0x73,g=0x67). (ProtocolTests:17-18)
- BC-005 endpoints videoIn 0x82, streamOut 0x04, dataIn 0x85. (ProtocolTests:20-22)

## Tile codec (HIGH, tests)
- BC-010 header: tileX=word1&0x7F, tileY=(word1>>7)&0x7F, solid=word1&0x4000.
- BC-011 solid fill RGB565→BGRA, 4B record (red 0xF800→0,0,F8,FF). (TileDecoderTests:20-25)
- BC-012 raw tile 516B, green 0x07E0→G=0xFC. (TileDecoderTests:27-32,54)
- BC-013 absolute addressing into 1920-wide fb; tile(2,1)→x[32,47]y[16,31]. (TileDecoderTests:34-39)
- BC-014 FFFF/FFFF padding → next 512B boundary. (TileDecoderTests:41-48)
- BC-015 partial record reassembled across two ingests; first returns nil. (TileDecoderTests:50-58)
- BC-016 frame emitted only when a tile written this call.
- BC-017 out-of-range tile skipped, record consumed. (MEDIUM)
- BC-018 setActiveSize clamps [1,max], crops output. (MEDIUM)
- BC-019 needsKeyframe never set true → documented desync/I-frame loop dormant. (LOW/divergence)

## USB transport (MEDIUM/HIGH code)
- BC-020 open matches exact bus+address, else deviceNotFound; ctx exit on failure.
- BC-021 libusb rc map: 0 ok, -7 timeout, -4 disconnected, else transferFailed. (HIGH constants)
- BC-022 bulkRead returns transferred prefix; default read 2000ms, write 1000ms.
- BC-023 disconnected guard before transfer; close() idempotent.

## Input/HID (HIGH tests)
- BC-030 keymap: 0x00→0x04,0x24→0x28,0x7E→0x52,0x38→0xE1. (KeymapTests)
- BC-031 Command 0x37/0x36 unmapped (nil); unknown→nil. (KeymapTests)
- BC-032 isModifier 0xE0..0xE7. (KeymapTests)
- BC-033 typing strokes: a→(0x04,F), A→(0x04,T), 1→(0x1E,F), !→(0x1E,T), space 0x2C, \n Enter; "Hi!" sequence. (TypingTests)
- BC-034 unmapped chars skipped. (TypingTests)
- BC-035 CH9329 input state: mod bit 1<<(usage-0xE0); ≤6 keys; allReleased clears. (MEDIUM)
- BC-036 mouse coalescing latest-wins. (MEDIUM)
- BC-037 CommandQueue input drained before control. (MEDIUM)

## UVC/CH9329 (BC-040 HIGH test, rest MEDIUM)
- BC-040 frame 0x57 0xAB 0x00 cmd len data checksum(sum&0xFF); empty kbd→checksum 0x0C; CtrlAltDel payload→0x5D. (ProtocolTests:24-30)
- BC-041 kbd report pad-to-6.
- BC-042 abs mouse scale 0..4095.
- BC-043 rel mouse signed bytes.
- BC-044 serial discovery cu.usbserial/wchusbserial/usbmodem; OCC_CH9329_PORT/BAUD; default 9600.
- BC-045 UVC view-only without CH9329; canDrive false; BGRA; keyboardOK=hasHID.

## Firmware (HIGH test for gunzip, rest MEDIUM)
- BC-050 gunzip round-trip; windowBits 47. (GunzipTests)
- BC-051 init/inflate error mapping.
- BC-052 firmware search order (profile→env→store→app-support→vendor).
- BC-053 file selection profile vs generation; notFound lists searched.
- BC-054 FPGA upload 'f'+be16(seq)+be16(len)+507B; len-0 terminator. (507 HIGH)

## Virtual media (MEDIUM)
- BC-060 geometry ISO 2048 RO / IMG 512 RW; blockCount=size/blockSize.
- BC-061 read zero-pads short/closed.
- BC-062 write no-op if RO/closed; close idempotent.
- BC-063 FT wire integration ('c'/'A'/'B'/'G').

## Profiles (HIGH tests)
- BC-070 vid/pid parse hex or decimal. (ProfileTests)
- BC-071 matches vid && pids.contains. (ProfileTests)
- BC-072 JSON round-trip Equatable. (ProfileTests)
- BC-073 ProfileStore persist/seed; built-ins not deletable.

## StarTech lifecycle (MEDIUM)
- BC-080 PID 0x8463→gen2 else gen1. (HIGH)
- BC-081 connect→claim→threads→boot ordering.
- BC-082 boot order v,s,g then FPGA (doc lists e too — minor divergence).
- BC-083 response dispatch + heartbeat echo.
- BC-084 STATUS parse 29/35B; bps formula; state derivation; on-change emit.
- BC-085 MISC encode + clamp.
- BC-086 disconnect/died teardown.

## Gaps (test-backfill targets): USB mapping, virtual media math, firmware search, FPGA upload framing, STATUS parse, mouse coalescing, command-queue priority — all code-grounded but UNTESTED.
