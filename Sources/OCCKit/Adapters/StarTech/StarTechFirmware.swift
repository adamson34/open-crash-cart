import Foundation

/// Locates and loads the adapter's FPGA bitstream **from the user's existing vendor
/// installation at runtime**. We deliberately do NOT bundle or redistribute the vendor's
/// proprietary firmware blobs — OpenCrashCart only reads the copy the user already has.
///
/// Resolution order:
///   1. `OCC_FIRMWARE_DIR` environment variable (explicit override), then
///   2. the installed "USB Crash Cart Adapter.app" bundle, then
///   3. the per-user data dir the vendor app copies into `~`.
public struct StarTechFirmware {

    public enum FirmwareError: Error, CustomStringConvertible {
        case notFound(searched: [String])
        public var description: String {
            switch self {
            case .notFound(let searched):
                return """
                Could not find the adapter FPGA bitstream (ulcvm.fgz / usbip.fgz).
                OpenCrashCart loads it from your existing StarTech install rather than shipping it.
                Searched:
                \(searched.map { "  • \($0)" }.joined(separator: "\n"))
                Set OCC_FIRMWARE_DIR to the folder containing the .fgz files to override.
                """
            }
        }
    }

    /// Candidate directories that may contain firmware files. `extra` (e.g. a profile's
    /// own firmwareDir) is searched first, then OpenCrashCart's own configured/owned locations,
    /// then the vendor install as a fallback.
    static func searchDirectories(extra: [String] = []) -> [String] {
        var dirs = extra
        if let override = ProcessInfo.processInfo.environment["OCC_FIRMWARE_DIR"] {
            dirs.append(override)
        }
        if let configured = ProfileStore.shared.firmwareDirectory, !configured.isEmpty {
            dirs.append(configured)
        }
        dirs.append(ProfileStore.shared.applicationSupportFirmwareDir)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        dirs.append(contentsOf: [
            "/Applications/USB Crash Cart Adapter.app/Contents/Resources/data",
            "\(home)/data",
            "\(home)/Library/Application Support/USB Crash Cart Adapter/data",
        ])
        return dirs
    }

    /// Locate a firmware file across the search directories.
    static func locate(_ filename: String, extra: [String]) -> String? {
        for dir in searchDirectories(extra: extra) {
            let path = (dir as NSString).expandingTildeInPath + "/" + filename
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    /// Load + inflate the FPGA bitstream for a given hardware profile.
    public static func loadFPGABitstream(profile: HardwareProfile) throws -> [UInt8] {
        let files = profile.firmwareFiles.isEmpty ? ["ulcvm.fgz", "usbip.fgz"] : profile.firmwareFiles
        let extra = profile.firmwareDir.map { [$0] } ?? []
        for name in files {
            if let path = locate(name, extra: extra) {
                let compressed = try Data(contentsOf: URL(fileURLWithPath: path))
                return try gunzip([UInt8](compressed))
            }
        }
        throw FirmwareError.notFound(searched: searchDirectories(extra: extra).flatMap { dir in
            files.map { "\(dir)/\($0)" }
        })
    }

    /// Find a firmware file by name across the search directories.
    static func locate(_ filename: String) -> String? {
        for dir in searchDirectories() {
            let path = "\(dir)/\(filename)"
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    /// Load and inflate the FPGA bitstream for the given hardware generation.
    /// gen-2 ("ulcvm") is the current NOTECONS02; gen-1 falls back to "usbip".
    public static func loadFPGABitstream(generation: Int) throws -> [UInt8] {
        let names = generation >= 2 ? ["ulcvm.fgz", "usbip.fgz"] : ["usbip.fgz", "ulcvm.fgz"]
        for name in names {
            if let path = locate(name) {
                let compressed = try Data(contentsOf: URL(fileURLWithPath: path))
                return try gunzip([UInt8](compressed))
            }
        }
        throw FirmwareError.notFound(searched: searchDirectories().flatMap { dir in
            names.map { "\(dir)/\($0)" }
        })
    }
}
