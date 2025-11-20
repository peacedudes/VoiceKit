# VoiceIO Programmer’s Guide

Audience
- App developers integrating VoiceKit into SwiftUI apps on iOS 17+/macOS 14+.
- Focused, practical guidance: quick start, sequencing, short clips, logging, and testing.

What this covers (at a glance)
- Quick start: create, speak, listen
- Sequencing and lifecycle
- Short SFX clips (clip)
- Logging (VOICEKIT_LOG and custom logger)
- Deterministic testing and previews
- API surface snapshots (VoiceIO, TTSConfigurable, models)

Requirements
- Swift tools-version: 6.0; Swift language mode .v6
- iOS 17.0+ and/or macOS 14.0+
- If you wire real STT in your app target, add Info.plist keys:
  - NSMicrophoneUsageDescription
  - NSSpeechRecognitionUsageDescription

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

Sequencing and lifecycle
- Public API is @MainActor. Call from the main actor.
- Typical flow (minimal RealVoiceIO with current package stubs):
  - You can use RealVoiceIO directly, or wrap it in a VoiceQueue for higher-level sequencing.
  1) await voice.speak("…")
  2) let result = try await voice.listen(timeout:…, inactivity:…, record: …, context: …)
  3) voice.stopAll() or voice.hardReset() to cancel/cleanup if needed
- Permissions and audio session:
  - The package includes PermissionBridge utilities and placeholders in RealVoiceIO:
    - ensurePermissions(), configureSessionIfNeeded() are stubs in the current core for CI determinism.
    - If your app wires real STT, perform permission + audio session setup in your app target.

Short SFX clips (clip path)
- Goal: near-zero-gap “thank you → play a short clip” UX.
- API (most apps can just use the first call):
  - playClip(url:gainDB:) play a short clip (one-shot)
  - prepareClip(url:gainDB:) pre-schedule a clip (advanced)
  - startPreparedClip() start a previously prepared clip (advanced)
- Current core behavior:
  - Tests use a shim; RealVoiceIO stubs actual playback while preserving scheduling/timing semantics.
  - Idempotent stop semantics:
    - stopClip() is safe to call multiple times; it cancels and clears any pending waiters exactly once.
    - Clip waiters are resumed immediately and not retained. This avoids double-resume.
- Notes:
  - prepareClip/startPreparedClip exist to minimize gap when chaining “speak → clip” by pre-rolling the clip; whether this is needed depends on your audio path. Measure in your app; playClip may be sufficient.
  - Streaming multiple clips back-to-back may benefit from prepare/start for seamlessness.

VoiceQueue (sequencing helper)
- Purpose
  - Small helper that sequences speech, short sound effects, and pauses.
  - Runs on @MainActor; accepts any VoiceIO, and uses TTSConfigurable when available.
- Core concepts
  - Items:
    - speak(text: String, voiceID: String? = nil) — say some text, optionally with a specific profile id.
    - sfx(url: URL, gainDB: Float = 0) — play a short clip.
    - pause(seconds: TimeInterval) — wait between items.
  - Channels:
    - Channel 0 uses the primary VoiceIO you pass in.
    - Extra channels can be created via an optional factory for simple parallel playback.
- Simple example
  ~~~swift
  let io = RealVoiceIO()
  let q = VoiceQueue(primary: io)
  let ding = Bundle.main.url(forResource: "ding", withExtension: "caf")!

  q.enqueueSpeak("A", voiceID: nil)
  q.enqueueSFX(ding, gainDB: 3)
  q.enqueuePause(0.2)
  q.enqueueSpeak("B", voiceID: nil)
  await q.play()
  ~~~
- Embedded SFX in text
  - You can also let VoiceQueue parse inline SFX tokens in text:
    - Syntax: `[sfx:NAME]`
    - Resolver: `(String) -> URL?` maps NAME → audio file URL.
  - Helper:
    - enqueueParsingSFX(text:resolver:defaultVoiceID:on:) — splits the text into speak and sfx items and enqueues them for you.

UI components (summary)
- VoiceChooserView (VoiceKitUI):
  - Lets users pick a system TTS voice and tune rate/pitch/volume with live previews.
  - Persists default voice, master control, and per-voice profiles via VoiceProfilesStore.
  - Typical embedding: a Settings screen in SwiftUI.
- ChorusLabView (VoiceKitUI):
  - A multi-voice playground for experimenting with several voices in parallel and calibrating timing.
  - Useful for demos and tuning voice mixes; keep it behind a developer toggle in production apps.

Logging (opt-in)
- RealVoiceIO exposes a tiny, optional logger to aid integration debugging:
  - Property:
    - logger: ((LogLevel, String) -> Void)?
    - LogLevel: .info, .warn, .error
  - Helper:
    - log(_ level: LogLevel = .info, _ message: @autoclosure () -> String)
- Environment flag for default print logging:
  - If you set VOICEKIT_LOG to 1, true, or yes in your scheme/environment,
    RealVoiceIO will default logger to print:
    [VoiceKit][info] speak(text:…, voiceID:…)
  - To customize, set the logger yourself:
    ~~~swift
    @MainActor
    let io = RealVoiceIO()
    io.logger = { level, msg in
        print("[VoiceKit][\(level)] \(msg)")
    }
    ~~~

Deterministic testing and previews
- Use ScriptedVoiceIO for tests/demos that must not rely on device voices, locale, or hardware:
  ~~~swift
  @MainActor
  let script = try! JSONSerialization.data(withJSONObject: ["hello","world"])
  let io = ScriptedVoiceIO(fromBase64: script.base64EncodedString())!
  let r = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
  XCTAssertEqual(r.transcript, "hello")
  ~~~
