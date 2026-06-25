# Pass 2+3 Deepening Round 3 (Convergence Check)  [Novelty: NITPICK — CONVERGED]

Sole carryover: confirm firmware-directory resolution precedence in the boot path vs BC-052/053.

## Finding: CONFIRMATION (not model-changing)
StarTechAdapter.boot(): `profile.map { loadFPGABitstream(profile:$0) } ?? loadFPGABitstream(generation:)`. Profile path sets extra=[profile.firmwareDir] and delegates to searchDirectories(extra:). Exact precedence:
1. profile.firmwareDir (per-profile override) FIRST
2. OCC_FIRMWARE_DIR
3. ProfileStore.firmwareDirectory
4. applicationSupportFirmwareDir
5. vendor fallbacks (/Applications/USB Crash Cart Adapter.app/.../data, ~/data, ~/Library/Application Support/USB Crash Cart Adapter/data)
Matches BC-052/053 EXACTLY (order + locations + profile-aware boot routing). No missing location.

Doc/impl drift (pre-existing, non-model-changing): StarTechFirmware header comment lists a narrower 3-tier order vs the 5-tier implementation; BC-052/053 already documents the implementation.

No-profile fallback uses loadFPGABitstream(generation:) with empty extra + generation file-order (gen≥2 ["ulcvm.fgz","usbip.fgz"] else reversed) — file ordering not directory precedence; already implicit in BC-052/053.

## Delta: 0 new contracts, 0 corrections (BC-052/053 confirmed), 0 new entities/flows, 0 remaining carryover.
## Novelty Assessment: NITPICK. Pass 2 + Pass 3 CONVERGED.
