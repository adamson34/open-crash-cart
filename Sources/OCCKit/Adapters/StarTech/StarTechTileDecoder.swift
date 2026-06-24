import Foundation

/// Real decoder for the StarTech 16×16-tile video codec, reverse-engineered from
/// `fbext_darwin.so` (see reverse/CODEC.md). Maintains a fixed 1920×1600 BGRA framebuffer
/// (matching the device's absolute tile addressing) and emits cropped active-region frames.
///
/// Output is BGRA8888 so frames drop straight into Metal `.bgra8Unorm` / CoreGraphics.
public final class StarTechTileDecoder: StarTechVideoDecoding, @unchecked Sendable {

    // Device framebuffer geometry is fixed; the active mode is a sub-rectangle at (0,0).
    private static let maxWidth = 1920
    private static let maxHeight = 1600
    private static let tileSize = 16
    private static let tilesWide = maxWidth / tileSize    // 120
    private static let tilesHigh = maxHeight / tileSize    // 100
    private static let stride = maxWidth * 4               // bytes per framebuffer row

    private let lock = NSLock()
    private var framebuffer: [UInt8]
    private var activeWidth = 1024
    private var activeHeight = 768

    // Partial-record reassembly across USB transfers.
    private var leftover: [UInt8] = []
    private var leftoverNeeded = 0      // 0 = nothing pending

    public private(set) var needsKeyframe = false
    private var sawTileSinceEmit = false

    public init() {
        framebuffer = [UInt8](repeating: 0, count: Self.maxWidth * Self.maxHeight * 4)
    }

    public func setActiveSize(width: Int, height: Int) {
        lock.lock(); defer { lock.unlock() }
        activeWidth = min(max(width, 1), Self.maxWidth)
        activeHeight = min(max(height, 1), Self.maxHeight)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        for i in framebuffer.indices { framebuffer[i] = 0 }
        leftover.removeAll(keepingCapacity: true)
        leftoverNeeded = 0
        needsKeyframe = false
        sawTileSinceEmit = false
    }

    public func ingest(_ chunk: [UInt8]) -> VideoFrame? {
        lock.lock(); defer { lock.unlock() }
        needsKeyframe = false
        sawTileSinceEmit = false

        var data = chunk

        // 1) Finish any record split across the previous transfer.
        if leftoverNeeded > 0 {
            let want = leftoverNeeded - leftover.count
            let take = min(want, data.count)
            leftover.append(contentsOf: data[0..<take])
            data.removeFirst(take)
            if leftover.count == leftoverNeeded {
                // leftover holds exactly one complete record at offset 0.
                let buf = leftover
                leftover.removeAll(keepingCapacity: true)
                leftoverNeeded = 0
                _ = processRecord(buf, at: 0)   // self-contained; padding can't occur here
            } else {
                return nil                      // still incomplete; wait for more
            }
        }

        // 2) Process whole records from the current transfer.
        processBuffer(data)

        // 3) Emit a cropped frame if we touched the framebuffer this call.
        return sawTileSinceEmit ? snapshotActiveRegion() : nil
    }

    // MARK: Stream parsing

    /// Walk tile records starting at offset 0. `pos` tracks the absolute position within
    /// this transfer (needed for 512-byte padding alignment).
    private func processBuffer(_ data: [UInt8]) {
        var pos = 0
        let count = data.count
        while count - pos >= 4 {
            let word0 = u16(data, pos)
            let word1 = u16(data, pos + 2)

            // Padding → advance to next 512-byte boundary.
            if word0 == 0xFFFF && word1 == 0xFFFF {
                let skip = min(512 - (pos & 511), count - pos)
                pos += skip
                continue
            }

            let isSolid = (word1 & 0x4000) != 0
            let recordSize = isSolid ? 4 : 4 + 512

            // Not enough bytes for this record → stash the tail for the next transfer.
            if count - pos < recordSize {
                leftover = Array(data[pos..<count])
                leftoverNeeded = recordSize
                return
            }

            _ = processRecord(data, at: pos)
            pos += recordSize
        }
    }

    /// Decode one complete record located at `offset`. Returns the record size in bytes.
    @discardableResult
    private func processRecord(_ data: [UInt8], at offset: Int) -> Int {
        let word0 = u16(data, offset)
        let word1 = u16(data, offset + 2)
        let tileX = Int(word1 & 0x7F)
        let tileY = Int((word1 >> 7) & 0x7F)
        let isSolid = (word1 & 0x4000) != 0

        // Out-of-range tile coordinate: skip, write nothing.
        guard tileX < Self.tilesWide, tileY < Self.tilesHigh else {
            return isSolid ? 4 : 4 + 512
        }

        if isSolid {
            fillTile(tileX: tileX, tileY: tileY, rgb565: word0)
            sawTileSinceEmit = true
            return 4
        } else {
            decodeRawTile(tileX: tileX, tileY: tileY, body: data, bodyOffset: offset + 4)
            sawTileSinceEmit = true
            return 4 + 512
        }
    }

    // MARK: Tile writers (BGRA output)

    private func decodeRawTile(tileX: Int, tileY: Int, body: [UInt8], bodyOffset: Int) {
        let baseX = tileX * Self.tileSize
        let baseY = tileY * Self.tileSize
        framebuffer.withUnsafeMutableBufferPointer { fb in
            var src = bodyOffset
            for row in 0..<16 {
                var dst = ((baseY + row) * Self.maxWidth + baseX) * 4
                for _ in 0..<16 {
                    let px = UInt16(body[src]) | (UInt16(body[src + 1]) << 8)
                    src += 2
                    fb[dst]     = UInt8((px << 3) & 0xFF)   // B
                    fb[dst + 1] = UInt8((px >> 3) & 0xFC)   // G
                    fb[dst + 2] = UInt8((px >> 8) & 0xF8)   // R
                    fb[dst + 3] = 0xFF                      // A
                    dst += 4
                }
            }
        }
    }

    private func fillTile(tileX: Int, tileY: Int, rgb565 px: UInt16) {
        let b = UInt8((px << 3) & 0xFF)
        let g = UInt8((px >> 3) & 0xFC)
        let r = UInt8((px >> 8) & 0xF8)
        let baseX = tileX * Self.tileSize
        let baseY = tileY * Self.tileSize
        framebuffer.withUnsafeMutableBufferPointer { fb in
            for row in 0..<16 {
                var dst = ((baseY + row) * Self.maxWidth + baseX) * 4
                for _ in 0..<16 {
                    fb[dst] = b; fb[dst + 1] = g; fb[dst + 2] = r; fb[dst + 3] = 0xFF
                    dst += 4
                }
            }
        }
    }

    // MARK: Frame extraction

    /// Copy the active (activeWidth × activeHeight) sub-rectangle into a tightly-packed
    /// BGRA buffer for display.
    private func snapshotActiveRegion() -> VideoFrame {
        let w = activeWidth, h = activeHeight
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let rowBytes = w * 4
        framebuffer.withUnsafeBufferPointer { fb in
            pixels.withUnsafeMutableBufferPointer { out in
                for y in 0..<h {
                    let srcStart = y * Self.stride
                    let dstStart = y * rowBytes
                    for i in 0..<rowBytes {
                        out[dstStart + i] = fb[srcStart + i]
                    }
                }
            }
        }
        return VideoFrame(width: w, height: h, pixels: pixels)
    }

    @inline(__always)
    private func u16(_ data: [UInt8], _ i: Int) -> UInt16 {
        UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
    }
}
