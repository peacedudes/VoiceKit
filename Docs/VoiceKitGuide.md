# VoiceKit Guide

Audience
- Swift developers building iOS 17+/macOS 14+ apps who want reliable voice I/O with great tests.

What’s here
- One page with everything you need: quick start, API basics, picker UI, sequencing, models, concurrency notes, and testing.

Requirements
- Swift tools-version: 6.0 (swiftLanguageModes [.v6])
- iOS 17.0+ and/or macOS 14.0+
- If you enable real STT in your app target, add Info.plist keys:
  - NSMicrophoneUsageDescription
  - NSSpeechRecognitionUsageDescription

Install
- Local during development: Add Local Package…; link VoiceKitCore and (optionally) VoiceKitUI (Do Not Embed).
- Remote: Add from GitHub URL; rule “Up to Next Major” from your tag (e.g., v0.1.1).

Quick start
```swift
import VoiceKitCore

@MainActor
final class DemoVM: ObservableObject {
    let voice = RealVoiceIO()
    func run() {
        Task {
            await voice.speak("Say your name after the beep.")
            let r = try? await voice.listen(timeout: 8, inactivity: 2, record: true,
                                            context: .init(expectation: .number))
            print("Heard:", r?.transcript ?? "(none)")
        }
    }
}
```

Modules and primary types
- VoiceKitCore
  - RealVoiceIO (@MainActor): production TTS via AVSpeechSynthesizer; package ships with a minimal STT shim for CI/tests.
  - ScriptedVoiceIO (@MainActor): deterministic engine for tests/demos (listen dequeues scripted strings; speak emits a pulse pattern).
  - VoiceQueue (@MainActor): sequence speak/SFX/pause; optional parallel channels.
  - Utilities: NameMatch, NameResolver, PermissionBridge, VoiceOpGate.
  - Models: TTSVoiceInfo, TTSVoiceProfile (rate: Double; pitch/volume: Float), TTSMasterControl, RecognitionContext, VoiceResult.
- VoiceKitUI
  - VoicePickerView: SwiftUI UI for system voices with profiles (default/active/hidden), language filter, and live previews.
  - VoiceProfilesStore: JSON persistence for profiles/master/flags; deterministic in tests.

Speak and listen
```swift
let io = RealVoiceIO()
await io.speak("Hello there!")

let result = try await io.listen(timeout: 6, inactivity: 2, record: false,
                                 context: .init(expectation: .number))
// STT shim returns "42" for .number in tests/CI by design
```

Short SFX clips (clip)
```swift
let url = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await io.playClip(url: url, gainDB: 6)
```

Sequencing with VoiceQueue
```swift
let q = VoiceQueue(primary: io)
q.enqueueSpeak("A")
q.enqueueSFX(url)
q.enqueueSpeak("B")
await q.play()
```

Picker UI
```swift
import VoiceKitCore
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View { VoicePickerView(tts: voice) }
}
```

Models (shared)
```swift
public struct TTSVoiceInfo { public let id, name, language: String }

public struct TTSVoiceProfile {
    public let id: String
    public var rate: Double
    public var pitch, volume: Float
}

public struct TTSMasterControl {
    public var rateVariation, pitchVariation, volume: Float
}

public struct VoiceResult { public let transcript: String; public let recordingURL: URL? }

public struct RecognitionContext {
    public enum Expectation { case freeform, name(allowed: [String]), number }
    public var expectation: Expectation
    public init(expectation: Expectation = .freeform) { self.expectation = expectation }
}
```

Picker details (VoicePickerView + VoiceProfilesStore)
- Provides favorite (default), active set, hide/unhide + Show Hidden toggle.
- Language filter: current or all.
- Master sliders (volume, pitch range, speed range) with debounced live preview.
- Persistence fields:
  - defaultVoiceID: String?
  - master: TTSMasterControl
  - profilesByID: [String: TTSVoiceProfile]
  - activeVoiceIDs: [String]
  - hiddenVoiceIDs: [String]
- Deterministic tests: use a FakeTTS that conforms to TTSConfigurable & VoiceListProvider; set vm.languageFilter = .all.

Concurrency and thread-safety (Swift 6)
- Public API is @MainActor (VoiceIO, RealVoiceIO, ScriptedVoiceIO). Call from main.
- UI callbacks (onTranscriptChanged, onLevelChanged, onTTSSpeakingChanged, onTTSPulse, onStatusMessageChanged) are invoked on @MainActor.
- Permission callbacks (TCC): don’t pass @MainActor closures into background APIs directly; use PermissionBridge with continuations and rejoin main safely.
- AVSpeechSynthesizer delegate methods hop to @MainActor; only ObjectIdentifier/primitive data cross actor boundaries.
- If you wire real STT in your app: avoid capturing @MainActor self from the audio thread. Compute locally, then hop to main to update UI.

