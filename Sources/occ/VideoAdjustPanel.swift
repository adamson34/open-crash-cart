import AppKit
import OCCKit

/// Floating, non-activating panel of live sliders for manual analog-video tuning. Dragging
/// a slider sends the value to the device immediately so you can tune while watching.
final class VideoAdjustPanel: NSPanel {
    struct Spec {
        let adjustment: VideoAdjustment
        let label: String
        let min: Double
        let max: Double
    }
    private static let specs: [Spec] = [
        Spec(adjustment: .sharpness,  label: "Sharpness",  min: 0,   max: 15),
        Spec(adjustment: .phase,      label: "Phase",      min: 0,   max: 31),
        Spec(adjustment: .horizontal, label: "Horizontal", min: -30, max: 30),
        Spec(adjustment: .vertical,   label: "Vertical",   min: -30, max: 30),
        Spec(adjustment: .noise,      label: "Noise",      min: 0,   max: 15),
    ]

    private let onChange: (VideoAdjustment, Int) -> Void
    private let onSave: () -> Void
    private let onReset: () -> Void
    private var sliders: [VideoAdjustment: NSSlider] = [:]
    private var valueLabels: [VideoAdjustment: NSTextField] = [:]
    private var lastSent: [VideoAdjustment: Int] = [:]

    init(onChange: @escaping (VideoAdjustment, Int) -> Void,
         onSave: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.onChange = onChange
        self.onSave = onSave
        self.onReset = onReset
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                   styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Video Adjustments"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        buildContent()
    }

    private func buildContent() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1).cgColor

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        rows.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        rows.translatesAutoresizingMaskIntoConstraints = false

        for spec in Self.specs {
            let name = NSTextField(labelWithString: spec.label)
            name.font = .systemFont(ofSize: 11, weight: .medium)
            name.textColor = Theme.shared.textPrimary
            name.translatesAutoresizingMaskIntoConstraints = false
            name.widthAnchor.constraint(equalToConstant: 78).isActive = true

            let slider = NSSlider(value: 0, minValue: spec.min, maxValue: spec.max,
                                  target: self, action: #selector(sliderChanged(_:)))
            slider.isContinuous = true
            slider.numberOfTickMarks = Int(spec.max - spec.min) + 1
            slider.allowsTickMarkValuesOnly = true
            slider.tag = Self.specs.firstIndex { $0.adjustment == spec.adjustment } ?? 0
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.widthAnchor.constraint(equalToConstant: 150).isActive = true

            let value = NSTextField(labelWithString: "0")
            value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            value.textColor = Theme.shared.accentOrange
            value.alignment = .right
            value.translatesAutoresizingMaskIntoConstraints = false
            value.widthAnchor.constraint(equalToConstant: 34).isActive = true

            sliders[spec.adjustment] = slider
            valueLabels[spec.adjustment] = value

            let row = NSStackView(views: [name, slider, value])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            rows.addArrangedSubview(row)
        }

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetTapped))
        let save = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [reset, save])
        buttons.spacing = 8
        rows.addArrangedSubview(buttons)

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

    /// Sync slider positions to the device's current values.
    func apply(_ values: [VideoAdjustment: Int]) {
        for (adj, v) in values {
            sliders[adj]?.integerValue = v
            valueLabels[adj]?.stringValue = "\(v)"
            lastSent[adj] = v
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let spec = Self.specs[sender.tag]
        let v = sender.integerValue
        valueLabels[spec.adjustment]?.stringValue = "\(v)"
        guard lastSent[spec.adjustment] != v else { return }   // only send on a real change
        lastSent[spec.adjustment] = v
        onChange(spec.adjustment, v)
    }
    @objc private func saveTapped()  { onSave() }
    @objc private func resetTapped() { onReset() }

    func present(relativeTo anchor: NSWindow) {
        if !isVisible {
            let a = anchor.frame
            setFrameTopLeftPoint(NSPoint(x: a.maxX + 12, y: a.maxY - 40))
        }
        orderFront(nil)
    }
}
