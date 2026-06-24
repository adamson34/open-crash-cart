import Foundation

/// Loads, persists, and matches hardware profiles. Backed by a user-editable JSON file at
/// ~/Library/Application Support/OpenCrashCart/profiles.json, seeded with built-in defaults.
public final class ProfileStore: @unchecked Sendable {
    public static let shared = ProfileStore()

    private let lock = NSLock()
    private let fileURL: URL
    private var _profiles: [HardwareProfile]
    private var _firmwareDirectory: String?

    private struct Config: Codable {
        var firmwareDirectory: String?
        var profiles: [HardwareProfile]
    }

    /// Shipped defaults. StarTech NOTECONS02 is the same Digital Multitools (DMTZ) hardware
    /// several brands resell, so the "dmtz-vsp" backend covers the whole family.
    public static let builtIns: [HardwareProfile] = [
        HardwareProfile(
            id: "startech-notecons02",
            name: "StarTech NOTECONS02",
            backend: "dmtz-vsp",
            vendorId: "0x152A",
            productIds: ["0x8460", "0x8463"],
            firmwareFiles: ["ulcvm.fgz", "usbip.fgz"],
            builtIn: true),
    ]

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenCrashCart", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("profiles.json")

        if let data = try? Data(contentsOf: fileURL),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            _profiles = cfg.profiles.isEmpty ? Self.builtIns : cfg.profiles
            _firmwareDirectory = cfg.firmwareDirectory
        } else {
            _profiles = Self.builtIns
            _firmwareDirectory = nil
            writeToDisk()
        }
    }

    // MARK: Accessors (thread-safe; read from the connect/boot thread + the UI)

    public var profiles: [HardwareProfile] {
        lock.lock(); defer { lock.unlock() }; return _profiles
    }

    public var firmwareDirectory: String? {
        get { lock.lock(); defer { lock.unlock() }; return _firmwareDirectory }
        set { lock.lock(); _firmwareDirectory = newValue; lock.unlock(); writeToDisk() }
    }

    /// Folder OpenCrashCart offers as its own firmware home (so the vendor app isn't required).
    public var applicationSupportFirmwareDir: String {
        fileURL.deletingLastPathComponent().appendingPathComponent("firmware").path
    }

    public func match(vendorID: UInt16, productID: UInt16) -> HardwareProfile? {
        lock.lock(); defer { lock.unlock() }
        return _profiles.first { $0.matches(vendorID: vendorID, productID: productID) }
    }

    public func upsert(_ profile: HardwareProfile) {
        lock.lock()
        if let i = _profiles.firstIndex(where: { $0.id == profile.id }) { _profiles[i] = profile }
        else { _profiles.append(profile) }
        lock.unlock()
        writeToDisk()
    }

    public func remove(id: String) {
        lock.lock()
        _profiles.removeAll { $0.id == id && !$0.builtIn }
        lock.unlock()
        writeToDisk()
    }

    private func writeToDisk() {
        lock.lock()
        let cfg = Config(firmwareDirectory: _firmwareDirectory, profiles: _profiles)
        lock.unlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(cfg) { try? data.write(to: fileURL) }
    }
}
