# VoiceKit

Reusable voice I/O for SwiftUI apps (iOS 17+, macOS 14+)
[![CI](https://github.com/rdoggett/VoiceKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/rdoggett/VoiceKit/actions/workflows/ci.yml?query=branch%3Amain)
Products
- VoiceKitCore: Voice I/O engine (RealVoiceIO), deterministic test engine (ScriptedVoiceIO), STT hints, TTS models, NameMatch utilities.
- VoiceKitUI: VoicePickerView with persistence (profiles, favorites, active/hidden, language filter, live previews).

Highlights
- Swift 6 actor-safety: main-actor public API, safe bridging for permission callbacks, audio tap isolation, TTS delegate isolation.
- Drop-in UI picker with user profiles and live “preview as you slide” behavior.
- Deterministic ScriptedVoiceIO for tests and demos.
- Lightweight utilities for name normalization and fuzzy matching.

Requirements
- Swift tools-version: 6.0 (swiftLanguageModes [.v6])
- iOS 17.0+ and/or macOS 14.0+
- App Info.plist keys:
  - NSMicrophoneUsageDescription
  - NSSpeechRecognitionUsageDescription

Quick start
```swift
import VoiceKitCore

@MainActor
final class DemoVM: ObservableObject {
    let voice = RealVoiceIO()
    func run() {
        Task {
            try? await voice.ensurePermissions()
            try? await voice.configureSessionIfNeeded()
            await voice.speak("Say your name after the beep.")
            let r = try? await voice.listen(timeout: 8, inactivity: 2, record: true)
            print("Heard:", r?.transcript ?? "(none)")
        }
    }
}
```

Voice picker UI
```swift
import VoiceKitCore
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View {
        VoicePickerView(tts: voice)
    }
}
```

Docs
- docs/QuickStart.md
- docs/ProgrammersGuide.md
- docs/VoiceIO.md
- docs/VoicePicker.md
- docs/Concurrency.md
- docs/Testing.md
- docs/FAQ.md
- CHANGELOG.md

Install
- Local (recommended while iterating): Add Package… > Add Local… and pick the VoiceKit folder; link VoiceKitCore and (optionally) VoiceKitUI (Do Not Embed).
- Remote (from GitHub): Add Packages… > enter the repo URL; rule “Up to Next Major” from your tag (e.g., v0.1.0).

License
- MIT — see LICENSE.
