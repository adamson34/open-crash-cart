import Foundation
import OCCKit

// occ-selftest — framework-free self-tests for the reverse-engineered tile codec.
// Validates RGB565→BGRA, solid/raw tiles, addressing, padding, and partial reassembly
// with no hardware. Exits non-zero on any failure.

var failures = 0
@MainActor func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") }
    else { print("  ✗ \(msg)"); failures += 1 }
}

func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }

// word1 = tileX | tileY<<7 | solid<<14 | first<<15
func tileHeader(x: Int, y: Int, solid: Bool, first: Bool, word0: UInt16) -> [UInt8] {
    var w1 = UInt16(x & 0x7F) | (UInt16(y & 0x7F) << 7)
    if solid { w1 |= 0x4000 }
    if first { w1 |= 0x8000 }
    return le16(word0) + le16(w1)
}

func bgra(_ f: VideoFrame, _ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    let i = (y * f.width + x) * 4
    return (f.pixels[i], f.pixels[i+1], f.pixels[i+2], f.pixels[i+3])
}

print("occ-selftest — tile codec")

// 1) Solid-fill red tile.
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
    let frame = d.ingest(tileHeader(x: 0, y: 0, solid: true, first: true, word0: 0xF800))
    if let f = frame {
        let (b, g, r, a) = bgra(f, 5, 5)
        check(r == 0xF8 && g == 0 && b == 0 && a == 0xFF, "solid red tile → BGRA (0,0,F8,FF)")
    } else { check(false, "solid red tile produced a frame") }
}

// 2) Raw green tile (16×16 RGB565 body).
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
    let body = Array(repeating: le16(0x07E0), count: 256).flatMap { $0 }
    let frame = d.ingest(tileHeader(x: 0, y: 0, solid: false, first: true, word0: 1) + body)
    if let f = frame {
        let (b, g, r, _) = bgra(f, 3, 9)
        check(r == 0 && g == 0xFC && b == 0, "raw green tile → G=FC")
    } else { check(false, "raw tile produced a frame") }
}

// 3) Tile addressing: solid blue at tile (2,1).
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 64, height: 64)
    let f = d.ingest(tileHeader(x: 2, y: 1, solid: true, first: false, word0: 0x001F))!
    let (b, g, r, _) = bgra(f, 40, 20)
    check(b == 0xF8 && g == 0 && r == 0, "blue tile lands at x∈[32,47] y∈[16,31]")
    let (b2, _, _, _) = bgra(f, 0, 0)
    check(b2 == 0, "pixel outside the tile stays black")
}

// 4) Padding skips to the 512-byte boundary, then a real tile decodes.
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
    var stream: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
    stream += Array(repeating: 0, count: 512 - stream.count)
    stream += tileHeader(x: 0, y: 0, solid: true, first: false, word0: 0xF800)
    if let f = d.ingest(stream) {
        let (_, _, r, _) = bgra(f, 1, 1)
        check(r == 0xF8, "tile after padding decodes")
    } else { check(false, "stream with padding produced a frame") }
}

// 5) Partial raw tile reassembled across two transfers.
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
    let body = Array(repeating: le16(0x07E0), count: 256).flatMap { $0 }
    let full = tileHeader(x: 0, y: 0, solid: false, first: true, word0: 1) + body
    check(full.count == 516, "raw record is 516 bytes")
    let firstChunk = Array(full[0..<200]), secondChunk = Array(full[200..<516])
    check(d.ingest(firstChunk) == nil, "incomplete transfer yields no frame")
    if let f = d.ingest(secondChunk) {
        let (_, g, _, _) = bgra(f, 8, 8)
        check(g == 0xFC, "reassembled tile decodes correctly")
    } else { check(false, "completing transfer yields a frame") }
}

// 6) RGB565 channel expansion (white).
do {
    let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
    let f = d.ingest(tileHeader(x: 0, y: 0, solid: true, first: false, word0: 0xFFFF))!
    let (b, g, r, _) = bgra(f, 0, 0)
    check(r == 0xF8 && g == 0xFC && b == 0xF8, "white 0xFFFF → BGRA (F8,FC,F8)")
}

print(failures == 0 ? "\nALL PASSED ✓" : "\n\(failures) FAILURE(S) ✗")
exit(failures == 0 ? 0 : 1)
