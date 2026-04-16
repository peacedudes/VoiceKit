# Status

## Current version
v0.1.3 — released 2025-12-05

## Build health
- **Tests**: 115 passing, 0 failures (`swift test`)
- **SwiftLint**: 0 violations, 0 warnings
- **Swift 6**: clean — no unsafe workarounds beyond `@preconcurrency` on AVFoundation/Speech imports (required by framework)

## Active work
`feature/observable-v0.2` branch — `@Observable` migration in progress (VoiceKit + VoiceKitUI).

## Blocked on
Nothing.

## Known issues / tech debt
- `VoiceOpGate` (VoicePublic.swift) uses a spin-poll with 200μs sleep — not a fairness lock. Fine for current use; not production-grade if hold times grow.
- `extendListen(by:)` spawns an unstructured `Task {}` to hop to `sttActivityTracker` — minor; worth revisiting if the method sees more use.

## Recently completed
- ✅ Core + UI: `@Observable` migration — removed six `onXxx` closure callbacks from `VoiceIO`; replaced with observable properties (`isSpeaking`, `isListening`, `transcript`, `audioLevel`, `pulse`, `statusMessage`). `VoiceProfilesStore` and `VoiceChooserViewModel` migrated; `VoiceChooserView` updated to `@State`.
- ✅ Fix: TTS delegate hops use `Task(priority: .high)` — replaces deprecated `.userInteractive`
- ✅ Core: `pause(_ seconds:)` method + `<silence:N>` inline token in `speak()`
- ✅ Fix: cooperative task cancellation in `speakSentence` and `speak()`
- ✅ VoiceChooserView: commits only on Choose button (not on picker change)
- ✅ Tests: edge-case coverage for trimming, SFX parsing, listen state
- ✅ CI detection consolidated in `IsCI.swift`

## Next up
1. Merge `feature/observable-v0.2` → `main`; tag v0.2.0
2. Extract `Demos/ChorusLabApp` into a separate VoiceKitSamples repo (see ROADMAP.md)
