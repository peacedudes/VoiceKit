# VoiceKit Guide

Audience
- Swift developers building iOS 17+/macOS 14+ apps who want reliable voice I/O with great tests.

What’s here
- One page with everything you need: quick start, API basics, voice chooser UI, sequencing, models, concurrency notes, and testing.

Requirements
- Swift tools-version: 6.0 (swiftLanguageModes [.v6])
- iOS 17.0+ and/or macOS 14.0+
- If you enable real STT in your app target, add Info.plist keys:
  - NSMicrophoneUsageDescription
  - NSSpeechRecognitionUsageDescription

Install
- Local during development: Add Local Package…; link VoiceKit and (optionally) VoiceKitUI (Do Not Embed).
- Remote: Add from GitHub URL; rule “Up to Next Major” from your tag (e.g., v0.x.y).

- Note: as of v0.2.0 the core module is named "VoiceKit" (previously "VoiceKitCore").
  If you’re upgrading from older tags, update imports to:
~~~swift
import VoiceKit
~~~

Quick start
~~~swift
import VoiceKit

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
~~~

Modules and primary types
- VoiceKit
  - RealVoiceIO (@MainActor): production TTS via AVSpeechSynthesizer; package ships with a minimal STT shim for CI/tests.
  - ScriptedVoiceIO (@MainActor): deterministic engine for tests/demos (listen dequeues scripted strings; speak emits a pulse pattern).
  - VoiceQueue (@MainActor): sequence speak/SFX/pause; optional parallel channels.
  - Utilities: NameMatch, NameResolver, PermissionBridge, VoiceOpGate.
  - Models: TTSVoiceInfo, TTSVoiceProfile (rate: Double; pitch/volume: Float), TTSMasterControl, RecognitionContext, VoiceResult.
- VoiceKitUI
  - VoiceChooserView: pick a system voice and tune its settings (rate, pitch, volume) with live preview.
  - ChorusLabView: experiment with multiple voices speaking in parallel and calibrate timing.
  - VoiceProfilesStore: JSON persistence for profiles/master/flags; deterministic in tests.

Speak and listen
~~~swift
let io = RealVoiceIO()
await io.speak("Hello there!")

let result = try await io.listen(timeout: 6, inactivity: 2, record: false,
                                 context: .init(expectation: .number))
// STT shim returns "42" for .number in tests/CI by design
~~~

Short SFX clips (clip)
~~~swift
let url = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await io.playClip(url: url, gainDB: 6)
~~~

Sequencing with VoiceQueue
~~~swift
let q = VoiceQueue(primary: io)
q.enqueueSpeak("A")
q.enqueueSFX(url)
q.enqueueSpeak("B")
await q.play()
~~~

UI components (summary)
- VoiceChooserView (VoiceKitUI):
  - Lets users pick a system TTS voice and tune rate/pitch/volume with live previews.
  - Persists default voice, master control, and per-voice profiles via VoiceProfilesStore.
  - Typical embedding: a Settings screen in SwiftUI.
- ChorusLabView (VoiceKitUI):
  - A multi-voice playground for experimenting with several voices in parallel and calibrating timing.
  - Useful for demos and tuning voice mixes; keep it behind a developer toggle in production apps.

Formatting tip for contributors
- Use ~~~ fenced code blocks (not backticks) in docs for clipboard-friendly patches.

Voice chooser
~~~swift
import VoiceKit
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View { VoiceChooserView(tts: voice) }
}
~~~

Models (shared)
~~~swift
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
~~~

Chooser notes
- VoiceChooserView lets users select a system TTS voice and adjust rate, pitch, and volume with immediate audio feedback.
- Profiles persist via VoiceProfilesStore (id → TTSVoiceProfile) along with default voice and master control values.
- For deterministic tests, use a FakeTTS (conforming to TTSConfigurable) and avoid relying on device locale/voices.

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
~~~swift
let data = try! JSONSerialization.data(withJSONObject: ["hello","world"])
let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!
let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
XCTAssertEqual(r1.transcript, "hello")
~~~

Example (UI)
~~~swift
@MainActor
final class FakeTTS: TTSConfigurable {
    var profiles: [String: TTSVoiceProfile] = [:]
    var defaultProfile: TTSVoiceProfile?
    var master: TTSMasterControl = .init()
    func setVoiceProfile(_ p: TTSVoiceProfile) { profiles[p.id] = p }
    func getVoiceProfile(id: String) -> TTSVoiceProfile? { profiles[id] }
    func setDefaultVoiceProfile(_ p: TTSVoiceProfile) { defaultProfile = p }
    func getDefaultVoiceProfile() -> TTSVoiceProfile? { defaultProfile }
    func setMasterControl(_ m: TTSMasterControl) { master = m }
    func getMasterControl() -> TTSMasterControl { master }
    func speak(_ text: String, using voiceID: String?) async {}
}
~~~

