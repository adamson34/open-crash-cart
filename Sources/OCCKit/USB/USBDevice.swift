import Foundation
import Clibusb

public enum USBTransportError: Error, CustomStringConvertible {
    case contextInitFailed(Int32)
    case deviceNotFound
    case openFailed(Int32)
    case claimFailed(Int32)
    case transferFailed(Int32)
    case timeout
    case disconnected
    public var description: String {
        switch self {
        case .contextInitFailed(let rc): return "libusb_init failed (\(rc))"
        case .deviceNotFound:            return "device no longer present on the bus"
        case .openFailed(let rc):        return "libusb_open failed (\(rc) — \(USBDevice.errorName(rc)))"
        case .claimFailed(let rc):       return "claim interface failed (\(rc) — \(USBDevice.errorName(rc)))"
        case .transferFailed(let rc):    return "bulk transfer failed (\(rc) — \(USBDevice.errorName(rc)))"
        case .timeout:                   return "transfer timed out"
        case .disconnected:              return "device disconnected"
        }
    }
}

/// A claimed, openable USB device. Wraps a libusb handle and exposes blocking bulk
/// reads/writes. libusb transfers are thread-safe across endpoints, so the StarTech
/// backend drives separate reader/writer threads against one `USBDevice`.
public final class USBDevice: @unchecked Sendable {
    // libusb numeric error codes we special-case (avoids enum-import fragility).
    private static let LIBUSB_ERROR_TIMEOUT: Int32 = -7
    private static let LIBUSB_ERROR_NO_DEVICE: Int32 = -4

    private var ctx: OpaquePointer?
    private var handle: OpaquePointer?
    public let info: DiscoveredDevice

    private init(ctx: OpaquePointer?, handle: OpaquePointer?, info: DiscoveredDevice) {
        self.ctx = ctx
        self.handle = handle
        self.info = info
    }

    /// Open the specific device identified during discovery (matched by bus/address so
    /// we open the exact unit, not just the first VID/PID match).
    public static func open(matching target: DiscoveredDevice) throws -> USBDevice {
        var ctx: OpaquePointer?
        let initRC = libusb_init(&ctx)
        guard initRC == 0 else { throw USBTransportError.contextInitFailed(initRC) }

        var list: UnsafeMutablePointer<OpaquePointer?>?
        let count = libusb_get_device_list(ctx, &list)
        guard count >= 0 else {
            libusb_exit(ctx)
            throw USBTransportError.deviceNotFound
        }
        defer { libusb_free_device_list(list, 1) }

        for i in 0..<count {
            guard let dev = list?[i] else { continue }
            if libusb_get_bus_number(dev) == target.busNumber,
               libusb_get_device_address(dev) == target.address {
                var handle: OpaquePointer?
                let rc = libusb_open(dev, &handle)
                guard rc == 0, let h = handle else {
                    libusb_exit(ctx)
                    throw USBTransportError.openFailed(rc)
                }
                return USBDevice(ctx: ctx, handle: h, info: target)
            }
        }
        libusb_exit(ctx)
        throw USBTransportError.deviceNotFound
    }

    public func claimInterface(_ number: UInt8) throws {
        guard let handle else { throw USBTransportError.disconnected }
        let rc = libusb_claim_interface(handle, Int32(number))
        guard rc == 0 else { throw USBTransportError.claimFailed(rc) }
    }

    /// Blocking bulk write. Returns bytes transferred.
    @discardableResult
    public func bulkWrite(endpoint: UInt8, data: [UInt8], timeoutMs: UInt32 = 1000) throws -> Int {
        guard let handle else { throw USBTransportError.disconnected }
        var transferred: Int32 = 0
        var buffer = data
        let rc = buffer.withUnsafeMutableBufferPointer { ptr in
            libusb_bulk_transfer(handle, endpoint, ptr.baseAddress, Int32(ptr.count), &transferred, timeoutMs)
        }
        try check(rc)
        return Int(transferred)
    }

    /// Blocking bulk read. Returns up to `maxLength` bytes actually received.
    public func bulkRead(endpoint: UInt8, maxLength: Int, timeoutMs: UInt32 = 2000) throws -> [UInt8] {
        guard let handle else { throw USBTransportError.disconnected }
        var buffer = [UInt8](repeating: 0, count: maxLength)
        var transferred: Int32 = 0
        let rc = buffer.withUnsafeMutableBufferPointer { ptr in
            libusb_bulk_transfer(handle, endpoint, ptr.baseAddress, Int32(ptr.count), &transferred, timeoutMs)
        }
        try check(rc)
        return Array(buffer[0..<Int(transferred)])
    }

    public var isHighSpeedOrBetter: Bool { info.isHighSpeedOrBetter }

    public func close() {
        if let handle {
            libusb_release_interface(handle, Int32(VSProtocol.interfaceNumber))
            libusb_close(handle)
            self.handle = nil
        }
        if let ctx {
            libusb_exit(ctx)
            self.ctx = nil
        }
    }

    private func check(_ rc: Int32) throws {
        guard rc != 0 else { return }
        switch rc {
        case Self.LIBUSB_ERROR_TIMEOUT:   throw USBTransportError.timeout
        case Self.LIBUSB_ERROR_NO_DEVICE: throw USBTransportError.disconnected
        default:                          throw USBTransportError.transferFailed(rc)
        }
    }

    static func errorName(_ rc: Int32) -> String {
        String(cString: libusb_error_name(rc))
    }
}
