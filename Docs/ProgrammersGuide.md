# VoiceIO Programmer’s Guide

Audience
- App developers integrating VoiceKit into SwiftUI apps on iOS 17+/macOS 14+.
- Focused, practical guidance: quick start, sequencing, recording+trimming, SFX clips, logging, and testing.

What this covers (at a glance)
- Quick start: create, speak, listen
- STT semantics: 'timeout' vs 'inactivity', recording + trimming
- Sequencing and lifecycle
- Short SFX clips (clip API)
- VoiceQueue and embedded SFX in text
- VoiceChorus (parallel voices)
- Logging (VOICEKIT_LOG and custom logger)
- Deterministic testing and previews
- Config & diagnostics (VoiceIOConfig, VoiceIOError, VoiceKitInfo)
- API surface snapshots (VoiceIO, TTSConfigurable, models, RecognitionContext)

Requirements
- Swift tools-version: 6.0; Swift language mode '.v6'
- iOS 17.0+ and/or macOS 14.0+
- If you wire real STT in your app target, add Info.plist keys:
  - 'NSMicrophoneUsageDescription'
  - 'NSSpeechRecognitionUsageDescription'

---

## Quick start

### Basic integration

~~~swift
import VoiceKit

@Observable
@MainActor
final class DemoVM {
    let voice = RealVoiceIO()

    func run() {
        Task {
            try await voice.ensurePermissions()
            try await voice.configureSessionIfNeeded()

            await voice.speak("Please say your name after the beep.")
            let result = try? await voice.listen(
                timeout: 12,
                inactivity: 2.0,
                record: true
            )
            print("Heard:", result?.transcript ?? "(none)")

            if let url = result?.recordingURL {
                try? await voice.prepareClip(url: url, gainDB: 12)
                await voice.speak("Thank you,")
                try? await voice.startPreparedClip()
            }
        }
    }
}
~~~

---

## Sequencing and lifecycle

- Public 'RealVoiceIO' API is '@MainActor'. Call from the main actor.
- Typical high‑level flow:

  1. 'try await voice.ensurePermissions()'
  2. 'try await voice.configureSessionIfNeeded()'
  3. 'await voice.speak("...")'
  4. 'let result = try await voice.listen(timeout:inactivity:record:)'
  5. Optionally: play 'result.recordingURL' via 'prepareClip' / 'startPreparedClip'
  6. 'voice.stopAll()' or 'voice.hardReset()' to cancel/cleanup if needed

- Permissions and audio session:
  - Handled inside 'RealVoiceIO':
    - Mic and speech permissions requested via nonisolated async helpers (no @MainActor closures passed to TCC/AVF).
    - On iOS, 'AVAudioSession' is configured for '.playAndRecord' + '.voiceChat' with sensible options.
  - Safe to call multiple times, but you should conceptually treat them as a one‑time bootstrap per app run.

---

## STT semantics (listen)

### 'listen(timeout:inactivity:record:)'

Signature:

~~~swift
func listen(
    timeout: TimeInterval,
    inactivity: TimeInterval,
    record: Bool
) async throws -> VoiceResult
~~~

#### Parameters

- 'timeout' (seconds)
  - Hard cap on total listen duration.
  - If this elapses, the listen ends even if the user is still talking.

- 'inactivity' (seconds)
  - Measures *silence after speech*.
  - The inactivity timer starts **only after a non‑empty transcript is observed**.
  - Silence is measured using an adaptive noise floor:
    - The input tap computes loudness in dB for each buffer.
    - An 'STTActivityTracker' maintains a running baseline (noise floor).
    - Buffers louder than 'baseline + margin' are treated as "speech".
    - When we’ve seen 'inactivity' seconds since the last such buffer, we stop.
  - If no "loud enough" buffers are ever seen, we fall back to "time since first non‑empty transcript".

