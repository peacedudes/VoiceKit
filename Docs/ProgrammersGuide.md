# VoiceIO Programmer’s Guide

This document introduces the `VoiceIO` API used in **VoiceLogin**. It is designed to be a small, reusable component for:

- Text‑to‑speech (TTS)
- Speech‑to‑text (STT)
- Short‑clip playback of recorded audio (e.g., “hear your name back”)

with clean concurrency and low‑latency “Thank you → play clip” handoff.

---

## Targets

- iOS 17+ (primary), macOS supported with conditional permission handling.
- Swift 6, strict actor isolation.
- All public `RealVoiceIO` APIs are `@MainActor`.

---

## Modules

- **RealVoiceIO** (VoiceKit):
  - Production implementation using `AVFoundation` + `Speech`.
  - Handles TTS, STT, recording, trimming, and short‑clip playback.

- **ScriptedVoiceIO** (VoiceKit):
  - Deterministic test double for UI/integration tests.
  - Returns a scripted sequence of transcripts and simulates TTS pulses.

- **VoiceIO (protocol)**:
  - Unified API surface that both implementations conform to.

---

## Quick Start

### 1. Create an instance

~~~swift
// Production (app code)
@MainActor
let voice: VoiceIO = RealVoiceIO()

// Tests / previews / UI automation
@MainActor
let data = try JSONSerialization.data(withJSONObject: ["Alice", "yes", "no"])
let b64 = data.base64EncodedString()
let voice: VoiceIO = ScriptedVoiceIO(fromBase64: b64)!
// or ScriptedVoiceIO(script: ["Alice", "yes", "no"])
~~~

### 2. Request permissions and configure audio session (iOS)

Call these *once* early in your flow (e.g., before the first STT):

~~~swift
try await voice.ensurePermissions()
try await voice.configureSessionIfNeeded()
~~~

- On iOS:
  - Prompts for microphone access if needed.
  - Requests speech recognition authorization.
  - Verifies that a `SFSpeechRecognizer` is available.
  - Configures `AVAudioSession` for voice I/O.
- On macOS:
  - Requests mic access via `AVCaptureDevice`.
  - Uses the default audio session.

These calls are safe to invoke multiple times (idempotent-ish), but in app code you should conceptually treat them as a one‑time bootstrap.

### 3. Speak, then listen for a reply

~~~swift
await voice.speak("Please say your name.")

let result = try await voice.listen(
    timeout: 12,        // hard cap on total listening time
    inactivity: 2.0,    // seconds of silence after speech
    record: true        // mirror audio to a trimmed clip
)

// Use the transcript
let transcript = result.transcript

// Optionally prepare the trimmed recording for playback
if let url = result.recordingURL {
    try await voice.prepareClip(url: url, gainDB: 12)
    await voice.speak("Thank you,")
    try await voice.startPreparedClip()
}
~~~

---

## API Surface

### Protocol (conceptual)

~~~swift
@MainActor
protocol VoiceIO {
    // UI callbacks (set by client)
    var onListeningChanged: ((Bool) -> Void)? { get set }
    var onTranscriptChanged: ((String) -> Void)? { get set }
    var onLevelChanged: ((CGFloat) -> Void)? { get set }
    var onTTSSpeakingChanged: ((Bool) -> Void)? { get set }
    var onTTSPulse: ((CGFloat) -> Void)? { get set }
    var onStatusMessageChanged: ((String?) -> Void)? { get set }

    // Session / permissions
    func ensurePermissions() async throws
    func configureSessionIfNeeded() async throws

    // Core I/O
    func speak(_ text: String) async
    func listen(timeout: TimeInterval,
                inactivity: TimeInterval,
                record: Bool) async throws -> VoiceResult

    // Short-clip playback (using pre-recorded audio)
    func prepareClip(url: URL, gainDB: Float) async throws
    func startPreparedClip() async throws
    func playClip(url: URL, gainDB: Float) async throws

