# Decisions

Architectural choices and why. Prevents re-litigating them every session.

---

## RealVoiceIO is `@MainActor class`, not an `actor`

AVFoundation delegate callbacks (`AVSpeechSynthesizerDelegate`) are nonisolated entry points.
Using a custom actor would require explicit hops in every delegate method for no practical gain —
we're already serializing on the main actor, which is what all SwiftUI callers are on anyway.
`@MainActor` keeps the API straightforward.

**How it holds**: The audio tap callbacks are explicitly `nonisolated` and never touch `@MainActor`
state directly. They write into `STTActivityTracker` (an actor) and the recognition request only.

---

## Simulator is treated as CI for live STT

Many simulator/runtime combinations fail reliably with `kAFAssistantErrorDomain` errors when
`SFSpeechRecognizer` + `AVAudioEngine` are combined. Rather than let tests and demos flake on
simulator, the live STT path is bypassed there and the CI stub is used instead.

Real devices use the full live pipeline. `VOICEKIT_FORCE_CI=false` overrides this if needed.

---

## ScriptedVoiceIO instead of protocol mocks for tests

Protocol mocks are brittle: they break when the protocol evolves and test call-patterns rather
than behavior. `ScriptedVoiceIO` is a real, deterministic `VoiceIO` implementation with scripted
inputs. Tests are robust to refactors and exercise real state transitions.

---

## SFX token syntax: `<sfx:URL>` in speak(), `<sfx:NAME>` in VoiceQueue

Two separate systems:
- `speak()` resolves `<sfx:URL>` tokens with direct file URLs. No resolver function needed.
- `VoiceQueue.enqueueParsingSFX()` resolves `<sfx:NAME>` tokens via a caller-supplied `(String) -> URL?` resolver.

Angle-bracket syntax is unlikely to appear in normal spoken text, making false positives rare.
The two systems are intentionally different — speak() is the simple path, VoiceQueue is the
orchestration path.

---

## Sentence splitting in speak() (replaced punctuation normalization)

`speak()` splits text at `.`, `!`, `?` boundaries before synthesis. This replaced an earlier approach
of normalizing punctuation characters.

`AVSpeechSynthesizer` applies different prosody at sentence boundaries. Splitting into sentences
ensures SFX tokens play at the right moment and that intonation resets correctly between sentences.
Commit: `TTS: Replace punctuation normalization with sentence splitting`.

---

## VoiceOpGate uses a spin-poll

`VoiceOpGate` busy-waits with `Task.sleep(nanoseconds: 200_000)` rather than using a
continuation-based suspension queue. The gate is never held for more than a few milliseconds in
current usage, so the simple poll was sufficient and easier to reason about.

This is not production-grade. If VoiceOpGate ever guards operations with longer hold times,
replace with a proper continuation queue.

---

## ChorusLabApp lives in Demos/ (inside this repo)

Convenient during active ChorusLab development to keep the demo co-located with the package for
rapid iteration. Extracting to a separate repo adds overhead that wasn't worth it while the demo
was changing frequently.

**Plan**: Extract to VoiceKitSamples repo per ROADMAP.md once the demo stabilizes.