- 'record' (Bool)
  - When 'true':
    - The same audio fed into STT is mirrored to a temp CAF file.
    - After the listen completes, we call 'trimAudioSmart(inputURL:sttStart:sttEnd:prePad:postPad:)':
      - Primary signal: 'firstSpeechStart' / 'lastSpeechEnd' from STT segments.
      - Fallback: energy‑based bounds when STT timestamps don’t cover the full file (e.g. long leading silence).
      - Pads by 'trimPrePad' and 'trimPostPad' to avoid clipping consonants/breaths.
    - 'VoiceResult.recordingURL' points to this **trimmed** clip (or 'nil' on failure).
  - When 'false':
    - No recording file is created; 'recordingURL' will be 'nil'.

#### Behaviour

- On success:
  - Returns:

    ~~~swift
    struct VoiceResult {
        let transcript: String      // Final transcript (may be normalized in .number contexts)
        let recordingURL: URL?      // Trimmed clip when record == true
    }
    ~~~

- On cancellation:
  - Throws 'CancellationError'.
  - Calling 'hardReset()' also cancels any in‑flight listen and clears state.

- On recognizer availability problems:
  - Implementations may throw 'VoiceIOError.recognizerUnavailable'.
  - Your app should surface a clear message (e.g., "Speech recognizer is unavailable on this device. Please try again later.") and abort the flow rather than continue to re‑prompt.

---

## Short SFX clips (clip path)

Goal: near-zero-gap "Thank you → play a short clip" UX.

### API (most apps only need the first)

- 'playClip(url:gainDB:)' – play a short clip (one-shot).
- 'prepareClip(url:gainDB:)' – pre-schedule a clip (advanced).
- 'startPreparedClip()' – start a previously prepared clip (advanced).

Typical usage for the name playback flow:

~~~swift
if let url = result.recordingURL {
    try await voice.prepareClip(url: url, gainDB: 12)
    await voice.speak("Thank you,")
    try await voice.startPreparedClip()
}
~~~

Notes:

- ‘prepareClip’/’startPreparedClip’ exist to minimize the gap when chaining "speak → clip" by pre‑rolling the clip; whether you need both vs just ‘playClip’ depends on your app’s audio path. Measure if you care about single‑frame smoothness.
- Internally, clip waiters are resumed exactly once; multiple ‘stopAll()’/’hardReset()’ calls are safe.

---

## speak() with embedded tokens

### Inline SFX and silence tokens

‘speak()’ parses inline tokens in the text — no extra API calls needed:

~~~swift
let io = RealVoiceIO()
let dingURL = Bundle.main.url(forResource: "ding", withExtension: "caf")!

// Play a clip inline
await io.speak("Hello <sfx:\(dingURL.absoluteString)> world")

// Pause inline
await io.speak("Ready? <silence:1.5> Go!")
~~~

Tokens:
- `<sfx:URL>` — plays a clip at 0dB between surrounding text.
- `<silence:N>` — pauses for N seconds (respects task cancellation).

You can also pause explicitly between speak calls:

~~~swift
await io.speak("Step one.")
await io.pause(1.5)
await io.speak("Step two.")
~~~

### Parsing rules

- **Sentence splitting**: Text is automatically split at `.`, `!`, `?` boundaries
- **Token format**: `<sfx:URL>` or `<silence:N>` — value is anything until the closing `>`
- **Synthesis order**: Each sentence segment is synthesized sequentially
- **SFX playback**: Tokens are played between segments with 0dB gain
- **Voice profile**: Applied uniformly to all text segments

Example parsing: `"Hello world. <sfx:ding> How are you?"`
- Segment 1: "Hello world." (synthesized)
- Segment 2: ding.caf (played)
- Segment 3: "How are you?" (synthesized)

### When to use

**Good fit:**
- Simple patterns: "phrase + effect" or "phrase + pause"
- Tutorial steps: "Step 1. [ding] [pause] Step 2. [bell] Done!"
- Status announcements: "Processing <sfx:spinner> Complete <sfx:success>"

**Not a good fit:**
- Complex choreography (many clips, precise pauses)
- Parallel playback (multiple channels)
- Very tight timing requirements (lowest latency)

For those cases, use `VoiceQueue` (below) or `prepareClip`/`startPreparedClip` (above).

### Example: Tutorial with embedded tokens

~~~swift
@Observable
@MainActor
final class TutorialVM {
    let io = RealVoiceIO()