    // Lifecycle / emergency stop
    func stopAll()
    func hardReset()
}
~~~

### Types

~~~swift
struct VoiceResult {
    /// Final transcript for the listen. May be post-processed for numeric contexts.
    let transcript: String

    /// Optional trimmed recording of the user’s speech, or nil if:
    /// - record == false, or
    /// - recording failed, or
    /// - the platform does not support recording in the current configuration.
    let recordingURL: URL?
}

/// Example error type used by VoiceIO implementations.
enum VoiceIOError: Error {
    case recognizerUnavailable   // System STT stack is not available
    // ... other cases as needed
}
~~~

---

## STT Semantics

### `listen(timeout:inactivity:record:)`

Parameters:

- `timeout` (seconds)
  - Hard cap on total listen duration.
  - If this elapses, the listen ends even if the user is still talking.
- `inactivity` (seconds)
  - Measures *silence after speech*.
  - The inactivity timer starts **only after a non‑empty transcript is observed**.
  - Silence is measured using an adaptive noise floor:
    - Buffers whose loudness (in dB) is significantly above the learned baseline are treated as “speech”.
    - When we’ve seen `inactivity` seconds since the last such buffer, we stop.
- `record` (Bool)
  - When `true`, STT input is mirrored into a temp CAF file.
  - After the listen completes, the file is:
    - Trimmed to a window that covers the spoken region:
      - Primary signal: first and last speech timestamps from STT segments.
      - Fallback: energy-based start/end when STT timestamps don’t describe the full file (e.g. long leading silence).
    - Padded by a small pre/post amount (`trimPrePad`, `trimPostPad`) to avoid clipping consonants.
  - `VoiceResult.recordingURL` is set to the trimmed file, or `nil` on failure.

Behaviour:

- On success:
  - Returns `VoiceResult(transcript: ..., recordingURL: optionalTrimmedURL)`.
- On cancellation:
  - Throws `CancellationError`.
  - `hardReset()` will also cancel a pending listen and clear state.
- On recognizer unavailability:
  - Implementations may throw `VoiceIOError.recognizerUnavailable`.
  - Callers (like `LoginFlow`) should surface this clearly (“Speech recognizer is unavailable on this device…”) and abort, not blindly re-prompt.

---

## Callbacks (UI wiring)

Set these closures to keep your UI reactive:

- `onListeningChanged(Bool)`
  - Called when STT starts/stops listening.
  - Drives mic UI state (e.g., red “recording” dot and “Recording” label vs “Idle”).

- `onTranscriptChanged(String)`
  - Called with live transcript updates (partial + final).
  - In VoiceLogin, this drives the “Heard so far” text.

- `onLevelChanged(CGFloat)`
  - Mic input level in `[0, 1]` (normalized from buffer energy / dB).
  - Drives a mic meter or pulse visualization.

- `onTTSSpeakingChanged(Bool)`
  - Whether TTS is currently speaking.
  - Good for “speaking” indicators or disabling certain buttons.

- `onTTSPulse(CGFloat)`
  - Decorative TTS pulse level (e.g., to drive a waveform/pulse view while TTS is active).

- `onStatusMessageChanged(String?)`
  - Optional status text channel (e.g., “Confirm: \<username\>”).
  - VoiceLogin uses this to show flow‑level status.

All callbacks are invoked on the main actor.

---

## TTS Semantics

### `speak(_:)`

- Queues a single TTS utterance and waits until it finishes.
- UI can listen to:
  - `onTTSSpeakingChanged` for start/stop.
  - `onTTSPulse` for a decorative animation.

### Short‑clip playback (`prepareClip`, `startPreparedClip`, `playClip`)

These APIs are used to play **pre‑recorded** audio (e.g., the trimmed name clip) with an optional gain boost:

- `prepareClip(url:gainDB:)`
  - Schedules the clip for playback and applies `gainDB` (in dB) via an EQ node.
  - Non‑blocking; prepares an internal pipeline.

