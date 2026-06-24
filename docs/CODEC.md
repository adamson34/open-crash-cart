# StarTech NOTECONS02 Video Codec — Reverse-Engineered Spec

Recovered by disassembling `fbext_darwin.so` (x86_64, unstripped) — functions
`do_createBuffer`, `do_videoSink`, `ProcessVideoData`. This is the format of the byte
stream the device sends on bulk endpoint **0x82**. Clean-room: derived from the binary's
behavior, no vendor source used.

## Framebuffer (`do_createBuffer`)
- Allocated at a **fixed max size 1920×1600**, 4 bytes/pixel, `malloc(W*H*4)`, zeroed.
- Stride = `frameWidth` = **1920** (constant), regardless of the active video mode.
- Tiles are **16×16 px**. `tilesWidth = ceil(W/16) = 120`, `tilesHeight = ceil(H/16) = 100`.
- `changedArray` = 1 byte per tile (`tilesWidth*tilesHeight`), set to 1 when a tile updates.
- The active video region (e.g. 1024×768) is a sub-rectangle anchored at (0,0); display
  crops to it. Tile coordinates are **absolute** in the 1920-wide buffer.

## Pixel format
Each pixel is **16-bit RGB565, little-endian** in the stream:
`R = bits[15:11], G = bits[10:5], B = bits[4:0]`. Expanded to 8-bit per channel:
```
R8 = (px >> 8) & 0xF8      # (px >> 11) << 3
G8 = (px >> 3) & 0xFC      # (px >> 5)  << 2
B8 = (px << 3) & 0xFF      #  px        << 3
A8 = 0xFF
```
The native code stores R,G,B,A. Our Swift decoder stores **B,G,R,A (BGRA8888)** so the
buffer drops straight into Metal `.bgra8Unorm` / CoreGraphics — just swap the R and B writes.

## Stream = sequence of tile records (`ProcessVideoData`)
Processed while ≥4 bytes remain. Each record starts with a **4-byte header** (two
little-endian u16): `word0`, `word1`.

```
word1 layout:  tileX = word1 & 0x7F
               tileY = (word1 >> 7) & 0x7F
               mode  = (word1 >> 14) & 1     # 0 = raw, 1 = solid-fill
               first = (word1 >> 15) & 1     # 1 = first tile of a frame (sets HasFirstTile)
```

### Record types
1. **Padding** — `word0 == 0xFFFF && word1 == 0xFFFF`:
   advance position to the next 512-byte boundary: `skip = min(512 - (pos & 511), remaining)`.
   (Tiles are packed within 512-byte-aligned framing in each USB transfer.)

2. **Raw tile** — `mode == 0`: header + **512-byte body** = 16 rows × 16 px × 2 bytes,
   row-major. Each pixel RGB565→BGRA into framebuffer at
   `((tileY*16 + row)*1920 + tileX*16 + col) * 4`. **Consumes 516 (0x204) bytes.**

3. **Solid-fill tile** — `mode == 1`: header only; `word0` is the RGB565 color for the
   entire 16×16 tile. **Consumes 4 bytes.**

4. **Out-of-range** (`tileX >= tilesWidth || tileY >= tilesHeight`): skip the record
   (516 if raw, 4 if solid), increment a "bogus" stat, write nothing.

After a raw or solid tile, `changedArray[tileY*tilesWidth + tileX] = 1`.

### Partial tiles across USB transfers (`leftoverData`)
If fewer than a full record's bytes remain at the end of a transfer (`< 0x204` for raw,
`< 4` for solid) and it's not padding, the tail is copied to `leftoverData` and
`leftoverDataNeeded` is set to the full record size (516 or 4). The next `videoSink`
call tops it up to `leftoverDataNeeded` bytes, processes that one complete record, then
continues with the rest of the new transfer.

### Return value / `trouble`
`ProcessVideoData` returns bytes consumed. `do_videoSink` sets `trouble=1` if consumed ≠
input length (host then requests an I-frame via `doIFrame`/'i'). It also returns
`HasFirstTile` (whether a first-of-frame tile was seen) and stashes the last 2048 bytes
as `previousData` — both used only by the record/playback feature, not live decode.

## What the rewrite needs
A decoder that: keeps a 1920×1600 BGRA framebuffer; parses tile records (padding / raw /
solid / out-of-range); buffers partial records across transfers; and emits a cropped
active-region `VideoFrame`. Frame-boundary emission can key off the `first` bit, with a
time-throttled fallback. Implemented in `StarTechTileDecoder.swift`.
