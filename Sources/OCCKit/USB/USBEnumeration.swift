import Foundation
import Clibusb

public enum USBError: Error, CustomStringConvertible {
    case initFailed(Int32)
    case enumerationFailed(Int32)
    public var description: String {
        switch self {
        case .initFailed(let rc):        return "libusb_init failed (\(rc))"
        case .enumerationFailed(let rc): return "libusb_get_device_list failed (\(rc))"
        }
    }
}

/// Enumerate every USB device currently on the bus. String descriptors (manufacturer,
/// product, serial) are best-effort: reading them requires opening the device, which
/// may fail for devices held by another driver — that's non-fatal here.
public func enumerateUSBDevices() throws -> [DiscoveredDevice] {
    var ctx: OpaquePointer?
    let initRC = libusb_init(&ctx)
    guard initRC == 0 else { throw USBError.initFailed(initRC) }
    defer { libusb_exit(ctx) }

    var list: UnsafeMutablePointer<OpaquePointer?>?
    let count = libusb_get_device_list(ctx, &list)
    guard count >= 0 else { throw USBError.enumerationFailed(Int32(count)) }
    defer { libusb_free_device_list(list, 1) }

    var devices: [DiscoveredDevice] = []
    for i in 0..<count {
        guard let dev = list?[i] else { continue }
        var desc = libusb_device_descriptor()
        guard libusb_get_device_descriptor(dev, &desc) == 0 else { continue }

        let bus = libusb_get_bus_number(dev)
        let addr = libusb_get_device_address(dev)
        // libusb_speed: UNKNOWN=0, LOW=1, FULL=2, HIGH=3, SUPER=4, SUPER_PLUS=5.
        let highSpeedOrBetter = libusb_get_device_speed(dev) >= 3

        var manufacturer: String?, product: String?, serial: String?
        var handle: OpaquePointer?
        if libusb_open(dev, &handle) == 0, let h = handle {
            manufacturer = asciiStringDescriptor(h, desc.iManufacturer)
            product      = asciiStringDescriptor(h, desc.iProduct)
            serial       = asciiStringDescriptor(h, desc.iSerialNumber)
            libusb_close(h)
        }

        devices.append(DiscoveredDevice(
            vendorID: desc.idVendor,
            productID: desc.idProduct,
            busNumber: bus,
            address: addr,
            manufacturer: manufacturer,
            product: product,
            serial: serial,
            isHighSpeedOrBetter: highSpeedOrBetter
        ))
    }
    return devices
}

/// Discover only devices that a registered crash-cart backend recognizes.
public func discoverCrashCartDevices() throws -> [(device: DiscoveredDevice, model: AdapterModel)] {
    try enumerateUSBDevices().compactMap { dev in
        AdapterRegistry.match(vendorID: dev.vendorID, productID: dev.productID).map { (dev, $0) }
    }
}

private func asciiStringDescriptor(_ handle: OpaquePointer, _ index: UInt8) -> String? {
    guard index != 0 else { return nil }
    var buf = [UInt8](repeating: 0, count: 256)
    let n = libusb_get_string_descriptor_ascii(handle, index, &buf, Int32(buf.count))
    guard n > 0 else { return nil }
    return String(decoding: buf[0..<Int(n)], as: UTF8.self)
}
