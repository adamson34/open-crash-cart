import AppKit

/// The empty-state screen shown when there's no live video: prompts to connect the adapter,
/// shows a connecting state, or reports no signal detected.
final class PlaceholderView: NSView {
    enum State {
        case noAdapter        // nothing on the USB bus
        case connecting       // adapter found, handshaking
        case noSignal         // adapter connected, but no video input detected
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        build()
        set(.noAdapter)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        let theme = Theme.shared

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.heightAnchor.constraint(equalToConstant: 76).isActive = true

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = theme.textPrimary
        titleLabel.alignment = .center

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = theme.textSecondary
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2

        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.alignment = .center
        badge.textColor = theme.windowBG
        badge.wantsLayer = true
        badge.drawsBackground = false
        badge.isBezeled = false
        badge.isEditable = false

        let stack = NSStackView(views: [iconView, titleLabel, subtitleLabel, badge])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    func set(_ state: State) {
        let theme = Theme.shared
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .light)
        let symbol: String, title: String, subtitle: String, tint: NSColor, badgeText: String, badgeColor: NSColor

        switch state {
        case .noAdapter:
            symbol = "cable.connector.horizontal"
            title = "Please connect your crash cart adapter"
            subtitle = "Plug the USB crash cart adapter into this Mac to begin."
            tint = theme.textSecondary
            badgeText = "  NOT CONNECTED  "
            badgeColor = NSColor(calibratedWhite: 0.40, alpha: 1)
        case .connecting:
            symbol = "arrow.triangle.2.circlepath"
            title = "Connecting to adapter…"
            subtitle = "Initializing and uploading device firmware."
            tint = theme.accentOrange
            badgeText = "  CONNECTING  "
            badgeColor = theme.accentOrange
        case .noSignal:
            symbol = "display.trianglebadge.exclamationmark"
            title = "No video signal detected"
            subtitle = "Connect the adapter's VGA and USB to a powered-on target machine."
            tint = theme.accentPink
            badgeText = "  NO INPUT  "
            badgeColor = theme.accentPink
        }

        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = tint
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle

        badge.stringValue = badgeText
        badge.layer?.backgroundColor = badgeColor.cgColor
        badge.layer?.cornerRadius = 8
    }
}
