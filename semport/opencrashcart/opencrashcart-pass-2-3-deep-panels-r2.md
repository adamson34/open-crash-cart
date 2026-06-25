# Pass 2+3 Deepening Round 2 — UI Panels + ProfileStore + DDC/Theme  [Novelty: SUBSTANTIVE]

Audit of round-1/B.5 claims: BC-AUDIT-029/030/031/032/033 all VERIFIED; 0 CONV-ABS retractions; none of the 5 hallucination classes triggered.

## New domain facts
- DF-200 Two-tier firmware location: HardwareProfile.firmwareDir (per-profile override, HardwareProfile.swift:13) separate from store-wide ProfileStore.firmwareDirectory (:54); profile beats store, both fall back to app-support firmware/.
- DF-201 applicationSupportFirmwareDir derived (<profiles.json dir>/firmware), never persisted — the BYO-firmware home.
- DF-202 DDCPreset (Types.swift:122-132, 4 cases rv 0..3) is a fire-and-forget device command, NOT persisted (no UserDefaults/ProfileStore field; no "current preset" state).
- DF-203 setDDCPreset has a getVersions re-query side effect (StarTechAdapter:121-125).
- DF-204 Theme.padding is the ONLY persisted UI-layout state (key "OpenCrashCartPadding"); heights/colors compile-time fixed; accent = accentOrange alias.
- DF-205 StatusBar declares a private KeyboardEmulation.name = ["usb","ps2","sun"][rawValue] — the only HID-emulation labels (UI-layer extension, not the OCCKit enum).

## New behavioral contracts
- BC-200 ProfileStore seeds/self-heals to builtIns: missing/corrupt → builtIns + writeToDisk; empty-array → builtIns in-memory only (no rewrite) (ProfileStore:37-45). HIGH.
- BC-201 remove() cannot delete built-ins: removeAll { id==id && !builtIn } + writeToDisk (:77-82). HIGH.
- BC-202 upsert() id-keyed replace-or-append, write-through; no format validation here (:69-75). HIGH.
- BC-203 firmwareDirectory setter persists immediately; all accessors NSLock-guarded (@unchecked Sendable) (:50-67,84-91). HIGH.
- BC-204 JSON written prettyPrinted+sortedKeys (stable/diff-friendly); write failure silently swallowed (try?) — reliability gap (:88-90). HIGH.
- BC-205 HardwareProfile id-string parse hex/decimal, default 0; matches fails closed on unparseable (vendor 0) (HardwareProfile:29-41). HIGH.
- BC-206 Theme padding dual clamp: OCC_PADDING env = no clamp; saved UserDefaults clamped 0..40; default 14; runtime adjust(by:) clamped 0..96; reset→14; each write persists + onChange relayout (Theme:12-17,38-55). HIGH.
- BC-207 ImageEnhancePanel emits normalized ÷100 ImageEnhancement; slider ranges brightness -50..50, contrast 50..200(def 100), sharpness 0..100 → -0.5..0.5 / 0.5..2.0 / 0..1.0; reset emits default ImageEnhancement() (ImageEnhancePanel:8-11,77-93). HIGH.
- BC-208 VideoAdjustPanel ranges per-adjustment, tick-quantized integer-only: sharpness 0-15, phase 0-31, horizontal -30..30, vertical -30..30, noise 0-15 (allowsTickMarkValuesOnly enforces bounds); apply() syncs without emit (:13-19,64-71,109-115). HIGH.
- BC-209 StatusBar.update renders AdapterState→4 colored strings (disconnected secondary / connecting orange / noVideo pink+reason / live green ●W×H@Hz); kbdLabel uppercased name when keyboardOK else "no kbd"; LEDs caps/num/scroll; setMessage clears readouts (:62-92). HIGH.
- BC-210 StatusBar keyboard-type label can trap on rawValue≥3 (array vs closed enum lockstep coupling) (:109-111). MEDIUM (latent).
- BC-211 Floating panels anchor-once present contract: reposition only if !isVisible then orderFront; nonactivating/.floating, hidesOnDeactivate=false, becomesKeyOnlyIfNeeded — main window keeps key focus so physical keyboard still drives target (KeyboardPanel/VideoAdjust/ImageEnhance). HIGH.

## Remaining gaps: ToolbarStrip = no substantive contracts (chrome/HoverTip only); ProfileStore write-error swallow = Pass-4 NFR not a contract; firmwareDir resolution precedence already covered by broad BC-052/053 (boot layer); no tests cover any panel/ProfileStore (all code-derived).
