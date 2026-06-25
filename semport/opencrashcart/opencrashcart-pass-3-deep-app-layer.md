# Pass 3 Deep — App/UI Layer Behavioral Contracts (round 1)  [Novelty: SUBSTANTIVE]

No app-layer tests exist (occ-tests covers only Gunzip/Profile/TileDecoder/Typing/Protocol/Keymap). All BC-100..143 are MEDIUM (from code) — promoted untested contracts with exact refs.

## AppController lifecycle (Sources/occ/AppController.swift)
- BC-100 tryConnect idempotent under guard adapter==nil && !connecting (:173-174).
- BC-101 no device → clean state + .noAdapter; next rescan retries (:176-178).
- BC-102 success → connecting=true through whole async handshake, cleared after connect() returns (:180-188).
- BC-103 connect throw → full reset (connecting=false, adapter=nil, status, .noAdapter) (:189-194).
- BC-104 2s rescan timer = sole auto-reconnect driver; first connect once synchronously (:126-129).
- BC-105 OCC_SECONDS → unconditional auto-quit NSApp.terminate (:130-134).
- BC-106 applicationWillTerminate cancels eventTask + fire-and-forget disconnect (NOT awaited — risk) (:139-143).
- BC-107 .disconnected re-arms rescan loop; resets didAutoSize (:268-274).
- BC-108 live status auto-sizes window exactly once/session (didAutoSize latch) (:256-259, sizing :603-624).
- BC-109 device adjustments cached not pushed to live sliders (:248-255, applied on open :543).
- BC-110 UVC menu connect tears down prior adapter first (:218-239).
- BC-111 UVC submenu lazily populated on open; empty→disabled item (:200-216).
- BC-112 Reconnect forces immediate rediscovery; Disconnect resets but rescan re-connects within 2s (subtlety) (:397-407).
- BC-113 Settings onChange → menuReconnect (profile/firmware edits apply w/o restart) (:472).
- BC-114 Ctrl-Alt-Del/Windows(0xE3)/Escape(0x29) direct chords; no-op if adapter nil (:438-440).
- BC-115 Paste gated non-empty clipboard; count-correct pluralization (:416-423).
- BC-116 Type-Text types on first button; empty field still typeText("") — asymmetric w/ Paste (:425-437).
- BC-117 on-screen chord: mods down(order)→key down→key up→mods up(reverse), allReleased on final (:579-590).
- BC-118 relative-mouse toggle syncs menu state + view + status from one source (:454-461).

## VideoView input/OCR/key-safety (Sources/occ/VideoView.swift)
- BC-119 absolute mouse letterbox-aware; pixel max fw-1/fh-1; clamp to edge over bars (:296-309).
- BC-120 relative mode rounded clamped Int16 deltas (:289-293).
- BC-121 buttons from global pressedMouseButtons; wheel ±1/0 (:283-287, 276-279).
- BC-122 mouse suppressed entirely while selecting OCR region (:254-273,282).
- BC-123 OCR selection → clamped floor/ceil pixel crop of RAW frame; <3pt/<4px → nil; defer endRegionSelection (:164-188).
- BC-124 Esc cancels selection; selection swallows all keys (:190-194,151-158).
- BC-125 enhancement display-only; snapshot+OCR use raw frame; isActive gate (:45-47,96-123).
- BC-126 releaseAllKeys on focus loss + resignFirstResponder (snapshot keysDown, allReleased:true) (:223-241).
- BC-127 Command-modified presses not forwarded; keyUp always forwarded (:195-208).
- BC-128 flagsChanged guards isModifier (avoids stray 'A' keyCode-0) (:210-219).

## SettingsWindow (Sources/occ/SettingsWindow.swift)
- BC-129 empty name aborts save (:228-229).
- BC-130 CSV split/trim/filter; firmware default ["ulcvm.fgz"]; VID stored raw string no hex-validation here (gap) (:230-241).
- BC-131 new vs edited id/backend/builtIn provenance (id custom-+uuid8, backend dmtz-vsp, builtIn false) (:233-241).
- BC-132 built-in not deletable in UI (:139-148).
- BC-133 live USB-presence dot; enumeration failure→all-gray (:110-125).
- BC-134 firmware import copies into App Support + repoints dir; silent try? (partial-failure risk) (:184-203).

## Recorder (Sources/occ/Recorder.swift)
- BC-135 drops size-mismatch frames (no corrupt mov) (:38-39).
- BC-136 lazy session start first accepted frame, real-time PTS @600 (:41-49,62-64).
- BC-137 init fails closed if writer/canAdd fail → "Could not start recording" (:18-36).
- BC-138 finish short-circuits frameCount=0 if never started (:67-72).
- BC-139 record start requires isLive && frameSize.width>0; dims locked at start (:493-515).

## OCR (Sources/occ/OCR.swift)
- BC-140 runs off main, .accurate, usesLanguageCorrection=false; swallowed perform error → no callback (stuck "Reading…" status, gap) (:7-24).
- BC-141 observations ordered top→bottom then left→right (0.012 band), newline-joined (:11-19).
- BC-142 handleOCR trims, clipboard only on non-empty; cancel/empty paths untouched (:639-665).
- BC-143 OCR entry requires isLive (:639-646).

## Surfaced risks (→ Pass 4/6): non-awaited disconnect on terminate (BC-106); Disconnect auto-undone by rescan (BC-112); silent try? firmware copy (BC-134); no VID/PID hex validation at Settings (BC-130); swallowed Vision error stuck status (BC-140); Type-Text types empty where Paste guards (BC-116 vs BC-115).

## Remaining gaps / next scope: ToolbarStrip/StatusBar/KeyboardPanel/VideoAdjustPanel/ImageEnhancePanel/PlaceholderView per-control contracts (slider ranges/clamping, status rendering, KeyboardPanel sticky-modifier feeding BC-117); Theme padding state machine + resizeToVideo multi-monitor edge cases; DDCPreset round-trip; ProfileStore persistence contracts.
