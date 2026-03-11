//
//  POLISH.md
//  VoiceKit
//
//  Remaining work to reach "pristine" state.
//  Items marked DONE have been completed; only outstanding issues remain.
//
//  — rdoggett & Claude Haiku, March 2026
//

# What's Left to Do

VoiceKit is well-made and thoroughly tested. Most of the rough edges identified
in the initial review have been addressed. What follows is what remains.

---

## Completed (no action needed)

✓ Numeric parsing — fixed accumulation logic; added hundred/thousand/million support
✓ Unconditional `print` statements — removed from TTSImpl
✓ `master` property — renamed to `tuning` throughout
✓ `SeamsLive.swift` — deleted; `BoostedNodesProvider` moved to TTS
✓ Rate semantics documentation — clarified in VoicePublic.swift
✓ Recording file cleanup — raw recordings deleted after trimming
✓ `VoiceTempoCalibrator` tests — 10-test comprehensive suite added
✓ SimpleError → VoiceIOError — unified to typed error handling
✓ `BoostedNodesProvider` consolidation — all state now @MainActor stored properties on RealVoiceIO (no static dicts)
✓ `VoiceIOConfig` validation — NaN/infinite/negative values clamped to safe ranges; no more undefined behavior
✓ Punctuation normalization → sentence splitting — split at `.!?`, speak sequentially, preserves inflection and rate calibration
✓ STT inactivity timeout extension — `extendListen(by:)` public API defers timeout via activity tracker
✓ `filteredVoices` caching — computed property sufficient; performance negligible for typical voice lists
✓ `handleRecognitionSuccess` isolation — marked `nonisolated`, uses `MainActor.run` explicitly instead of deferred Task

---

## Outstanding Issues

*All polish issues have been addressed.*

---

*Maintained by rdoggett & Claude, March 2026*
*This covers polish and quality. See ROADMAP.md for features.*
