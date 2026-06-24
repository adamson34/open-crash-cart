import Foundation

/// The StarTech / Digital Multitools "VSP" wire protocol, translated verbatim from the
/// original app's `vsproto.py` (decompiled from the vendor app, clean-room reference only). Each message is one
/// ASCII command byte followed by a struct-packed payload. See docs/PROTOCOL.md.
public enum VSProtocol {

    // USB interface + bulk endpoint addresses (interface 0).
    public static let interfaceNumber: UInt8 = 0
    public enum Endpoint {
        public static let videoIn: UInt8   = 0x82  // bulk IN  — video frame stream
        public static let streamIn: UInt8  = 0x83  // bulk IN  — command responses / status
        public static let streamOut: UInt8 = 0x04  // bulk OUT — commands
        public static let dataIn: UInt8    = 0x85  // bulk IN  — virtual-disk data
        public static let dataOut: UInt8   = 0x05  // bulk OUT — virtual-disk data
    }

    // Host → device commands (ASCII).
    public enum Command: UInt8 {
        case getStatus      = 0x73 // 's'
        case fpgaData       = 0x66 // 'f'
        case firmware       = 0x77 // 'w'
        case firmware2      = 0x78 // 'x'
        case keyEvent       = 0x6B // 'k'
        case mouseEvent     = 0x6D // 'm'
        case hotplug        = 0x68 // 'h'
        case autophase      = 0x70 // 'p'
        case getVersions    = 0x76 // 'v'
        case startVStream   = 0x67 // 'g'
        case setMisc        = 0x79 // 'y'
        case defaultMisc    = 0x7A // 'z'
        case saveMisc       = 0x75 // 'u'
        case doIFrame       = 0x69 // 'i'
        case vmodeGet       = 0x6A // 'j'
        case setDDC         = 0x64 // 'd'
        case selftest       = 0x74 // 't'
        case videoReset     = 0x72 // 'r'
        case linuxMode      = 0x6C // 'l'
        case ftConnect      = 0x63 // 'c'
        case ftDisconnect   = 0x65 // 'e'
        case reboot         = 0x6E // 'n'
        case burnFuse       = 0x6F // 'o'
        case channelSelect  = 0x62 // 'b'
        case forceRelease   = 0x71 // 'q'
    }

    // Device → host responses (ASCII), keyed by first byte.
    public enum Response: UInt8 {
        case status         = 0x53 // 'S'
        case fpgaGood       = 0x46 // 'F'
        case fpgaBad        = 0x58 // 'X'
        case firmwareFail   = 0x57 // 'W'
        case autophaseDone  = 0x50 // 'P'
        case debug          = 0x44 // 'D'
        case versions       = 0x56 // 'V'
        case vmodeDetails   = 0x49 // 'I'
        case selftestDone   = 0x54 // 'T'
        case ftRead         = 0x41 // 'A'
        case ftWrite        = 0x42 // 'B'
        case ftMediaRemove  = 0x52 // 'R'
        case ftStartStop    = 0x47 // 'G'
        case channelSet     = 0x43 // 'C'
        case heartbeat      = 0x48 // 'H'
    }

    // Misc tuning value indices (subset; see vsproto MISC_*).
    public enum Misc {
        public static let phase        = 0
        public static let posX         = 1
        public static let posY         = 2
        public static let countCC1     = 9
        public static let countCC2     = 15
    }

    // FPGA bitstream block size for gen-1 (single-port). Reduced on full-speed links.
    public static let fpgaBlockSize = 507
}

/// Helpers for the original Python `struct` packings used by the protocol, big-endian.
public enum VSPack {
    /// `k` keyboard event: `>4B` = usage, modifiers, down, allUp.
    public static func keyEvent(_ e: HIDKeyEvent) -> [UInt8] {
        [VSProtocol.Command.keyEvent.rawValue,
         e.usage, e.modifiers, e.isDown ? 1 : 0, e.allReleased ? 1 : 0]
    }

    /// `m` mouse event: `>BB3h` = absMode, buttons, x, y, dz (big-endian Int16).
    public static func mouseEvent(_ e: MouseEvent) -> [UInt8] {
        var out: [UInt8] = [VSProtocol.Command.mouseEvent.rawValue,
                            e.isAbsolute ? 1 : 0, e.buttons.rawValue]
        out += be16(e.x); out += be16(e.y); out += be16(e.wheel)
        return out
    }

    /// A bare command with no payload.
    public static func command(_ c: VSProtocol.Command) -> [UInt8] { [c.rawValue] }

    static func be16(_ v: Int16) -> [UInt8] {
        let u = UInt16(bitPattern: v)
        return [UInt8(u >> 8), UInt8(u & 0xFF)]
    }
}
