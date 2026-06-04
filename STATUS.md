# Status

## Current version
v0.2.0 — released 2026-04-05 (on `main`)

## Build health
- **Tests**: 123 passing, 0 failures (`swift test`)
- **SwiftLint**: 0 violations, 0 warnings
- **Swift 6**: clean — no unsafe workarounds beyond `@preconcurrency` on AVFoundation/Speech imports (required by framework)

## Active work
Nothing — on `main`.

## Blocked on
Nothing.

## Known issues / tech debt
- `VoiceOpGate` (VoicePublic.swift) uses a spin-poll with 200μs sleep — not a fairness lock. Fine for current use; not production-grade if hold times grow.
- `extendListen(by:)` spawns an unstructured `Task {}` to hop to `sttActivityTracker` — minor; worth revisiting if the method sees more use.
- Residual `unsafeForcedSync` from `AFPreferences _languageCodeWithFallback` in `AVSpeechSynthesizer` on newer OS: this is Apple's internal Apple Intelligence preferences query; not fixable from VoiceKit code.

## Recently completed
- ✅ Fix: `SFSpeechRecognizer` lazily initialized on first `listen()` — eliminates startup warnings in TTS-only apps (e.g., ChorusLab, VoiceChorus).
- ✅ Fix: `AVSpeechSynthesizer.speak()` dispatched via `DispatchQueue.main.async` — eliminates `unsafeForcedSync` + zero-byte `mBuffers` cascade from calling speak inside a Swift Task context.
- ✅ Tests: `testSpeakFromAsyncContextProducesNonZeroAudioDuration` regression guard added.
- ✅ Core + UI: `@Observable` migration (v0.2.0) — removed six `onXxx` callbacks, replaced with observable properties.
- ✅ Core: `pause(_ seconds:)` + `<silence:N>` inline token in `speak()`.
- ✅ CI detection consolidated in `IsCI.swift`.

## Next up
1. Extract `Demos/ChorusLabApp` into a separate VoiceKitSamples repo (see ROADMAP.md).
