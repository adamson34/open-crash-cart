import Foundation

/// A user-definable hardware profile: which USB device a crash-cart adapter is, which
/// backend protocol drives it, and where its firmware lives. Profiles let OpenCrashCart support
/// new (often OEM-rebranded) adapters without code changes — "bring your own firmware".
public struct HardwareProfile: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var backend: String          // protocol backend, e.g. "dmtz-vsp"
    public var vendorId: String         // "0x152A" (hex) or decimal
    public var productIds: [String]     // ["0x8460", "0x8463"]
    public var firmwareFiles: [String]  // ordered candidates, e.g. ["ulcvm.fgz", "usbip.fgz"]
    public var firmwareDir: String?     // optional per-profile firmware folder override
    public var builtIn: Bool            // shipped default (can be edited, not deleted)

    public init(id: String, name: String, backend: String, vendorId: String,
                productIds: [String], firmwareFiles: [String],
                firmwareDir: String? = nil, builtIn: Bool = false) {
        self.id = id
        self.name = name
        self.backend = backend
        self.vendorId = vendorId
        self.productIds = productIds
        self.firmwareFiles = firmwareFiles
        self.firmwareDir = firmwareDir
        self.builtIn = builtIn
    }

    public var vid: UInt16 { HardwareProfile.parse(vendorId) }
    public var pids: [UInt16] { productIds.map(HardwareProfile.parse) }

    public func matches(vendorID: UInt16, productID: UInt16) -> Bool {
        vid == vendorID && pids.contains(productID)
    }

    /// Parse "0x152A" (hex) or "5418" (decimal) → UInt16.
    static func parse(_ s: String) -> UInt16 {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.lowercased().hasPrefix("0x") { return UInt16(t.dropFirst(2), radix: 16) ?? 0 }
        return UInt16(t) ?? 0
    }
}
