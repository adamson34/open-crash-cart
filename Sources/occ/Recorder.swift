import AVFoundation
import QuartzCore
import OCCKit

/// Records the decoded video stream to an H.264 .mov using AVAssetWriter — fully native, no
/// external tools. Frames are appended with real-time timestamps; mode changes mid-recording
/// (different resolution) are skipped rather than corrupting the file.
final class Recorder {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let width: Int
    private let height: Int
    private var started = false
    private var startTime: CFTimeInterval = 0
    private(set) var frameCount = 0

    init?(url: URL, width: Int, height: Int) {
        self.width = width
        self.height = height
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        writer = w
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
    }

    func append(_ frame: VideoFrame) {
        guard frame.width == width, frame.height == height else { return }
        let now = CACurrentMediaTime()
        if !started {
            startTime = now
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            started = true
        }
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var pb: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let buffer = pb else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let dstStride = CVPixelBufferGetBytesPerRow(buffer)
            let srcStride = width * 4
            frame.pixels.withUnsafeBytes { src in
                guard let srcBase = src.baseAddress else { return }
                for row in 0..<height {
                    memcpy(base.advanced(by: row * dstStride), srcBase.advanced(by: row * srcStride), srcStride)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let t = CMTime(seconds: max(0, now - startTime), preferredTimescale: 600)
        adaptor.append(buffer, withPresentationTime: t)
        frameCount += 1
    }

    func finish(_ completion: @escaping @Sendable (Int) -> Void) {
        guard started else { completion(0); return }
        let n = frameCount
        input.markAsFinished()
        writer.finishWriting { completion(n) }
    }
}
