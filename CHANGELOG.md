# Changelog

## [0.1.1] — 2025-09-19
- Consolidate docs to match current implementation:
  - Core model: TTSVoiceProfile with rate: Double; pitch/volume: Float
  - UI store tracks hidden IDs separately; sample phrases resolve system names on demand
  - Tests prefer FakeTTS/ScriptedVoiceIO — no reliance on system voices or locale
- Boosted tests use waiter-based implementation; stopClip() cancels/clears waiters
- Concurrency notes clarified for TCC and delegate hops

## [0.1.0] — 2025-09-12
- Initial public extract: VoiceKitCore and VoiceKitUI
- RealVoiceIO with Swift 6 actor-safety
- ScriptedVoiceIO for tests/demos
- VoiceChooserView + VoiceProfilesStore
- NameMatch utilities
- Package tests: NameMatch and ScriptedVoiceIO
