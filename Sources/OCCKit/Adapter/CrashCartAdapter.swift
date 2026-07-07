import Foundation

/// A USB device discovered on the bus, before any backend has claimed it.
public struct DiscoveredDevice: Sendable, Identifiable {
    public let id: String                // stable "bus.address" identity
    public let vendorID: UInt16
    public let productID: UInt16
    public let busNumber: UInt8
    public let address: UInt8
    public let manufacturer: String?
    public let product: String?
    public let serial: String?
    public let isHighSpeedOrBetter: Bool
    public init(vendorID: UInt16, productID: UInt16, busNumber: UInt8, address: UInt8,
                manufacturer: String?, product: String?, serial: String?,
                isHighSpeedOrBetter: Bool) {
        self.id = "\(busNumber).\(address)"
        self.vendorID = vendorID
        self.productID = productID
        self.busNumber = busNumber
        self.address = address
        self.manufacturer = manufacturer
        self.product = product
        self.serial = serial
        self.isHighSpeedOrBetter = isHighSpeedOrBetter
    }
}

/// The contract every crash-cart backend implements. The session/UI layer talks only
/// to this protocol, so adding a new adapter model (UVC-based, Lantronix, …) means
/// adding a conformance — nothing in the UI changes.
public protocol CrashCartAdapter: AnyObject, Sendable {
    /// The model this backend drives (name, USB IDs, etc.).
    static var model: AdapterModel { get }

    /// Whether this backend can drive the given freshly-discovered device.
    static func canDrive(_ device: DiscoveredDevice) -> Bool

    /// Open the device, run the boot/handshake sequence, and begin streaming.
    /// Events (status, frames, messages) arrive on the returned stream.
    func connect() async throws -> AsyncStream<AdapterEvent>

    /// Send an input event to the target machine. Synchronous and ordered: these enqueue
    /// onto a thread-safe queue, so they can be called directly from the UI thread without
    /// reordering key/mouse events.
    func send(key: HIDKeyEvent)
    func send(mouse: MouseEvent)

    /// Force a full (key) frame — used by "refresh screen". Default: no-op.
    func requestKeyframe()

    /// Re-tune video timing/sharpness (auto-phase). Default: no-op.
    func autoTuneVideo()

    /// Mount a disk image (ISO/IMG) as a USB drive on the target. Default: no-op.
    func mountMedia(path: String, asCDROM: Bool)

    /// Eject any mounted virtual media. Default: no-op.
    func ejectMedia()

    /// Set a manual video-tuning value. Default: no-op.
    func setVideoAdjustment(_ adjustment: VideoAdjustment, value: Int)
    /// Persist a tuning value on the device. Default: no-op.
    func saveVideoAdjustment(_ adjustment: VideoAdjustment)
    /// Reset a tuning value to its device default. Default: no-op.
    func resetVideoAdjustment(_ adjustment: VideoAdjustment)

    /// Advertise a DDC/EDID resolution preset to the target. Default: no-op.
    func setDDCPreset(_ preset: DDCPreset)

    /// Tear down cleanly.
    func disconnect() async
}

public extension CrashCartAdapter {
    func requestKeyframe() {}
    func autoTuneVideo() {}
    func mountMedia(path: String, asCDROM: Bool) {}
    func ejectMedia() {}
    func setVideoAdjustment(_ adjustment: VideoAdjustment, value: Int) {}
    func saveVideoAdjustment(_ adjustment: VideoAdjustment) {}
    func resetVideoAdjustment(_ adjustment: VideoAdjustment) {}
    func setDDCPreset(_ preset: DDCPreset) {}

    /// Type a string into the target as key presses (paste/type text). Runs off the main
    /// thread, lightly paced so fast typing registers reliably. `completion` fires once the
    /// last keystroke has been enqueued, reporting how many characters were `typed` and how
    /// many were `skipped` (unmapped in the US-ASCII layout) — the UI uses it to confirm the
    /// paste finished. It runs on a background thread; hop to the main actor before touching UI.
    func typeText(_ text: String,
                  completion: (@Sendable (_ typed: Int, _ skipped: Int) -> Void)? = nil) {
        let strokes = HIDTyping.strokes(for: text)
        let skipped = text.count - strokes.count
        guard !strokes.isEmpty else {
            completion?(0, skipped)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            for s in strokes {
                for e in HIDTyping.keyEvents(usage: s.usage, shift: s.shift) { self.send(key: e) }
                Thread.sleep(forTimeInterval: 0.007)   // light pacing so fast typing registers
            }
            completion?(strokes.count, skipped)
        }
    }

    /// Press then release a single HID key (for the "special keys" menu).
    func sendKeyPress(usage: UInt8) {
        send(key: HIDKeyEvent(usage: usage, modifiers: 0, isDown: true, allReleased: false))
        send(key: HIDKeyEvent(usage: usage, modifiers: 0, isDown: false, allReleased: true))
    }

    /// Send the Ctrl-Alt-Del "three-finger salute": LeftCtrl(0xE0)+LeftAlt(0xE2)+Delete(0x4C).
    func sendCtrlAltDel() {
        send(key: HIDKeyEvent(usage: 0xE0, modifiers: 0, isDown: true, allReleased: false))
        send(key: HIDKeyEvent(usage: 0xE2, modifiers: 0, isDown: true, allReleased: false))
        send(key: HIDKeyEvent(usage: 0x4C, modifiers: 0, isDown: true, allReleased: false))
        send(key: HIDKeyEvent(usage: 0x4C, modifiers: 0, isDown: false, allReleased: false))
        send(key: HIDKeyEvent(usage: 0xE2, modifiers: 0, isDown: false, allReleased: false))
        send(key: HIDKeyEvent(usage: 0xE0, modifiers: 0, isDown: false, allReleased: true))
    }
}
