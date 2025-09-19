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

RealVoiceIO
- TTS: AVSpeechSynthesizer; applies TTSVoiceProfile and TTSMasterControl; emits onTTSPulse/ onTTSSpeakingChanged.
- STT: default package path is a minimal shim suitable for CI/tests. If you adopt the full engine in your app, wire permissions and AVAudioEngine in your app target.

ScriptedVoiceIO
- Deterministic: init with base64 JSON array; listen() dequeues strings; speak() emits pulse pattern.

Convenience listen with context
```swift
let result = try await io.listen(timeout: 6, inactivity: 2, record: false,
                                 context: .init(expectation: .number))
```

Models (shared)
```swift
public struct TTSVoiceInfo { public let id, name, language: String }
public struct TTSVoiceProfile { public let id: String; public var rate: Double; public var pitch, volume: Float }
public struct TTSMasterControl { public var rateVariation, pitchVariation, volume: Float }
public struct VoiceResult { public let transcript: String; public let recordingURL: URL? }
public struct RecognitionContext { public enum Expectation { case freeform, name(allowed: [String]), number } }
```
