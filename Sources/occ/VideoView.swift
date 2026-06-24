import AppKit
import OCCKit

/// Receives translated input from the video view.
@MainActor protocol VideoViewInput: AnyObject {
    func sendKey(usage: UInt8, isDown: Bool, allReleased: Bool)
    func sendMouse(buttons: MouseButtons, x: Int16, y: Int16, wheel: Int16, absolute: Bool)
}

/// Transparent overlay that draws the OCR selection rectangle and passes mouse events
/// through to the video view beneath it.
final class SelectionOverlay: NSView {
    var selectionRect: NSRect? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // never intercept input
    override func draw(_ dirtyRect: NSRect) {
        guard let r = selectionRect else { return }
        Theme.shared.accentPink.withAlphaComponent(0.18).setFill()
        r.fill()
        Theme.shared.accentPink.setStroke()
        let path = NSBezierPath(rect: r)
        path.lineWidth = 1.5
        path.stroke()
    }
}

/// Layer-backed view that displays decoded BGRA frames and captures keyboard/mouse,
/// translating them to the device's HID/absolute-mouse conventions.
final class VideoView: NSView {
    weak var input: VideoViewInput?

    private(set) var frameSize = CGSize(width: 1024, height: 768)
    private var lastImage: CGImage?

    /// OCR region selection. `onRegionSelected` is called with the cropped frame (or nil if
    /// cancelled/empty) when the user finishes dragging a rectangle.
    var onRegionSelected: ((CGImage?) -> Void)?
    private var selecting = false
    private var selectionStart: NSPoint?
    private let overlay = SelectionOverlay()

