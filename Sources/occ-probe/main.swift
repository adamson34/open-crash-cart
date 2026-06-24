import Foundation
import OCCKit

// occ-probe — Phase 1 smoke test.
// Scans USB and reports any recognized crash-cart adapter. Run with the adapter
// plugged in to confirm OpenCrashCart sees and identifies it before we attempt I/O.

func hex(_ v: UInt16) -> String { String(format: "0x%04X", v) }

let devices: [DiscoveredDevice]
do {
    devices = try enumerateUSBDevices()
} catch {
    FileHandle.standardError.write(Data("USB enumeration failed: \(error)\n".utf8))
    exit(1)
}

let carts = devices.compactMap { d in
    AdapterRegistry.match(vendorID: d.vendorID, productID: d.productID).map { (d, $0) }
}

print("occ-probe — scanning USB for crash-cart adapters")
print(String(repeating: "─", count: 56))

if carts.isEmpty {
    print("No known crash-cart adapter found (\(devices.count) USB devices seen).\n")
    print("Supported models:")
    for m in AdapterRegistry.known {
        let pids = m.productIDs.map(hex).joined(separator: "/")
        print("  • \(m.name)\n      VID \(hex(m.vendorID))  PID \(pids)")
    }
    print("\nTip: plug in the adapter and run `swift run occ-probe` again.")
} else {
    print("Found \(carts.count) crash-cart adapter(s):\n")
    for (d, m) in carts {
        print("  ✓ \(m.name)")
        print("      VID/PID : \(hex(d.vendorID)):\(hex(d.productID))")
        print("      bus/addr: \(d.busNumber)/\(d.address)")
        print("      product : \(d.product ?? "—")")
        print("      serial  : \(d.serial ?? "—")")
        let speed = d.isHighSpeedOrBetter
            ? "High-Speed+ (480 Mbps+, good)"
            : "Full-Speed only — video will be slow"
        print("      usb     : \(speed)")
        print("      backend : \(m.id)\n")
    }
}
