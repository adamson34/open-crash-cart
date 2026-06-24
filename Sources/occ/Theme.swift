import AppKit

/// Central place for colors and the adjustable padding. Changing `padding` re-lays-out the
/// whole window via `onChange`. Persisted in UserDefaults; overridable with OCC_PADDING.
@MainActor
final class Theme {
    static let shared = Theme()

    private let key = "OpenCrashCartPadding"
    var onChange: (() -> Void)?

    var padding: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(padding), forKey: key)
            onChange?()
        }
    }

    // Highlighter accents — used sparingly on a neutral grey/black base for a clean,
    // professional dark UI.
    let accentOrange = NSColor(srgbRed: 1.00, green: 0.55, blue: 0.13, alpha: 1)   // #FF8C21
    let accentGreen  = NSColor(srgbRed: 0.24, green: 0.89, blue: 0.52, alpha: 1)   // #3DE385
    let accentPink   = NSColor(srgbRed: 1.00, green: 0.32, blue: 0.67, alpha: 1)   // #FF52AB
    var accent: NSColor { accentOrange }

    // Neutral base.
    let windowBG     = NSColor(calibratedWhite: 0.07, alpha: 1)
    let barBG        = NSColor(calibratedWhite: 0.12, alpha: 1)
    let screenBG     = NSColor.black
    let cardBorder   = NSColor(calibratedWhite: 0.20, alpha: 1)
    let textPrimary  = NSColor(calibratedWhite: 0.94, alpha: 1)
    let textSecondary = NSColor(calibratedWhite: 0.55, alpha: 1)

    let toolbarHeight: CGFloat = 44
    let statusHeight: CGFloat = 28
    let cornerRadius: CGFloat = 10

    private init() {
        let env = ProcessInfo.processInfo.environment["OCC_PADDING"].flatMap { Double($0) }
        if let env {
            padding = CGFloat(env)
        } else if UserDefaults.standard.object(forKey: key) != nil {
            // Clamp a previously-saved value to a sane range so a stale setting can't
            // leave the layout looking off.
            padding = CGFloat(min(max(UserDefaults.standard.double(forKey: key), 0), 40))
        } else {
            padding = 14
        }
    }

    func adjust(by delta: CGFloat) {
        padding = max(0, min(96, padding + delta))
    }

    func reset() { padding = 14 }
}
