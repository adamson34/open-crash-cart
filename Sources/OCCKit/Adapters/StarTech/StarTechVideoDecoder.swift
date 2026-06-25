import Foundation

/// Seam for the StarTech 16×16-tile video codec. The device streams frame data on bulk EP 0x82;
/// chunks are handed to `ingest(_:)`, which updates an internal framebuffer and, when a frame
/// boundary is reached, returns a displayable `VideoFrame`.
///
/// The real implementation is `StarTechTileDecoder` (reverse-engineered from `fbext_darwin.so`;
/// see docs/CODEC.md). `PlaceholderVideoDecoder` below is a no-pixel alternative that exercises
/// the transport/threading without decoding.
public protocol StarTechVideoDecoding: AnyObject {
    /// Called when the active video mode changes (from STATUS messages).
    func setActiveSize(width: Int, height: Int)
    /// Feed a chunk from the video endpoint. Returns a frame if one completed.
    func ingest(_ chunk: [UInt8]) -> VideoFrame?
    /// True if the decoder lost sync and the host should request an I-frame.
    var needsKeyframe: Bool { get }
    func reset()
}

/// No-pixel decoder: tracks throughput only. An alternative to `StarTechTileDecoder` for
/// exercising the transport/threading without decoding pixels.
public final class PlaceholderVideoDecoder: StarTechVideoDecoding, @unchecked Sendable {
    public private(set) var bytesIngested: Int = 0
    public private(set) var chunksIngested: Int = 0
    public private(set) var needsKeyframe: Bool = false
    private var width = 1024
    private var height = 768
    private let lock = NSLock()

    public init() {}

    public func setActiveSize(width: Int, height: Int) {
        lock.lock(); defer { lock.unlock() }
        self.width = width
        self.height = height
    }

    public func ingest(_ chunk: [UInt8]) -> VideoFrame? {
        lock.lock(); defer { lock.unlock() }
        bytesIngested += chunk.count
        chunksIngested += 1
        return nil   // intentionally never decodes — use StarTechTileDecoder for real frames.
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        bytesIngested = 0
        chunksIngested = 0
        needsKeyframe = false
    }
}
