# Programmer’s Guide

Architecture
- VoiceKitCore
  - VoiceIO protocol: speak/listen/boosted playback with UI callbacks.
  - RealVoiceIO: AVSpeechSynthesizer + SFSpeechRecognizer + AVAudioEngine implementation.
  - ScriptedVoiceIO: deterministic “fake mic” for tests/demos.
  - TTS models: TTSVoiceInfo, TTSVoiceProfile, TTSMasterControl; TTSConfigurable protocol.
  - RecognitionContext: STT hints (freeform, name(allowed:), number).
  - NameMatch: normalizeKey + stringDistanceScore.
- VoiceKitUI
  - VoicePickerView: SwiftUI picker with favorites, active/hidden, language filter, live previews.
  - VoiceProfilesStore: JSON persistence (profiles, default, active, master).

Data flow
1) ViewModel calls RealVoiceIO.ensurePermissions/configureSession.
2) speak() produces TTS with pulse callbacks for animation; listen() captures audio and streams to Speech for partial/final transcripts (with optional recording/trim).
3) VoicePickerView uses TTSConfigurable and VoiceProfilesStore to list/preview/update voices and master controls.

Key APIs (Core)
- VoiceIO (all @MainActor)
  - onListeningChanged/onTranscriptChanged/onLevelChanged
  - onTTSSpeakingChanged/onTTSPulse
  - ensurePermissions(), configureSessionIfNeeded()
  - speak(_ text:), listen(timeout:inactivity:record:)
  - prepareBoosted/startPreparedBoosted/playBoosted
  - stopAll(), hardReset()
- RealVoiceIO: implements VoiceIO + TTSConfigurable
- ScriptedVoiceIO: implements VoiceIO (deterministic scripts)
- NameMatch.normalizeKey(String) -> String
- NameMatch.stringDistanceScore(a:b) -> Double

STT hints (RecognitionContext)
- .freeform (default)
- .name(allowed: [String]) sets contextualStrings
- .number sets numeric contextualStrings and normalizes spelled numbers when possible

Persistence (VoicePicker)
- VoiceProfilesStore writes JSON to Application Support.
- Fields: defaultVoiceID, master, profilesByID, activeVoiceIDs.

Customization
- Replace RealVoiceIO with your own TTS engine by conforming to TTSConfigurable; the picker works unchanged.
- Build custom voice UI by reusing VoiceProfilesStore directly.

See also
- docs/VoiceIO.md for API details and examples.
- docs/Concurrency.md for Swift 6 isolation notes.
- docs/VoicePicker.md for UI details and customization.
