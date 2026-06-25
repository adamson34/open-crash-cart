import Foundation
import AVFoundation
import CoreVideo

/// Backend for a generic USB-Video (UVC) capture device via AVFoundation. View-only:
/// keyboard/mouse injection over UVC requires separate serial-HID hardware (e.g. CH9329),
/// which is a future backend. Video frames are delivered as BGRA, same as every other
/// backend, so the rest of the app is unchanged.
public final class UVCAdapter: NSObject, CrashCartAdapter, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    public static let model = AdapterModel(
        id: "uvc", name: "USB Video (UVC) Capture", vendorID: 0, productIDs: [])

    public static func canDrive(_ device: DiscoveredDevice) -> Bool { false }  // not libusb-driven

    public enum UVCError: Error, CustomStringConvertible {
        case deviceNotFound
        case cameraAccessDenied
        case sessionSetupFailed
        public var description: String {
            switch self {
            case .deviceNotFound:     return "UVC capture device not found"
            case .cameraAccessDenied: return "Camera access denied — enable it in System Settings ▸ Privacy & Security ▸ Camera"
            case .sessionSetupFailed: return "Could not start the capture session"
            }
        }
    }

    private let deviceID: String
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "co.opencrashcart.uvc.capture")
    private var continuation: AsyncStream<AdapterEvent>.Continuation?
    private var lastSize = CGSize.zero

    public init(deviceID: String) {
        self.deviceID = deviceID
        super.init()
    }

    public func connect() async throws -> AsyncStream<AdapterEvent> {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw UVCError.cameraAccessDenied }
        guard let device = resolveUVCDevice(id: deviceID) else { throw UVCError.deviceNotFound }
        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        guard session.canAddInput(input) else { session.commitConfiguration(); throw UVCError.sessionSetupFailed }
        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); throw UVCError.sessionSetupFailed }
        session.addOutput(output)
        session.commitConfiguration()

        let stream = AsyncStream<AdapterEvent> { continuation in
            self.continuation = continuation
        }
        emit(.message("Connected to \(device.localizedName) — view-only (no keyboard/mouse over UVC)"))
        nonisolated(unsafe) let session = self.session   // AVCaptureSession is thread-safe for start/stop
        queue.async { session.startRunning() }
        return stream
    }

    // MARK: Capture delegate

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let srcStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard w > 0, h > 0, let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let rowBytes = w * 4
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBytes { dst in
            guard let dstBase = dst.baseAddress else { return }
            for row in 0..<h {
                memcpy(dstBase.advanced(by: row * rowBytes), base.advanced(by: row * srcStride), rowBytes)
            }
        }

        if CGSize(width: w, height: h) != lastSize {
            lastSize = CGSize(width: w, height: h)
            var status = AdapterStatus()
            status.state = .live(width: w, height: h, hz: 0)
            status.keyboardOK = false   // view-only
            emit(.status(status))
        }
        emit(.frame(VideoFrame(width: w, height: h, pixels: pixels)))
    }

    // MARK: CrashCartAdapter (view-only: input is a no-op)

    public func send(key: HIDKeyEvent) {}
    public func send(mouse: MouseEvent) {}

    public func disconnect() async {
        nonisolated(unsafe) let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
        continuation?.yield(.disconnected(reason: "Closed"))
        continuation?.finish()
        continuation = nil
    }

    private func emit(_ event: AdapterEvent) { continuation?.yield(event) }
}
