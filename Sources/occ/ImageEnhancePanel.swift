import AppKit

/// Floating panel of client-side image filters (brightness/contrast/sharpen/grayscale).
/// Live: changes re-render the current frame immediately.
final class ImageEnhancePanel: NSPanel {
    private let onChange: (ImageEnhancement) -> Void

    private let brightness = NSSlider(value: 0, minValue: -50, maxValue: 50, target: nil, action: nil)
    private let contrast = NSSlider(value: 100, minValue: 50, maxValue: 200, target: nil, action: nil)
    private let sharpness = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let grayscale = NSButton(checkboxWithTitle: "Grayscale", target: nil, action: nil)

    init(onChange: @escaping (ImageEnhancement) -> Void) {
        self.onChange = onChange
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                   styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Image Enhancement"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        build()
    }

    private func row(_ label: String, _ slider: NSSlider) -> NSStackView {
        let name = NSTextField(labelWithString: label)
        name.font = .systemFont(ofSize: 11, weight: .medium)
        name.textColor = Theme.shared.textPrimary
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 78).isActive = true
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(changed)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        let s = NSStackView(views: [name, slider])
        s.orientation = .horizontal; s.alignment = .centerY; s.spacing = 8
        return s
    }

    private func build() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1).cgColor

        grayscale.target = self
        grayscale.action = #selector(changed)
        grayscale.contentTintColor = Theme.shared.textPrimary

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetTapped))

        let rows = NSStackView(views: [
            row("Brightness", brightness),
            row("Contrast", contrast),
            row("Sharpness", sharpness),
            grayscale,
            reset,
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        rows.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        rows.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: container.topAnchor),
            rows.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rows.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(rows.fittingSize)
    }

    private func current() -> ImageEnhancement {
        ImageEnhancement(
            brightness: brightness.doubleValue / 100.0,
            contrast: contrast.doubleValue / 100.0,
            sharpness: sharpness.doubleValue / 100.0,
            grayscale: grayscale.state == .on)
    }

    @objc private func changed() { onChange(current()) }

    @objc private func resetTapped() {
        brightness.doubleValue = 0
        contrast.doubleValue = 100
        sharpness.doubleValue = 0
        grayscale.state = .off
        onChange(ImageEnhancement())
    }

    func present(relativeTo anchor: NSWindow) {
        if !isVisible {
            let a = anchor.frame
            setFrameTopLeftPoint(NSPoint(x: a.maxX + 12, y: a.maxY - 40))
        }
        orderFront(nil)
    }
}