    func runTutorial() async {
        try? await io.ensurePermissions()
        try? await io.configureSessionIfNeeded()

        let dingPath = Bundle.main.url(forResource: "ding", withExtension: "caf")?.absoluteString ?? ""
        let bellPath = Bundle.main.url(forResource: "bell", withExtension: "caf")?.absoluteString ?? ""

        await io.speak(
            "Welcome to the tutorial. <sfx:\(dingPath)> <silence:0.5>" +
            "This is step one. <sfx:\(bellPath)> " +
            "You’re all done."
        )
    }
}
~~~

---

## VoiceQueue (sequencing helper)

### Purpose

- Lightweight helper that sequences speech, short sound effects, and pauses.
- Runs on '@MainActor'; accepts any 'VoiceIO', and uses 'TTSConfigurable' when available.
- Good for:
  - Tutorials ("Step 1, [ding], Step 2...").
  - Simple "scripted" readings with occasional SFX.

### Core concepts

- Items:
  - 'speak(text: String, voiceID: String? = nil)' - say some text, optionally with a specific profile id.
  - 'sfx(url: URL, gainDB: Float = 0)' - play a short clip.
  - 'pause(seconds: TimeInterval)' - wait between items.

- Channels:
  - Channel 0 uses the primary 'VoiceIO' you pass in.
  - Extra channels can be created via an optional factory for simple parallel playback.

### Simple example

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

### Embedded SFX in text

- VoiceQueue can parse inline SFX tokens in text.
- Syntax: '<sfx:NAME>'
- Resolver: '(String) -> URL?' maps 'NAME' → audio file URL.

Example:

~~~swift
let text = "Hello <sfx:ding> world."
q.enqueueParsingSFX(
    text: text,
    resolver: { name in
        Bundle.main.url(forResource: name, withExtension: "caf")
    },
    defaultVoiceID: nil,
    on: 0
)
~~~

---

## VoiceChorus (parallel voices)

### Purpose

- Coordinate several 'VoiceIO' engines in parallel.
- Used for:
  - "Chorus" effects (multiple voices speaking together).
  - Lead + backing voices mixes.

### Simple example

~~~swift
@MainActor
let chorus = VoiceChorus(engine: RealVoiceIO())
await chorus.speak(
    "Hello from a small chorus of voices.",
    withVoiceProfiles: [
        .init(id: "v1"),
        .init(id: "v2")
    ]
)
~~~

(See VoiceKitUI’s 'ChorusLabView' for a richer playground.)

---

## UI components (summary)

### VoiceChooserView (VoiceKitUI)

- Lets users:
  - Pick a system TTS voice.
  - Tune rate/pitch/volume with live previews.
- Persists:
  - Default voice.
  - Master tuning ('Tuning': volume, pitch range, speed range).
  - Per-voice 'TTSVoiceProfile's.
- Typical use: embed in a Settings screen.

### ChorusLabView (VoiceKitUI)

- Playground for:
  - Multiple voices in parallel.
  - Timing calibration for "chorus" effects.
- Recommended: keep behind a developer toggle in production apps.

---

## Logging (opt-in)

### Built-in logger

'RealVoiceIO' exposes a tiny logger:

- Property:

  ~~~swift
  var logger: ((LogLevel, String) -> Void)?
  // LogLevel: .info, .warn, .error
  ~~~

- Helper:

  ~~~swift
  func log(_ level: LogLevel = .info,
           _ message: @autoclosure () -> String)
  ~~~

### Environment flag

- If you set 'VOICEKIT_LOG' to '1', 'true', or 'yes' in your scheme/environment, 'RealVoiceIO' will log to stdout by default, for example:

  - '[VoiceKit][info] speak(text:..., voiceID:...)'
  - '[VoiceKit][info] listen(start) timeout=... inactivity=...'
  - '[VoiceKit][info] trimAudioSmart ...'

### Custom logger

You can override the logger to integrate with your own logging system:

~~~swift
@MainActor
let io = RealVoiceIO()
io.logger = { level, msg in
    print("[VoiceKit][\(level)] \(msg)")
}
~~~

---

## Deterministic testing and previews

### ScriptedVoiceIO for tests/demos

Use 'ScriptedVoiceIO' when you need to avoid hardware, locale, or random STT behaviour:

