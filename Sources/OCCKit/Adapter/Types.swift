import Foundation

// Shared, device-agnostic value types used across all crash-cart adapter backends.
// Keeping these independent of any one device keeps the UI/session layer reusable.

/// A decoded video frame ready for display: tightly-packed BGRA8888, `width`×`height`.
public struct VideoFrame: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]   // BGRA, row-major, width*height*4 bytes
    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

/// A host keyboard event already translated to a USB-HID usage code.
public struct HIDKeyEvent: Sendable {
    public let usage: UInt8      // USB HID keyboard usage ID
    public let modifiers: UInt8  // HID modifier bitmask
    public let isDown: Bool
    public let allReleased: Bool // true once no keys remain held (mirrors original "allUp")
    public init(usage: UInt8, modifiers: UInt8, isDown: Bool, allReleased: Bool) {
        self.usage = usage
        self.modifiers = modifiers
        self.isDown = isDown
        self.allReleased = allReleased
    }
}

public struct MouseButtons: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let left   = MouseButtons(rawValue: 1 << 0)
    public static let right  = MouseButtons(rawValue: 1 << 1)
    public static let middle = MouseButtons(rawValue: 1 << 2)
}

public struct MouseEvent: Sendable {
    public let buttons: MouseButtons
    public let x: Int16          // absolute (scaled to active area) or relative delta
    public let y: Int16
    public let wheel: Int16
    public let isAbsolute: Bool
    public init(buttons: MouseButtons, x: Int16, y: Int16, wheel: Int16, isAbsolute: Bool) {
        self.buttons = buttons
        self.x = x
        self.y = y
        self.wheel = wheel
        self.isAbsolute = isAbsolute
    }
}

public enum KeyboardEmulation: UInt8, Sendable {
    case usb = 0, ps2 = 1, sun = 2
}

/// Manual analog-video tuning parameters (map to the device's MISC values).
public enum VideoAdjustment: String, Sendable, CaseIterable {
    case phase, horizontal, vertical, noise, sharpness
}

public struct KeyboardLEDs: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let num    = KeyboardLEDs(rawValue: 1 << 0)
    public static let caps   = KeyboardLEDs(rawValue: 1 << 1)
    public static let scroll = KeyboardLEDs(rawValue: 1 << 2)
}

/// Why there is currently no usable video (mirrors the original `noVideo` enum).
public enum NoVideoReason: UInt8, Sendable {
    case ok = 0, noSignal = 1, badMode = 2, dpmsStandby = 3
    case dpmsPowerdown = 4, noPower = 5, unstable = 6, badAuthcode = 7
}

/// High-level connection lifecycle of an adapter.
public enum AdapterState: Sendable, Equatable {
    case disconnected
    case connecting          // claimed, uploading FPGA / handshaking
    case noVideo(NoVideoReason)
    case live(width: Int, height: Int, hz: Int)
}

/// A snapshot of adapter status surfaced to the UI.
public struct AdapterStatus: Sendable {
    public var state: AdapterState
    public var keyboardOK: Bool
    public var keyboardType: KeyboardEmulation
    public var leds: KeyboardLEDs
    public var fps: Int
    public var bytesPerSecond: Double
    public var adjustments: [VideoAdjustment: Int]
    public init(state: AdapterState = .disconnected,
                keyboardOK: Bool = false,
                keyboardType: KeyboardEmulation = .usb,
                leds: KeyboardLEDs = [],
                fps: Int = 0,
                bytesPerSecond: Double = 0,
                adjustments: [VideoAdjustment: Int] = [:]) {
        self.state = state
        self.keyboardOK = keyboardOK
        self.keyboardType = keyboardType
        self.leds = leds
        self.fps = fps
        self.bytesPerSecond = bytesPerSecond
        self.adjustments = adjustments
    }
}

/// Events streamed from a backend to the session/UI layer.
public enum AdapterEvent: Sendable {
    case status(AdapterStatus)
    case frame(VideoFrame)
    case message(String)          // human-readable progress ("Installing firmware…")
    case mediaChanged(name: String?)   // virtual media mounted (name) or ejected (nil)
    case disconnected(reason: String)
}

/// DDC/EDID presets the adapter can advertise to the target.
public enum DDCPreset: Int, Sendable, CaseIterable {
    case res1280x1024 = 0, res1024x768 = 1, res1920x1200 = 2, res1920x1080 = 3
    public var label: String {
        switch self {
        case .res1280x1024: return "1280 × 1024"
        case .res1024x768:  return "1024 × 768"
        case .res1920x1200: return "1920 × 1200"
        case .res1920x1080: return "1920 × 1080"
        }
    }
}
