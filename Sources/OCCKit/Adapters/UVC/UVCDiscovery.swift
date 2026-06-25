import Foundation
import AVFoundation

/// A USB-Video (UVC) capture source — e.g. an HDMI/VGA→USB capture dongle that macOS sees
/// as an external camera.
public struct UVCDevice: Sendable, Identifiable {
    public let id: String       // AVCaptureDevice.uniqueID
    public let name: String
}

/// List external UVC video devices. Built-in cameras are excluded. UVC capture requires the
/// `.external` device type (macOS 14+); returns empty on older systems.
public func discoverUVCDevices() -> [UVCDevice] {
    guard #available(macOS 14.0, *) else { return [] }
    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.external], mediaType: .video, position: .unspecified)
    return session.devices.map { UVCDevice(id: $0.uniqueID, name: $0.localizedName) }
}

/// Resolve an AVCaptureDevice from a UVC device id.
func resolveUVCDevice(id: String) -> AVCaptureDevice? {
    guard #available(macOS 14.0, *) else { return nil }
    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.external], mediaType: .video, position: .unspecified)
    return session.devices.first { $0.uniqueID == id }
}