~~~swift
@MainActor
let data = try! JSONSerialization.data(withJSONObject: ["hello", "world"])
let b64 = data.base64EncodedString()
let io = ScriptedVoiceIO(fromBase64: b64)!

let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
let r2 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)

XCTAssertEqual(r1.transcript, "hello")
XCTAssertEqual(r2.transcript, "world")
~~~

### UI voice selection and previews

- Use 'VoiceChooserView' + 'VoiceProfilesStore' to:
  - List system voices.
  - Save per-voice profiles and master tuning.
- For tests:
  - Prefer a fake type conforming to 'TTSConfigurable & VoiceListProvider' to avoid hitting real AV/locale.

### Live STT smoke tests (opt-in)

To exercise real STT (on device or a good simulator) without making CI flaky:

~~~swift
@MainActor
final class RealSTTSmokeTests: XCTestCase {
    func testLiveListenDoesNotCrash() async throws {
        guard ProcessInfo.processInfo.environment["REAL_STT_SMOKE"] == "1" else {
            throw XCTSkip("REAL_STT_SMOKE not enabled; skipping live STT smoke test")
        }

        let io = RealVoiceIO()
        try await io.ensurePermissions()
        try await io.configureSessionIfNeeded()

        _ = try? await io.listen(timeout: 3, inactivity: 1.0, record: false)
        // Pass if no crash/deadlock/unexpected error.
    }
}
~~~

CI: don’t set ‘REAL_STT_SMOKE’ → test is skipped.

### CI detection: IsCI.running

VoiceKit automatically detects CI environments via the `IsCI` utility. When `IsCI.running == true`:

- ‘ensurePermissions()’ succeeds immediately (no system dialogs)
- ‘listen()’ returns deterministic stub results:
  - If ‘RecognitionContext.expectation == .number’, returns transcript "42"
  - Otherwise, returns the current ‘transcript’ property value (default: empty string)
  - No audio hardware is accessed
- ‘speak()’ uses a minimal synthetic path (no ‘AVSpeechSynthesizer’ instantiation)
- All operations are fully deterministic and fast

**Detection priority:**

1. ‘VOICEKIT_FORCE_CI’ environment variable (override): "1", "true", or "yes" forces CI mode
2. ‘CI’ environment variable (standard): set by GitHub Actions, GitLab CI, and other platforms
3. If neither is set, defaults to false (real hardware mode)

**Usage in tests:**

~~~swift
// Force CI mode in a test scheme:
// Build → Schemes → Edit Scheme → Test → Environment Variables
// Add: VOICEKIT_FORCE_CI = true

// Or skip a test in CI:
func testRealSTTFeature() async throws {
    guard !IsCI.running else {
        throw XCTSkip("Skipping real STT test in CI")
    }
    // ...real audio test...
}

// Or force real mode even in CI (for smoke tests):
// VOICEKIT_FORCE_CI = false
~~~

For full details, see the `IsCI` enum documentation in `Sources/VoiceKit/Utilities/IsCI.swift`.

---

## Config & diagnostics

### VoiceIOConfig

Controls advanced behaviours of 'RealVoiceIO'. All values have sensible defaults.

Fields (relevant ones):

- 'trimPrePad: Double' - seconds of audio to keep *before* detected speech when trimming recordings. Preserves breath and consonant attack.
- 'trimPostPad: Double' - seconds of audio to keep *after* detected speech. Preserves word tail and natural intonation.
- 'clipWaitTimeoutSeconds: Double' - maximum duration to wait for a short clip (playClip, startPreparedClip) to complete. If the audio device is disconnected mid-playback, this prevents the app from hanging indefinitely.
- 'ttsSuppressAfterFinish: Double' - duration to suppress microphone input immediately after TTS finishes. Prevents the microphone from picking up the speaker output when listen() starts immediately after speak().

Usage example:

~~~swift
let cfg = VoiceIOConfig(
    trimPrePad: 0.10,
    trimPostPad: 0.30,
    clipWaitTimeoutSeconds: 1.5,
    ttsSuppressAfterFinish: 0.25
)

let io = RealVoiceIO(config: cfg)
~~~

### VoiceIOError

