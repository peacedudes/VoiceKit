# VoiceKit

Reusable voice I/O for SwiftUI apps (iOS 17+, macOS 14+)

Products
- VoiceKitCore: RealVoiceIO (TTS), ScriptedVoiceIO (deterministic tests/demos), NameMatch/NameResolver, minimal STT shim, VoiceQueue, models.
- VoiceKitUI: VoicePickerView with profiles (default/active/hidden), language filter, and live previews.

Highlights
- Swift 6 actor-safety (@MainActor API), safe permission bridging, deterministic test path.
- Picker UI with persisted profiles and debounced previews.
- Clean models shared across Core and UI.

Requirements
- Swift tools-version: 6.0; Swift language mode v6
- iOS 17.0+ and/or macOS 14.0+
- App Info.plist keys (if you enable real STT in app): NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription

Quick start
```swift
import VoiceKitCore
@MainActor final class DemoVM: ObservableObject {
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

Voice picker
```swift
import VoiceKitCore, VoiceKitUI, SwiftUI
struct SettingsView: View {
  let voice = RealVoiceIO()
  var body: some View { VoicePickerView(tts: voice) }
}
```

Docs
- Docs/QuickStart.md
- Docs/ProgrammersGuide.md
- Docs/VoiceIO.md
- Docs/VoicePicker.md
- Docs/Concurrency.md
- Docs/Testing.md
- Docs/FAQ.md
- CHANGELOG.md

Install
- Local during development: Add Local Package…; link VoiceKitCore and (optionally) VoiceKitUI (Do Not Embed).
- Remote: Add from GitHub URL; rule “Up to Next Major” from your tag (e.g., v0.1.1).

License
- MIT — see LICENSE.
