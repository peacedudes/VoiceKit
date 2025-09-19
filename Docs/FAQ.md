# FAQ

Q: “Why does listen() return ‘42’ in tests?”
- The package ships with a minimal STT shim for CI determinism. If you need real STT, enable the full engine in your app target (AVAudioEngine + Speech).

Q: “How do I preview a voice name without storing displayName?”
- Use AVSpeechSynthesisVoice(identifier: profile.id)?.name for UI text. TTSVoiceProfile intentionally omits displayName for simpler persistence.

Q: “Locale-dependent tests are flaky.”
- Use FakeTTS in UI tests and set languageFilter = .all. Avoid asserting specific system voices.

Q: “How do I avoid libdispatch queue assertions with permissions?”
- Use PermissionBridge (nonisolated), then await the result to rejoin @MainActor.
