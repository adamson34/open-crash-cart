import OCCKit

func runInputHardeningTests(_ t: Harness) {
    t.section("Mouse coalescer preserves button transitions (C-8)")

    func move(_ x: Int16, _ y: Int16, _ b: MouseButtons = []) -> MouseEvent {
        MouseEvent(buttons: b, x: x, y: y, wheel: 0, isAbsolute: true)
    }

    do {  // consecutive same-button moves collapse to the latest
        let c = MouseCoalescer()
        c.store(move(1, 1)); c.store(move(2, 2)); c.store(move(3, 3))
        let first = c.drain()
        t.expect(first?.x == 3 && first?.y == 3, "same-button moves coalesce to the newest")
        t.expect(c.drain() == nil, "only one entry after coalescing a move run")
    }

    do {  // a press then release is NOT swallowed by a following move
        let c = MouseCoalescer()
        c.store(move(1, 1))                 // no buttons
        c.store(move(1, 1, .left))          // button DOWN — distinct state
        c.store(move(1, 1))                 // button UP — distinct state
        c.store(move(9, 9))                 // move after release → coalesces onto the release entry
        let e1 = c.drain(); let e2 = c.drain(); let e3 = c.drain()
        t.expect(e1?.buttons == [], "1st drained: buttons up (move)")
        t.expect(e2?.buttons == .left, "2nd drained: button DOWN preserved (click not dropped)")
        t.expect(e3?.buttons == [] && e3?.x == 9, "3rd drained: release + coalesced move")
        t.expect(c.drain() == nil, "queue drained")
    }

    t.section("MISC adjustment clamps per field (C-7)")

    // Signed fields (horizontal/vertical) two's-complement; unsigned (phase/noise/sharpness) 0…255.
    t.expectEqual(StarTechAdapter.miscByte(.horizontal, value: -1), 0xFF, "horizontal -1 → 0xFF (signed)")
    t.expectEqual(StarTechAdapter.miscByte(.horizontal, value: 200), 0x7F, "horizontal 200 → clamp to +127")
    t.expectEqual(StarTechAdapter.miscByte(.vertical, value: -200), 0x80, "vertical -200 → clamp to -128")
    t.expectEqual(StarTechAdapter.miscByte(.phase, value: -1), 0, "phase -1 → clamp to 0 (unsigned)")
    t.expectEqual(StarTechAdapter.miscByte(.noise, value: 300), 0xFF, "noise 300 → clamp to 255")
    t.expectEqual(StarTechAdapter.miscByte(.sharpness, value: 10), 10, "sharpness 10 → 10")
}
