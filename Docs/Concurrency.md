# Concurrency - practical guidance (Swift 6)

Audience
- Developers integrating VoiceKit who want to avoid runtime warnings and ensure actor-safety.
- Test authors writing higher-QoS XCTest cases that exercise real AVFoundation / STT.

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

## Runtime hygiene in tests (QoS + live STT/TTS)

Most VoiceKit tests (and most app tests that use ScriptedVoiceIO) never need to worry about thread QoS.
However, if you run **live** RealVoiceIO tests with the Xcode Thread Performance Checker enabled,
you may occasionally see warnings like:

- “higher QoS waiting on lower QoS”
- “Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context”

These generally stem from XCTest threads running at a higher QoS than AVFoundation’s audio threads,
not from VoiceKit doing anything inherently unsafe.

Recommended patterns:

1. **Prefer ScriptedVoiceIO in tests**
   - For deterministic coverage of flows, always use `ScriptedVoiceIO` or a fake `VoiceIO`.
   - This avoids hardware/permission issues and keeps the test bundle quiet.

2. **Gate live STT smoke tests**
   - If you want one or two live “smoke” tests that hit the real STT pipeline, make them opt‑in:

   ~~~swift
   @MainActor
   final class RealSTTSmokeTests: XCTestCase {
       func testLiveListenDoesNotCrash() async throws {
           if IsCI.running {
               throw XCTSkip("Skipping live STT smoke test in CI.")
           }
           let env = ProcessInfo.processInfo.environment
           guard let smoke = env["REAL_STT_SMOKE"]?.lowercased(),
                 smoke == "1" || smoke == "true" || smoke == "yes" else {
               throw XCTSkip("REAL_STT_SMOKE not set; skipping live STT smoke test.")
           }

           let io = RealVoiceIO()
           try await io.ensurePermissions()
           try await io.configureSessionIfNeeded()

           _ = try? await io.listen(timeout: 3, inactivity: 1.0, record: true)
       }
   }
   ~~~

3. **Neutralize XCTest thread QoS for live audio tests**
   - For tests that exercise **real** AVSpeech/AVAudioEngine/STT, it can help to run the test body at
     **Default** QoS to avoid “higher QoS waiting on lower QoS” hints from the Thread Performance Checker.
   - You can copy this tiny helper into your app’s **test target** and subclass it instead of XCTestCase:

   ~~~swift
   import XCTest
   import Darwin // for pthread_* QoS APIs

   internal final class QoSNeutralizingTestCase: XCTestCase {
       override func invokeTest() {
           var oldClass: qos_class_t = QOS_CLASS_DEFAULT
           var oldRelPri: Int32 = 0
           pthread_get_qos_class_np(pthread_self(), &oldClass, &oldRelPri)
           pthread_set_qos_class_self_np(QOS_CLASS_DEFAULT, 0)
           defer { pthread_set_qos_class_self_np(oldClass, oldRelPri) }
           super.invokeTest()
       }
   }
   ~~~

See also
- Docs/VoiceKitGuide.md → "Concurrency and thread‑safety (Swift 6)"
- Docs/ProgrammersGuide.md → Notes under Sequencing and Logging

Checklist
- [ ] Call public VoiceKit APIs on main (or via MainActor.run).
- [ ] Don’t capture @MainActor self on audio/background threads.
- [ ] AV delegates hop to @MainActor before mutating UI state.
- [ ] System voice enumeration gated in CI; optionally prewarmed on main in app.
- [ ] Tests prefer ScriptedVoiceIO or a FakeTTS; avoid device voice/locale assumptions.
