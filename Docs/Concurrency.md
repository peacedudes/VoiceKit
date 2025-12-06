# Concurrency - practical guidance (Swift 6)

Audience
- Developers integrating VoiceKit who want to avoid runtime warnings and ensure actor-safety.

Principles
- Public APIs in VoiceKit (RealVoiceIO, ScriptedVoiceIO) and caches like SystemVoicesCache are @MainActor.
- Keep AVFoundation calls on the main actor unless explicitly documented otherwise.
- Use Task and continuations carefully; pass only Sendable data across actor hops.

Quick do/don’t
- Do:
  - Call VoiceKit APIs from the main actor (SwiftUI is already main).
  - Hop back to MainActor before touching UI from background work.
  - Gate system-voice enumeration in CI/headless tests to avoid simulator noise.
  - Optionally prewarm SystemVoicesCache on main at app start.
- Don’t:
  - Capture @MainActor self on audio or background threads.
  - Assume AV delegates are on main-always hop explicitly.

UI callbacks
- VoiceKit invokes UI callbacks on @MainActor:
  onTranscriptChanged, onLevelChanged, onTTSSpeakingChanged, onTTSPulse, onStatusMessageChanged.
- You can bind them directly to SwiftUI state without extra hops.

Patterns
- UI → Core on main:
  - Interact with RealVoiceIO, ScriptedVoiceIO, and SystemVoicesCache on @MainActor (e.g., from SwiftUI).
- Permissions (TCC):
  - Use PermissionBridge helpers which wrap callbacks in continuations and rejoin main safely.
- AVSpeechSynthesizer delegate:
  - Delegate methods are nonisolated entry points; immediately hop to @MainActor and store only primitive/ObjectIdentifier keys across hops.

Examples
- Permission bridge (continuation; rejoin main):
~~~swift
@MainActor
func awaitSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { cont in
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in cont.resume(returning: status) }
        }
    }
}
~~~

- AVSpeech delegate → MainActor:
~~~swift
final class SpeechDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    weak var owner: RealVoiceIO?
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in owner?.onTTSSpeakingChanged?(true) }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in owner?.onTTSSpeakingChanged?(false) }
    }
}
~~~

- Binding UI safely:
~~~swift
@MainActor
final class DemoVM: ObservableObject {
    let io = RealVoiceIO()
    @Published var isSpeaking = false
    init() {
        io.onTTSSpeakingChanged = { [weak self] speaking in self?.isSpeaking = speaking }
    }
}
~~~

Prewarm (optional)
~~~swift
@MainActor
func prewarmSystemVoices() {
    _ = SystemVoicesCache.refresh() // stable sort; safe to call at startup
}
~~~

Testing tips
- Avoid querying system voices by default in UI/unit tests to prevent XPC/SQLite noise on simulators.
- Prefer ScriptedVoiceIO for STT/TTS‑like flows that must be deterministic.

See also
- Docs/VoiceKitGuide.md → "Concurrency and thread‑safety (Swift 6)"
- Docs/ProgrammersGuide.md → Notes under Sequencing and Logging

Checklist
- [ ] Call public VoiceKit APIs on main (or via MainActor.run).
- [ ] Don’t capture @MainActor self on audio/background threads.
- [ ] AV delegates hop to @MainActor before mutating UI state.
- [ ] System voice enumeration gated in CI; optionally prewarmed on main in app.
- [ ] Tests prefer ScriptedVoiceIO or a FakeTTS; avoid device voice/locale assumptions.
