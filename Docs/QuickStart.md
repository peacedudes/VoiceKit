# Quick Start

1) Add the package
- Local path (fastest while iterating): File > Add Packages… > Add Local… and choose the VoiceKit folder.
- Remote URL (for releases): Add Packages… > paste the GitHub URL; select “Up to Next Major” starting at v0.1.0.

2) Link products
- In your app target, General > Frameworks, Libraries, and Embedded Content:
  - Add VoiceKitCore and VoiceKitUI (Do Not Embed).

3) App permissions
- Add to Info.plist:
  - NSMicrophoneUsageDescription
  - NSSpeechRecognitionUsageDescription

4) Use RealVoiceIO
```swift
import VoiceKitCore

@MainActor
final class MyVM: ObservableObject {
    let voice = RealVoiceIO()
    func go() {
        Task {
            try? await voice.ensurePermissions()
            try? await voice.configureSessionIfNeeded()
            await voice.speak("Hello!")
            let r = try? await voice.listen(timeout: 8, inactivity: 2, record: false)
            print("Transcript:", r?.transcript ?? "")
        }
    }
}
```

5) Add the picker UI
```swift
import VoiceKitCore
import VoiceKitUI

struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View {
        VoicePickerView(tts: voice)
    }
}
```

6) Tests without hardware
- Use ScriptedVoiceIO:
```swift
import VoiceKitCore
import XCTest

@MainActor
final class ScriptTests: XCTestCase {
    func testListen() async throws {
        let b64 = try! JSONSerialization.data(withJSONObject: ["alpha","beta"]).base64EncodedString()
        let io = ScriptedVoiceIO(fromBase64: b64)!
        let r1 = try await io.listen(timeout: 1.5, inactivity: 0.4, record: false)
        XCTAssertEqual(r1.transcript, "alpha")
    }
}
```
