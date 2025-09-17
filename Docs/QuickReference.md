# VoiceKit Quick Reference

Import
- Core: import VoiceKitCore
- UI: import VoiceKitUI

Primary types
- RealVoiceIO (@MainActor): production speech + recognition engine.
- ScriptedVoiceIO (@MainActor): deterministic test engine; no hardware.
- VoiceQueue (@MainActor): kid‑friendly sequencing of speak/SFX/pause with optional parallel channels.
- VoicePickerView (SwiftUI): voices UI with profiles and live preview.

Common flows
- Permissions + session
```swift
let voice = RealVoiceIO()
try await voice.ensurePermissions()
try await voice.configureSessionIfNeeded()
```

- Speak
```swift
await voice.speak("Hello there!")
```

- Listen (with numeric hints)
```swift
let r = try await voice.listen(timeout: 6, inactivity: 2, record: false,
                               context: RecognitionContext(expectation: .number))
print(r.transcript)
```

- Play a short clip (boosted)
```swift
let url = Bundle.main.url(forResource: "ding", withExtension: "caf")!
try await voice.playBoosted(url: url, gainDB: 6)
```

- Sequence speak → sfx → speak (near‑zero gap)
```swift
let q = VoiceQueue(primary: voice)
q.enqueueSpeak("Thank you.", voiceID: nil)
q.enqueueSFX(url) // pre-scheduled; will auto-fire right after speak
q.enqueueSpeak("Next question.")
await q.play()
```

- Embedded SFX in text
```swift
let resolver: VoiceQueue.SFXResolver = { name in Bundle.main.url(forResource: name, withExtension: "caf") }
let q = VoiceQueue(primary: voice)
q.enqueueParsingSFX(text: "Say your name [sfx:ding] now.", resolver: resolver)
await q.play()
```

- Parallel channels (optional)
```swift
let q = VoiceQueue(primary: RealVoiceIO()) { RealVoiceIO() } // channel factory
q.enqueueSpeak("Left", on: 0)
q.enqueueSpeak("Right", on: 1)
await q.play() // channels 0 and 1 run concurrently
```

- Cancel everything
```swift
q.cancelAll()     // cancels queued playback
voice.stopAll()   // stops any active speech/recording/clip at engine level
```

Picker UI
```swift
import VoiceKitCore
import VoiceKitUI
let voice = RealVoiceIO()
VoicePickerView(tts: voice)
```

Diagnostics
```swift
print("VoiceKit", VoiceKitInfo.version)
```
