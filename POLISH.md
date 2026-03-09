//
//  POLISH.md
//  VoiceKit
//
//  A frank assessment of what's rough, what's missing, and what I'd do
//  differently. Written from a fresh perspective after a full code review.
//
//  — Claude Sonnet 4.6, March 2026
//

# What's Left to Do

VoiceKit is genuinely well-made. The concurrency discipline is exemplary —
Swift 6 strict isolation, actors in the right places, nonisolated helpers where
the runtime demands it, checked continuations bridged correctly. That's hard to
get right, and it's right here. The test coverage is organic and meaningful.

But GPT built this, and GPT has tells. What follows is what I'd fix.

---

## Bugs (actual correctness issues)

### 1. Numeric parsing silently breaks for multi-digit sequences

**File:** `Sources/VoiceKit/STT/RealVoiceIO+Numeric.swift`

The `commitInt` logic uses `(intValue ?? 0) * 1000 + value`, which was probably
written to eventually handle "thousand" as a shift factor. But "thousand" is
never handled as a token — so this multiplier is currently orphaned scaffolding
that corrupts results.

"forty two" works by accident because tens-branch lookahead catches the "two"
before it becomes a separate token. But "four two" (said as separate digits,
which STT sometimes produces) gives 4002, not 42.

Fix: Replace the `* 1000` accumulation with correct digit composition.
For this use case (voice entry of small numbers), that means summing:
```swift
intValue = (intValue ?? 0) + value   // for ones/teens
intValue = (intValue ?? 0) + tensValue  // then add ones via lookahead
```
Add "hundred" and "thousand" as explicit tokens if you want large numbers. Don't
leave a multiplier floating with no token to trigger it.

Tests needed: "four two", "one hundred", "two hundred three", "one thousand",
"a hundred and one", "negative five" (currently fails gracefully but silently).

---

### 2. `SimpleError` vs. `VoiceIOError` — two error systems, never unified

**Files:** `VoicePublic.swift:26`, `VoiceIOError.swift`, all STT + Boosted code

`VoiceIOError` is the public-facing typed enum: `.micUnavailable`, `.timedOut`,
`.cancelled`, etc. `SimpleError` is a stringly-typed escape hatch. The problem:
every internal throw uses `SimpleError`, so callers who try to catch
`VoiceIOError.micUnavailable` will never see it — they get `SimpleError`
wrapped in the unknown catch-all.

This is an API correctness bug. Callers can't write `catch VoiceIOError.timedOut`
and have it work.

Fix: Replace all internal `SimpleError` throws with the appropriate `VoiceIOError`
case. Keep `SimpleError` only for true one-off edge cases, or remove it entirely
if everything fits in the enum. Add a test that catches `VoiceIOError.micUnavailable`
specifically to lock in the behavior.

---

### 3. Unconditional `print` in production TTS code

**File:** `Sources/VoiceKit/TTS/RealVoiceIO+TTSImpl.swift:154`

```swift
// Also print so Xcode Previews shows it even if the logger is muted
print("[VoiceKit]", trace)
```

This fires on every utterance in production apps. Every. Single. Utterance.
The comment reveals intent (Xcode Previews debugging), but the solution is wrong.
Previews have their own lifecycle; leaving a print statement for them is not
the answer.

Fix: Gate on `IsCI.running` or check for a Previews environment variable, or
simply remove it. The logger exists for this. If preview visibility is valuable,
add it to the preview-specific path only.

---

## Design Rough Edges

### 4. `master` is the wrong name for a published property

**File:** `Sources/VoiceKitUI/Stores/VoiceProfilesStore.swift:73`

```swift
@Published public var master: Tuning = .init()
```

There's even a comment acknowledging the problem: "Proxies to 'master' until
the persistence and API are renamed." So the proxy exists. The rename was planned
but never happened. This is a one-grep fix.

```bash
grep -rn "\.master\b\|var master\b" Sources/
```

Rename `master` → `tuning` throughout. Delete the proxy. The persistence key
is `tuning` already (from the Codable model), so the rename is purely internal.

---

### 5. `SeamsLive.swift` is misnamed and misplaced

**File:** `Sources/VoiceKit/STT/SeamsLive.swift`

This file defines `BoostedNodesProvider` and `LiveBoostedNodesProvider`. Neither
is STT-related. Neither is a "seam" in any architectural sense that the rest of
the codebase uses. The file sits in the STT folder, defines TTS clip infrastructure,
and is named after a concept that isn't used consistently elsewhere.

