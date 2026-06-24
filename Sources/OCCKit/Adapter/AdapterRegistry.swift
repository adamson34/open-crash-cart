import Foundation

/// Describes a known crash-cart adapter model and which backend drives it.
public struct AdapterModel: Sendable, Identifiable {
    public let id: String          // backend identifier, e.g. "startech-notecons02"
    public let name: String
    public let vendorID: UInt16
    public let productIDs: [UInt16]
    public init(id: String, name: String, vendorID: UInt16, productIDs: [UInt16]) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productIDs = productIDs
    }
}

/// Central catalogue of supported adapters. New models register here.
public enum AdapterRegistry {
    public static let known: [AdapterModel] = [
        AdapterModel(
            id: "startech-notecons02",
            name: "StarTech NOTECONS02 USB Crash Cart Adapter",
            vendorID: 0x152A,                 // Digital Multitools (OEM)
            productIDs: [0x8460, 0x8463]      // gen-1 / gen-2
        ),
    ]

    /// Returns the model matching a USB VID/PID, if any.
    public static func match(vendorID: UInt16, productID: UInt16) -> AdapterModel? {
        known.first { $0.vendorID == vendorID && $0.productIDs.contains(productID) }
    }
}
