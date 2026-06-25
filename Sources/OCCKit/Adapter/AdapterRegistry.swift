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

/// Central catalogue of supported adapters, **derived from `ProfileStore.builtIns`** so device
/// identity (VID/PID) is declared in exactly one place (BC-1.04.020). No identity constants are
/// hardcoded here — to support a new model, add a built-in profile.
public enum AdapterRegistry {
    public static let known: [AdapterModel] = ProfileStore.builtIns.map {
        AdapterModel(id: $0.id, name: $0.name, vendorID: $0.vid, productIDs: $0.pids)
    }

    /// Returns the model matching a USB VID/PID, if any.
    public static func match(vendorID: UInt16, productID: UInt16) -> AdapterModel? {
        known.first { $0.vendorID == vendorID && $0.productIDs.contains(productID) }
    }
}
