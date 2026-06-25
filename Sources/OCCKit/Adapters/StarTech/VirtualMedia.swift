import Foundation

/// A disk image served to the target as a USB drive. The device requests block reads/writes;
/// this maps them to the backing file. ISO → CD-ROM (2048-byte, read-only); IMG/raw → disk
/// (512-byte, read/write).
public final class VirtualMedia: @unchecked Sendable {
    public let blockSize: Int
    public let blockCount: UInt32
    public let readOnly: Bool
    public let name: String

    private let handle: FileHandle
    private let lock = NSLock()
    private var closed = false

    public init?(path: String, cdrom: Bool) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64, size > 0 else { return nil }
        blockSize = cdrom ? 2048 : 512
        readOnly = cdrom
        name = (path as NSString).lastPathComponent
        if cdrom {
            guard let h = FileHandle(forReadingAtPath: path) else { return nil }
            handle = h
        } else {
            guard let h = FileHandle(forUpdatingAtPath: path) ?? FileHandle(forReadingAtPath: path) else { return nil }
            handle = h
        }
        blockCount = UInt32(size / UInt64(blockSize))
    }

    /// Read `length` bytes starting at `startBlock`, zero-padded if short.
    public func read(startBlock: UInt32, length: Int) -> Data {
        lock.lock(); defer { lock.unlock() }
        guard !closed, length > 0 else { return Data(count: max(0, length)) }
        do {
            try handle.seek(toOffset: UInt64(startBlock) * UInt64(blockSize))
            let data = handle.readData(ofLength: length)
            return data.count < length ? data + Data(count: length - data.count) : data
        } catch {
            return Data(count: length)
        }
    }

    public func write(startBlock: UInt32, data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !closed, !readOnly else { return }
        try? handle.seek(toOffset: UInt64(startBlock) * UInt64(blockSize))
        try? handle.write(contentsOf: data)
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        if !closed { try? handle.close(); closed = true }
    }
}
