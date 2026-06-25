import Foundation
import OCCKit

// P1.5 — characterization tests for previously-untested behavior, now reachable via pure public
// cores extracted in v1.1.0 (BC-1.06.004..009).
func runBackfillTests(_ t: Harness) {
    t.section("USB libusb return-code mapping (BC-1.06.004)")
    t.expect(USBDevice.mapLibusbResult(0) == nil, "rc 0 → nil (success)")
    t.expectEqual(USBDevice.mapLibusbResult(-7), .timeout, "rc -7 → .timeout")
    t.expectEqual(USBDevice.mapLibusbResult(-4), .disconnected, "rc -4 → .disconnected")
    t.expectEqual(USBDevice.mapLibusbResult(-99), .transferFailed(-99), "other rc → .transferFailed(rc)")

    t.section("STATUS bps + state derivation (BC-1.06.007)")
    t.expectEqual(StarTechAdapter.computeBytesPerSecond(words: 500, ticks: 1000), 8000.0, "bps = words*16*1000/ticks")
    t.expectEqual(StarTechAdapter.computeBytesPerSecond(words: 500, ticks: 0), 0.0, "ticks 0 → 0 (no divide)")
    t.expectEqual(StarTechAdapter.deriveState(fpgaLoaded: true, noVideo: 0, width: 1920, height: 1080, hz: 60),
                  .live(width: 1920, height: 1080, hz: 60), "fpga + dims → .live")
    t.expectEqual(StarTechAdapter.deriveState(fpgaLoaded: false, noVideo: 0, width: 1920, height: 1080, hz: 60),
                  .connecting, "no fpga → .connecting")
    t.expectEqual(StarTechAdapter.deriveState(fpgaLoaded: true, noVideo: 1, width: 1920, height: 1080, hz: 60),
                  .noVideo(.noSignal), "noVideo byte wins → .noVideo(reason)")

    t.section("Firmware search-path order (BC-1.06.006)")
    t.expectEqual(StarTechFirmware.firmwareSearchPaths(profileDir: "P", env: "E", storeDir: "S",
                                                       appSupportDir: "A", vendorPaths: ["V1", "V2", "V3"]),
                  ["P", "E", "S", "A", "V1", "V2", "V3"], "full ordered chain")
    t.expectEqual(StarTechFirmware.firmwareSearchPaths(profileDir: nil, env: nil, storeDir: nil,
                                                       appSupportDir: "A", vendorPaths: ["V"]),
                  ["A", "V"], "nil inputs dropped")
    t.expectEqual(StarTechFirmware.firmwareSearchPaths(profileDir: nil, env: "", storeDir: "",
                                                       appSupportDir: "A", vendorPaths: []),
                  ["", "A"], "empty env included (nil-only check); empty storeDir excluded")

    t.section("Mouse coalescing latest-wins (BC-1.06.008)")
    let mc = MouseCoalescer()
    t.expect(mc.drain() == nil, "empty coalescer drains nil")
    mc.store(MouseEvent(buttons: [], x: 10, y: 20, wheel: 0, isAbsolute: true))
    mc.store(MouseEvent(buttons: [], x: 30, y: 40, wheel: 0, isAbsolute: true))
    mc.store(MouseEvent(buttons: [], x: 50, y: 60, wheel: 0, isAbsolute: true))
    let drained = mc.drain()
    t.expect(drained?.x == 50 && drained?.y == 60, "drain returns only the latest event")
    t.expect(mc.drain() == nil, "second drain is empty")

    t.section("Virtual media block math (BC-1.06.005)")
    let tmp = (NSTemporaryDirectory() as NSString).appendingPathComponent("occ-vm-\(getpid()).img")
    try? Data(repeating: 0xAB, count: 1024).write(to: URL(fileURLWithPath: tmp))
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    if let vm = VirtualMedia(path: tmp, cdrom: false) {
        t.expectEqual(vm.blockSize, 512, "img → 512-byte blocks")
        t.expectEqual(vm.blockCount, UInt32(2), "1024 bytes / 512 = 2 blocks")
        t.expect(!vm.readOnly, "img is read/write")
        t.expectEqual(vm.read(startBlock: 0, length: 4), Data([0xAB, 0xAB, 0xAB, 0xAB]), "reads file bytes")
        t.expectEqual(vm.read(startBlock: 100, length: 8), Data(count: 8), "read past EOF zero-pads")
        vm.close()
    } else {
        t.expect(false, "VirtualMedia init from temp file")
    }
    if let cd = VirtualMedia(path: tmp, cdrom: true) {
        t.expectEqual(cd.blockSize, 2048, "cdrom → 2048-byte blocks")
        t.expect(cd.readOnly, "cdrom is read-only")
        cd.write(startBlock: 0, data: Data([0x01]))   // no-op, must not crash
        t.expectEqual(cd.read(startBlock: 0, length: 4), Data([0xAB, 0xAB, 0xAB, 0xAB]), "cdrom write was a no-op")
        cd.close()
    }

    t.section("Command-queue input-before-control priority (BC-1.06.009)")
    let q = CommandQueue()
    q.enqueue([0x01], priority: .control)
    q.enqueue([0x02], priority: .input)
    t.expectEqual(q.take(), [0x02], "input drains before control")
    t.expectEqual(q.take(), [0x01], "then the control message")
    q.close()
    t.expect(q.take() == nil, "closed empty queue → nil")
}
