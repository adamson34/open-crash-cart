# Phase B.5 Coverage Audit — OpenCrashCart  [Verdict: SUBSTANTIVE]

Independent recount (verified, not trusted): 45 Swift files, 4,764 LOC — artifacts accurate. Artifacts present: pass-0..6 + pass-2/3 deep.

## Coverage verdict
- OCCKit device/protocol/codec layer: COMPREHENSIVELY COVERED (Pass 2 domain + Pass 3 BC-001..086, mostly test-pinned).
- AppKit UI layer (~2,300 LOC): was a SYSTEMATIC BLIND SPOT in the broad sweep (Pass 2/3 had ZERO UI entities/contracts). Now filled by the Pass 2/3 deep rounds + this audit.

## Blind-spot files (>100 LOC, no broad-sweep decomposition)
SettingsWindow 297, ToolbarStrip 198, KeyboardPanel 173, VideoAdjustPanel 135, StatusBar 111, ImageEnhancePanel 102, PlaceholderView 102; + PARTIAL AppController 666, VideoView 332. All now covered by pass-2/3-deep + BC-AUDIT below.

## Coverage matrix (source file × pass; substantive = decomposed not name-dropped)
All OCCKit/Adapter, Adapters/StarTech, Adapters/UVC, Input, USB, Util files: COVERED across P1-P5 + Pass-3 BCs. occ-tests used as spec source. occ-connect/occ-probe PARTIAL (thin drivers, sub-100/sub-100... 77/47 LOC). All occ/ UI files now covered via deep rounds + BC-AUDIT-001..033.

## Draft contracts from audit (BC-AUDIT-001..033) — corroborate Pass 3 deep BC-100..143
- AppController: BC-AUDIT-001 tryConnect idempotent; 002 connect-fail reset; 003 rescan re-discovery; 004 one auto-resize; 005 adjustments latched-not-pushed; 006 sendChord ordering; 007 mountMedia .iso→asCDROM; 008 isLive guards emit status; 009 UVC teardown-of-prior; 010 lazy UVC submenu; 011 record guard; 012 relative-mouse tri-sync.
- VideoView: BC-AUDIT-013 frameSize default 1024×768; 014 makeCGImage noneSkipFirst|byteOrder32Little nearest mag; 015 enhancement display-only/raw retained; 016 ⌘-held + isARepeat dropped; 017 keyUp always forwarded; 018 flagsChanged modifier-only (stray-'A' guard); 019 releaseAllKeys; 020 absolute letterbox pixel clamp [0,dim-1]; 021 relative deltas + cursor capture; 022 buttons from pressedMouseButtons; 023 OCR crop guards; 024 selecting suppresses target mouse.
- SettingsWindow: BC-AUDIT-025 green dot on present-match; 026 built-in non-deletable; 027 empty-name abort + firmware default + custom-uuid8 id; 028 every mutation→onChange→menuReconnect.
- KeyboardPanel: BC-AUDIT-029 sticky-toggle modifiers, non-modifier emits one chord then clears armed; 030 ⊞ win→0xE3 (panel exists to send keys macOS intercepts). 7-row layout w/ exact HID usages; VKButton armed(orange)/hover; main window keeps focus.
- VideoAdjustPanel: BC-AUDIT-031 onChange once per distinct value transition (lastSent dedupe); apply() silent. Specs: Sharpness 0-15, Phase 0-31, Horizontal -30..30, Vertical -30..30, Noise 0-15.
- StatusBar: BC-AUDIT-032 bandwidth "--" unless finite && 0<=mbps<100 (spike suppression); fps hidden when 0. State color-coded (disconnected/connecting orange, noVideo pink+reason, live green WxH@Hz); kbd type or "no kbd"; caps/num/scroll LEDs; REC pill; 💿 media.
- ImageEnhancePanel: builds ImageEnhancement → VideoView.setEnhancement (client-side only). PlaceholderView: BC-AUDIT-033 State {noAdapter, connecting, noSignal} — UI counterpart to AdapterState.
- Recorder/OCR: as Pass 3 deep BC-135..143. CLIs: occ-probe enumerate→Registry.match→print + speed warn; occ-connect discover→StarTechAdapter.connect→print stream + SIGINT/OCC_SECONDS(default 20s).

## Correctness-critical UI behaviors that had NO contract before deepening (now contracted)
sticky-modifier chord ordering (BC-117/AUDIT-006), focus-loss key release (BC-126/AUDIT-019), stray-'A' flagsChanged guard (BC-128/AUDIT-018), letterbox OCR/mouse pixel mapping (BC-119/123/AUDIT-020/023).
