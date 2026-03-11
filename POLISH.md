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

---

## Outstanding Issues

### 1. `handleRecognitionSuccess` uses `Task { @MainActor in }` from nonisolated context

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift:247`

The speech recognizer callback is not isolated. It defers segment updates to the next
main-actor scheduling slot, creating a potential race with the inactivity timer. Works
in practice, but fragile and non-obvious.

Fix: Annotate `handleRecognitionSuccess` as nonisolated, then use `MainActor.run`
with explicit priority, or restructure the callback setup to be `@MainActor` directly.

---

### 2. `filteredVoices` in VoiceChooserViewModel is computed, not cached

**File:** `Sources/VoiceKitUI/VoiceChooserViewModel.swift:75`

Computed property filters voices on every access. Fine for small lists, but means
every SwiftUI property read (including during layout) triggers the full filter pass.

Fix: Cache `filteredVoices` as a `@Published` property. Rebuild only when `voices`,
`languageFilter`, `showHidden`, or `hiddenVoiceIDs` change. Easier to test and
more efficient.

---

### 3. No public API to extend STT inactivity timeout mid-listen

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift`

`startInactivityTimer()` fires at a fixed interval with no way for callers to signal
"user is pausing to think, not finishing." The activity tracker updates internally,
but there's no public `extendListen(by:)` method.

Fix: Add public `extendListen(by:)` to defer the timeout, or document that passing
0 as the inactivity timeout disables the timer entirely (allowing app-level control).

---

## Priority Order (if tackling these)

1. **Cache `filteredVoices` as @Published** — Performance and testability.
2. **Add `extendListen(by:)` to STT** — Improve timer control.
3. **Fix `handleRecognitionSuccess` isolation** — Use `MainActor.run` instead of deferred Task.

---

*Maintained by rdoggett & Claude, March 2026*
*This covers polish and quality. See ROADMAP.md for features.*
