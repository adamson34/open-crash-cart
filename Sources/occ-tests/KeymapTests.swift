import OCCKit

func runKeymapTests(_ t: Harness) {
    t.section("HID keymap (macOS → USB HID)")

    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0x00) == 0x04, "macOS 'A' (kc 0x00) → HID 0x04")
    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0x24) == 0x28, "Return → 0x28")
    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0x7E) == 0x52, "Up arrow → 0x52")
    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0x38) == 0xE1, "Left Shift → 0xE1")
    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0x37) == nil, "Command is NOT mapped (never forwarded)")
    t.expect(HIDKeymap.hidUsage(forMacKeyCode: 0xFFFF) == nil, "unknown key → nil")

    t.expect(HIDKeymap.isModifier(0xE1), "0xE1 (Left Shift) is a modifier")
    t.expect(HIDKeymap.isModifier(0xE7), "0xE7 (Right GUI) is a modifier")
    t.expect(!HIDKeymap.isModifier(0x04), "0x04 (A) is not a modifier")
}
