import Foundation
import OCCKit

// ProfileStore persistence/matching, exercised against a temp file so the real user config
// is never touched (BC-1.04.005 / .073 / .200–.204).
func runProfileStoreTests(_ t: Harness) {
    t.section("ProfileStore persistence + matching")

    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("occ-profiles-\(getpid()).json")
    try? FileManager.default.removeItem(atPath: path)
    defer { try? FileManager.default.removeItem(atPath: path) }
    let url = URL(fileURLWithPath: path)

    let store = ProfileStore(fileURL: url)
    t.expect(store.profiles.contains { $0.id == "startech-notecons02" }, "seeds the built-in profile")
    t.expect(FileManager.default.fileExists(atPath: path), "writes profiles.json on first run")

    t.expect(store.match(vendorID: 0x152A, productID: 0x8463) != nil, "matches the built-in device")
    t.expect(store.match(vendorID: 0x152A, productID: 0x9999) == nil, "rejects an unknown PID")

    let custom = HardwareProfile(id: "custom-1", name: "Test", backend: "dmtz-vsp",
                                 vendorId: "0x1234", productIds: ["0x5678"], firmwareFiles: [])
    store.upsert(custom)
    t.expect(store.match(vendorID: 0x1234, productID: 0x5678)?.id == "custom-1", "upsert + match a custom profile")

    var edited = custom; edited.name = "Edited"
    store.upsert(edited)
    t.expectEqual(store.profiles.filter { $0.id == "custom-1" }.count, 1, "upsert replaces, not duplicates")
    t.expectEqual(store.profiles.first { $0.id == "custom-1" }?.name, "Edited", "upsert updates fields")

    store.remove(id: "custom-1")
    t.expect(!store.profiles.contains { $0.id == "custom-1" }, "removes a custom profile")
    store.remove(id: "startech-notecons02")
    t.expect(store.profiles.contains { $0.id == "startech-notecons02" }, "cannot remove a built-in")

    // Persistence across reloads.
    store.upsert(custom)
    store.firmwareDirectory = "/tmp/fw"
    let reloaded = ProfileStore(fileURL: url)
    t.expect(reloaded.profiles.contains { $0.id == "custom-1" }, "profiles persist across reloads")
    t.expectEqual(reloaded.firmwareDirectory, "/tmp/fw", "firmwareDirectory persists across reloads")
}
