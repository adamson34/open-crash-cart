import Foundation
import AVFoundation
import CoreVideo

/// Backend for a generic USB-Video (UVC) capture device via AVFoundation, with optional
/// keyboard/mouse over a CH9329 USB-serial HID controller (the chip many HDMI/VGA-capture
/// KVM dongles include). If a CH9329 serial port is found it's a full KVM; otherwise it's
/// view-only. Video frames are delivered as BGRA, same as every other backend.
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
    private let captureQueue = DispatchQueue(label: "co.opencrashcart.uvc.capture")
    private var continuation: AsyncStream<AdapterEvent>.Continuation?

    private var frameW = 0, frameH = 0   // set on capture queue, read on input queue (Int = atomic)

    // CH9329 HID (optional). All access on inputQueue.
    private let inputQueue = DispatchQueue(label: "co.opencrashcart.ch9329")
    private var ch9329: CH9329?
    private var hasHID = false
    private var modifierByte: UInt8 = 0
    private var downKeys: [UInt8] = []
    // Mouse coalescing — the serial link is slow, so always send the latest position.
    private let mouseLock = NSLock()
    private var pendingMouse: MouseEvent?
    private var mouseScheduled = false

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
        output.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); throw UVCError.sessionSetupFailed }
        session.addOutput(output)
        session.commitConfiguration()

        let stream = AsyncStream<AdapterEvent> { continuation in
            self.continuation = continuation
        }

        // Try to attach a CH9329 HID controller for keyboard/mouse.
        let env = ProcessInfo.processInfo.environment
        let baud = Int(env["OCC_CH9329_BAUD"] ?? "") ?? 9600
        if let path = env["OCC_CH9329_PORT"] ?? discoverCH9329Ports().first,
           let chip = CH9329(path: path, baud: baud) {
            ch9329 = chip
            hasHID = true
            emit(.message("Connected to \(device.localizedName) — full KVM via CH9329 on \(path)"))
        } else {
            emit(.message("Connected to \(device.localizedName) — view-only (no CH9329 HID controller found)"))
        }

        nonisolated(unsafe) let session = self.session   // AVCaptureSession is thread-safe for start/stop
        captureQueue.async { session.startRunning() }
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

        if w != frameW || h != frameH {
            frameW = w; frameH = h
            var status = AdapterStatus()
            status.state = .live(width: w, height: h, hz: 0)
            status.keyboardOK = hasHID
            emit(.status(status))
        }
        emit(.frame(VideoFrame(width: w, height: h, pixels: pixels)))
    }

    // MARK: CrashCartAdapter input → CH9329

    public func send(key event: HIDKeyEvent) {
        guard hasHID else { return }
        inputQueue.async { [weak self] in self?.applyKey(event) }
    }

    private func applyKey(_ e: HIDKeyEvent) {
        if e.usage >= 0xE0 && e.usage <= 0xE7 {
            let bit = UInt8(1) << (e.usage - 0xE0)
            if e.isDown { modifierByte |= bit } else { modifierByte &= ~bit }
        } else if e.isDown {
            if !downKeys.contains(e.usage) && downKeys.count < 6 { downKeys.append(e.usage) }
        } else {
            downKeys.removeAll { $0 == e.usage }
        }
        if e.allReleased { modifierByte = 0; downKeys.removeAll() }
        ch9329?.keyboard(modifier: modifierByte, keys: downKeys)
    }

    public func send(mouse m: MouseEvent) {
        guard hasHID else { return }
        mouseLock.lock()
        pendingMouse = m
        let schedule = !mouseScheduled
        mouseScheduled = true
        mouseLock.unlock()
        if schedule { inputQueue.async { [weak self] in self?.drainMouse() } }
    }

    private func drainMouse() {
        while true {
            mouseLock.lock()
            guard let m = pendingMouse else { mouseScheduled = false; mouseLock.unlock(); return }
            pendingMouse = nil
            mouseLock.unlock()

            let wheel = Int8(clamping: Int(m.wheel))
            if m.isAbsolute {
                ch9329?.mouseAbsolute(buttons: m.buttons.rawValue, x: Int(m.x), y: Int(m.y),
                                      wheel: wheel, width: frameW, height: frameH)
            } else {
                ch9329?.mouseRelative(buttons: m.buttons.rawValue,
                                      dx: Int8(clamping: Int(m.x)), dy: Int8(clamping: Int(m.y)), wheel: wheel)
            }
        }
    }

    public func disconnect() async {
        hasHID = false
        inputQueue.async { [weak self] in self?.ch9329?.close(); self?.ch9329 = nil }
        nonisolated(unsafe) let session = self.session
        captureQueue.async { if session.isRunning { session.stopRunning() } }
        continuation?.yield(.disconnected(reason: "Closed"))
        continuation?.finish()
        continuation = nil
    }

    private func emit(_ event: AdapterEvent) { continuation?.yield(event) }
}
