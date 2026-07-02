import AppKit

/// A banner overlaid on the video area while a boot-key hammer is running. It states the key
/// being tapped, a live countdown, and — the important bit — exactly how to stop it, so the
/// user isn't left guessing while keys fire at the target.
final class HammerHUD: NSView {
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "Stops on any keypress, a click, or after 30s")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 0.94).cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = Theme.shared.accentPink.withAlphaComponent(0.9).cgColor
        isHidden = true

        let dot = NSImageView()
        dot.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
        dot.contentTintColor = Theme.shared.accentPink

        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = Theme.shared.accentPink
        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = Theme.shared.textSecondary

        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let row = NSStackView(views: [dot, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Show the banner for a hotkey with the initial time remaining.
    func show(hotkey label: String, secondsLeft: Int) {
        title.stringValue = "Hammering \(label) · \(secondsLeft)s"
        isHidden = false
    }

    /// Update the countdown while hammering.
    func update(secondsLeft: Int, hotkey label: String) {
        title.stringValue = "Hammering \(label) · \(secondsLeft)s"
    }

    func hide() { isHidden = true }
}
