# VoiceKit

Reusable voice I/O for SwiftUI apps (iOS 17+, macOS 14+)

- VoiceKitCore: RealVoiceIO (AVSpeech + Speech framework + AVAudioEngine), ScriptedVoiceIO (deterministic test/demos), NameMatch utilities
- VoiceKitUI: VoicePickerView with profiles, favorites, language filter, and live previews

Status: 0.1.0 (early but production-friendly)

## Install (local package)

- In Xcode: File > Add Packages… > Add Local… and pick the VoiceKit folder.
- Link products to your app target: VoiceKitCore and (optionally) VoiceKitUI.

## Permissions (app Info.plist)

- NSMicrophoneUsageDescription
- NSSpeechRecognitionUsageDescription

## Quick start

```swift
import VoiceKitCore

@MainActor
final class MyVM: ObservableObject {
    private let voice = RealVoiceIO()

    func go() {
        Task {
            try? await voice.ensurePermissions()
            await voice.speak("Hello!")
            let r = try? await voice.listen(timeout: 8, inactivity: 2, record: false)
            print("Heard:", r?.transcript ?? "")
        }
    }
}
```

Voice Picker UI:

```swift
import VoiceKitCore
import VoiceKitUI

struct SettingsView: View {
    @State private var vm = MyVM()
    var body: some View {
        VoicePickerView(tts: vm.voice)
    }
}
```

## Tests

- Package tests: NameMatch and ScriptedVoiceIO (no device I/O).
- App tests: RealVoiceIO timing/boosted playback (device/simulator only).

## License

MIT. Attribution appreciated (rdoggett, GPT‑5/OpenAI).