Testing (deterministic)
- Prefer ScriptedVoiceIO in core tests: no microphone or speech permissions.
- Prefer FakeTTS for UI tests: avoid system voice/locale flakiness.

Example (core)
```swift
let data = try! JSONSerialization.data(withJSONObject: ["hello","world"])
let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!
let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
XCTAssertEqual(r1.transcript, "hello")
```

Example (UI)
```swift
@MainActor
final class FakeTTS: TTSConfigurable, VoiceListProvider {
    var voices: [TTSVoiceInfo] = []
    var profiles: [String: TTSVoiceProfile] = [:]
    var defaultProfile: TTSVoiceProfile?
    var master: TTSMasterControl = .init()
    nonisolated func availableVoices() -> [TTSVoiceInfo] { MainActor.assumeIsolated { voices } }
    func setVoiceProfile(_ p: TTSVoiceProfile) { profiles[p.id] = p }
    func getVoiceProfile(id: String) -> TTSVoiceProfile? { profiles[id] }
    func setDefaultVoiceProfile(_ p: TTSVoiceProfile) { defaultProfile = p }
    func getDefaultVoiceProfile() -> TTSVoiceProfile? { defaultProfile }
    func setMasterControl(_ m: TTSMasterControl) { master = m }
    func getMasterControl() -> TTSMasterControl { master }
    func speak(_ text: String, using voiceID: String?) async {}
}
```

Minimizing system warnings (best practices)
- Context: on simulators/CI, AVSpeechSynthesisVoice queries may emit logs (XPC/SQLite fallback messages). Also, invoking AV APIs from non-main contexts can trigger “Potential Structural Swift Concurrency Issue” warnings.
- Goals: keep real AV usage in your app; avoid noisy logs in tests/CI; ensure AV calls occur on @MainActor.

Patterns (no API changes)
- Avoid enumerating system voices in headless tests by default:
  - VoicePickerViewModel(tts:store:allowSystemVoices:) lets you force-enable enumeration when desired.
  - VoiceKitTestMode.setAllowSystemVoiceQueries(_:) can opt-in per test.
- Keep AV calls on the main actor:
  - VoicePickerViewModel and RealVoiceIO are @MainActor; interact with them on main or hop to MainActor.
- App prewarm (on main) to populate the cache:
```swift
@MainActor
func prewarmSystemVoices() {
    _ = SystemVoicesCache.refresh() // main-actor; stable sort; safe to call at startup
}
```
- Test: quiet list building (no enumeration):
```swift
@MainActor
func testQuietList() async {
    await VoiceKitTestMode.setAllowSystemVoiceQueries(false)
    let vm = VoicePickerViewModel(tts: RealVoiceIO(), store: VoiceProfilesStore(), allowSystemVoices: false)
    vm.refreshAvailableVoices()
    // Provide a VoiceListProvider if you want deterministic voices instead.
}
```
- Test: opt-in real voice usage (still @MainActor):
```swift
@MainActor
func testRealVoice() async {
    await VoiceKitTestMode.setAllowSystemVoiceQueries(true)
    let vm = VoicePickerViewModel(tts: RealVoiceIO(), store: VoiceProfilesStore(), allowSystemVoices: true)
    let id = "com.apple.speech.synthesis.voice.Alex"
    let phrase = vm.samplePhrase(for: .init(id: id))
    XCTAssertTrue(phrase.contains("My name is"))
}
```

Name utilities
- NameMatch.normalizeKey(_:) normalizes ligatures, diacritics, punctuation; unifies dash variants; collapses whitespace.
- NameResolver resolves transcripts to allowed names via strict normalization (folds case/diacritics, trims punctuation).

FAQ (short)
- Why does listen() return “42” in tests?
  - The package ships a minimal STT shim for determinism. For real STT, wire AVAudioEngine + Speech in your app target.
- Where do display names come from?
  - TTSVoiceProfile intentionally omits displayName; UI resolves system names on demand via AVSpeechSynthesisVoice.
- Locale-dependent tests are flaky—what to do?
  - Use FakeTTS with VoiceListProvider and set languageFilter = .all.
- Permission assertions on background queues?
  - Use PermissionBridge and continuations; rejoin @MainActor before touching UI.

Changelog
- See CHANGELOG.md.

License
- MIT — see LICENSE.