- `startPreparedClip()`
  - Starts playback of the previously prepared clip and awaits its completion (or a timeout, depending on config).
  - Used in flows like “Thank you, [play name]”.

- `playClip(url:gainDB:)`
  - Convenience: prepare + start in one call.
  - Asynchronous; returns when playback is finished or timed out.

---

## Lifecycle and Sequencing

A typical high‑level sequence:

1. Permissions + audio session:

   ~~~swift
   try await voice.ensurePermissions()
   try await voice.configureSessionIfNeeded()
   ~~~

2. Speak a prompt:

   ~~~swift
   await voice.speak("Please say your name.")
   ~~~

3. Listen:

   ~~~swift
   let result = try await voice.listen(timeout: 12, inactivity: 2, record: true)
   ~~~

4. Use result:

   - Transcript for logic:

     ~~~swift
     let name = result.transcript
     ~~~

   - Optional clip for UX:

     ~~~swift
     if let url = result.recordingURL {
         try await voice.prepareClip(url: url, gainDB: 12)
         await voice.speak("Thank you,")
         try await voice.startPreparedClip()
     }
     ~~~

5. Cancel / reset:

   ~~~swift
   // Stop ongoing speech, listens, and clear state.
   voice.hardReset()
   ~~~

`RealVoiceIO` internally serializes high‑level operations to avoid overlapping `speak`/`listen`/clip playback in unsafe ways.

---

## Testing Strategy

### Deterministic logic tests

Use `ScriptedVoiceIO` or small VoiceIO fakes:

- Scripted flows:

  ~~~swift
  let io = ScriptedVoiceIO(script: ["Nick Danger", "yes", "no"])!
  let res = try await io.listen(timeout: 5, inactivity: 1, record: false)
  XCTAssertEqual(res.transcript, "Nick Danger")
  ~~~

- FakeVoiceIO (like in VoiceLoginTests) lets you enqueue `VoiceResult` values directly and capture `speak` calls.

### Live STT smoke tests (opt‑in)

For testing **on a real device / good simulator**, you can add a small smoke test guarded by an env var:

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
        // Test passes if we don’t crash, deadlock, or throw unexpected errors.
    }
}
~~~

- CI: do **not** set `REAL_STT_SMOKE` → test is skipped (no flakiness).
- Local/device: set it to `"1"` in the test scheme to exercise the real STT path.

---

## Troubleshooting Notes

- **Simulator spam (kLSR=300, kAFA=1101)**:
  - Sometimes iOS Simulator’s localspeechrecognition assets get into a bad state and log errors:
    - `kLSRErrorDomain Code=300 "Failed to initialize recognizer"`
    - `kAFAssistantErrorDomain Code=1101` for `com.apple.speech.localspeechrecognition`.
  - Resetting the simulator usually clears this; it’s an OS issue rather than VoiceKit logic.
  - Future improvement: track repeated recognizer failures and map to `VoiceIOError.recognizerUnavailable`, so apps can surface a clear message instead of re‑prompting while the OS spams logs.

- **“Ghost” listening after Cancel**:
  - `RealVoiceIO.hardReset()` now:
    - Cancels timers and recognition.
    - Stops `AVAudioEngine` and removes the tap.
    - Cancels any pending listen continuation with `CancellationError`.
  - After Cancel, `onTranscriptChanged` should no longer fire until a new `listen` is started.

- **Inactivity feels too long/short**:
  - Tune `inactivity` at the call site (e.g., `1.5–2.0` seconds for name capture, a bit longer for passwords).
  - Remember inactivity starts only after first non‑empty transcript and is measured relative to an adaptive noise floor.

---

This guide is meant to be the “how do I use this?” entrypoint. For deeper implementation details (exact types, file layout, simulator quirks, future robustness ideas), see `handoff.md` in the VoiceKit repo.
