import Foundation
import OCCKit

func runProfileTests(_ t: Harness) {
    t.section("Hardware profiles")

    let hex = HardwareProfile(id: "t", name: "t", backend: "x",
                              vendorId: "0x152A", productIds: ["0x8460"], firmwareFiles: [])
    t.expectEqual(hex.vid, UInt16(0x152A), "hex vendorId → vid")

    let dec = HardwareProfile(id: "t", name: "t", backend: "x",
                              vendorId: "5418", productIds: ["33888"], firmwareFiles: [])
    t.expectEqual(dec.vid, UInt16(5418), "decimal vendorId → vid")
    t.expectEqual(dec.pids, [UInt16(33888)], "decimal productIds → pids")

    let startech = ProfileStore.builtIns.first { $0.id == "startech-notecons02" }!
    t.expect(startech.matches(vendorID: 0x152A, productID: 0x8463), "StarTech profile matches PID 0x8463")
    t.expect(startech.matches(vendorID: 0x152A, productID: 0x8460), "StarTech profile matches PID 0x8460")
    t.expect(!startech.matches(vendorID: 0x152A, productID: 0x9999), "does not match an unknown PID")

    // JSON round-trip (the on-disk profiles.json format).
    let data = try! JSONEncoder().encode(startech)
    let back = try! JSONDecoder().decode(HardwareProfile.self, from: data)
    t.expectEqual(back, startech, "profile survives JSON encode/decode")
}
