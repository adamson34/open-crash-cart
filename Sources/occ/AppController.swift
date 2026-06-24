import AppKit
import OCCKit
import UniformTypeIdentifiers

/// Owns the window chrome (toolbar · screen card · status bar), the adapter session, and
/// the bridge between the UI and the device. Padding is driven by `Theme` and adjustable
/// live (⌘+ / ⌘−).
@MainActor
final class AppController: NSObject, NSApplicationDelegate, VideoViewInput, ToolbarActions {
    private var window: NSWindow!
    private var root: NSView!
    private var videoView: VideoView!
    private var placeholder: PlaceholderView!
    private var screenCard: NSView!
    private var toolbar: ToolbarStrip!
    private var statusBar: StatusBar!

    // Constraints whose constants follow Theme.padding.
    private var cardTop, cardLeading, cardTrailing, cardBottom: NSLayoutConstraint!

    private var keyboardPanel: KeyboardPanel?
    private var adjustPanel: VideoAdjustPanel?
    private var settingsController: SettingsWindowController?
    private var latestAdjustments: [VideoAdjustment: Int] = [:]
    private var adapter: (any CrashCartAdapter)?
    private var eventTask: Task<Void, Never>?
    private var rescanTimer: Timer?
    private var connecting = false
    private var isLive = false
    private var didAutoSize = false
    private var relativeMouse = false
    private var recorder: Recorder?
    private var relativeMouseItem: NSMenuItem!

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenuBar()
        let theme = Theme.shared
        let initial = NSRect(x: 0, y: 0, width: 1100, height: 820)
        window = NSWindow(
            contentRect: initial,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "OpenCrashCart"
        window.center()
        window.acceptsMouseMovedEvents = true
        window.setFrameAutosaveName("OpenCrashCartMainWindow")

        root = NSView(frame: initial)
        root.wantsLayer = true
        root.layer?.backgroundColor = theme.windowBG.cgColor
        window.contentView = root

        toolbar = ToolbarStrip(actions: self)
        statusBar = StatusBar()

        // Screen card: rounded, bordered container holding the video + placeholder overlay.
        screenCard = NSView()
        screenCard.wantsLayer = true
        screenCard.layer?.backgroundColor = theme.screenBG.cgColor
        screenCard.layer?.cornerRadius = theme.cornerRadius
        screenCard.layer?.borderColor = theme.cardBorder.cgColor
        screenCard.layer?.borderWidth = 1
        screenCard.layer?.masksToBounds = true

        videoView = VideoView(frame: .zero)
        videoView.input = self
        videoView.onRegionSelected = { [weak self] image in self?.handleOCR(image) }
        placeholder = PlaceholderView(frame: .zero)

        [toolbar, screenCard, statusBar].forEach {
            $0!.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0!)
        }
        [videoView, placeholder].forEach {
            $0!.translatesAutoresizingMaskIntoConstraints = false
            screenCard.addSubview($0!)
        }

