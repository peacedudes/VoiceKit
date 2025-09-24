# Programmer’s Guide

Modules
- VoiceKitCore
  - RealVoiceIO: AVSpeechSynthesizer TTS; STT shim by default in-package.
  - ScriptedVoiceIO: deterministic test engine (speak pulses, listen dequeues).
  - VoiceQueue: sequence speak/SFX/pause; optional parallel channels factory.
  - Utilities: NameMatch, NameResolver, PermissionBridge, VoiceOpGate.
  - Models: TTSVoiceInfo, TTSVoiceProfile (rate: Double; pitch/volume: Float), TTSMasterControl, RecognitionContext.
- VoiceKitUI
  - VoicePickerView: SwiftUI picker with profiles and previews.
  - VoiceProfilesStore: JSON persistence; tracks default, active, hidden, master.

Data flow
- ViewModel (UI) queries system voices (or FakeTTS in tests), bootstraps profiles, applies TTS master/profile to TTSConfigurable, and drives previews.

Extensibility
- Replace RealVoiceIO with your own TTS by conforming to TTSConfigurable.
- Keep tests deterministic with ScriptedVoiceIO/FakeTTS. Reserve real STT for app-level integration tests.

Design decisions
- @MainActor public API for simplicity and safety.
- No displayName in TTSVoiceProfile: UI fetches system name lazily via AVSpeechSynthesisVoice.
- STT shim in-package to avoid CI/device dependencies; full STT reserved for apps.
