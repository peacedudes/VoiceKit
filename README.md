# VoiceKit

Reusable voice I/O for SwiftUI apps (iOS 17+, macOS 14+). Swift 6–safe, test‑friendly, and designed for delightful APIs.

Modules at a glance
- VoiceKit: RealVoiceIO (TTS with a simple STT test shim), ScriptedVoiceIO (deterministic tests/demos), NameMatch/NameResolver, VoiceQueue, models.
- VoiceKitUI: VoiceChooserView (select a system voice and tune rate/pitch/volume with live preview), and ChorusLabView (developer playground for multi‑voice experiments; not intended for production apps).

Highlights
- Swift 6 actor-safety (@MainActor public API), safe permission bridging.
- Deterministic test paths that don’t depend on device voices or locale.
- Clean shared models across Core and UI.

Requirements
- Swift tools-version: 6.0; Swift language mode v6
- iOS 17.0+ and/or macOS 14.0+

Install (Swift Package Manager)
- Local during development: Add Local Package…; choose the VoiceKit folder; link VoiceKit (and VoiceKitUI if needed).
- Remote: Add from your Git URL; rule “Up to Next Major” from your tag (e.g., v0.1.1).
- No special embedding step is required—SwiftPM/Xcode handle linking automatically.

Quick start
~~~swift
import VoiceKit

@MainActor
final class DemoVM: ObservableObject {
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
~~~

Voice chooser
~~~swift
import VoiceKit
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
  let voice = RealVoiceIO()
  var body: some View { VoiceChooserView(tts: voice) }
}
~~~

Docs
- Docs/VoiceKitGuide.md (comprehensive reference: API, models, UI, testing)
- Docs/ProgrammersGuide.md (concise: quick start, sequencing, logging, boosted clips)
- Docs/Concurrency.md (actor-safety and practical patterns)
- Docs/ROADMAP.md (structure, samples, scope decisions)
- CHANGELOG.md

Logging (opt-in)
- Set VOICEKIT_LOG=1 (or true/yes) in your scheme/environment to enable a default print logger in RealVoiceIO.
- Or, set a custom logger:
~~~swift
// @MainActor
let realIO = RealVoiceIO()
realIO.logger = { level, msg in print("[VoiceKit][\(level)] \(msg)") }
~~~

License
- MIT — see LICENSE.
