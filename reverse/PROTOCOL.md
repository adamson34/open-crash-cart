# StarTech NOTECONS02 USB Crash Cart Adapter — Reverse-Engineered Protocol

Source: `/Applications/USB Crash Cart Adapter.app` v124.517 (May 2024).
Original app: Python 2.7 + wxPython, py2app bundle, **Intel x86_64 only** (the reason
for this rewrite — Rosetta 2 is being phased out).

Decompiled sources live in `reverse/decompiled/`. This doc is the distilled spec.

## Device identity
- VID `0x152A` (decimal 5418, "DMTZ" = Digital Multitools Inc., the OEM)
- PID `0x8460` (CC gen-1) or `0x8463` (CC gen-2 / "ulcvm"). Both supported.
- Vendor-specific class → macOS binds no driver → **libusb can claim it directly**
  (no kext, no IOKit-private API needed). Confirmed by the Linux backend which uses
  raw usbfs.

## USB endpoints (interface 0, bulk)
| Pipe | Address | Dir | Purpose |
|------|---------|-----|---------|
| VSTREAM_OUT | `0x04` | OUT | command channel (control/status msgs out) |
| VSTREAM_IN  | `0x83` | IN  | command responses / status in |
| VIDEO_IN    | `0x82` | IN  | video frame stream (bulk, read continuously) |
| DATA_OUT    | `0x05` | OUT | virtual-disk / file-transfer data out |
| DATA_IN     | `0x85` | IN  | virtual-disk / file-transfer data in |

Three reader threads in the original: response reader (0x83), video reader (0x82),
writer (drains prioritized queues to 0x04). Disk I/O on 0x05/0x85 on demand.

## Command wire format
Each message = 1 ASCII command byte + `struct`-packed payload. Commands (host→device):

| Char | Name | Payload (`struct`, big-endian unless noted) |
|------|------|---------------------------------------------|
| `s` | GET_STATUS | none |
| `v` | GET_VERSIONS | none |
| `g` | START_VSTREAM | none — tells device to begin video |
| `k` | KBD_EVENT | `>4B` = (usbKeycode, metaMask, down, allUp) — **USB HID usage codes** |
| `m` | MS_EVENT | `>BB3h` = (absMode, buttons, x, y, dz) |
| `f` | FPGA_DATA | `>HH%ds` = (seq, len, data) — streams the FPGA bitstream |
| `w` | FIRMWARE | `>H64s` = (offset, 64-byte block) — gen-1 micro firmware |
| `x` | FIRMWARE_2 | `<L256s` = (addr, 256-byte block) — gen-2 firmware |
| `h` | HOTPLUG | none |
| `p` | AUTOPHASE | none — auto-tune video phase |
| `i` | DO_IFRAME | none — request full (key) frame |
| `r` | VIDEO_RESET | none |
| `j` | VMODE_GET | none |
| `d` | SET_DDC | which(+optional EDID bytes) |
| `y`/`z`/`u` | SET/DEFAULT/SAVE_MISC | misc tuning values (phase, posX/Y, noise…) |
| `b` | CHA_SEL | `>BBB` = (first, channel, 0) — dual-channel models |
| `c`/`e` | FT_CON / FT_DIS | file-transfer connect(`<BL`=media,blocks) / disconnect |
| `t` | SELFTEST | none |
| `n` | REBOOT | none |
| `l` | LINUX_MODE | none (Linux only handshake) |

Responses (device→host), first byte = command char:

| Char | Name | Payload |
|------|------|---------|
| `S` | STATUS | `>6B2H3BHLB{N}s` — see status struct below |
| `V` | MY_VERSIONS | `>IB16s16s8s12s2B` = (stamp, fpgaRev, bootBuild, mainBuild, serial, authcode, brandIdx, ddcWhich) |
| `F`/`X` | FPGA_GOOD / FPGA_BAD | FPGA load result |
| `W` | FIRMWARE_FAIL | asciiz reason |
| `P` | AUTOPHASE_DONE | `>B` phase |
| `I` | VMODE_DETAILS | `>8H2BH2BI` (BE gen-1 / LE gen-2) — video timing |
| `T` | SELFTEST_DONE | `>B30s30s` |
| `H` | HEART_BEAT | `<L` — echo back same to keep alive |
| `C` | CHA_SET | `>BBB` channel switched |
| `A`/`B` | FT_READ / FT_WRITE | `<II` (startBlock, lengthBytes) — then disk data on 0x85/0x05 |
| `R`/`G` | FT_MEDIAREMOVE / FT_STARTSTOP | `>B` |
| `D` | DEBUG | `>H{n}s` debug text |

