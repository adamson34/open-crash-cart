// swift-tools-version: 6.0
import PackageDescription

// libusb is located via Homebrew at /opt/homebrew (Apple Silicon default). pkg-config is
// not required: the Clibusb module map points at the Homebrew header directly and we add
// the lib search path below. Adjust the prefix if Homebrew lives elsewhere.
let homebrewLib = "/opt/homebrew/lib"

let package = Package(
    name: "OpenCrashCart",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "OCCKit", targets: ["OCCKit"]),
        .executable(name: "occ", targets: ["occ"]),                  // the app
        .executable(name: "occ-probe", targets: ["occ-probe"]),
        .executable(name: "occ-connect", targets: ["occ-connect"]),
        .executable(name: "occ-selftest", targets: ["occ-selftest"]),
    ],
    targets: [
        .systemLibrary(name: "Clibusb", path: "Sources/Clibusb"),
        .systemLibrary(name: "Czlib", path: "Sources/Czlib"),
        .target(
            name: "OCCKit",
            dependencies: ["Clibusb", "Czlib"],
            linkerSettings: [.unsafeFlags(["-L\(homebrewLib)"])]
        ),
        .executableTarget(
            name: "occ-probe",
            dependencies: ["OCCKit"],
            linkerSettings: [.unsafeFlags(["-L\(homebrewLib)"])]
        ),
        .executableTarget(
            name: "occ-connect",
            dependencies: ["OCCKit"],
            linkerSettings: [.unsafeFlags(["-L\(homebrewLib)"])]
        ),
        .executableTarget(
            name: "occ-selftest",
            dependencies: ["OCCKit"],
            linkerSettings: [.unsafeFlags(["-L\(homebrewLib)"])]
        ),
        .executableTarget(
            name: "occ",
            dependencies: ["OCCKit"],
            linkerSettings: [.unsafeFlags(["-L\(homebrewLib)"])]
        ),
    ]
)
