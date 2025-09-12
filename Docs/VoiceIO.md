# VoiceIO API Reference

Import
```swift
import VoiceKitCore
```

VoiceIO (protocol, @MainActor)
```swift
public protocol VoiceIO: AnyObject {
    var onListeningChanged: ((Bool) -> Void)? { get set }
    var onTranscriptChanged: ((String) -> Void)? { get set }
    var onLevelChanged: ((CGFloat) -> Void)? { get set }
    var onTTSSpeakingChanged: ((Bool) -> Void)? { get set }
    var onTTSPulse: ((CGFloat) -> Void)? { get set }
    var onStatusMessageChanged: ((String?) -> Void)? { get set }

    func ensurePermissions() async throws
    func configureSessionIfNeeded() async throws

    func speak(_ text: String) async
    func listen(timeout: TimeInterval, inactivity: TimeInterval, record: Bool) async throws -> VoiceResult

    func prepareBoosted(url: URL, gainDB: Float) async throws
    func startPreparedBoosted() async throws
    func playBoosted(url: URL, gainDB: Float) async throws

    func stopAll()
    func hardReset()
}
```

Implementations
- RealVoiceIO (@MainActor)
  - Uses AVSpeechSynthesizer for TTS; SFSpeechRecognizer + AVAudioEngine for STT.
  - Conforms to TTSConfigurable.
  - VoiceResult contains transcript and optional trimmed recording URL when record = true.
- ScriptedVoiceIO (@MainActor)
  - Base64-encoded JSON array of strings; listen() dequeues and returns them; TTS is mocked with pulse callbacks.

TTSConfigurable
```swift
@MainActor
public protocol TTSConfigurable: AnyObject {
    func availableVoices() -> [TTSVoiceInfo]
    func setVoiceProfile(_ profile: TTSVoiceProfile)
    func getVoiceProfile(id: String) -> TTSVoiceProfile?
    func setDefaultVoiceProfile(_ profile: TTSVoiceProfile)
    func getDefaultVoiceProfile() -> TTSVoiceProfile?
    func setMasterControl(_ master: TTSMasterControl)
    func getMasterControl() -> TTSMasterControl
    func speak(_ text: String, using voiceID: String?) async
    func stopSpeakingNow()
}
```

Models
```swift
public struct TTSVoiceInfo { public let id, name, language: String }
public struct TTSVoiceProfile { public let id: String; public var displayName: String; public var rate, pitch, volume: Float; public var isSelected, isHidden: Bool }
public struct TTSMasterControl { public var volume, pitchVariation, rateVariation: Float }
public struct VoiceResult { public let transcript: String; public let recordingURL: URL? }
public struct RecognitionContext { public enum Expectation { case freeform, name(allowed: [String]), number } }
```

Examples
Speak and listen
```swift
let voice = RealVoiceIO()
try await voice.ensurePermissions()
try await voice.configureSessionIfNeeded()
await voice.speak("Please say your favorite number.")
let r = try await voice.listen(timeout: 6, inactivity: 2, record: false)
print(r.transcript)
```

Use STT hints
```swift
let r = try await voice.listen(timeout: 6, inactivity: 2, record: false,
                               context: RecognitionContext(expectation: .number))
```

Boosted short-clip playback
```swift
let url = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await voice.prepareBoosted(url: url, gainDB: 6)
try await voice.startPreparedBoosted()
```