- UI voice selection and previews:
  - Use VoiceChooserView and VoiceProfilesStore to select a system voice and tune rate/pitch/volume with live previews.
  - Tests should prefer a FakeTTS conforming to TTSConfigurable & VoiceListProvider to avoid AV/locale variability.
- Name utilities:
  - NameMatch and NameResolver provide robust normalization and exact matching for kid-friendly inputs.

Config & diagnostics
- VoiceIOConfig
  - Controls a few advanced behaviors of RealVoiceIO. All values have sensible defaults.
  - Fields:
    - trimPrePad: Double — seconds of audio to keep *before* detected speech when trimming recordings.
    - trimPostPad: Double — seconds of audio to keep *after* detected speech.
    - clipWaitTimeoutSeconds: Double — how long to wait for a short clip (“boosted” path) to complete before timing out.
    - ttsSuppressAfterFinish: Double — brief suppression window after TTS to avoid the mic “hearing” its own output.
  - Usage example:
    ~~~swift
    let cfg = VoiceIOConfig(
        trimPrePad: 0.10,
        trimPostPad: 0.30,
        clipWaitTimeoutSeconds: 1.5,
        ttsSuppressAfterFinish: 0.25
    )
    let io = RealVoiceIO(config: cfg)
    ~~~

- VoiceIOError
  - Canonical error cases RealVoiceIO may surface when you wire real STT/audio:
    - micUnavailable, recognizerUnavailable, audioFormatInvalid
    - timedOut, cancelled
    - underlying(String) — preserves a short message from deeper layers.
  - Current core stubs do not throw these in CI by default, but applications integrating real audio should be prepared to switch on them.

- VoiceKitInfo
  - Light runtime metadata for logging and diagnostics:
    - VoiceKitInfo.version — semantic version string (e.g., "0.1.2").
    - VoiceKitInfo.buildTimestampISO8601 — build-time timestamp string in ISO‑8601 form.
  - Example:
    ~~~swift
    print("VoiceKit \(VoiceKitInfo.version) @ \(VoiceKitInfo.buildTimestampISO8601)")
    ~~~

Build/test one-liner (clipboard-first)
- Keep the loop fast and calm. A simple alias we recommend:
~~~bash
alias test='(swift build && SWIFTPM_TEST_LOG_FORMAT=xcode swift test) 2>&1 | tee >(tail -n ${LINES_CLIP:-200} | toClip)'
~~~
- Why this shape:
  - xcode format improves readability
  - avoid -v by default to reduce noise; add -v only when chasing a specific failure
  - full output stays in your terminal; only the last ~200 lines go to the clipboard (adjust LINES_CLIP as needed)
- When to add switches:
  - Focus a single test: swift test --filter SuiteName/TestName
  - Temporarily add verbosity: swift test -v
- Same spirit as a project “xcb.sh” runner: tailor the default early so collaboration is smooth.

API reference snapshots (current)
- See Docs/VoiceKitGuide.md for a full reference. Short snapshots here:

VoiceIO (public protocol, @MainActor)
~~~swift
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
    func listen(timeout: TimeInterval, inactivity: TimeInterval, record: Bool) async throws -> VoiceResult

    // Short-clip playback (clip)
    func prepareClip(url: URL, gainDB: Float) async throws
    func startPreparedClip() async throws
    func playClip(url: URL, gainDB: Float) async throws

    // Lifecycle
    func stopAll()
    func hardReset()
}
~~~

TTSConfigurable (shared with UI; @MainActor)
~~~swift
@MainActor
public protocol TTSConfigurable: AnyObject {
    func setVoiceProfile(_ profile: TTSVoiceProfile)
    func getVoiceProfile(id: String) -> TTSVoiceProfile?
    func setDefaultVoiceProfile(_ profile: TTSVoiceProfile)
    func getDefaultVoiceProfile() -> TTSVoiceProfile?
    func setTuning(_ tuning: Tuning)
    func getTuning() -> Tuning
    func speak(_ text: String, using voiceID: String?) async
}
~~~

Models (shared)
~~~swift
public struct VoiceResult: Sendable {
    public let transcript: String
    public let recordingURL: URL?
}

public struct TTSVoiceInfo: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let language: String
}

public struct TTSVoiceProfile: Sendable, Equatable, Codable {
    public let id: String
    public var rate: Double
    public var pitch: Float
    public var volume: Float
}

public struct Tuning: Sendable, Equatable, Codable {
    public var rateVariation: Float
    public var pitchVariation: Float
    public var volume: Float
}
~~~

Recognition context
~~~swift
public struct RecognitionContext: Sendable {
    public enum Expectation: Sendable {
        case freeform
        case name(allowed: [String])
        case number
    }
    public var expectation: Expectation
    public init(expectation: Expectation = .freeform) { self.expectation = expectation }
}
~~~

Notes
- listen accepts an optional RecognitionContext via the context: parameter and defaults to .freeform.
- Pass .number when you expect numeric entries, or .name(allowed:) for constrained name inputs.
- Both forms compile (with or without context:) since it has a default value.
- RealVoiceIO currently includes a minimal listen stub that returns "42" for numeric expectation in tests/CI.
- Clip playback plumbing is present; real audio playback can be layered in your app target as needed.
- Concurrency: public APIs and callbacks run on @MainActor; avoid capturing @MainActor self on audio threads.

See also
- Docs/VoiceKitGuide.md for the in-depth guide and examples.
- VoiceKitUI: VoiceChooserView and ChorusLabView for selecting/tuning voices and experimenting with multi-voice playback.
- Tests/… for deterministic patterns (ScriptedVoiceIO, FakeTTS).
