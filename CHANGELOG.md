# Changelog

## [0.1.2] — 2025-10-29
- Docs synchronized with current implementation:
  - Guide and README reference the “VoiceKit” module directly; removed obsolete upgrade note.
  - Quick starts and API snapshots reflect current models and @MainActor surfaces.
- Core
  - RealVoiceIO: CI fast-path for speak; minimal listen shim honoring RecognitionContext.number.
  - Short-clip path (“clip”): idempotent stop semantics; waiter handling made safe and non-retaining.
  - Trimming: extracted energy-based helper to reduce complexity; pads and bounds clarified.
  - SystemVoicesCache: simple @MainActor cache with stable, name-sorted order.
  - Name utilities: NameResolver and NameMatch tuned for ligatures, diacritics, dash variants, and invisibles.
- UI
  - VoiceChooserView and ChorusLabView refined; VoiceProfilesStore persists profiles, default, tuning, and hidden IDs.
- Tooling and hygiene
  - SwiftLint configuration tightened; explicit ACL across sources; complexity reductions in helpers.

## [0.1.1] — 2025-09-19
- Consolidate docs to match current implementation:
  - Core model: TTSVoiceProfile with rate: Double; pitch/volume: Float
  - UI store tracks hidden IDs separately; sample phrases resolve system names on demand
  - Tests prefer FakeTTS/ScriptedVoiceIO — no reliance on system voices or locale
- Boosted tests use waiter-based implementation; stopClip() cancels/clears waiters
- Concurrency notes clarified for TCC and delegate hops

## [0.1.0] — 2025-09-12
- Initial public extract: VoiceKit and VoiceKitUI
- RealVoiceIO with Swift 6 actor-safety
- ScriptedVoiceIO for tests/demos
- VoiceChooserView + VoiceProfilesStore
- NameMatch utilities
- Package tests: NameMatch and ScriptedVoiceIO