Fix: Move the protocol into `RealVoiceIO+Boosted.swift` (where it's actually used),
or into a `BoostedNodesProvider.swift` file in the TTS folder. Delete SeamsLive.swift.

---

### 6. `BoostedNodesProvider` is vestigial — the seam abstraction was never built out

**File:** `Sources/VoiceKit/TTS/RealVoiceIO+Boosted.swift`

The `BoostedNodesProvider` protocol exists, `LiveBoostedNodesProvider` implements
it with empty stubs (`reset()` does nothing, `live()` returns an instance that
does nothing). The static dictionaries used for per-instance state (`Self.boostedProviders`,
`Self.clipWaiters`, etc.) bypass this provider entirely.

The provider was probably scaffolding for dependency injection that was never
completed. As-is, it adds surface area without providing value.

Fix: Either finish the seam (actually route boosted node creation through it,
making the code testable without real audio hardware), or remove it. Half-abstractions
are worse than none because they imply testability that isn't there.

---

### 7. Rate semantics are undocumented and confusing

**File:** `Sources/VoiceKit/Public/VoicePublic.swift` and `RealVoiceIO+TTSImpl.swift`

`TTSVoiceProfile.rate` is documented as normalized 0...1, but:
- Default rate in VoiceProfilesStore is 0.55 (not 0.5, with no explanation)
- `applyProfile()` maps 0...1 → system rate range (non-linear)
- `Tuning.rateVariation` is also normalized but represents a delta, not a rate

The relationship between these is only understandable by reading `applyProfile()`.
Add a doc comment to `TTSVoiceProfile` explaining: what 0 means (slowest), what 1
means (fastest), what the default of 0.55 represents (slightly above midpoint
because that's conversational pace for most voices), and how variation interacts.

---

### 8. Recording cleanup is never done

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift`, `RealVoiceIO+Trimming.swift`

When `record: true` is passed to `listen()`, a `.caf` file is written to the
temp directory. If trimming succeeds, a second `.trim.caf` file is created. The
original `.caf` is never deleted. Neither file is deleted on `hardReset()`.

On long-running apps (like voice assistants), this accretes temp files indefinitely.

Fix: Track the raw and trimmed URLs in `completeCurrentListen()`. Delete the raw
recording after the trimmed file is confirmed. Add cleanup to `hardReset()`.
Use `defer` blocks in trimming helpers to clean up on failure.

---

## Missing Things That Should Exist

### 9. No cancellation story for the STT inactivity timer

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift`

`startInactivityTimer()` polls every 250ms and fires `completeCurrentListen()`
when silence exceeds the threshold. But there's no way to extend or reset the
timer from outside (e.g., if the caller wants to restart the timer when they know
the user is pausing to think, not finishing). The activity tracker updates it
internally, but the polling interval and the lack of a public "I know they're
not done" API means this is a black box.

Consideration: Add `extendListen(by:)` or allow the inactivity timeout to be 0
(documented as "no timeout" — which it already does). What's missing is a way
for callers to signal intent without cancelling.

---

### 10. `VoiceTempoCalibrator` has no tests

**File:** `Sources/VoiceKit/TTS/VoiceTempoCalibrator.swift`

Used by ChorusLab (an external app), but has zero tests in this package. The
calibration algorithm is non-trivial (iterative proportional control). It's also
the kind of thing that could silently regress — if the rate mapping changes, the
calibrator could overshoot indefinitely.

Fix: Add a `VoiceTempoCalibrator` test using `ScriptedVoiceIO` with a
`speakAndMeasure` shim that returns deterministic timing. Test convergence,
cancellation mid-loop, and the zero-measurement safety path.

---

### 11. No way to get voices synchronously for UI tests

**File:** `Sources/VoiceKitUI/VoiceChooserViewModel.swift`

`refreshAvailableVoices()` is async and calls `SystemVoicesCache.refresh()`.
In tests, if `tts` is a `VoiceListProvider`, voices are loaded synchronously.
But the `allowSystemVoices: true` path has no test seam — tests that pass a
`ScriptedVoiceIO` which isn't a `VoiceListProvider` will still hit the live path.

The `VoiceListProvider` protocol exists but isn't consistently exploited.
VoiceChooserViewModel should check `tts is VoiceListProvider` or take a
`voicesProvider` in its init rather than baking in both paths inline.

---

### 12. `VoiceIOConfig` fields could use validation

**File:** `Sources/VoiceKit/Public/VoiceIOConfig.swift`

`trimPrePad` and `trimPostPad` accept any `Double`. A negative pad, an NaN, or
a value of 100 seconds will silently produce malformed output. `clipWaitTimeoutSeconds`
accepts 0 (which might mean "infinite" or might mean "immediate timeout" — unclear).

These are configuration values passed by users of the library. Add guards at
the `RealVoiceIO(config:)` init boundary: clamp pads to reasonable ranges,
reject NaN/infinite values, document what 0 means for each field.

---

## Code Smell

### 13. `RealVoiceIO+Boosted.swift` uses static dictionaries keyed by ObjectIdentifier

This is the standard Swift pattern for extending behavior per-instance in an
extension without stored properties. It works but it has a cost: instances hold
memory permanently unless explicitly cleaned up. `hardReset()` calls `Self.cleanup(id:)`
but if an instance is deallocated without calling `hardReset()`, the entries remain.

A better pattern for Swift 6: use `@MainActor` stored properties on a class
directly, or consolidate the state into an inner helper type. The extension
constraint (no stored properties) was the original reason for static dicts, but
breaking things into extensions primarily for line count isn't a good reason.
Consider consolidating `RealVoiceIO+Boosted.swift` state into `RealVoiceIO.swift`
as real stored properties.

---

### 14. `handleRecognitionSuccess` fires a `Task { @MainActor in }` from a non-isolated context

**File:** `Sources/VoiceKit/STT/RealVoiceIO+STT.swift`

The recognizer callback is not isolated to any actor. It calls:
```swift
Task { @MainActor in self.updateSpeechSegments(segments) }
```

This works, but it means segment updates are deferred to the next main-actor
scheduling slot — there can be races between the inactivity timer (also async)
and the segment update. In practice it probably doesn't matter, but the pattern
is fragile and non-obvious to anyone reading the code later.

Fix: If `handleRecognitionSuccess` must be called from a non-isolated context,
annotate it as such and use `MainActor.run` with explicit priority. Or make the
whole callback `@MainActor` by restructuring how the recognition task is set up.

---

### 15. Language filter and voice loading are tightly coupled in ViewModel

**File:** `Sources/VoiceKitUI/VoiceChooserViewModel.swift`

`filteredVoices` is a computed property that filters on `languageFilter`, `hiddenVoiceIDs`,
and `showHidden`. This is computed fresh on every access. Fine for a small list
of system voices, but it means every SwiftUI property access (including during
layout) triggers the full filter pass.

Cache `filteredVoices` as a `@Published` property and rebuild it only when
`voices`, `languageFilter`, `showHidden`, or `hiddenVoiceIDs` change. This is
also easier to test — you can assert on the cached result rather than calling
the computed property.

---

## What GPT Does That I'd Do Differently

These aren't bugs — they're stylistic and architectural choices where GPT tends
toward one pattern and I'd reach for another.

**GPT favors long doc comments on every method.** Many of these explain the
*what* (which is evident from the method name) rather than the *why* (which is
where comments earn their keep). I'd prune the obvious ones and expand the
non-obvious ones. The best comment in this codebase is the nonisolated tap
closure explanation in `installRecognitionTap` — that's a *why* comment that
saves the next reader real time.

**GPT favors explicit type annotations everywhere.** `@State private var selectedIDString: String = ""`
would be `@State private var selectedIDString = ""` with me — which is now in
the code, but only after SwiftLint demanded it. Verbose type annotations are
a crutch when the value makes the type obvious.

**GPT initializes things in a flat, sequential style.** I prefer to let the
compiler infer as much as possible and use the initializer as documentation of
intent, not a transcript of every assignment. The `VoiceChooserView` initializer
consolidation fight we had during this session is a good example — the original
GPT version repeated the same 8-line `StateObject(wrappedValue: VoiceChooserViewModel(...))`
block four times. Swift's delegating initializer pattern (which does work) would
have been my first instinct.

**GPT writes wide functions with many concerns.** The `performSTTListen` refactor
in this session extracted helpers well, but the original had thirteen separate
things happening in one function body. My instinct is to extract earlier — before
lint forces it. The extraction reveals structure; lint just enforces the outcome.

**GPT doesn't clean up its own scaffolding.** `SeamsLive.swift`, the `boostWaiters`
setter, the `master` proxy, the `* 1000` multiplier in numeric parsing — all of
these are scaffolding that was never finished or removed. GPT is good at building
things but has a gap in the "is this still needed?" loop. That's a context window
problem as much as a capability one, but it's real.

---

## Priority Order (if I were doing it)

1. **Fix `SimpleError` → `VoiceIOError`** — Correctness bug. Callers can't handle errors.
2. **Fix numeric parsing `* 1000` logic** — Correctness bug. Wrong answers in production.
3. **Remove the `print` in TTSImpl** — Logging noise in every production app.
4. **Rename `master` → `tuning`** — One grep, no design decisions required.
5. **Add recording file cleanup** — Resource leak. Slow-motion, but real.
6. **Delete `SeamsLive.swift`** — Move `BoostedNodesProvider` to its real home or remove it.
7. **Cache `filteredVoices`** — Performance and testability improvement.
8. **Document `TTSVoiceProfile.rate` semantics** — Saves confusion for every future caller.
9. **Test `VoiceTempoCalibrator`** — Untested non-trivial algorithm.
10. **Fix numeric parsing to support hundreds/thousands** — Completeness.

---

*This file was written by Claude Sonnet 4.6 as a code review artifact.*
*It doesn't replace the existing ROADMAP.md or todo.md — those cover features.*
*This covers quality. They're different things.*
