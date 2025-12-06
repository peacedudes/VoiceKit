# VoiceKit Guide

Audience
- Swift developers building iOS 17+/macOS 14+ apps who want reliable voice I/O with a simple, testable API.

What this page covers
- How to use 'RealVoiceIO' for:
  - Speaking text (TTS)
  - Listening for speech (STT) with timeouts and inactivity
  - Optional recording + smart trimming of the user’s utterance
  - Short “clip” playback (near-zero-gap name playback or SFX)
- VoiceKitUI: VoiceChooserView + VoiceProfilesStore
- Sequencing with VoiceQueue (speak + SFX + pauses)
- Concurrency and testing patterns

> CI / simulator behavior is summarized briefly near the end. Most of this page focuses on **how to use VoiceKit in a real app**.

---

## Requirements and installation

Requirements
- Swift tools-version: 6.0 ('swiftLanguageModes [.v6]')
- iOS 17.0+ and/or macOS 14.0+
- If you use real STT in your app target, add Info.plist keys:
  - 'NSMicrophoneUsageDescription'
  - 'NSSpeechRecognitionUsageDescription'

Install (Swift Package Manager)
- Local during development:
  - Add Local Package...; select the VoiceKit folder.
  - Link 'VoiceKit' and (optionally) 'VoiceKitUI' to your app target.
- Remote:
  - Add from your Git URL.
  - Rule “Up to Next Major” from your tag (e.g., 'v0.1.3').

Modules
- **VoiceKit**
  - 'RealVoiceIO' (@MainActor): production voice engine
    - TTS via 'AVSpeechSynthesizer'
    - Live STT via 'AVAudioEngine' + 'SFSpeechRecognizer'
    - Recording + trimming for listens
    - Short-clip playback ('prepareClip' / 'startPreparedClip' / 'playClip')
  - 'ScriptedVoiceIO' (@MainActor): deterministic engine for tests/demos.
  - 'VoiceQueue' (@MainActor): sequence speak/SFX/pause; optional parallel channels.
  - Utilities: 'NameMatch', 'NameResolver', 'PermissionBridge', 'VoiceOpGate', etc.
  - Models: 'TTSVoiceInfo', 'TTSVoiceProfile', 'Tuning', 'RecognitionContext', 'VoiceResult'.
- **VoiceKitUI**
  - 'VoiceChooserView': pick a system voice and tune rate/pitch/volume with live preview.
  - 'VoiceProfilesStore': JSON persistence for profiles/tuning/flags; deterministic in tests.

---

## Quick start: speak and listen

### A minimal “say something and listen back” flow

~~~swift
import VoiceKit

@MainActor
final class DemoViewModel: ObservableObject {
    let voice = RealVoiceIO()

    @Published var transcript: String = ""

    func run() {
        Task {
            try await voice.ensurePermissions()
            try await voice.configureSessionIfNeeded()

            await voice.speak("Say your name after the beep.")

            let result = try await voice.listen(
                timeout: 8,
                inactivity: 2,
                record: false,
                context: .init(expectation: .freeform)
            )

            transcript = result.transcript
        }
    }
}
~~~

Key points:
- 'RealVoiceIO' is '@MainActor'. Call all its methods from the main actor (SwiftUI already is).
- 'ensurePermissions()':
  - Requests microphone + speech recognizer access (unless CI overrides are active).
- 'configureSessionIfNeeded()':
  - Configures 'AVAudioSession' appropriately on iOS, and is a no-op / light touch on macOS.
- 'listen(timeout:inactivity:record:context:)':
  - 'timeout': hard cap on overall listen duration (seconds).
  - 'inactivity': seconds of “silence after speech” before automatically stopping.
  - 'record': when 'true', records the mic input, then trims around the speech and returns a 'recordingURL'.
  - 'context': hints for STT (freeform vs numeric vs constrained names).

---

## STT semantics: timeout, inactivity, recording, context

### Signature

~~~swift
@MainActor
public protocol VoiceIO {
    func listen(
        timeout: TimeInterval,
        inactivity: TimeInterval,
        record: Bool
    ) async throws -> VoiceResult
}

public struct VoiceResult: Sendable {
    public let transcript: String
    public let recordingURL: URL?
}

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

There is a convenience overload for 'RealVoiceIO' that takes a context:

~~~swift
// Protocol extension (effective when self is a RealVoiceIO instance)
public extension VoiceIO {
    func listen(
        timeout: TimeInterval,
        inactivity: TimeInterval,
        record: Bool,
        context: RecognitionContext = .init()
    ) async throws -> VoiceResult {
        if let real = self as? RealVoiceIO {
            real.setRecognitionContext(context)
        }
        return try await listen(timeout: timeout, inactivity: inactivity, record: record)
    }
}
~~~

