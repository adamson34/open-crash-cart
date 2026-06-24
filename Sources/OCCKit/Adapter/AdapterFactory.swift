import Foundation

/// Create the right backend for a discovered device + its matched profile. New backends
/// (e.g. a generic UVC one) plug in here keyed by `profile.backend`.
public func makeAdapter(for device: DiscoveredDevice, profile: HardwareProfile) -> (any CrashCartAdapter)? {
    switch profile.backend {
    case "dmtz-vsp":
        return StarTechAdapter(device: device, profile: profile)
    default:
        return nil
    }
}

/// Discover USB devices that match a configured hardware profile.
public func discoverProfiledDevices() -> [(device: DiscoveredDevice, profile: HardwareProfile)] {
    guard let devices = try? enumerateUSBDevices() else { return [] }
    return devices.compactMap { d in
        ProfileStore.shared.match(vendorID: d.vendorID, productID: d.productID).map { (d, $0) }
    }
}
