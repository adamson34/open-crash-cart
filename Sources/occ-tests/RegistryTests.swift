import Foundation
import OCCKit

// BC-1.04.020 — device identity (VID/PID) is declared in exactly one place
// (ProfileStore.builtIns); AdapterRegistry and StarTechAdapter.model derive from it.
func runRegistryTests(_ t: Harness) {
    t.section("Device-matching single source of truth (BC-1.04.020)")

    let builtin = ProfileStore.builtIns.first { $0.id == "startech-notecons02" }!

    let reg = AdapterRegistry.known.first { $0.id == "startech-notecons02" }!
    t.expectEqual(reg.vendorID, builtin.vid, "registry vendorID derives from built-in profile")
    t.expectEqual(reg.productIDs, builtin.pids, "registry productIDs derive from built-in profile")

    t.expectEqual(StarTechAdapter.model.vendorID, builtin.vid, "adapter model vendorID derives from built-in")
    t.expectEqual(StarTechAdapter.model.productIDs, builtin.pids, "adapter model productIDs derive from built-in")

    // The three former hardcode sites now agree by construction.
    t.expect(StarTechAdapter.model.vendorID == reg.vendorID
                && StarTechAdapter.model.productIDs == reg.productIDs,
             "registry and adapter model agree (single source)")

    // End-to-end matching still works.
    t.expect(AdapterRegistry.match(vendorID: 0x152A, productID: 0x8463) != nil, "registry matches gen-2 PID")
    t.expect(AdapterRegistry.match(vendorID: 0x152A, productID: 0x8460) != nil, "registry matches gen-1 PID")
    t.expect(AdapterRegistry.match(vendorID: 0x152A, productID: 0x9999) == nil, "registry rejects unknown PID")

    let dev = DiscoveredDevice(vendorID: 0x152A, productID: 0x8463, busNumber: 1, address: 2,
                               manufacturer: nil, product: nil, serial: nil, isHighSpeedOrBetter: true)
    t.expect(StarTechAdapter.canDrive(dev), "canDrive accepts a supported device")
}