### Live STT pipeline (apps)

When 'IsCI.running == false' (your app on device or simulator), 'RealVoiceIO.listen(...)':

1. Ensures permissions (mic + speech).
2. Configures 'AVAudioSession' for voice I/O on iOS.
3. Creates an 'AVAudioEngine' + 'SFSpeechAudioBufferRecognitionRequest' + 'SFSpeechRecognizer'.
4. Installs an input tap on the engine:
   - Forwards audio buffers to the speech request.
   - Optionally writes them to a '.caf' file when 'record == true'.
   - Computes buffer loudness in dB and feeds an 'STTActivityTracker' actor.
5. Starts recognition:
   - Updates 'latestTranscript' and 'onTranscriptChanged' as results arrive.
   - Tracks first/last speech times ('firstSpeechStart' / 'lastSpeechEnd') from STT segments.
   - When 'result.isFinal', finishes the listen.
6. Enforces timeouts:
   - **Overall timeout**: stops after 'timeout' seconds, regardless of activity.
   - **Inactivity timeout**: stops after 'inactivity' seconds since the last “loud” buffer, using 'STTActivityTracker'’s adaptive noise floor.
7. Recording + trimming (if 'record == true'):
   - Writes raw audio to a temp '.caf' during the listen.
   - On completion, runs 'trimAudioSmart':
     - Uses STT timestamps when they look sane.
     - Falls back to energy-based bounds when needed.
     - Applies configurable pre/post pads ('trimPrePad', 'trimPostPad' in 'VoiceIOConfig').
   - Returns the trimmed URL in 'VoiceResult.recordingURL' (or 'nil' on failure).

### Numeric and name contexts

Use 'RecognitionContext' to give STT better hints:

~~~swift
// Numeric
let numberResult = try await voice.listen(
    timeout: 6,
    inactivity: 2,
    record: false,
    context: .init(expectation: .number)
)
// Example: "forty-two point five" -> "42.5"
print(numberResult.transcript)

// Name from a known list
let allowedNames = ["Alice", "Bob", "Charlotte"]
let nameResult = try await voice.listen(
    timeout: 8,
    inactivity: 2,
    record: true,
    context: .init(expectation: .name(allowed: allowedNames))
)
let resolved = NameResolver().resolve(transcript: nameResult.transcript, allowed: allowedNames)
~~~

---

## Short clips: near‑zero‑gap playback

Use the clip API for short name clips or effects that should follow TTS very closely:

~~~swift
let io = RealVoiceIO()

// Simple one-shot
let dingURL = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await io.playClip(url: dingURL, gainDB: 6)

// “Thank you,” then play the trimmed name clip with minimal gap
if let url = result.recordingURL {
    try await io.prepareClip(url: url, gainDB: 12)
    await io.speak("Thank you,")
    try await io.startPreparedClip()
}
~~~

Internally:
- 'prepareClip' sets up an 'AVAudioPlayer' with a gain in dB.
- 'startPreparedClip' plays the prepared clip and awaits its completion.
- 'playClip' is a convenience that calls both in sequence.

'VoiceQueue' builds on this to implement speak+SFX sequences (see below).

---

## VoiceQueue: sequencing speech + SFX + pauses

~~~swift
import VoiceKit

@MainActor
func playSequence(io: VoiceIO, sfxURL: URL) async {
    let queue = VoiceQueue(primary: io)
    queue.enqueueSpeak("Step one.")
    queue.enqueueSFX(sfxURL, gainDB: 3)
    queue.enqueuePause(0.2)
    queue.enqueueSpeak("Step two.")
    await queue.play()
}
~~~

Embedded SFX tokens in text:

~~~swift
let nameClipURL: URL = /* recorded name URL */
let resolver: VoiceQueue.SFXResolver = { name in
    switch name {
    case "nameClip": return nameClipURL
    case "ding":     return Bundle.main.url(forResource: "ding", withExtension: "caf")
    default:         return nil
    }
}

let text = "Hello [sfx:nameClip] may I call you Alex?"
let q = VoiceQueue(primary: RealVoiceIO())
q.enqueueParsingSFX(text: text, resolver: resolver, defaultVoiceID: nil)
await q.play()
~~~

Notes:
- If an SFX token follows a 'speak' item, VoiceQueue pre‑schedules the clip with 'prepareClip' and then starts it with 'startPreparedClip' to minimize the gap.

