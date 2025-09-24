# VoiceKit Quick Reference

Import
- Core: import VoiceKitCore
- UI: import VoiceKitUI

Primary types
- RealVoiceIO (@MainActor): production TTS + a simple STT test shim by default.
- ScriptedVoiceIO (@MainActor): deterministic listen/speak for tests and demos.
- VoiceQueue (@MainActor): sequence speak/SFX/pause; optional parallel channels.
- VoicePickerView (SwiftUI): system voices with profiles, hidden/active, preview.

Core models (as used across Core & UI)
```swift
public struct TTSVoiceInfo { public let id, name, language: String }
public struct TTSVoiceProfile { public let id: String; public var rate: Double; public var pitch, volume: Float }
public struct TTSMasterControl { public var rateVariation, pitchVariation, volume: Float }
public struct VoiceResult { public let transcript: String; public let recordingURL: URL? }
public struct RecognitionContext { public enum Expectation { case freeform, name(allowed: [String]), number } }
```

Typical flow
- Speak
```swift
let io = RealVoiceIO()
await io.speak("Hello there!")
```

- Listen (shim returns “42” for .number)
```swift
let r = try await io.listen(timeout: 6, inactivity: 2, record: false,
                            context: .init(expectation: .number))
```

- Short clip SFX
```swift
let url = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await io.playBoosted(url: url, gainDB: 6)
```

- Sequencing with VoiceQueue
```swift
let q = VoiceQueue(primary: io)
q.enqueueSpeak("A")
q.enqueueSFX(url)
q.enqueueSpeak("B")
await q.play()
```

Picker UI
```swift
let voice = RealVoiceIO()
VoicePickerView(tts: voice)
```
