import Foundation

/// Driver for the CH9329 USB-serial → USB-HID controller used by many HDMI/VGA-capture KVM
/// dongles. It emulates a USB keyboard + mouse to the target. Protocol: each frame is
/// `0x57 0xAB <addr=0x00> <cmd> <len> <data…> <checksum>` where checksum = sum of all
/// preceding bytes mod 256.
final class CH9329 {
    private let port: SerialPort

    init?(path: String, baud: Int) {
        guard let p = SerialPort(path: path, baud: baud) else { return nil }
        port = p
    }

    func close() { port.close() }

    private func send(cmd: UInt8, data: [UInt8]) {
        port.writeBytes(ch9329Frame(cmd: cmd, data: data))
    }

    /// CMD 0x02: full 8-byte HID keyboard report — [modifier, 0x00, key1…key6].
    func keyboard(modifier: UInt8, keys: [UInt8]) {
        var k = Array(keys.prefix(6))
        while k.count < 6 { k.append(0) }
        send(cmd: 0x02, data: [modifier, 0x00] + k)
    }

    /// CMD 0x04: absolute mouse — report id 0x02, x/y scaled to 0…4095 of the screen.
    func mouseAbsolute(buttons: UInt8, x: Int, y: Int, wheel: Int8, width: Int, height: Int) {
        let ax = width > 0 ? max(0, min(4095, x * 4096 / width)) : 0
        let ay = height > 0 ? max(0, min(4095, y * 4096 / height)) : 0
        send(cmd: 0x04, data: [
            0x02, buttons,
            UInt8(ax & 0xFF), UInt8((ax >> 8) & 0xFF),
            UInt8(ay & 0xFF), UInt8((ay >> 8) & 0xFF),
            UInt8(bitPattern: wheel),
        ])
    }

    /// CMD 0x05: relative mouse — report id 0x01, signed dx/dy/wheel.
    func mouseRelative(buttons: UInt8, dx: Int8, dy: Int8, wheel: Int8) {
        send(cmd: 0x05, data: [
            0x01, buttons,
            UInt8(bitPattern: dx), UInt8(bitPattern: dy), UInt8(bitPattern: wheel),
        ])
    }
}

/// Build a CH9329 frame: `0x57 0xAB 0x00 <cmd> <len> <data…> <checksum>`, where checksum is
/// the sum of all preceding bytes mod 256.
public func ch9329Frame(cmd: UInt8, data: [UInt8]) -> [UInt8] {
    var frame: [UInt8] = [0x57, 0xAB, 0x00, cmd, UInt8(data.count)] + data
    var sum = 0
    for b in frame { sum = (sum + Int(b)) & 0xFF }
    frame.append(UInt8(sum))
    return frame
}

/// Candidate serial ports for a CH9329 (CH340/CH343-based dongles enumerate as these).
public func discoverCH9329Ports() -> [String] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
    return names
        .filter { $0.hasPrefix("cu.usbserial") || $0.hasPrefix("cu.wchusbserial") || $0.hasPrefix("cu.usbmodem") }
        .map { "/dev/\($0)" }
        .sorted()
}
