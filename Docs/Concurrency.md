# Concurrency and Thread Safety (Swift 6)

Isolation
- Public API is @MainActor (VoiceIO, RealVoiceIO, ScriptedVoiceIO).
- UI callbacks (onTranscriptChanged, onLevelChanged, etc.) are invoked on @MainActor.

Permission callbacks (TCC)
- Don’t pass @MainActor closures directly into TCC callbacks (background queues).
- Use PermissionBridge (nonisolated) with withCheckedContinuation to await results safely.

AVSpeechSynthesizer delegate
- Delegate methods hop to @MainActor and only move ObjectIdentifier/primitive data across actors.

Audio tap (if you enable real STT in your app)
- Don’t capture @MainActor self on real-time thread. Compute level locally and hop updates to main via a Sendable helper.

Do / Don’t
- Do call VoiceIO methods on main.
- Don’t mutate UI from background contexts around callbacks.
- Do keep tests deterministic by using ScriptedVoiceIO or FakeTTS.
