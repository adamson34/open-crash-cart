import AppKit
import OCCKit

/// Bottom status strip: connection state on the left; keyboard type, lock-LED indicators,
/// and bandwidth/fps on the right — mirroring the original's status readout.
final class StatusBar: NSView {
    private let stateLabel = NSTextField(labelWithString: "No device")
    private let mediaLabel = NSTextField(labelWithString: "")
    private let recLabel = NSTextField(labelWithString: "")
    private let kbdLabel = NSTextField(labelWithString: "")
    private let caps = LED("CAPS")
    private let num = LED("NUM")
    private let scrl = LED("SCRL")
    private let rateLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Theme.shared.barBG.cgColor
        build()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    private func style(_ tf: NSTextField, _ size: CGFloat = 11) {
        tf.font = .monospacedDigitSystemFont(ofSize: size, weight: .medium)
        tf.textColor = NSColor(white: 0.75, alpha: 1)
    }

    private func build() {
        [stateLabel, kbdLabel, rateLabel].forEach { style($0) }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        recLabel.font = .systemFont(ofSize: 10, weight: .bold)
        recLabel.textColor = Theme.shared.accentPink
        mediaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        mediaLabel.textColor = Theme.shared.accentOrange

        let stack = NSStackView(views: [stateLabel, recLabel, spacer, mediaLabel, kbdLabel, caps, num, scrl, rateLabel])
        stack.orientation = .horizontal
        stack.spacing = 16
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 18, bottom: 4, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func setMedia(_ name: String?) {
        mediaLabel.stringValue = name.map { "💿 \($0)" } ?? ""
    }

    func setRecording(_ on: Bool) {
        recLabel.stringValue = on ? "● REC" : ""
    }

    func setMessage(_ text: String) {
        stateLabel.stringValue = text
        stateLabel.textColor = Theme.shared.textSecondary
        kbdLabel.stringValue = ""
        rateLabel.stringValue = ""
        caps.on = false; num.on = false; scrl.on = false
    }

    func update(_ s: AdapterStatus) {
        let theme = Theme.shared
        switch s.state {
        case .disconnected:
            stateLabel.stringValue = "Disconnected"; stateLabel.textColor = theme.textSecondary
        case .connecting:
            stateLabel.stringValue = "Connecting…"; stateLabel.textColor = theme.accentOrange
        case .noVideo(let r):
            stateLabel.stringValue = "No video — \(r)"; stateLabel.textColor = theme.accentPink
        case .live(let w, let h, let hz):
            stateLabel.stringValue = "● \(w) × \(h) @ \(hz) Hz"; stateLabel.textColor = theme.accentGreen
        }
        kbdLabel.stringValue = s.keyboardOK ? s.keyboardType.name.uppercased() : "no kbd"
        kbdLabel.textColor = s.keyboardOK ? theme.accentGreen : theme.textSecondary
        caps.on = s.leds.contains(.caps)
        num.on  = s.leds.contains(.num)
        scrl.on = s.leds.contains(.scroll)
        // Bandwidth occasionally spikes to absurd values from a tiny ticks divisor in the
        // device status; ignore those for a stable readout.
        let mbps = s.bytesPerSecond / 1_000_000
        let rate = (mbps.isFinite && mbps >= 0 && mbps < 100) ? String(format: "%4.1f MB/s", mbps) : "—"
        rateLabel.stringValue = s.fps > 0 ? String(format: "%2d fps   %@", s.fps, rate) : ""
    }

    /// A small lock-LED pill that brightens when active.
    final class LED: NSTextField {
        var on: Bool = false { didSet { textColor = on ? Theme.shared.accentGreen : NSColor(white: 0.32, alpha: 1) } }
        init(_ label: String) {
            super.init(frame: .zero)
            stringValue = label
            isEditable = false; isBordered = false; isSelectable = false
            drawsBackground = false
            font = .systemFont(ofSize: 10, weight: .bold)
            textColor = NSColor(white: 0.35, alpha: 1)
        }
        required init?(coder: NSCoder) { fatalError("not used") }
    }
}

private extension KeyboardEmulation {
    // Exhaustive switch — the compiler forces a case for every emulation type, so a future
    // addition can't trap an array index (was `["usb","ps2","sun"][Int(rawValue)]`).
    var name: String {
        switch self {
        case .usb: return "usb"
        case .ps2: return "ps2"
        case .sun: return "sun"
        }
    }
}
