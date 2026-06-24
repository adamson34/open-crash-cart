import Foundation

/// A thread-safe, two-priority command queue. Input events (key/mouse) jump ahead of
/// control traffic (status polls, FPGA blocks) so typing stays responsive even while a
/// bitstream is uploading — mirroring the original's separate GUI/control lists.
final class CommandQueue: @unchecked Sendable {
    enum Priority { case input, control }

    private let cond = NSCondition()
    private var inputQ: [[UInt8]] = []
    private var controlQ: [[UInt8]] = []
    private var closed = false

    func enqueue(_ message: [UInt8], priority: Priority) {
        guard !message.isEmpty else { return }
        cond.lock()
        if !closed {
            switch priority {
            case .input:   inputQ.append(message)
            case .control: controlQ.append(message)
            }
            cond.signal()
        }
        cond.unlock()
    }

    /// Block until a message is available (input first) or the queue is closed (→ nil).
    func take() -> [UInt8]? {
        cond.lock()
        defer { cond.unlock() }
        while inputQ.isEmpty && controlQ.isEmpty && !closed {
            cond.wait()
        }
        if !inputQ.isEmpty { return inputQ.removeFirst() }
        if !controlQ.isEmpty { return controlQ.removeFirst() }
        return nil   // closed
    }

    func close() {
        cond.lock()
        closed = true
        cond.broadcast()
        cond.unlock()
    }
}

/// Minimal atomic boolean for cross-thread run/stop signaling.
final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    init(_ initial: Bool) { value = initial }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ newValue: Bool) { lock.lock(); value = newValue; lock.unlock() }
}

/// Sequential big-endian reader for parsing fixed-layout protocol messages.
struct ByteReader {
    private let bytes: [UInt8]
    private var offset = 0
    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func u8() -> UInt8 {
        guard offset < bytes.count else { return 0 }
        defer { offset += 1 }
        return bytes[offset]
    }
    mutating func u16() -> UInt16 {
        let hi = UInt16(u8()), lo = UInt16(u8())
        return (hi << 8) | lo
    }
    mutating func u32() -> UInt32 {
        let a = UInt32(u16()), b = UInt32(u16())
        return (a << 16) | b
    }
    mutating func bytes(_ count: Int) -> [UInt8] {
        let end = min(offset + count, bytes.count)
        defer { offset = end }
        return Array(bytes[offset..<end])
    }
}

/// Decode a NUL-terminated ASCII field (vendor strings in some responses).
func asciiz(_ bytes: [UInt8]) -> String {
    let trimmed = bytes.prefix { $0 != 0 }
    return String(decoding: trimmed, as: UTF8.self)
}
