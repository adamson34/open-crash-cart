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

    do {  // C-4: padding after a split-record completion aligns to the absolute transfer offset
        let d = StarTechTileDecoder(); d.setActiveSize(width: 64, height: 64)
        let body = Array(repeating: le16(0x07E0), count: 256).flatMap { $0 }
        let raw = tileHeader(x: 0, y: 0, solid: false, first: true, word0: 1) + body  // 516 bytes
        // Transfer 1: first 300 bytes of the raw tile → incomplete.
        t.expect(d.ingest(Array(raw[0..<300])) == nil, "split raw tile: first transfer yields no frame")
        // Transfer 2: the 216-byte tail (abs offset 0..216) + a padding record + a solid tile.
        // The padding must skip 512-(216)=296 bytes (abs 216→512); if the decoder ignored the
        // 216-byte base offset it would skip 512 and swallow the solid tile.
        var t2 = Array(raw[300..<516])                       // 216-byte tail
        t2 += [0xFF, 0xFF, 0xFF, 0xFF]                       // padding marker at abs 216
        t2 += Array(repeating: 0, count: 296 - 4)            // filler to the 512 boundary
        t2 += tileHeader(x: 2, y: 2, solid: true, first: false, word0: 0x001F)  // blue tile at abs 512
        let f2 = d.ingest(t2)!
        t.expectEqual(bgra(f2, 34, 34).0, 0xF8, "solid tile after padding-past-split-record decodes (C-4)")
    }

    t.section("Keyframe self-heal on desync (BC-1.02.018)")

    // A solid record with tileY ≥ 100 (tilesHigh) is always out-of-range garbage.
    func oorRecord() -> [UInt8] { tileHeader(x: 0, y: 120, solid: true, first: false, word0: 0) }

    do {  // clean transfer does not request a keyframe
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        _ = d.ingest(tileHeader(x: 0, y: 0, solid: true, first: false, word0: 0xF800))
        t.expect(!d.needsKeyframe, "clean in-range tile → no keyframe request")
    }

    do {  // a burst of out-of-range tiles in one transfer requests a keyframe
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        var garbage: [UInt8] = []; for _ in 0..<8 { garbage += oorRecord() }
        _ = d.ingest(garbage)
        t.expect(d.needsKeyframe, "8 out-of-range records in one transfer → keyframe requested")
    }

    do {  // below the burst threshold does NOT request a keyframe
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        var few: [UInt8] = []; for _ in 0..<7 { few += oorRecord() }
        _ = d.ingest(few)
        t.expect(!d.needsKeyframe, "7 out-of-range records (below threshold) → no keyframe")
    }

    do {  // sustained no-decode transfers eventually request a keyframe
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        for _ in 0..<7 { _ = d.ingest(oorRecord()) }
        t.expect(!d.needsKeyframe, "7 stale ingests → no keyframe yet")
        _ = d.ingest(oorRecord())
        t.expect(d.needsKeyframe, "8th stale ingest → keyframe requested")
    }

    do {  // a clean decode after desync clears the request (self-heal)
        let d = StarTechTileDecoder(); d.setActiveSize(width: 16, height: 16)
        var garbage: [UInt8] = []; for _ in 0..<8 { garbage += oorRecord() }
        _ = d.ingest(garbage)
        t.expect(d.needsKeyframe, "desync set needsKeyframe")
        _ = d.ingest(tileHeader(x: 0, y: 0, solid: true, first: false, word0: 0xF800))
        t.expect(!d.needsKeyframe, "clean decode clears needsKeyframe (self-heal)")
    }
}
