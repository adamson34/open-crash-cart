import AppKit

@MainActor protocol ToolbarActions: AnyObject {
    func ctrlAltDel()
    func toggleKeyboard()
    func refreshScreen()
    func retuneVideo()
    func toggleVideoAdjust()
    func snapshot()
    func copyTextFromScreen()
    func mountMedia()
    func toggleRecording()
    func actualSize()
    func fitToWindow()
    func toggleFullScreen()
}

/// A small floating tooltip bubble that appears immediately on hover (unlike the slow
/// system tooltip). Shared across all toolbar buttons.
@MainActor
final class HoverTip {
    static let shared = HoverTip()
    private var panel: NSPanel?
    private let field = NSTextField(labelWithString: "")

    private init() {}

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        field.font = .systemFont(ofSize: 11, weight: .medium)
        field.textColor = .white
        field.isBezeled = false; field.isEditable = false; field.drawsBackground = false

        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.97).cgColor
        bg.layer?.cornerRadius = 6
        bg.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        bg.layer?.borderWidth = 1
        field.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 9),
            field.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -9),
            field.topAnchor.constraint(equalTo: bg.topAnchor, constant: 5),
            field.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -5),
        ])

        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.ignoresMouseEvents = true
        p.contentView = bg
        panel = p
        return p
    }

    func show(_ text: String, under view: NSView) {
        guard let host = view.window else { return }
        let panel = ensurePanel()
        field.stringValue = text
        let size = panel.contentView!.fittingSize
        let rectInWindow = view.convert(view.bounds, to: nil)
        let rectOnScreen = host.convertToScreen(rectInWindow)
        let x = rectOnScreen.midX - size.width / 2
        let y = rectOnScreen.minY - size.height - 5
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.orderFront(nil)
    }

    func hide() { panel?.orderOut(nil) }
}

/// Icon-only toolbar button with a hover highlight + immediate tooltip bubble.
final class ToolbarButton: NSButton {
    private let tip: String

    init(symbol: String, tip: String, target: AnyObject, action: Selector) {
        self.tip = tip
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .texturedRounded
        imagePosition = .imageOnly
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(config)
        contentTintColor = Theme.shared.textPrimary
        wantsLayer = true
        layer?.cornerRadius = 7
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 42).isActive = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true
        self.target = target
        self.action = action
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.10).cgColor
        contentTintColor = Theme.shared.accentPink
        HoverTip.shared.show(tip, under: self)
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
        contentTintColor = Theme.shared.textPrimary
        HoverTip.shared.hide()
    }
    override func mouseDown(with event: NSEvent) {
        HoverTip.shared.hide()
        super.mouseDown(with: event)
    }
}

/// The top button bar — clean icon-only buttons, each with a hover tooltip.
final class ToolbarStrip: NSView {
    weak var actions: ToolbarActions?

    init(actions: ToolbarActions) {
        self.actions = actions
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Theme.shared.barBG.cgColor
        build()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    private func button(_ symbol: String, _ tip: String, _ sel: Selector) -> ToolbarButton {
        ToolbarButton(symbol: symbol, tip: tip, target: self, action: sel)
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return box
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 14, bottom: 5, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(button("bolt.horizontal.circle", "Send Ctrl-Alt-Del", #selector(onCAD)))
        stack.addArrangedSubview(button("keyboard", "On-screen keyboard", #selector(onKeyboard)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(button("arrow.clockwise", "Refresh screen", #selector(onRefresh)))
        stack.addArrangedSubview(button("wand.and.stars", "Auto-tune video", #selector(onRetune)))
        stack.addArrangedSubview(button("slider.horizontal.3", "Video adjustments", #selector(onAdjust)))
        stack.addArrangedSubview(button("camera", "Save snapshot", #selector(onSnap)))
        stack.addArrangedSubview(button("text.viewfinder", "Copy text from screen (OCR)", #selector(onOCR)))
        stack.addArrangedSubview(button("opticaldisc", "Mount disk image (ISO/IMG)", #selector(onMedia)))
        stack.addArrangedSubview(button("record.circle", "Record session to video", #selector(onRecord)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(button("arrow.up.left.and.arrow.down.right", "Fit to window", #selector(onFit)))
        stack.addArrangedSubview(button("1.magnifyingglass", "Actual size (1:1)", #selector(onActual)))
        stack.addArrangedSubview(button("rectangle.inset.filled", "Full screen", #selector(onFull)))

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func onKeyboard() { actions?.toggleKeyboard() }
    @objc private func onCAD()      { actions?.ctrlAltDel() }
    @objc private func onRefresh()  { actions?.refreshScreen() }
    @objc private func onRetune()   { actions?.retuneVideo() }
    @objc private func onAdjust()   { actions?.toggleVideoAdjust() }
    @objc private func onSnap()     { actions?.snapshot() }
    @objc private func onOCR()      { actions?.copyTextFromScreen() }
    @objc private func onMedia()    { actions?.mountMedia() }
    @objc private func onRecord()   { actions?.toggleRecording() }
    @objc private func onFit()      { actions?.fitToWindow() }
    @objc private func onActual()   { actions?.actualSize() }
    @objc private func onFull()     { actions?.toggleFullScreen() }
}
