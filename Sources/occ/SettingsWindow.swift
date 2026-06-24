import AppKit
import OCCKit
import UniformTypeIdentifiers

/// A button that remembers which profile it acts on.
private final class RowButton: NSButton {
    var profileID = ""
}

/// OpenCrashCart Settings: manage the firmware folder and the hardware-adapter profiles.
final class SettingsWindowController: NSWindowController {
    private let onChange: () -> Void
    private let firmwarePathLabel = NSTextField(labelWithString: "")
    private let profilesStack = NSStackView()

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "OpenCrashCart Settings"
        window.center()
        super.init(window: window)
        buildUI()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: UI

    private func sectionTitle(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = Theme.shared.textPrimary
        return l
    }
    private func caption(_ text: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = .systemFont(ofSize: 11)
        l.textColor = Theme.shared.textSecondary
        return l
    }

    private func buildUI() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = Theme.shared.windowBG.cgColor
        window?.contentView = root

        // Firmware section.
        firmwarePathLabel.font = .systemFont(ofSize: 11, weight: .medium)
        firmwarePathLabel.textColor = Theme.shared.accentGreen
        firmwarePathLabel.lineBreakMode = .byTruncatingMiddle

        let chooseBtn = NSButton(title: "Choose Folder…", target: self, action: #selector(chooseFirmwareFolder))
        let importBtn = NSButton(title: "Import Firmware…", target: self, action: #selector(importFirmware))
        let useDefaultBtn = NSButton(title: "Use Defaults", target: self, action: #selector(clearFirmwareFolder))
        let firmwareButtons = NSStackView(views: [chooseBtn, importBtn, useDefaultBtn])
        firmwareButtons.spacing = 8

        let firmwareSection = NSStackView(views: [
            sectionTitle("Firmware"),
            caption("OpenCrashCart loads your adapter's firmware (.fgz) from here. Import it from your "
                  + "vendor install once, and the vendor app is no longer needed."),
            firmwarePathLabel,
            firmwareButtons,
        ])
        firmwareSection.orientation = .vertical
        firmwareSection.alignment = .leading
        firmwareSection.spacing = 7

        // Profiles section.
        profilesStack.orientation = .vertical
        profilesStack.alignment = .leading
        profilesStack.spacing = 8

        let addBtn = NSButton(title: "Add Adapter…", target: self, action: #selector(addProfile))

        let profilesSection = NSStackView(views: [
            sectionTitle("Adapter Profiles"),
            caption("Each profile maps a USB device to a protocol + firmware. Add a profile to "
                  + "support another (often OEM-rebranded) crash-cart adapter."),
            profilesStack,
            addBtn,
        ])
        profilesSection.orientation = .vertical
        profilesSection.alignment = .leading
        profilesSection.spacing = 9

        let main = NSStackView(views: [firmwareSection, NSBox.divider(), profilesSection])
        main.orientation = .vertical
        main.alignment = .leading
        main.spacing = 16
        main.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(main)
        NSLayoutConstraint.activate([
            main.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            main.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            main.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
        ])
    }

    // MARK: Refresh

    private func refresh() {
        let store = ProfileStore.shared
        firmwarePathLabel.stringValue = store.firmwareDirectory.map { "📁  \($0)" }
            ?? "Using default locations (incl. vendor install)"

        let present = (try? enumerateUSBDevices()) ?? []
        profilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for profile in store.profiles {
            let detected = present.contains { profile.matches(vendorID: $0.vendorID, productID: $0.productID) }
            profilesStack.addArrangedSubview(makeProfileRow(profile, detected: detected))
        }
    }

    private func makeProfileRow(_ profile: HardwareProfile, detected: Bool) -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        dot.layer?.backgroundColor = (detected ? Theme.shared.accentGreen : NSColor(white: 0.3, alpha: 1)).cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let name = NSTextField(labelWithString: profile.name + (profile.builtIn ? "  (built-in)" : ""))
        name.font = .systemFont(ofSize: 12, weight: .medium)
        name.textColor = Theme.shared.textPrimary
        let pids = profile.productIds.joined(separator: "/")
        let detail = NSTextField(labelWithString: "\(profile.vendorId):\(pids) • \(profile.firmwareFiles.joined(separator: ", "))")
        detail.font = .systemFont(ofSize: 10)
        detail.textColor = Theme.shared.textSecondary
        let text = NSStackView(views: [name, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let edit = RowButton(title: "Edit", target: self, action: #selector(editProfile(_:)))
        edit.profileID = profile.id
        edit.controlSize = .small
        let buttons = NSStackView(views: [edit])
        if !profile.builtIn {
            let del = RowButton(title: "Delete", target: self, action: #selector(deleteProfile(_:)))
            del.profileID = profile.id
            del.controlSize = .small
            buttons.addArrangedSubview(del)
        }
        buttons.spacing = 6

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [dot, text, spacer, buttons])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 540).isActive = true
        return row
    }

    // MARK: Firmware actions

    @objc private func chooseFirmwareFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        panel.beginSheetModal(for: window!) { [weak self] resp in
            if resp == .OK, let url = panel.url {
                ProfileStore.shared.firmwareDirectory = url.path
                self?.refresh(); self?.onChange()
            }
        }
    }

    @objc private func clearFirmwareFolder() {
        ProfileStore.shared.firmwareDirectory = nil
        refresh(); onChange()
    }

    /// Copy chosen firmware file(s) into OpenCrashCart's own firmware folder so the vendor app
    /// is no longer required.
    @objc private func importFirmware() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "fgz") ?? .data, .data]
        panel.prompt = "Import"
        panel.beginSheetModal(for: window!) { [weak self] resp in
            guard resp == .OK else { return }
            let dest = ProfileStore.shared.applicationSupportFirmwareDir
            try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)
            for url in panel.urls {
                let target = dest + "/" + url.lastPathComponent
                try? FileManager.default.removeItem(atPath: target)
                try? FileManager.default.copyItem(atPath: url.path, toPath: target)
            }
            ProfileStore.shared.firmwareDirectory = dest
            self?.refresh(); self?.onChange()
        }
    }

    // MARK: Profile actions

    @objc private func addProfile() { presentEditor(for: nil) }

    @objc private func editProfile(_ sender: RowButton) {
        presentEditor(for: ProfileStore.shared.profiles.first { $0.id == sender.profileID })
    }

    @objc private func deleteProfile(_ sender: RowButton) {
        ProfileStore.shared.remove(id: sender.profileID)
        refresh(); onChange()
    }

    private func presentEditor(for existing: HardwareProfile?) {
        let alert = NSAlert()
        alert.messageText = existing == nil ? "Add Adapter Profile" : "Edit Adapter Profile"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let (view, fields) = buildEditor(existing)
        alert.accessoryView = view
        alert.beginSheetModal(for: window!) { [weak self] resp in
            guard resp == .alertFirstButtonReturn else { return }
            let name = fields.name.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let pids = fields.pids.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let files = fields.files.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let dir = fields.dir.stringValue.trimmingCharacters(in: .whitespaces)
            let profile = HardwareProfile(
                id: existing?.id ?? "custom-" + UUID().uuidString.prefix(8).lowercased(),
                name: name,
                backend: existing?.backend ?? "dmtz-vsp",
                vendorId: fields.vid.stringValue.trimmingCharacters(in: .whitespaces),
                productIds: pids,
                firmwareFiles: files.isEmpty ? ["ulcvm.fgz"] : files,
                firmwareDir: dir.isEmpty ? nil : dir,
                builtIn: existing?.builtIn ?? false)
            ProfileStore.shared.upsert(profile)
            self?.refresh(); self?.onChange()
        }
    }

    private struct EditorFields { let name, vid, pids, files, dir: NSTextField }

    private func buildEditor(_ p: HardwareProfile?) -> (NSView, EditorFields) {
        func field(_ value: String, _ placeholder: String) -> NSTextField {
            let tf = NSTextField(string: value)
            tf.placeholderString = placeholder
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.widthAnchor.constraint(equalToConstant: 320).isActive = true
            return tf
        }
        func row(_ label: String, _ tf: NSTextField) -> NSStackView {
            let l = NSTextField(labelWithString: label)
            l.alignment = .right
            l.textColor = Theme.shared.textSecondary
            l.translatesAutoresizingMaskIntoConstraints = false
            l.widthAnchor.constraint(equalToConstant: 110).isActive = true
            let s = NSStackView(views: [l, tf]); s.spacing = 8; s.alignment = .centerY
            return s
        }
        let fields = EditorFields(
            name: field(p?.name ?? "", "My Crash Cart Adapter"),
            vid: field(p?.vendorId ?? "0x152A", "0x152A"),
            pids: field(p?.productIds.joined(separator: ", ") ?? "", "0x8460, 0x8463"),
            files: field(p?.firmwareFiles.joined(separator: ", ") ?? "ulcvm.fgz", "ulcvm.fgz"),
            dir: field(p?.firmwareDir ?? "", "(optional firmware folder)"))
        let stack = NSStackView(views: [
            row("Name", fields.name),
            row("Vendor ID", fields.vid),
            row("Product IDs", fields.pids),
            row("Firmware files", fields.files),
            row("Firmware folder", fields.dir),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.frame = NSRect(x: 0, y: 0, width: 450, height: 190)
        let container = NSView(frame: stack.frame)
        container.addSubview(stack)
        return (container, fields)
    }
}

private extension NSBox {
    static func divider() -> NSBox {
        let b = NSBox(); b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 540).isActive = true
        return b
    }
}