        let p = theme.padding
        cardTop = screenCard.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: p)
        cardLeading = screenCard.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: p)
        cardTrailing = root.trailingAnchor.constraint(equalTo: screenCard.trailingAnchor, constant: p)
        cardBottom = statusBar.topAnchor.constraint(equalTo: screenCard.bottomAnchor, constant: p)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: theme.toolbarHeight),

            statusBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            statusBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: theme.statusHeight),

            cardTop, cardLeading, cardTrailing, cardBottom,
        ])
        for v in [videoView!, placeholder!] {
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: screenCard.topAnchor),
                v.bottomAnchor.constraint(equalTo: screenCard.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: screenCard.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: screenCard.trailingAnchor),
            ])
        }

        theme.onChange = { [weak self] in self?.applyPadding() }

        // Release any held keys whenever we lose focus, so nothing sticks on a live target
        // (window deactivated, app switched away, screenshot overlay, etc.).
        let nc = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSApplication.didResignActiveNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.videoView.releaseAllKeys() }
            }
        }

        showPlaceholder(.noAdapter)
        window.makeFirstResponder(videoView)
        window.makeKeyAndOrderFront(nil)

        tryConnect()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tryConnect() }
        }
        if let s = ProcessInfo.processInfo.environment["OCC_SECONDS"], let secs = Double(s) {
            Timer.scheduledTimer(withTimeInterval: secs, repeats: false) { _ in
                MainActor.assumeIsolated { NSApp.terminate(nil) }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        eventTask?.cancel()
        let a = adapter
        Task { await a?.disconnect() }
    }

    private func applyPadding() {
        let p = Theme.shared.padding
        cardTop.constant = p
        cardLeading.constant = p
        cardTrailing.constant = p
        cardBottom.constant = p
        root.layoutSubtreeIfNeeded()
    }

    // MARK: Placeholder / live state

    private func showPlaceholder(_ state: PlaceholderView.State) {
        isLive = false
        placeholder.set(state)
        placeholder.isHidden = false
        videoView.isHidden = true
    }

    private func showVideo() {
        guard !isLive else { return }
        isLive = true
        placeholder.isHidden = true
        videoView.isHidden = false
        window.makeFirstResponder(videoView)
    }

    // MARK: Connection

    private func tryConnect() {
        guard adapter == nil, !connecting else { return }
        let found = discoverProfiledDevices()
        guard let (device, profile) = found.first, let adapter = makeAdapter(for: device, profile: profile) else {
            if !connecting && adapter == nil { showPlaceholder(.noAdapter) }
            return
        }
        connecting = true
        showPlaceholder(.connecting)
        statusBar.setMessage("Connecting to \(profile.name)…")
        self.adapter = adapter
        eventTask = Task { [weak self] in
            do {
                let events = try await adapter.connect()
                self?.connecting = false
                for await event in events { self?.handle(event) }
            } catch {
                self?.connecting = false
                self?.adapter = nil
                self?.statusBar.setMessage("Connect failed: \(error)")
                self?.showPlaceholder(.noAdapter)
            }
        }
    }

    private func handle(_ event: AdapterEvent) {
        switch event {
        case .frame(let frame):
            showVideo()
            videoView.display(frame)
            recorder?.append(frame)
        case .status(let status):
            statusBar.update(status)
            if !status.adjustments.isEmpty {
                latestAdjustments = status.adjustments
                adjustPanel?.apply(status.adjustments)
            }
            if case .live(let w, let h, _) = status.state {
                showVideo()
                window.title = liveTitle(status)
                if !didAutoSize { didAutoSize = true; resizeToVideo(width: w, height: h) }
            } else {
                showPlaceholder(.noSignal)
                window.title = "OpenCrashCart"
            }
        case .message(let message):
            statusBar.setMessage(message)
        case .mediaChanged(let name):
            statusBar.setMedia(name)
        case .disconnected(let reason):
            statusBar.setMessage("Disconnected: \(reason) — rescanning…")
            window.title = "OpenCrashCart"
            adapter = nil
            eventTask = nil
            didAutoSize = false
            showPlaceholder(.noAdapter)
        }
    }

    private func liveTitle(_ s: AdapterStatus) -> String {
        if case .live(let w, let h, _) = s.state { return "OpenCrashCart — \(w)×\(h)" }
        return "OpenCrashCart"
    }

    // MARK: Menu bar

    private func installMenuBar() {
        let main = NSMenu()

        // Application menu (the bold "OpenCrashCart" menu).
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About OpenCrashCart",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(mi("Settings…", #selector(openSettings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide OpenCrashCart",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                        action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit OpenCrashCart",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // Connection
        addSubmenu(to: main, "Connection", [
            mi("Reconnect", #selector(menuReconnect), "r", [.command, .shift]),
            mi("Disconnect", #selector(menuDisconnect)),
            .separator(),
            mi("Mount Disk Image…", #selector(menuMountMedia)),
            mi("Eject Disk Image", #selector(menuEjectMedia)),
            .separator(),
            mi("Start/Stop Recording", #selector(menuRecord), "e", [.command, .shift]),
            mi("Save Snapshot…", #selector(menuSnapshot), "s"),
            mi("Copy Text from Screen…", #selector(menuOCR), "c", [.command, .shift]),
        ])

        // Keyboard
        addSubmenu(to: main, "Keyboard", [
            mi("On-Screen Keyboard", #selector(menuKeyboard), "k"),
            .separator(),
            mi("Paste Text to Target", #selector(menuPasteText), "v", [.command, .shift]),
            mi("Type Text…", #selector(menuTypeText)),
            .separator(),
            mi("Send Ctrl-Alt-Del", #selector(menuCtrlAltDel)),
            mi("Send Windows Key", #selector(menuWindowsKey)),
            mi("Send Escape", #selector(menuEscape)),
        ])

        // Video
        let videoMenu = NSMenu(title: "Video")
        videoMenu.addItem(mi("Refresh Screen", #selector(menuRefresh), "r"))
        videoMenu.addItem(mi("Auto-Tune Video", #selector(menuAutoTune)))
        videoMenu.addItem(mi("Video Adjustments…", #selector(menuAdjust)))
        videoMenu.addItem(.separator())
        let ddc = NSMenu(title: "Preferred Resolution (DDC)")
        for preset in DDCPreset.allCases {
            let item = mi(preset.label, #selector(menuDDC(_:)))
            item.representedObject = NSNumber(value: preset.rawValue)
            ddc.addItem(item)
        }
        let ddcItem = NSMenuItem(); ddcItem.title = "Preferred Resolution (DDC)"; ddcItem.submenu = ddc
        videoMenu.addItem(ddcItem)
        let videoItem = NSMenuItem(); videoItem.submenu = videoMenu; videoItem.title = "Video"
        main.addItem(videoItem)

        // View
        relativeMouseItem = mi("Relative Mouse Mode", #selector(menuToggleRelativeMouse))
        addSubmenu(to: main, "View", [
            mi("Fit to Window", #selector(menuFit)),
            mi("Actual Size", #selector(menuActualSize)),
            mi("Enter Full Screen", #selector(menuFullScreen), "f", [.command, .control]),
            .separator(),
            relativeMouseItem,
            .separator(),
            mi("Increase Padding", #selector(increasePadding), "+"),
            mi("Decrease Padding", #selector(decreasePadding), "-"),
            mi("Reset Padding", #selector(resetPadding), "0"),
        ])

        // Window (standard)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let windowItem = NSMenuItem(); windowItem.submenu = windowMenu; main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    /// Make a menu item targeting this controller.
    private func mi(_ title: String, _ action: Selector, _ key: String = "",
                    _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = mods }
        item.target = self
        return item
    }

    private func addSubmenu(to main: NSMenu, _ title: String, _ items: [NSMenuItem]) {
        let menu = NSMenu(title: title)
        items.forEach { menu.addItem($0) }
        let item = NSMenuItem(); item.submenu = menu; item.title = title
        main.addItem(item)
    }

    // MARK: Menu actions

    @objc private func menuReconnect() {
        if let a = adapter { Task { await a.disconnect() } }
        adapter = nil; eventTask = nil; connecting = false; didAutoSize = false
        showPlaceholder(.noAdapter)
        tryConnect()
    }
    @objc private func menuDisconnect() {
        if let a = adapter { Task { await a.disconnect() } }
        adapter = nil; eventTask = nil; connecting = false; didAutoSize = false
        showPlaceholder(.noAdapter)
    }
    @objc private func menuSnapshot()    { snapshot() }
    @objc private func menuOCR()         { copyTextFromScreen() }
    @objc private func menuMountMedia()  { mountMedia() }
    @objc private func menuEjectMedia()  { adapter?.ejectMedia() }
    @objc private func menuKeyboard()    { toggleKeyboard() }

    @objc private func menuPasteText() { pasteText() }

    func pasteText() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            adapter?.typeText(text)
            statusBar.setMessage("Pasting \(text.count) character\(text.count == 1 ? "" : "s") to target…")
        } else {
            statusBar.setMessage("Clipboard has no text to paste.")
        }
    }

    @objc private func menuTypeText() {
        let alert = NSAlert()
        alert.messageText = "Type Text to Target"
        alert.informativeText = "The text below will be typed into the target as keystrokes."
        alert.addButton(withTitle: "Type")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "Text to type…"
        alert.accessoryView = field
        alert.beginSheetModal(for: window) { [weak self] resp in
            if resp == .alertFirstButtonReturn { self?.adapter?.typeText(field.stringValue) }
        }
    }
    @objc private func menuCtrlAltDel()  { ctrlAltDel() }
    @objc private func menuWindowsKey()  { adapter?.sendKeyPress(usage: 0xE3) }   // Left GUI
    @objc private func menuEscape()      { adapter?.sendKeyPress(usage: 0x29) }   // Escape
    @objc private func menuRefresh()     { refreshScreen() }
    @objc private func menuAutoTune()    { retuneVideo() }
    @objc private func menuAdjust()      { toggleVideoAdjust() }
    @objc private func menuRecord()      { toggleRecording() }

    @objc private func menuDDC(_ sender: NSMenuItem) {
        if let n = sender.representedObject as? NSNumber, let preset = DDCPreset(rawValue: n.intValue) {
            adapter?.setDDCPreset(preset)
            statusBar.setMessage("Set preferred resolution: \(preset.label)")
        }
    }

    @objc private func menuToggleRelativeMouse() {
        relativeMouse.toggle()
        videoView.relativeMode = relativeMouse
        relativeMouseItem.state = relativeMouse ? .on : .off
        statusBar.setMessage(relativeMouse
            ? "Relative mouse mode ON — cursor captured (toggle off in View menu)."
            : "Relative mouse mode off.")
    }
    @objc private func menuFit()         { fitToWindow() }
    @objc private func menuActualSize()  { actualSize() }
    @objc private func menuFullScreen()  { toggleFullScreen() }

    @objc func increasePadding() { Theme.shared.adjust(by: 6) }
    @objc func decreasePadding() { Theme.shared.adjust(by: -6) }
    @objc func resetPadding()    { Theme.shared.reset() }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(onChange: { [weak self] in self?.menuReconnect() })
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: VideoViewInput (UI → device)

    func sendKey(usage: UInt8, isDown: Bool, allReleased: Bool) {
        adapter?.send(key: HIDKeyEvent(usage: usage, modifiers: 0, isDown: isDown, allReleased: allReleased))
    }
    func sendMouse(buttons: MouseButtons, x: Int16, y: Int16, wheel: Int16, absolute: Bool) {
        adapter?.send(mouse: MouseEvent(buttons: buttons, x: x, y: y, wheel: wheel, isAbsolute: absolute))
    }

    // MARK: ToolbarActions

    func ctrlAltDel()             { adapter?.sendCtrlAltDel() }
    func refreshScreen()          { adapter?.requestKeyframe() }

    func toggleRecording() {
        if recorder != nil {
            stopRecording()
            return
        }
        guard isLive, videoView.frameSize.width > 0 else {
            statusBar.setMessage("Connect to a live target before recording.")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.nameFieldStringValue = "OpenCrashCart-recording.mov"
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard let self, resp == .OK, let url = panel.url else { return }
            let w = Int(self.videoView.frameSize.width), h = Int(self.videoView.frameSize.height)
            guard let rec = Recorder(url: url, width: w, height: h) else {
                self.statusBar.setMessage("Could not start recording.")
                return
            }
            self.recorder = rec
            self.statusBar.setRecording(true)
        }
    }

    private func stopRecording() {
        guard let rec = recorder else { return }
        recorder = nil
        statusBar.setRecording(false)
        rec.finish { [weak self] frames in
            DispatchQueue.main.async { self?.statusBar.setMessage("Saved recording (\(frames) frames).") }
        }
    }

    func toggleVideoAdjust() {
        if adjustPanel == nil {
            adjustPanel = VideoAdjustPanel(
                onChange: { [weak self] adj, value in self?.adapter?.setVideoAdjustment(adj, value: value) },
                onSave:   { [weak self] in VideoAdjustment.allCases.forEach { self?.adapter?.saveVideoAdjustment($0) } },
                onReset:  { [weak self] in VideoAdjustment.allCases.forEach { self?.adapter?.resetVideoAdjustment($0) } })
        }
        guard let panel = adjustPanel else { return }
        if panel.isVisible { panel.orderOut(nil) }
        else { panel.apply(latestAdjustments); panel.present(relativeTo: window) }
    }

    func mountMedia() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "iso") ?? .data,
            UTType(filenameExtension: "img") ?? .data,
            .diskImage, .data,
        ]
        panel.prompt = "Mount"
        panel.message = "Choose an ISO or disk image to present to the target as a USB drive."
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard resp == .OK, let url = panel.url else { return }
            let cdrom = url.pathExtension.lowercased() == "iso"
            self?.adapter?.mountMedia(path: url.path, asCDROM: cdrom)
        }
    }

    func toggleKeyboard() {
        if keyboardPanel == nil {
            keyboardPanel = KeyboardPanel { [weak self] modifiers, usage in
                self?.sendChord(modifiers: modifiers, usage: usage)
            }
        }
        guard let panel = keyboardPanel else { return }
        if panel.isVisible { panel.orderOut(nil) }
        else { panel.present(relativeTo: window) }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(videoView)
    }

    /// Send modifiers (held) + a key (press/release) + release modifiers — for the
    /// on-screen keyboard's sticky-modifier chords.
    private func sendChord(modifiers: [UInt8], usage: UInt8) {
        guard let a = adapter else { return }
        for m in modifiers {
            a.send(key: HIDKeyEvent(usage: m, modifiers: 0, isDown: true, allReleased: false))
        }
        a.send(key: HIDKeyEvent(usage: usage, modifiers: 0, isDown: true, allReleased: false))
        a.send(key: HIDKeyEvent(usage: usage, modifiers: 0, isDown: false, allReleased: modifiers.isEmpty))
        let mods = Array(modifiers.reversed())
        for (i, m) in mods.enumerated() {
            a.send(key: HIDKeyEvent(usage: m, modifiers: 0, isDown: false, allReleased: i == mods.count - 1))
        }
    }
    func retuneVideo()            { adapter?.autoTuneVideo() }
    func toggleFullScreen()       { window.toggleFullScreen(nil) }
    func fitToWindow()            { /* the view always aspect-fits */ }

    func actualSize() {
        let fs = videoView.frameSize
        guard fs.width > 0, isLive else { return }
        resizeToVideo(width: Int(fs.width), height: Int(fs.height), animate: true)
    }

    /// Size the window so the video shows close to `width`×`height`, scaled down to fit the
    /// screen when the native resolution is larger than the display.
    private func resizeToVideo(width: Int, height: Int, animate: Bool = false) {
        let theme = Theme.shared
        let p = theme.padding
        let chrome = theme.toolbarHeight + theme.statusHeight
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        let maxW = visible.width * 0.92, maxH = visible.height * 0.92

        // Largest 1:1-ish scale (≤1) where the whole window still fits on screen.
        let scale = min(1, (maxW - 2 * p) / CGFloat(width), (maxH - chrome - 2 * p) / CGFloat(height))
        let contentW = CGFloat(width) * scale + 2 * p
        let contentH = CGFloat(height) * scale + chrome + 2 * p

        let topY = window.frame.maxY
        window.setContentSize(NSSize(width: contentW, height: contentH))
        var origin = window.frame.origin
        origin.y = topY - window.frame.height   // keep the top edge anchored
        if animate {
            window.animator().setFrameOrigin(origin)
        } else {
            window.setFrameOrigin(origin)
        }
    }

    func snapshot() {
        guard let png = videoView.snapshotPNG() else {
            statusBar.setMessage("No frame to snapshot yet.")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "OpenCrashCart-snapshot.png"
        panel.begin { response in
            if response == .OK, let url = panel.url { try? png.write(to: url) }
        }
    }

    func copyTextFromScreen() {
        guard isLive else {
            statusBar.setMessage("Connect to a live target before using OCR.")
            return
        }
        statusBar.setMessage("Drag to select the text to copy (Esc to cancel)…")
        videoView.beginRegionSelection()
    }

    private func handleOCR(_ image: CGImage?) {
        guard let image else { statusBar.setMessage("OCR cancelled."); return }
        statusBar.setMessage("Reading text…")
        recognizeText(in: image) { [weak self] text in
            DispatchQueue.main.async {
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    self.statusBar.setMessage("No text found in the selection.")
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(trimmed, forType: .string)
                let n = trimmed.count
                self.statusBar.setMessage("Copied \(n) character\(n == 1 ? "" : "s") from screen to clipboard.")
            }
        }
    }
}
