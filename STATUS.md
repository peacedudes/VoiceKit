# Status

## Current version
v0.1.3 — released 2025-12-05

## Build health
- **Tests**: 109 passing, 0 failures (`swift test`)
- **SwiftLint**: 0 violations, 0 warnings
- **Swift 6**: clean — no unsafe workarounds beyond `@preconcurrency` on AVFoundation/Speech imports (required by framework)

## Active work
None. Package is stable at 0.1.3.

## Blocked on
Nothing.

## Known issues / tech debt
- `Docs/Concurrency.md` uses old callback names (`onTTSSpeakingChanged`, `onTTSPulse`) — renamed to `onSpeakingChanged`, `onPulseChanged` in commit 4955519. Doc not updated.
- `VoiceOpGate` (VoicePublic.swift) uses a spin-poll with 200μs sleep — not a fairness lock. Fine for current use; not production-grade if hold times grow.
- `extendListen(by:)` spawns an unstructured `Task {}` to hop to `sttActivityTracker` — minor; worth revisiting if the method sees more use.

## Recently completed
- ✅ VoiceChooserView: commits only on Choose button (not on picker change)
- ✅ API: callbacks renamed to `onSpeakingChanged`, `onPulseChanged`
- ✅ Tests: edge-case coverage for trimming, SFX parsing, listen state
- ✅ CI detection consolidated in `IsCI.swift`
- ✅ Code review scaffolding and stale handoff docs removed

## Next up
1. Extract `Demos/ChorusLabApp` into a separate VoiceKitSamples repo (see ROADMAP.md)
2. Fix `Docs/Concurrency.md` callback name mismatch
