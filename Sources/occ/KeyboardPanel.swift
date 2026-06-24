import AppKit

/// One key on the on-screen keyboard.
private struct VKey {
    let label: String
    let usage: UInt8
    let width: CGFloat   // in key units
    let modifier: Bool
    init(_ label: String, _ usage: UInt8, width: CGFloat = 1, modifier: Bool = false) {
        self.label = label; self.usage = usage; self.width = width; self.modifier = modifier
    }
}

/// A themed key: dark rounded cap, light text, hover highlight, and an orange "armed"
/// state for sticky modifiers.
private final class VKButton: NSButton {
    let key: VKey
    private var hovering = false
    private(set) var armed = false

    init(key: VKey, target: AnyObject, action: Selector) {
        self.key = key
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        (cell as? NSButtonCell)?.highlightsBy = []
        font = .systemFont(ofSize: key.label.count > 2 ? 10 : 13)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    func setArmed(_ value: Bool) { armed = value; refresh() }

    private func refresh() {
        let t = Theme.shared
        let textColor: NSColor
        if armed {
            layer?.backgroundColor = t.accentOrange.cgColor
            layer?.borderColor = t.accentOrange.cgColor
            textColor = NSColor(calibratedWhite: 0.06, alpha: 1)
        } else {
            layer?.backgroundColor = NSColor(calibratedWhite: hovering ? 0.26 : 0.17, alpha: 1).cgColor
            layer?.borderColor = NSColor(calibratedWhite: 0.30, alpha: 1).cgColor
            textColor = t.textPrimary
        }
        attributedTitle = NSAttributedString(string: key.label, attributes: [
            .foregroundColor: textColor,
            .font: font as Any,
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; refresh() }
    override func mouseExited(with event: NSEvent) { hovering = false; refresh() }
}

/// A floating, non-activating on-screen keyboard. Modifier keys are sticky: click Ctrl
/// then C to send Ctrl-C; click ⊞ Win to send the Windows key the Mac would otherwise eat.
/// The main window keeps keyboard focus, so the physical keyboard still drives the target.
final class KeyboardPanel: NSPanel {
    private let onChord: ([UInt8], UInt8) -> Void
    private var armed = Set<UInt8>()
    private var modifierButtons: [VKButton] = []

    private static let unit: CGFloat = 38
    private static let gap: CGFloat = 5
    private static let keyHeight: CGFloat = 32

    init(onChord: @escaping ([UInt8], UInt8) -> Void) {
        self.onChord = onChord
        super.init(contentRect: NSRect(x: 0, y: 0, width: 640, height: 260),
                   styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "On-Screen Keyboard"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        buildContent()
    }

    private let rows: [[VKey]] = [
        [VKey("esc", 0x29), VKey("F1",0x3A),VKey("F2",0x3B),VKey("F3",0x3C),VKey("F4",0x3D),
         VKey("F5",0x3E),VKey("F6",0x3F),VKey("F7",0x40),VKey("F8",0x41),
         VKey("F9",0x42),VKey("F10",0x43),VKey("F11",0x44),VKey("F12",0x45)],
        [VKey("`",0x35),VKey("1",0x1E),VKey("2",0x1F),VKey("3",0x20),VKey("4",0x21),VKey("5",0x22),
         VKey("6",0x23),VKey("7",0x24),VKey("8",0x25),VKey("9",0x26),VKey("0",0x27),
         VKey("-",0x2D),VKey("=",0x2E),VKey("⌫",0x2A, width: 1.5)],
        [VKey("⇥",0x2B, width: 1.5),VKey("Q",0x14),VKey("W",0x1A),VKey("E",0x08),VKey("R",0x15),VKey("T",0x17),
         VKey("Y",0x1C),VKey("U",0x18),VKey("I",0x0C),VKey("O",0x12),VKey("P",0x13),
         VKey("[",0x2F),VKey("]",0x30),VKey("\\",0x31)],
        [VKey("caps",0x39, width: 1.75),VKey("A",0x04),VKey("S",0x16),VKey("D",0x07),VKey("F",0x09),VKey("G",0x0A),
         VKey("H",0x0B),VKey("J",0x0D),VKey("K",0x0E),VKey("L",0x0F),VKey(";",0x33),VKey("'",0x34),
         VKey("⏎",0x28, width: 2.0)],
        [VKey("⇧",0xE1, width: 2.25, modifier: true),VKey("Z",0x1D),VKey("X",0x1B),VKey("C",0x06),VKey("V",0x19),
         VKey("B",0x05),VKey("N",0x11),VKey("M",0x10),VKey(",",0x36),VKey(".",0x37),VKey("/",0x38),
         VKey("⇧",0xE5, width: 2.25, modifier: true)],
        [VKey("ctrl",0xE0, width: 1.5, modifier: true),VKey("⊞ win",0xE3, width: 1.5, modifier: true),
         VKey("alt",0xE2, width: 1.5, modifier: true),VKey("space",0x2C, width: 5),
         VKey("alt",0xE6, width: 1.5, modifier: true),VKey("ctrl",0xE4, width: 1.5, modifier: true)],
        [VKey("ins",0x49),VKey("del",0x4C),VKey("home",0x4A),VKey("end",0x4D),
         VKey("pgup",0x4B),VKey("pgdn",0x4E),VKey("←",0x50),VKey("↓",0x51),VKey("↑",0x52),VKey("→",0x4F)],
    ]

    private func buildContent() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1).cgColor

        let vstack = NSStackView()
        vstack.orientation = .vertical
        vstack.spacing = Self.gap
        vstack.alignment = .leading
        vstack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        vstack.translatesAutoresizingMaskIntoConstraints = false

        for row in rows {
            let h = NSStackView()
            h.orientation = .horizontal
            h.spacing = Self.gap
            for key in row {
                let b = VKButton(key: key, target: self, action: #selector(keyTapped(_:)))
                b.translatesAutoresizingMaskIntoConstraints = false
                b.widthAnchor.constraint(equalToConstant: key.width * Self.unit + (key.width - 1) * Self.gap).isActive = true
                b.heightAnchor.constraint(equalToConstant: Self.keyHeight).isActive = true
                if key.modifier { modifierButtons.append(b) }
                h.addArrangedSubview(b)
            }
            vstack.addArrangedSubview(h)
        }

        container.addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: container.topAnchor),
            vstack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vstack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vstack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(vstack.fittingSize)
    }

    @objc private func keyTapped(_ sender: VKButton) {
        let key = sender.key
        if key.modifier {
            sender.setArmed(!sender.armed)
            if sender.armed { armed.insert(key.usage) } else { armed.remove(key.usage) }
            return
        }
        onChord(Array(armed), key.usage)
        armed.removeAll()
        modifierButtons.forEach { $0.setArmed(false) }
    }

    /// Show anchored just below a reference window the first time.
    func present(relativeTo anchor: NSWindow) {
        if !isVisible {
            let a = anchor.frame
            setFrameTopLeftPoint(NSPoint(x: a.minX, y: a.minY - 8))
        }
        orderFront(nil)
    }
}
