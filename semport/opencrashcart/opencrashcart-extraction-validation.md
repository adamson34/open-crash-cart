# Phase B.6 Extraction Validation — OpenCrashCart  [Result: PASS / TRUST]

## Phase 1 — Behavioral verification (26 BCs + 5 entities sampled, ~28% of contracts)
| Pass | Checked | Confirmed | Inaccurate | Hallucinated |
|---|---|---|---|---|
| 1 Architecture | 2 | 2 | 0 | 0 |
| 2 Domain | 7 | 7 | 0 | 0 |
| 3 Behavioral | 26 | 25 | 1 | 0 |
| 4 NFR/Panels | 5 | 5 | 0 | 0 |

Confirmed (read at cited lines): BC-001/002 (VSP packing + be16 -5→0xFFFB), BC-011/012/013 (tile RGB565→BGRA, 516B record, absolute addressing), BC-030/033 (keymap, "Hi!" strokes), BC-040 (CH9329 checksums 0x0C/0x5D), BC-052 (firmware order), BC-054 (FPGA 507B framing), BC-070/071/200/201/205 (profiles: parse, match, self-heal, built-in-protect, fail-closed), BC-100/108/112 (tryConnect guard, auto-size-once, Reconnect-vs-Disconnect subtlety), BC-119/126/128 (letterbox pixel max fw-1, releaseAllKeys, flagsChanged guard), BC-135/136/137 (Recorder drop/lazy-PTS/fail-closed), BC-140/141 (OCR config + ordering), BC-206 (Theme dual clamp), BC-209/210 (StatusBar render + latent OOB), BC-208 (VideoAdjust tick-quantized). Entities CONFIRMED: VideoFrame, HIDKeyEvent (modifiers always 0), DDCPreset (4 cases), VSProtocol Endpoint, ImageEnhancement (in VideoView not OCCKit).

### One inaccuracy
BC-031: claimed Command 0x37/0x36 unmapped as HIGH. Only 0x37 is test-pinned; 0x36 confirmed by code comment (HIDKeymap.swift:50) not test. Substance CORRECT (both unmapped); confidence for the 0x36 half corrected to MEDIUM.

## Phase 2 — Metric verification (52 numeric claims, independent find/wc/grep recount)
ALL 52 verified with ZERO delta: 45 files / 4764 LOC; per-area LOC (OCCKit 2134/22, occ 2285/13, StarTech 1029/7, UVC 311/4, etc.); largest files (AppController 666, StarTechAdapter 435, VideoView 332, SettingsWindow 297, TileDecoder 203, ToolbarStrip 198, UVCAdapter 180, KeyboardPanel 173); fpgaBlockSize 507; tile 1920×1600/16/120×100; DDCPreset 4; 5 OCC_* env vars; endpoints 0x82/0x83/0x04/0x85; Theme 14/40/96; ImageEnhance sliders -50..50/50..200/0..100; VideoAdjust 0-15/0-31/-30..30; Recorder PTS 600; OCR band 0.012; PID 0x8463→gen2; occ-connect OCC_SECONDS default 20s.

## Summary
- BCs sampled: 26/~140 (+5 entities). Confirmed 25, Inaccurate 1 (confidence-grade only), Hallucinated 0.
- Metrics: 52/52 verified, 0 delta. No inflation.
- Refinement iterations: 1/3.
- Behavioral accuracy 96% exact / 100% substantively correct; metric accuracy 100%; overall ~98%.
- **Result: PASS — recommendation TRUST.** No hallucinated functions/modules/metrics.
