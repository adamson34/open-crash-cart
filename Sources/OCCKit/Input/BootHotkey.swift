import Foundation

/// A boot-time hotkey — the key (optionally with held modifiers) you tap during POST to
/// reach a server's BIOS/UEFI setup or one-time boot menu. Backend-agnostic: it carries only
/// HID usages, so the same value drives StarTech, CH9329, or any future adapter.
///
/// The tricky part of a crash cart is *timing*: the window to catch the POST hotkey is short
/// and video often isn't up yet. The UI pairs this model with a repeat-tap ("hammer") loop so
/// you can fire a chosen key on a steady cadence and reliably land inside that window.
public struct BootHotkey: Equatable, Sendable {
    /// Human label shown in menus and the status bar (e.g. "Del", "F12", "Ctrl+Alt+F1").
    public let label: String
    /// HID modifier usages held down around the key press (e.g. 0xE0 LCtrl, 0xE2 LAlt).
    public let modifiers: [UInt8]
    /// HID key usage tapped (press then release) with the modifiers held.
    public let usage: UInt8

    public init(label: String, modifiers: [UInt8] = [], usage: UInt8) {
        self.label = label
        self.modifiers = modifiers
        self.usage = usage
    }

    /// The common BIOS/UEFI/boot-menu hotkeys, in the order shown in the UI. Del/F2/F12 cover
    /// the overwhelming majority of servers and PCs; the rest catch the long tail.
    public static let presets: [BootHotkey] = [
        BootHotkey(label: "Del",   usage: 0x4C),  // Delete Forward — most desktop/server BIOS
        BootHotkey(label: "F2",    usage: 0x3B),  // Dell, ASUS, Lenovo setup
        BootHotkey(label: "F12",   usage: 0x45),  // one-time boot menu (Dell, Lenovo, …)
        BootHotkey(label: "F10",   usage: 0x43),  // HP setup / boot menu
        BootHotkey(label: "F11",   usage: 0x44),  // boot menu (some ASUS/MSI)
        BootHotkey(label: "F1",    usage: 0x3A),  // older IBM/Lenovo setup
        BootHotkey(label: "F8",    usage: 0x41),  // boot menu (Asus) / recovery
        BootHotkey(label: "Esc",   usage: 0x29),  // HP/Toshiba menus
        BootHotkey(label: "Enter", usage: 0x28),  // Lenovo interrupt-menu confirm
    ]

    /// Look a preset up by label (case-insensitive), for building menus from a short list.
    public static func preset(_ label: String) -> BootHotkey? {
        presets.first { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    /// Parse a user-typed combo like "F12", "Del", "Ctrl+Alt+F1", "Shift+F10", or a single
    /// letter/digit. Tokens are split on `+`, `-`, or whitespace; the last token is the key and
    /// any leading tokens are modifiers. Returns nil if the key token is unrecognized.
    ///
    /// The `label` is normalized (e.g. "ctrl + alt+f1" → "Ctrl+Alt+F1") so menus and the status
    /// bar read consistently regardless of how the user typed it.
    public static func parse(_ input: String) -> BootHotkey? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let tokens = raw
            .split(whereSeparator: { $0 == "+" || $0 == "-" || $0 == " " || $0 == "\t" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let keyToken = tokens.last, let usage = keyUsage(keyToken) else { return nil }

        var modifiers: [UInt8] = []
        var modLabels: [String] = []
        for token in tokens.dropLast() {
            guard let (usage, label) = modifier(token) else { return nil }
            if !modifiers.contains(usage) { modifiers.append(usage); modLabels.append(label) }
        }
        let label = (modLabels + [keyLabel(keyToken)]).joined(separator: "+")
        return BootHotkey(label: label, modifiers: modifiers, usage: usage)
    }

    // MARK: - Token tables

    /// HID modifier usage + canonical label for a modifier token.
    private static func modifier(_ token: String) -> (UInt8, String)? {
        switch token.lowercased() {
        case "ctrl", "control", "ctl":                 return (0xE0, "Ctrl")
        case "shift":                                  return (0xE1, "Shift")
        case "alt", "opt", "option":                   return (0xE2, "Alt")
        case "win", "cmd", "gui", "meta", "super":     return (0xE3, "Win")
        default:                                       return nil
        }
    }

    /// HID key usage for a key token (function keys, named keys, letters, digits).
    private static func keyUsage(_ token: String) -> UInt8? {
        let lower = token.lowercased()
        if let named = namedKeys[lower] { return named }
        // F1–F12 are contiguous HID usages 0x3A…0x45.
        if lower.first == "f", let n = Int(lower.dropFirst()), (1...12).contains(n) {
            return UInt8(0x3A + n - 1)
        }
        // Single letter a–z → 0x04..0x1D
        if lower.count == 1, let c = lower.unicodeScalars.first, ("a"..."z").contains(Character(c)) {
            return UInt8(0x04 + Int(c.value - Unicode.Scalar("a").value))
        }
        // Single digit 1–9 → 0x1E..0x26, 0 → 0x27
        if lower.count == 1, let c = lower.unicodeScalars.first, ("0"..."9").contains(Character(c)) {
            return c == "0" ? 0x27 : UInt8(0x1E + Int(c.value - Unicode.Scalar("1").value))
        }
        return nil
    }

    private static let namedKeys: [String: UInt8] = [
        "del": 0x4C, "delete": 0x4C, "esc": 0x29, "escape": 0x29,
        "enter": 0x28, "return": 0x28, "tab": 0x2B, "space": 0x2C,
    ]

    /// Canonical display label for a key token.
    private static func keyLabel(_ token: String) -> String {
        let lower = token.lowercased()
        switch lower {
        case "del", "delete":   return "Del"
        case "esc", "escape":   return "Esc"
        case "enter", "return": return "Enter"
        case "tab":             return "Tab"
        case "space":           return "Space"
        default:
            if lower.first == "f", Int(lower.dropFirst()) != nil { return lower.uppercased() }  // F12
            return token.uppercased()
        }
    }
}
