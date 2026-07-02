import Foundation
import OCCKit

/// Minimal CrashCartAdapter that records the key events sent to it, so the protocol's default
/// helpers (sendKeyPress / sendCtrlAltDel) can be verified.
final class RecordingAdapter: CrashCartAdapter, @unchecked Sendable {
    static let model = AdapterModel(id: "mock", name: "Mock", vendorID: 0, productIDs: [])
    static func canDrive(_ device: DiscoveredDevice) -> Bool { false }
    private(set) var keys: [HIDKeyEvent] = []
    func connect() async throws -> AsyncStream<AdapterEvent> { AsyncStream { $0.finish() } }
    func send(key: HIDKeyEvent) { keys.append(key) }
    func send(mouse: MouseEvent) {}
    func disconnect() async {}
}

func runCoverageGapTests(_ t: Harness) {
    t.section("CH9329 report frames (BC-1.05.011/012/013)")
    t.expectEqual(ch9329KeyboardFrame(modifier: 0, keys: []),
                  [0x57, 0xAB, 0x00, 0x02, 0x08, 0, 0, 0, 0, 0, 0, 0, 0, 0x0C],
                  "empty keyboard report frame (checksum 0x0C)")
    let kf = ch9329KeyboardFrame(modifier: 0x01, keys: [0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A])
    t.expectEqual(Array(kf[5..<13]), [0x01, 0x00, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
                  "modifier + first 6 keys (7th dropped)")
    let am = ch9329AbsoluteMouseFrame(buttons: 0, x: 960, y: 540, wheel: 0, width: 1920, height: 1080)
    t.expectEqual(Array(am[5..<12]), [0x02, 0x00, 0x00, 0x08, 0x00, 0x08, 0x00],
                  "abs mouse center scales to 2048/2048 (0x0800)")
    let rm = ch9329RelativeMouseFrame(buttons: 0, dx: -1, dy: 2, wheel: -3)
    t.expectEqual(Array(rm[5..<10]), [0x01, 0x00, 0xFF, 0x02, 0xFD], "rel mouse signed bytes")

    t.section("HID type-text key events (BC-1.01.039 / paste)")
    let evA = HIDTyping.keyEvents(for: "A")
    t.expectEqual(evA.count, 4, "'A' → 4 events (shift-wrapped)")
    t.expect(evA[0].usage == 0xE1 && evA[0].isDown, "shift down first")
    t.expect(evA[1].usage == 0x04 && evA[1].isDown, "letter A down")
    t.expect(evA[3].usage == 0xE1 && !evA[3].isDown && evA[3].allReleased, "shift up last, allReleased")
    let eva = HIDTyping.keyEvents(for: "a")
    t.expectEqual(eva.count, 2, "'a' → 2 events (no shift)")
    t.expect(eva[1].allReleased, "lowercase release sets allReleased")

    t.section("CrashCartAdapter default key helpers")
    let cad = RecordingAdapter()
    cad.sendCtrlAltDel()
    t.expectEqual(cad.keys.count, 6, "Ctrl-Alt-Del = 6 events")
    t.expect(cad.keys[0].usage == 0xE0 && cad.keys[0].isDown, "1: LeftCtrl down")
    t.expect(cad.keys[1].usage == 0xE2 && cad.keys[1].isDown, "2: LeftAlt down")
    t.expect(cad.keys[2].usage == 0x4C && cad.keys[2].isDown, "3: Delete down")
    t.expect(cad.keys[3].usage == 0x4C && !cad.keys[3].isDown, "4: Delete up")
    t.expect(cad.keys[5].usage == 0xE0 && !cad.keys[5].isDown && cad.keys[5].allReleased,
             "6: LeftCtrl up, allReleased")
    let kp = RecordingAdapter()
    kp.sendKeyPress(usage: 0x29)
    t.expectEqual(kp.keys.count, 2, "key press = down + up")
    t.expect(kp.keys[0].usage == 0x29 && kp.keys[0].isDown, "press down")
    t.expect(kp.keys[1].usage == 0x29 && !kp.keys[1].isDown && kp.keys[1].allReleased, "release, allReleased")

    t.section("PlaceholderVideoDecoder")
    let p = PlaceholderVideoDecoder()
    p.setActiveSize(width: 800, height: 600)
    t.expect(p.ingest([1, 2, 3, 4]) == nil, "placeholder never returns a frame")
    t.expectEqual(p.bytesIngested, 4, "tracks bytes ingested")
    t.expectEqual(p.chunksIngested, 1, "tracks chunks ingested")
    t.expect(!p.needsKeyframe, "placeholder never requests a keyframe")
    p.reset()
    t.expectEqual(p.bytesIngested, 0, "reset clears counters")
}
