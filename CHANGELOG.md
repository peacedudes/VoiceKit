# Changelog

## [0.1.3] — 2025-12-05
- Core
  - RealVoiceIO: live STT pipeline wired to `listen(timeout:inactivity:record:)`:
    - Uses `AVAudioEngine` + `SFSpeechRecognizer` with task hints from `RecognitionContext`.
    - Tracks activity via `STTActivityTracker` (adaptive noise floor) to implement an “inactivity after speech” timeout.
    - Supports optional recording for each listen and returns a trimmed clip URL in `VoiceResult.recordingURL`.
  - Trimming: `trimAudioSmart` combines STT timestamps with an energy-based fallback:
    - Prefers STT segment timestamps when they look sane relative to the raw file.
    - Falls back to scanning audio energy and applies configurable pre/post pads from `VoiceIOConfig`.
  - Clip path: `prepareClip` / `startPreparedClip` / `playClip`:
    - Uses a simple `AVAudioPlayer` for short clips with gain in dB.
    - Keeps waiter handling idempotent and clears waiters on stop/timeout.
  - Seams: removed STT seams (`SpeechTaskDriver` / `RecognitionTapSource`) from the public surface; tests now exercise the CI stub path directly.
  - CI behavior:
    - `IsCI.running` / `VOICEKIT_FORCE_CI` short-circuit permissions and use a deterministic listen stub (e.g. `"42"` for numeric contexts).
    - Speak fast-path avoids `AVSpeechSynthesizer` on headless runners while still toggling callbacks.
- UI
  - ChorusLab: extracted non-visual helpers, added a more coherent “global adjustments” model, and aligned math via `ChorusMath.applyAdjustments`.
  - VoiceChooserView / VoiceProfilesStore: small refinements to filtering, preview behavior, and persistence tests; continue to favor deterministic `VoiceListProvider` fakes in tests.
- Docs
  - VoiceKitGuide rewritten to emphasize real-app usage:
    - Live STT semantics, recording + trimming, clip path, VoiceQueue orchestration, and VoiceKitUI usage.

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
