import OCCKit

func runTypingTests(_ t: Harness) {
    t.section("HID typing (paste/type text)")

    // Encode each stroke as usage*2 + shiftBit so arrays of tuples become comparable.
    func enc(_ s: String) -> [Int] {
        HIDTyping.strokes(for: s).map { Int($0.usage) * 2 + ($0.shift ? 1 : 0) }
    }

    t.expectEqual(enc("a"), [0x04 * 2], "'a' → 0x04, no shift")
    t.expectEqual(enc("A"), [0x04 * 2 + 1], "'A' → 0x04, shift")
    t.expectEqual(enc("1"), [0x1E * 2], "'1' → 0x1E, no shift")
    t.expectEqual(enc("!"), [0x1E * 2 + 1], "'!' → 0x1E, shift")
    t.expectEqual(enc(" "), [0x2C * 2], "space → 0x2C")
    t.expectEqual(enc("\n"), [0x28 * 2], "newline → Enter 0x28")
    // "Hi!" → H(0x0B+shift), i(0x0C), !(0x1E+shift)
    t.expectEqual(enc("Hi!"), [0x0B * 2 + 1, 0x0C * 2, 0x1E * 2 + 1], "'Hi!' full sequence")
    t.expectEqual(HIDTyping.strokes(for: "é€").count, 0, "unmapped characters are skipped")
}
