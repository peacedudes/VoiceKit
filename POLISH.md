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

---

## Outstanding Issues

### 1. `BoostedNodesProvider` uses static dictionaries with ObjectIdentifier keys

**File:** `Sources/VoiceKit/TTS/RealVoiceIO+Boosted.swift`

The `BoostedNodesProvider` protocol exists but its implementation (`LiveBoostedNodesProvider`)
is a stub. Actual state is stored in static dictionaries keyed by `ObjectIdentifier(self)`,
which is the pre-Swift 6 pattern for per-instance state in extensions.

This works but has two problems:
1. Memory is held indefinitely unless explicitly cleaned up via `cleanup(id:)`
2. If an instance is deallocated without calling `hardReset()`, dict entries remain

**Better approach:** Either finish the provider seam (route all state through it,
making it properly testable), or consolidate the static dicts into real `@MainActor`
stored properties on `RealVoiceIO` itself.

---

### 2. `VoiceIOConfig` documents missing validation but doesn't implement it

**File:** `Sources/VoiceKit/Public/VoiceIOConfig.swift`

The init warns: "No validation is performed. Negative, NaN, or infinite values will
cause undefined behavior." Users passing untrusted values (from UI, config files, etc.)
are expected to validate themselves, which puts the burden in the wrong place.

Fix: Add guards in the init. Clamp pads to reasonable ranges, reject NaN/infinite,
document what 0 means for timeout fields.

---

### 3. `handleRecognitionSuccess` uses `Task { @MainActor in }` from nonisolated context

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift:247`

The speech recognizer callback is not isolated. It defers segment updates to the next
main-actor scheduling slot, creating a potential race with the inactivity timer. Works
in practice, but fragile and non-obvious.

Fix: Annotate `handleRecognitionSuccess` as nonisolated, then use `MainActor.run`
with explicit priority, or restructure the callback setup to be `@MainActor` directly.

---

### 4. `filteredVoices` in VoiceChooserViewModel is computed, not cached

**File:** `Sources/VoiceKitUI/VoiceChooserViewModel.swift:75`

Computed property filters voices on every access. Fine for small lists, but means
every SwiftUI property read (including during layout) triggers the full filter pass.

Fix: Cache `filteredVoices` as a `@Published` property. Rebuild only when `voices`,
`languageFilter`, `showHidden`, or `hiddenVoiceIDs` change. Easier to test and
more efficient.

---

### 5. No public API to extend STT inactivity timeout mid-listen

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift`

`startInactivityTimer()` fires at a fixed interval with no way for callers to signal
"user is pausing to think, not finishing." The activity tracker updates internally,
but there's no public `extendListen(by:)` method.

Fix: Add public `extendListen(by:)` to defer the timeout, or document that passing
0 as the inactivity timeout disables the timer entirely (allowing app-level control).

---

### 6. Punctuation normalization flattens voice inflection (workaround, not solution)

**File:** `Sources/VoiceKit/TTS/RealVoiceIO+TTSImpl.swift`

AVSpeechSynthesis resets rate/pitch adjustments after `.!?`, breaking calibration.
Current fix normalizes punctuation to commas, preserving rate but removing inflection.
Voices sound flat because `.` (falling), `!` (emphasis), `?` (rising) are semantic.

**Better approach:** Split utterances at sentence boundaries, speak sequentially while
maintaining voice profile across all. Each sentence keeps its punctuation and inflection;
rate calibration persists.

Fix: Extract sentence-splitting logic, queue utterances with profile preservation,
manage as a single "logical utterance" from caller's perspective.

---

## Priority Order (if tackling these)

1. **Replace punctuation normalization with sentence splitting** — Better voice quality.
2. **Cache `filteredVoices` as @Published** — Performance and testability.
3. **Add `VoiceIOConfig` validation** — Catch errors at boundary, not at runtime.
4. **Consolidate `BoostedNodesProvider` state** — Either finish the seam or use stored properties.
5. **Add `extendListen(by:)` to STT** — Improve timer control.
6. **Fix `handleRecognitionSuccess` isolation** — Use `MainActor.run` instead of deferred Task.

---

*Maintained by rdoggett & Claude, March 2026*
*This covers polish and quality. See ROADMAP.md for features.*
