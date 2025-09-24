# Quick Start

Requirements
- Swift tools-version: 6.0 (swiftLanguageModes [.v6])
- iOS 17.0+ and/or macOS 14.0+

Add the package
- Local path while iterating: File > Add Packages… > Add Local… and choose the VoiceKit folder.
- Remote URL for releases: Add Packages… > paste the GitHub URL; rule “Up to Next Major” from your tag (e.g., v0.1.1+).

Link products
- Link VoiceKitCore (and VoiceKitUI if you use the picker). Do Not Embed.

App permissions (if you use RealVoiceIO.listen in your app)
- NSMicrophoneUsageDescription
- NSSpeechRecognitionUsageDescription

Say hello (TTS only)
```swift
import VoiceKitCore

@MainActor
final class DemoVM: ObservableObject {
    let voice = RealVoiceIO()
    func run() {
        Task {
            await voice.speak("Hello from VoiceKit!")
        }
    }
}
```

Listen (package default uses a simple shim suitable for tests)
```swift
let r = try await voice.listen(timeout: 6, inactivity: 2, record: false,
                               context: RecognitionContext(expectation: .number))
print("Heard:", r.transcript) // shim returns "42" for .number
```

Picker UI
```swift
import VoiceKitCore
import VoiceKitUI
import SwiftUI

struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View { VoicePickerView(tts: voice) }
}
```

Deterministic tests without hardware
```swift
import VoiceKitCore
import XCTest

@MainActor
final class ScriptTests: XCTestCase {
    func testListen() async throws {
        let data = try! JSONSerialization.data(withJSONObject: ["alpha","beta"])
        let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!
        let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
        XCTAssertEqual(r1.transcript, "alpha")
    }
}
```