### STATUS struct (`mStatusCC2` = `>6B2H3BHLB15s`, CC1 uses 9s)
fields: fpgaLoaded, fpgaPowered, kbdType(0=usb/1=ps2/2=sun), kmOkay, leds(bit0 num,
bit1 caps, bit2 scroll), noVideo(0=ok, else reason enum), W, H, Hz, pixPerClk,
savedPos, ticks, words, fps, misc[]. `bps = words*16*1000/ticks`.

## Boot / connection sequence (from `adapter._initDevice` + `MainFrame.attach`)
1. Enumerate; open device; read descriptors (VID/PID → hwver).
2. Start the 3 USB threads.
3. (linux only) send `l`. Send `v` (versions), `s` (status), `e` (FT disconnect).
4. `g` START_VSTREAM.
5. `loadFpga()` — gunzip `data/ulcvm.fgz` (gen-2) or `data/usbip.fgz` (gen-1) and
   stream it in `FPGA_DATA_BLKSIZE` (507, or smaller on full-speed) blocks via `f`.
   Device replies `F` (good) → video begins; status `noVideo=0` triggers vstream.
6. If `MY_VERSIONS` stamp != stamp in `data/*.fc5`, offer firmware upgrade (`w`/`x`).
7. Steady state: video frames stream on 0x82 → decoder; key/mouse events → `k`/`m`;
   periodic `s`; echo `H` heartbeats; fine-tune X/Y via black-edge detection.

Firmware/FPGA blobs ship in the app `data/` dir and are **reusable as-is**:
`cc.fc5, ulckm.fc5, ulcvm.fc5, ulcvm.fgz, usbip.fgz`. (Copied into `reverse/data/`.)

## Input encoding
- **Keyboard**: host maps native keycodes → USB HID usage IDs (`libwxkeys.wxKeyCodestoUSB`,
  tables in `keysyms`/`libkeys`). Modifiers tracked as a bitmask. Special handling for
  AltGr (224/230), CapsLock (57), Pause. Sent via `k` with down + allUp flags.
- **Mouse**: absolute (default) or relative; `m` with buttons bitmask, x/y (absolute =
  scaled to active area), and scroll dz. Some modes need MISC_MOUSE_* flags.

## Video codec — THE hard part (`fbext_darwin.so`, 105 KB, x86_64 only)
Native C Python-2 extension. Self-contained (only links libSystem). API:
- `createBuffer(W,H)` — alloc framebuffer (max 1920×1600 RGBA).
- `videoSink(bytes) -> (trouble, hasFirstTile)` — **decode a chunk of the 0x82 stream
  into the framebuffer.** This is the proprietary codec: tile-based (16×16 tiles),
  per-tile change detection, returns `trouble` to request an I-frame on desync.
- `toRGBString(x,y,w,h,scale) -> (rgba, (w*16,h*16))` — read back a tile region,
  resized — used to paint the wx canvas. Coords are in **tiles** (16px units).
- `getChanges(y,tw)`, `getBlackEdges(w,h)`, `toGreyscale()`, `getStats()`.
- `record()/playvideo()/findrechead()/removefiles()` — the raw `.out` record/playback
  format (recording feature; lower priority for a rewrite).

This 16×16-tile codec is the only component with no readable source. Reimplementing it
requires disassembling `fbext_darwin.so` (or capturing 0x82 traffic + the matching
framebuffer to infer the format). Everything else above is fully specified.

## What a rewrite must reproduce (minimum viable KVM)
1. libusb enumerate/open (VID 0x152A, PID 0x8460/0x8463), claim interface 0.
2. Boot sequence + FPGA upload (blobs reused).
3. Video reader on 0x82 → **tile codec** → display surface.
4. Keyboard + mouse capture → HID encode → `k`/`m` on 0x04.
5. Status/heartbeat handling.
Later: firmware upgrade, virtual disk (file transfer), recording/playback, DDC/EDID,
dual-channel, autophase/fine-tune, self-test.
