import Foundation

/// Seam for the proprietary StarTech 16×16-tile video codec (Phase 3). The device streams
/// frame data on bulk EP 0x82; chunks are handed to `ingest(_:)`, which updates an internal
/// framebuffer and, when a frame boundary is reached, returns a displayable `VideoFrame`.
///
/// The real decoder will be reverse-engineered from `fbext_darwin.so`. Until then this
/// placeholder tracks throughput so the transport/threading can be exercised end-to-end
/// without yet producing pixels.
public protocol StarTechVideoDecoding: AnyObject {
    /// Called when the active video mode changes (from STATUS messages).
    func setActiveSize(width: Int, height: Int)
    /// Feed a chunk from the video endpoint. Returns a frame if one completed.
    func ingest(_ chunk: [UInt8]) -> VideoFrame?
    /// True if the decoder lost sync and the host should request an I-frame.
    var needsKeyframe: Bool { get }
    func reset()
}

/// Placeholder decoder: no pixel decoding yet, only bookkeeping. Lets Phases 1–2 run.
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
        return nil   // Phase 3 will return decoded frames here.
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        bytesIngested = 0
        chunksIngested = 0
        needsKeyframe = false
    }
}