---

## VoiceKitUI: VoiceChooserView and profiles

### Embedding the voice chooser

~~~swift
import SwiftUI
import VoiceKit
import VoiceKitUI

struct SettingsView: View {
    @StateObject private var store = VoiceProfilesStore()
    private let io = RealVoiceIO()

    var body: some View {
        VoiceChooserView(tts: io, store: store)
    }
}
~~~

VoiceChooserView:
- Lists system TTS voices.
- Lets users tune per‑voice 'TTSVoiceProfile' (rate, pitch, volume) with live audio preview.
- Persists:
  - Default voice ID.
  - Master tuning ('Tuning').
  - Per‑voice profiles.
  - Hidden/active flags.

Under the hood:
- 'VoiceProfilesStore' stores everything in a JSON file under Application Support.
- 'VoiceChooserViewModel' keeps the UI in sync with the TTS engine (anything conforming to 'TTSConfigurable' & 'VoiceIO').

For tests, you can use a fake engine instead of 'RealVoiceIO':

~~~swift
@MainActor
final class FakeTTS: TTSConfigurable, VoiceListProvider {
    var voices: [TTSVoiceInfo] = []
    var profiles: [String: TTSVoiceProfile] = [:]
    var defaultProfile: TTSVoiceProfile?
    var tuning: Tuning = .init()

    nonisolated func availableVoices() -> [TTSVoiceInfo] { MainActor.assumeIsolated { voices } }
    func setVoiceProfile(_ profile: TTSVoiceProfile) { profiles[profile.id] = profile }
    func getVoiceProfile(id: String) -> TTSVoiceProfile? { profiles[id] }
    func setDefaultVoiceProfile(_ profile: TTSVoiceProfile) { defaultProfile = profile }
    func getDefaultVoiceProfile() -> TTSVoiceProfile? { defaultProfile }
    func setTuning(_ tuning: Tuning) { self.tuning = tuning }
    func getTuning() -> Tuning { tuning }
    func speak(_ text: String, using voiceID: String?) async {}
}
~~~

---

## Concurrency and testing

Concurrency basics
- 'RealVoiceIO', 'ScriptedVoiceIO', and 'SystemVoicesCache' are '@MainActor'.
  - Call them from the main actor (SwiftUI view models, etc.).
- Callbacks ('onTranscriptChanged', 'onLevelChanged', 'onTTSSpeakingChanged', 'onTTSPulse', 'onStatusMessageChanged') are invoked on '@MainActor'.
- The audio input tap used by live STT is a **nonisolated** closure running on a realtime audio queue:
  - It forwards buffers into the STT request and 'STTActivityTracker'.
  - It does **not** touch '@MainActor' state directly.
- See 'Docs/Concurrency.md' for more detail on patterns and edge cases.

Testing patterns
- Use **ScriptedVoiceIO** when you need deterministic behavior:

~~~swift
let data = try JSONSerialization.data(withJSONObject: ["hello", "world"])
let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!

let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
let r2 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)

XCTAssertEqual(r1.transcript, "hello")
XCTAssertEqual(r2.transcript, "world")
~~~

- Use 'FakeTTS' + 'VoiceProfilesStore' for UI tests around the chooser; avoid relying on real devices’ voice sets or locales.
- Use 'IsCI.running' / 'VOICEKIT_FORCE_CI' to:
  - Force CI mode for 'RealVoiceIO' (no real AV/permissions).
  - Short‑circuit 'PermissionBridge' and other system touchpoints.

### CI / simulator behavior (summary)

When 'IsCI.running == true' (e.g. when 'VOICEKIT_FORCE_CI=true' in your test scheme):

- 'ensurePermissions()' and 'PermissionBridge' return success immediately.
- 'listen(timeout:inactivity:record:)':
  - If 'RecognitionContext.expectation == .number', returns a stub 'VoiceResult' with transcript '"42"' (and 'recordingURL == nil').
  - Otherwise, returns whatever 'latestTranscript' is set to (default: empty string).
  - No AVAudioEngine or SFSpeechRecognizer work is performed.
- TTS “fast path”:
  - 'speak' toggles 'onTTSSpeakingChanged' and 'onTTSPulse' in a minimal synthetic way, without instantiating 'AVSpeechSynthesizer'.

This keeps CI runs deterministic and free from hardware/permission flakiness, while real apps on devices/simulators use the full pipelines described above.

---

## Changelog and license

- See 'CHANGELOG.md' for version history.
- License: MIT — see 'LICENSE'.
