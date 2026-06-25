# Pass 2 Deep — App/UI Layer Domain (round 1)  [Novelty: SUBSTANTIVE]

The broad Pass 2 modeled only OCCKit value types + the device-side AdapterState machine. This round adds the previously-unmodeled APP layer.

## 1. AppController = the Session aggregate root (Sources/occ/AppController.swift:9)
Mutable session state: adapter:(any CrashCartAdapter)? (:27), eventTask:Task (:28), rescanTimer:Timer 2.0s (:29), connecting:Bool single-flight guard (:30), isLive:Bool (:31), didAutoSize one-shot latch (:32), relativeMouse (:33), recorder:Recorder? doubles as record-active flag (:34), latestAdjustments:[VideoAdjustment:Int] buffered-not-pushed (:26), lazy panels (keyboard/adjust/enhance/settings, :21-24).
Invariants: single-session (tryConnect no-op unless adapter==nil && !connecting, :174); adjustments buffered not pushed live to avoid knob-jump during drag/auto-fine-tune (:250-255, applied on panel open :543); auto-size once per session (:259, resets on disconnect/UVC-switch); focus-loss releases all keys (:116-120).

## 2. handle(event:) — app-layer session state machine (:242) [distinct from OCCKit AdapterState]
.frame→showVideo+display+recorder.append; .status .live→buffer adjustments+showVideo+title WxH+first-time resizeToVideo; .status non-live→placeholder .noSignal; .message→statusbar; .mediaChanged→media field; .disconnected→clear adapter/eventTask, didAutoSize=false, placeholder .noAdapter (rescan re-discovers). PlaceholderView.State {noAdapter, connecting, noSignal}. showVideo idempotent via guard !isLive.

## 3. Command vocabulary (installMenuBar :285, @objc selectors)
Connection: Reconnect ⌘⇧R / Disconnect / Connect-UVC (dynamic submenu) / Mount-ISO / Eject / Record ⌘⇧E / Snapshot ⌘S / OCR ⌘⇧C. Keyboard: On-Screen ⌘K / Paste ⌘⇧V / Type Text / Ctrl-Alt-Del / Windows-key / Escape. Video: Refresh ⌘R / Auto-Tune / Adjustments / Image-Enhance / DDC submenu (DDCPreset.allCases). View: Fit / Actual / Fullscreen ⌘⌃F / Relative-Mouse (checkable) / padding ⌘+ ⌘− ⌘0.
Device mappings: Windows=sendKeyPress(0xE3); Escape=0x29; DDC via representedObject NSNumber(rawValue); Type/Paste→typeText; sendChord(modifiers,usage) presses mods down→key down/up→mods up reversed, allReleased only on final event (:579-590).

## 4. VideoView UI-domain state (:39)
frameSize (default 1024×768); lastImage:CGImage? = RAW retained for snapshot/OCR even when enhancement active; enhancement:ImageEnhancement display-only; keysDown:Set<UInt8>; OCR selection (selecting, selectionStart, overlay); relative capture (relativeMode didSet→applyCursorCapture, cursorHidden).
- ImageEnhancement struct (:6-12): brightness -1..1, contrast 0.5..2, sharpness 0..1, grayscale; isActive computed. Composition: CIColorControls(bright/contrast, sat=0 if grayscale) then CISharpenLuminance if sharpness>0; applied via CIContext only when isActive.
- SelectionOverlay:NSView pass-through (hitTest nil), pink fill alpha 0.18 + 1.5px stroke.
- Letterbox mouse math: scale=min(b.w/fw,b.h/fh), centered origin, normalized nx/ny clamped 0..1, x=nx*(fw-1) y=ny*(fh-1) absolute; relative=rounded clamped Int16 deltas. Buttons from pressedMouseButtons. Scroll→wheel ±1.
- keyDown swallowed while selecting (Esc cancels); ⌘-held dropped; repeats ignored. flagsChanged modifier-only guard (avoids stray 'A' on keyCode-0 focus theft). resignFirstResponder releases keys + restores cursor.
- Relative capture: CGAssociateMouseAndMouseCursorPosition(0)+NSCursor.hide when relativeMode && firstResponder && keyWindow.
- OCR crop: reject <3pt drag / <4px crop; letterbox map to integer pixels; crop RAW lastImage; onRegionSelected. snapshotPNG wraps lastImage→PNG.

## 5. OCR (OCR.swift): VNRecognizeTextRequest .accurate, usesLanguageCorrection=FALSE (server screens). Sort top→bottom then left→right (0.012 midY band), top candidate/line joined by \n. handleOCR trims, rejects empty, writes NSPasteboard + char count.

## 6. Recorder (Recorder.swift): AVAssetWriter H.264 .mov. Fixed width/height at init from frameSize; init? fails if writer/canAdd fail. append drops frames whose size differs (no corrupt file); lazy startSession on first accepted frame; per-frame BGRA memcpy into pooled CVPixelBuffer; PTS = CACurrentMediaTime()-startTime @600. finish→frameCount. recorder!=nil = record flag; toggle requires isLive && frameSize.width>0 + NSSavePanel.

## 7. SettingsWindow (SettingsWindow.swift): profile rows (green dot if present USB matches), editable fields name/vendorId/productIds(CSV)/firmwareFiles(CSV)/firmwareDir; NOT editable id/backend/builtIn. Validation: empty name aborts; CSV split/trim/filter; empty firmware→["ulcvm.fgz"]; empty dir→nil. Built-in: Edit but no Delete. Import Firmware copies .fgz into applicationSupportFirmwareDir + repoints firmwareDirectory. onChange→menuReconnect.

## Remaining gaps / next scope: KeyboardPanel sticky-modifier model, VideoAdjustPanel slider set + apply(latestAdjustments), ImageEnhancePanel slider→ImageEnhancement, PlaceholderView State+copy, StatusBar fields, ToolbarStrip/ToolbarActions, Theme padding state machine, ProfileStore persistence domain, device-discovery domain, HIDKeymap table.