    /// When true, the cursor is captured and movement is sent as relative deltas — for
    /// targets where absolute positioning doesn't work (some BIOS/console screens).
    var relativeMode = false { didSet { applyCursorCapture() } }
    private var cursorHidden = false
    /// HID usages currently held down (regular keys + modifiers) — drives the "all released" flag.
    private var keysDown = Set<UInt8>()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .nearest   // crisp pixels, no blur
        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.isHidden = true
        addSubview(overlay)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }       // top-left origin to match the video

    // MARK: Frame display

    /// Display a decoded frame. Called on the main actor by the event consumer.
    func display(_ frame: VideoFrame) {
        frameSize = CGSize(width: frame.width, height: frame.height)
        guard let image = makeCGImage(frame) else { return }
        lastImage = image
        layer?.contents = image
    }

    /// PNG of the current screen for the snapshot button.
    func snapshotPNG() -> Data? {
        guard let image = lastImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    private func makeCGImage(_ frame: VideoFrame) -> CGImage? {
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)   // BGRA in memory
        guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData) else { return nil }
        return CGImage(
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo,
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    // MARK: Keyboard

    // MARK: OCR region selection

    /// Begin dragging a rectangle over the screen to OCR. Esc cancels.
    func beginRegionSelection() {
        selecting = true
        selectionStart = nil
        overlay.selectionRect = nil
        overlay.isHidden = false
        NSCursor.crosshair.push()
        window?.makeFirstResponder(self)
    }

    private func endRegionSelection() {
        guard selecting else { return }
        selecting = false
        selectionStart = nil
        overlay.selectionRect = nil
        overlay.isHidden = true
        NSCursor.pop()
    }

    private func rect(from a: NSPoint, to b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func finishSelection(at point: NSPoint) {
        defer { endRegionSelection() }
        guard let start = selectionStart, let image = lastImage else { onRegionSelected?(nil); return }
        let r = rect(from: start, to: point)
        guard r.width > 3, r.height > 3 else { onRegionSelected?(nil); return }

        // Map the view rect → frame-pixel rect (letterbox-aware), then crop the frame image.
        let b = bounds
        let fw = max(frameSize.width, 1), fh = max(frameSize.height, 1)
        let scale = min(b.width / fw, b.height / fh)
        let dispW = fw * scale, dispH = fh * scale
        let ox = (b.width - dispW) / 2, oy = (b.height - dispH) / 2
        func toPixel(_ p: NSPoint) -> CGPoint {
            CGPoint(x: min(max((p.x - ox) / dispW, 0), 1) * fw,
                    y: min(max((p.y - oy) / dispH, 0), 1) * fh)
        }
        let p1 = toPixel(NSPoint(x: r.minX, y: r.minY))
        let p2 = toPixel(NSPoint(x: r.maxX, y: r.maxY))
        let crop = CGRect(x: floor(min(p1.x, p2.x)), y: floor(min(p1.y, p2.y)),
                          width: ceil(abs(p2.x - p1.x)), height: ceil(abs(p2.y - p1.y)))
        guard crop.width >= 4, crop.height >= 4, let cropped = image.cropping(to: crop) else {
            onRegionSelected?(nil); return
        }
        onRegionSelected?(cropped)
    }

    override func keyDown(with event: NSEvent) {
        if selecting {
            if event.keyCode == 0x35 { endRegionSelection(); onRegionSelected?(nil) }  // Esc cancels
            return  // swallow keys while selecting
        }
        // Let macOS own ⌘ shortcuts (screenshot, ⌘-Tab, Spotlight): don't forward presses
        // made while Command is held, so those never reach the target.
        if event.modifierFlags.contains(.command) { return }
        guard !event.isARepeat, let usage = HIDKeymap.hidUsage(forMacKeyCode: event.keyCode) else { return }
        keysDown.insert(usage)
        input?.sendKey(usage: usage, isDown: true, allReleased: keysDown.isEmpty)
    }

    override func keyUp(with event: NSEvent) {
        // Always forward releases (a release can only prevent a stuck key, never cause one).
        guard let usage = HIDKeymap.hidUsage(forMacKeyCode: event.keyCode) else { return }
        keysDown.remove(usage)
        input?.sendKey(usage: usage, isDown: false, allReleased: keysDown.isEmpty)
    }

    override func flagsChanged(with event: NSEvent) {
        // Modifier transitions arrive here. CRITICAL: only act on actual modifier keys —
        // flagsChanged can fire with keyCode 0 (which maps to 'A') when focus is stolen
        // (e.g. the screenshot overlay), which would otherwise inject stray 'A' keystrokes.
        guard let usage = HIDKeymap.hidUsage(forMacKeyCode: event.keyCode),
              HIDKeymap.isModifier(usage) else { return }
        let isDown = !keysDown.contains(usage)   // toggle: first event = press, next = release
        if isDown { keysDown.insert(usage) } else { keysDown.remove(usage) }
        input?.sendKey(usage: usage, isDown: isDown, allReleased: keysDown.isEmpty)
    }

    /// Release every key currently held on the target. Called when the window loses focus
    /// so a half-pressed key can never get stuck and lock out a live machine.
    func releaseAllKeys() {
        guard !keysDown.isEmpty else { return }
        let held = keysDown
        keysDown.removeAll()
        for usage in held {
            input?.sendKey(usage: usage, isDown: false, allReleased: true)
        }
    }

    override func resignFirstResponder() -> Bool {
        releaseAllKeys()
        // Always restore the cursor when we lose focus, even in relative mode.
        if cursorHidden {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            cursorHidden = false
        }
        return super.resignFirstResponder()
    }

    // MARK: Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited],
            owner: self))
    }

    override func mouseDown(with e: NSEvent) {
        if selecting { selectionStart = convert(e.locationInWindow, from: nil); return }
        window?.makeFirstResponder(self); sendMouse(e)
    }
    override func mouseUp(with e: NSEvent) {
        if selecting { finishSelection(at: convert(e.locationInWindow, from: nil)); return }
        sendMouse(e)
    }
    override func rightMouseDown(with e: NSEvent)   { sendMouse(e) }
    override func rightMouseUp(with e: NSEvent)     { sendMouse(e) }
    override func otherMouseDown(with e: NSEvent)   { sendMouse(e) }
    override func otherMouseUp(with e: NSEvent)     { sendMouse(e) }
    override func mouseMoved(with e: NSEvent)       { sendMouse(e) }
    override func mouseDragged(with e: NSEvent) {
        if selecting, let start = selectionStart {
            overlay.selectionRect = rect(from: start, to: convert(e.locationInWindow, from: nil))
            return
        }
        sendMouse(e)
    }
    override func rightMouseDragged(with e: NSEvent){ sendMouse(e) }
    override func otherMouseDragged(with e: NSEvent){ sendMouse(e) }
    override func scrollWheel(with e: NSEvent) {
        let wheel: Int16 = e.scrollingDeltaY > 0 ? 1 : (e.scrollingDeltaY < 0 ? -1 : 0)
        sendMouse(e, wheel: wheel)
    }

    private func sendMouse(_ event: NSEvent, wheel: Int16 = 0) {
        if selecting { return }   // don't drive the target while picking an OCR region
        let raw = NSEvent.pressedMouseButtons
        var buttons: MouseButtons = []
        if raw & 0b001 != 0 { buttons.insert(.left) }
        if raw & 0b010 != 0 { buttons.insert(.right) }
        if raw & 0b100 != 0 { buttons.insert(.middle) }

        if relativeMode {
            let dx = Int16(clamping: Int(event.deltaX.rounded()))
            let dy = Int16(clamping: Int(event.deltaY.rounded()))
            input?.sendMouse(buttons: buttons, x: dx, y: dy, wheel: wheel, absolute: false)
            return
        }

        let p = convert(event.locationInWindow, from: nil)   // flipped → top-left origin
        // Map view point → active-area pixel coordinates, accounting for the aspect-fit
        // letterbox: the image is centered and may have black bars, so the pointer must be
        // mapped against the displayed video rect, not the whole view.
        let b = bounds
        let fw = max(frameSize.width, 1), fh = max(frameSize.height, 1)
        let scale = min(b.width / fw, b.height / fh)
        let dispW = fw * scale, dispH = fh * scale
        let originX = (b.width - dispW) / 2, originY = (b.height - dispH) / 2
        let nx = max(0, min(1, (p.x - originX) / dispW))
        let ny = max(0, min(1, (p.y - originY) / dispH))
        let x = Int16(clamping: Int((nx * (fw - 1)).rounded()))
        let y = Int16(clamping: Int((ny * (fh - 1)).rounded()))
        input?.sendMouse(buttons: buttons, x: x, y: y, wheel: wheel, absolute: true)
    }

    // MARK: Relative-mode cursor capture

    private func applyCursorCapture() {
        let active = relativeMode && (window?.firstResponder === self) && (window?.isKeyWindow ?? false)
        if active && !cursorHidden {
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
            cursorHidden = true
        } else if !active && cursorHidden {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            cursorHidden = false
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        applyCursorCapture()
        return ok
    }
}
