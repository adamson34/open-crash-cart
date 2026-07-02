import OCCKit

func runBootHotkeyTests(_ t: Harness) {
    t.section("Boot-menu hotkeys")

    // Presets carry the right HID usages and cover the common trio.
    t.expectEqual(BootHotkey.preset("Del")?.usage, 0x4C, "Del → 0x4C")
    t.expectEqual(BootHotkey.preset("F2")?.usage, 0x3B, "F2 → 0x3B")
    t.expectEqual(BootHotkey.preset("F12")?.usage, 0x45, "F12 → 0x45")
    t.expectEqual(BootHotkey.preset("Esc")?.usage, 0x29, "Esc → 0x29")
    t.expect(BootHotkey.preset("del") != nil, "preset lookup is case-insensitive")
    t.expect(BootHotkey.preset("PrtSc") == nil, "unknown preset → nil")
    t.expect(BootHotkey.presets.allSatisfy { $0.modifiers.isEmpty }, "presets are unmodified single keys")

    // Parsing single keys.
    t.expectEqual(BootHotkey.parse("F12")?.usage, 0x45, "parse F12 usage")
    t.expectEqual(BootHotkey.parse("f12")?.label, "F12", "parse normalizes F12 label")
    t.expectEqual(BootHotkey.parse("Del")?.usage, 0x4C, "parse Del usage")
    t.expectEqual(BootHotkey.parse("delete")?.label, "Del", "parse 'delete' → Del label")
    t.expectEqual(BootHotkey.parse("a")?.usage, 0x04, "parse letter 'a' → 0x04")
    t.expectEqual(BootHotkey.parse("1")?.usage, 0x1E, "parse digit '1' → 0x1E")
    t.expectEqual(BootHotkey.parse("0")?.usage, 0x27, "parse digit '0' → 0x27")

    // Parsing modifier combos: order preserved, correct HID modifier usages.
    let cad = BootHotkey.parse("Ctrl+Alt+Del")
    t.expectEqual(cad?.usage, 0x4C, "Ctrl+Alt+Del key usage")
    t.expectEqual(cad?.modifiers ?? [], [0xE0, 0xE2], "Ctrl+Alt+Del modifiers [LCtrl, LAlt]")
    t.expectEqual(cad?.label, "Ctrl+Alt+Del", "Ctrl+Alt+Del canonical label")

    let shiftF10 = BootHotkey.parse("shift-f10")
    t.expectEqual(shiftF10?.modifiers ?? [], [0xE1], "shift-f10 modifier [LShift]")
    t.expectEqual(shiftF10?.usage, 0x43, "shift-f10 usage 0x43")
    t.expectEqual(shiftF10?.label, "Shift+F10", "shift-f10 normalized label")

    // Modifier aliases + separators (spaces) + dedupe.
    t.expectEqual(BootHotkey.parse("option esc")?.modifiers ?? [], [0xE2], "'option' alias → LAlt")
    t.expectEqual(BootHotkey.parse("win f2")?.modifiers ?? [], [0xE3], "'win' alias → LGUI")
    t.expectEqual(BootHotkey.parse("Ctrl+Ctrl+F1")?.modifiers ?? [], [0xE0], "duplicate modifier deduped")

    // Invalid input.
    t.expect(BootHotkey.parse("") == nil, "empty string → nil")
    t.expect(BootHotkey.parse("   ") == nil, "whitespace-only → nil")
    t.expect(BootHotkey.parse("Ctrl+Splat") == nil, "unknown key token → nil")
    t.expect(BootHotkey.parse("Bogus+F1") == nil, "unknown modifier token → nil")
}
