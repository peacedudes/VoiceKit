# Status

## Current version
v0.1.3 — released 2025-12-05

## Build health
- **Tests**: 115 passing, 0 failures (`swift test`)
- **SwiftLint**: 0 violations, 0 warnings
- **Swift 6**: clean — no unsafe workarounds beyond `@preconcurrency` on AVFoundation/Speech imports (required by framework)

## Active work
None. Package is stable at 0.1.3.

## Blocked on
Nothing.

## Known issues / tech debt
- `VoiceOpGate` (VoicePublic.swift) uses a spin-poll with 200μs sleep — not a fairness lock. Fine for current use; not production-grade if hold times grow.
- `extendListen(by:)` spawns an unstructured `Task {}` to hop to `sttActivityTracker` — minor; worth revisiting if the method sees more use.

## Recently completed
- ✅ Fix: QoS priority inversion in AVSpeechSynthesizer delegate callbacks — `Task { @MainActor in }` defaulted to Default QoS and could block the User-interactive main actor waiting for continuations; all three delegate methods now use `Task(priority: .userInteractive) { @MainActor in }`
- ✅ Core: `pause(_ seconds:)` method + `<silence:N>` inline token in `speak()`
- ✅ Fix: cooperative task cancellation in `speakSentence` and `speak()`
- ✅ VoiceChooserView: commits only on Choose button (not on picker change)
- ✅ API: callbacks renamed to `onSpeakingChanged`, `onPulseChanged`
- ✅ Tests: edge-case coverage for trimming, SFX parsing, listen state
- ✅ CI detection consolidated in `IsCI.swift`

## Next up
1. Extract `Demos/ChorusLabApp` into a separate VoiceKitSamples repo (see ROADMAP.md)
