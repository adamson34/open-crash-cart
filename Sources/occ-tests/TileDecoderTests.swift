import OCCKit

private func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }

private func tileHeader(x: Int, y: Int, solid: Bool, first: Bool, word0: UInt16) -> [UInt8] {
    var w1 = UInt16(x & 0x7F) | (UInt16(y & 0x7F) << 7)
    if solid { w1 |= 0x4000 }
    if first { w1 |= 0x8000 }
    return le16(word0) + le16(w1)
}

private func bgra(_ f: VideoFrame, _ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    let i = (y * f.width + x) * 4
    return (f.pixels[i], f.pixels[i + 1], f.pixels[i + 2], f.pixels[i + 3])
}

func runTileDecoderTests(_ t: Harness) {
    t.section("Tile codec (RGB565 → BGRA)")

    do {  // solid red fill
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        let f = d.ingest(tileHeader(x: 0, y: 0, solid: true, first: true, word0: 0xF800))!
        let (b, g, r, a) = bgra(f, 5, 5)
        t.expect(r == 0xF8 && g == 0 && b == 0 && a == 0xFF, "solid red → BGRA (0,0,F8,FF)")
    }

    do {  // raw green tile body
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        let body = Array(repeating: le16(0x07E0), count: 256).flatMap { $0 }
        let f = d.ingest(tileHeader(x: 0, y: 0, solid: false, first: true, word0: 1) + body)!
        t.expectEqual(bgra(f, 3, 9).1, 0xFC, "raw green tile → G channel")
    }

    do {  // tile addressing
        let d = StarTechTileDecoder(); d.setActiveSize(width: 64, height: 64)
        let f = d.ingest(tileHeader(x: 2, y: 1, solid: true, first: false, word0: 0x001F))!
        t.expectEqual(bgra(f, 40, 20).0, 0xF8, "blue tile (2,1) lands at x∈[32,47] y∈[16,31]")
        t.expectEqual(bgra(f, 0, 0).0, 0, "pixel outside the tile stays black")
    }

    do {  // padding to 512-byte boundary
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        var s: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        s += Array(repeating: 0, count: 512 - s.count)
        s += tileHeader(x: 0, y: 0, solid: true, first: false, word0: 0xF800)
        let f = d.ingest(s)!
        t.expectEqual(bgra(f, 1, 1).2, 0xF8, "tile after padding decodes")
    }

    do {  // partial record reassembled across transfers
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        let body = Array(repeating: le16(0x07E0), count: 256).flatMap { $0 }
        let full = tileHeader(x: 0, y: 0, solid: false, first: true, word0: 1) + body
        t.expectEqual(full.count, 516, "raw record is 516 bytes")
        t.expect(d.ingest(Array(full[0..<200])) == nil, "incomplete transfer yields no frame")
        let f = d.ingest(Array(full[200..<516]))!
        t.expectEqual(bgra(f, 8, 8).1, 0xFC, "reassembled tile decodes correctly")
    }
}
