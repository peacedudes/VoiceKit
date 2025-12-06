# VoiceKit

Reusable voice I/O for SwiftUI apps (iOS 17+, macOS 14+). Swift 6–safe, test‑friendly, and designed for simple, production‑friendly APIs.

Modules at a glance
- VoiceKit: RealVoiceIO (TTS, live STT with optional recording and trimming, short clip playback), ScriptedVoiceIO (deterministic tests and demos), NameMatch/NameResolver, VoiceQueue, VoiceChorus, shared models and utilities.
- VoiceKitUI: VoiceChooserView (select a system voice and tune rate, pitch, volume with live preview), VoiceProfilesStore, smaller reusable components.

Highlights
- Swift 6 actor safety (@MainActor public API), careful permission and delegate handling.
- Live STT pipeline for apps, plus a deterministic CI stub path that avoids hardware and TCC.
- Optional recording and smart trimming of each listen into a short playback clip.
- Short clip path for near zero gap "Thank you, [name]" style flows.
- Clean shared models across core and UI; deterministic tests that do not depend on device voices or locale.

Requirements
- Swift tools-version: 6.0; Swift language mode v6
- iOS 17.0+ and/or macOS 14.0+

Install (Swift Package Manager)
- Local during development: Add Local Package...; choose the VoiceKit folder; link VoiceKit (and VoiceKitUI if needed).
- Remote: Add from your Git URL; rule "Up to Next Major" from your tag (for example, v0.1.3).
- No special embedding step is required; SwiftPM and Xcode handle linking automatically.

Quick start
~~~swift
import VoiceKit

@MainActor
final class DemoVM: ObservableObject {
  let voice = RealVoiceIO()

  @Published var transcript: String = ""

  func run() {
    Task {
      try await voice.ensurePermissions()
      try await voice.configureSessionIfNeeded()

      await voice.speak("Say your name after the beep.")

      let result = try? await voice.listen(
        timeout: 8,
        inactivity: 2,
        record: true,
        context: .init(expectation: .freeform)
      )

      transcript = result?.transcript ?? ""
    }
  }
}
~~~

Voice chooser
~~~swift
import VoiceKit
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
  @StateObject private var store = VoiceProfilesStore()
  let voice = RealVoiceIO()

  var body: some View {
    VoiceChooserView(tts: voice, store: store)
  }
}
~~~

Docs
- Docs/VoiceKitGuide.md (how to use RealVoiceIO, VoiceQueue, VoiceChorus, VoiceKitUI)
- Docs/ProgrammersGuide.md (quick start, sequencing, logging, boosted clips, config)
- Docs/Concurrency.md (actor safety and practical patterns)
- Docs/ROADMAP.md (structure, samples, scope decisions)
- CHANGELOG.md

Logging (opt-in)
- Set VOICEKIT_LOG=1 (or true/yes) in your scheme or environment to enable a default print logger in RealVoiceIO.
- Or set a custom logger:

~~~swift
// @MainActor
let realIO = RealVoiceIO()
realIO.logger = { level, msg in
  print("[VoiceKit][\(level)] \(msg)")
}
~~~

License
- MIT - see LICENSE.