Canonical error cases 'RealVoiceIO' may surface when you wire real STT/audio, e.g.:

- 'micUnavailable'
- 'recognizerUnavailable'
- 'audioFormatInvalid'
- 'timedOut'
- 'cancelled'
- 'underlying(String)' - wraps a short message from deeper layers

Your app should be prepared to switch on these and present user‑friendly messages.

### VoiceKitInfo

Light runtime metadata for logging and diagnostics:

- 'VoiceKitInfo.version' - semantic version string (e.g., '"0.1.3"').
- 'VoiceKitInfo.buildTimestampISO8601' - build‑time timestamp in ISO‑8601.

Example:

~~~swift
print("VoiceKit \(VoiceKitInfo.version) @ \(VoiceKitInfo.buildTimestampISO8601)")
~~~

---

## Build/test helper (optional)

A shell alias to keep your SwiftPM loop fast and clipboard‑friendly:

~~~bash
alias test='(swift build && SWIFTPM_TEST_LOG_FORMAT=xcode swift test) 2>&1 | tee >(tail -n ${LINES_CLIP:-200} | toClip)'
~~~

- 'xcode' format improves readability.
- Full output stays in your terminal; only the last ~200 lines go to the clipboard.
- Adjust 'LINES_CLIP' as needed.

---

## API reference snapshots (current)

### VoiceIO (public protocol, @MainActor)

~~~swift
@MainActor
public protocol VoiceIO: AnyObject {
    // Observable state (fine-grained tracking via @Observable)
    var isSpeaking: Bool { get }
    var isListening: Bool { get }
    var transcript: String { get }
    var audioLevel: CGFloat { get }
    var pulse: CGFloat { get }
    var statusMessage: String? { get }

    // Session / permissions
    func ensurePermissions() async throws
    func configureSessionIfNeeded() async throws

    // Core I/O
    func speak(_ text: String) async  // Uses default voice profile; supports <sfx:URL> and <silence:N> tokens
    func pause(_ seconds: TimeInterval) async  // Explicit pause; respects task cancellation
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
~~~

### TTSConfigurable (shared with UI; @MainActor)

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

### speak() methods (RealVoiceIO)

Both overloads support embedded SFX tokens in the text:

~~~swift
// Use default voice profile
public func speak(_ text: String) async

// Use specific voice profile by ID
public func speak(_ text: String, using voiceID: String?) async

// Measure actual synthesis duration
public func speakAndMeasure(_ text: String, using voiceID: String?) async -> TimeInterval
~~~

**Processing**:
1. Text is split into sentences at boundaries: `.`, `!`, `?`
2. Inline tokens (`<sfx:URL>`, `<silence:N>`) are parsed and extracted
3. Text segments, SFX clips, and silences alternate sequentially
4. Each text segment uses the specified voice profile
5. SFX clips play with 0dB gain; silence tokens pause using `Task.sleep`

**Example**:
```swift
let ding = "file:///path/to/ding.caf"
await io.speak("Hello <sfx:\(ding)> <silence:0.5> world. How are you?")
// → [speak "Hello ", play ding.caf, pause 0.5s, speak " world.", speak " How are you?"]
```

### Models (shared)

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

### Recognition context

~~~swift
public struct RecognitionContext: Sendable {
    public enum Expectation: Sendable {
        case freeform
        case name(allowed: [String])
        case number
    }

    public var expectation: Expectation

    public init(expectation: Expectation = .freeform) {
        self.expectation = expectation
    }
}
~~~

Notes:

- 'listen' in 'RealVoiceIO' uses an internal 'recognitionContext' to choose hints and contextual strings.
- '.number' contexts may normalize numeric phrases (e.g., "forty two point five" → '"42.5"').
- '.name(allowed:)' can bias STT toward a small allowed set.

---

## Concurrency notes

- Public APIs and callbacks run on '@MainActor'.
- The audio input tap runs on a realtime audio queue and is explicitly **nonisolated**:
  - It never touches '@MainActor' state directly.
  - It posts into 'STTActivityTracker' and the STT request.
- Avoid capturing '@MainActor self' inside any callbacks that are executed on realtime audio threads.

For deeper implementation details and simulator quirks, see 'Docs/Concurrency.md'.