Minimizing system warnings (best practices)
- Context: on simulators/CI, AVSpeechSynthesisVoice queries may emit logs (XPC/SQLite fallback messages). Also, invoking AV APIs from non-main contexts can trigger concurrency warnings.
- Goals: keep real AV usage in your app; avoid noisy logs in tests/CI; ensure AV calls occur on @MainActor.

Patterns (no API changes)
- Avoid enumerating system voices in headless tests by default. Use Fake engines or gate enumeration under a flag.
- Keep AV calls on the main actor. SystemVoicesCache and RealVoiceIO are @MainActor; prewarm/refresh on main if needed.
- App prewarm (on main) to populate the cache:
~~~swift
@MainActor
func prewarmSystemVoices() {
    _ = SystemVoicesCache.refresh() // main-actor; stable sort; safe to call at startup
}
~~~
- See also: Docs/Concurrency.md for guidance and links to sections in this guide.

Name utilities
- NameMatch.normalizeKey(_:) normalizes ligatures, diacritics, punctuation; unifies dash variants; collapses whitespace.
- NameResolver resolves transcripts to allowed names via strict normalization (folds case/diacritics, trims punctuation).

FAQ (short)
- Why does listen() return “42” in tests?
  - The package ships a minimal STT shim for determinism. For real STT, wire AVAudioEngine + Speech in your app target.
- Where do display names come from?
  - TTSVoiceProfile intentionally omits displayName; UI resolves system names on demand via AVSpeechSynthesisVoice.
- Locale-dependent tests are flaky—what to do?
  - Prefer FakeTTS and avoid depending on device locale/voices.
- Permission assertions on background queues?
  - Use PermissionBridge and continuations; rejoin @MainActor before touching UI.

API snapshot (public surface)
~~~swift
// VoiceIO
@MainActor
public protocol VoiceIO: AnyObject {
    // UI callbacks
    var onListeningChanged: ((Bool) -> Void)? { get set }
    var onTranscriptChanged: ((String) -> Void)? { get set }
    var onLevelChanged: ((CGFloat) -> Void)? { get set }
    var onTTSSpeakingChanged: ((Bool) -> Void)? { get set }
    var onTTSPulse: ((CGFloat) -> Void)? { get set }
    var onStatusMessageChanged: ((String?) -> Void)? { get set }

    // Session / permissions (stubs in core for CI)
    func ensurePermissions() async throws
    func configureSessionIfNeeded() async throws

    // Core I/O
    func speak(_ text: String) async
    func listen(timeout: TimeInterval,
                inactivity: TimeInterval,
                record: Bool) async throws -> VoiceResult

    // Short-clip playback (clip)
    func prepareClip(url: URL, gainDB: Float) async throws
    func startPreparedClip() async throws
    func playClip(url: URL, gainDB: Float) async throws

    // Lifecycle
    func stopAll()
    func hardReset()
}

// TTSConfigurable (used by UI)
@MainActor
public protocol TTSConfigurable: AnyObject {
    func setVoiceProfile(_ profile: TTSVoiceProfile)
    func getVoiceProfile(id: String) -> TTSVoiceProfile?
    func setDefaultVoiceProfile(_ profile: TTSVoiceProfile)
    func getDefaultVoiceProfile() -> TTSVoiceProfile?
    func setMasterControl(_ master: TTSMasterControl)
    func getMasterControl() -> TTSMasterControl
    func speak(_ text: String, using voiceID: String?) async
}

// Models
public struct VoiceResult: Sendable { public let transcript: String; public let recordingURL: URL? }
public struct TTSVoiceInfo: Identifiable, Hashable, Codable, Sendable { public let id, name, language: String }
public struct TTSVoiceProfile: Sendable, Equatable, Codable { public let id: String; public var rate: Double; public var pitch, volume: Float }
public struct TTSMasterControl: Sendable, Equatable, Codable { public var rateVariation, pitchVariation, volume: Float }
public struct RecognitionContext: Sendable {
    public enum Expectation: Sendable { case freeform, name(allowed: [String]), number }
    public var expectation: Expectation
    public init(expectation: Expectation = .freeform) { self.expectation = expectation }
}
~~~

Changelog
- See CHANGELOG.md.

License
- MIT — see LICENSE.
