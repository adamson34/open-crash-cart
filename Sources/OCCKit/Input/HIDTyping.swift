import Foundation

/// Converts text into a sequence of HID key strokes (usage + whether Shift is held), for
/// "paste text / type text" into the target. US-ASCII layout; unmapped characters are skipped.
public enum HIDTyping {
    public static func strokes(for text: String) -> [(usage: UInt8, shift: Bool)] {
        text.compactMap { map[$0] }
    }

    private static let map: [Character: (UInt8, Bool)] = {
        var m: [Character: (UInt8, Bool)] = [:]

        // Letters a–z (HID 0x04–0x1D); uppercase = same usage + shift.
        for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() {
            let usage = UInt8(0x04 + i)
            m[c] = (usage, false)
            m[Character(c.uppercased())] = (usage, true)
        }

        // Number row and their shifted symbols.
        let digits: [(Character, UInt8, Character)] = [
            ("1", 0x1E, "!"), ("2", 0x1F, "@"), ("3", 0x20, "#"), ("4", 0x21, "$"),
            ("5", 0x22, "%"), ("6", 0x23, "^"), ("7", 0x24, "&"), ("8", 0x25, "*"),
            ("9", 0x26, "("), ("0", 0x27, ")"),
        ]
        for (d, u, s) in digits { m[d] = (u, false); m[s] = (u, true) }

        // Whitespace.
        m[" "]  = (0x2C, false)
        m["\n"] = (0x28, false); m["\r"] = (0x28, false)   // Enter
        m["\t"] = (0x2B, false)                            // Tab

        // Punctuation (unshifted, shifted).
        let punct: [(Character, UInt8, Character?)] = [
            ("-", 0x2D, "_"), ("=", 0x2E, "+"), ("[", 0x2F, "{"), ("]", 0x30, "}"),
            ("\\", 0x31, "|"), (";", 0x33, ":"), ("'", 0x34, "\""), ("`", 0x35, "~"),
            (",", 0x36, "<"), (".", 0x37, ">"), ("/", 0x38, "?"),
        ]
        for (c, u, s) in punct { m[c] = (u, false); if let s { m[s] = (u, true) } }
        return m
    }()
}
