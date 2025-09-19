# VoicePickerView (VoiceKitUI)

What it provides
- SwiftUI picker for system voices with:
  - Favorite (default), Active set, Hide/Unhide + Show hidden toggle
  - Filter: Current language or All (based on Locale)
  - Master controls (volume, pitch range, speed range) with live preview (debounced)
  - Tap a row to preview; slider changes also trigger short previews

Usage
```swift
import VoiceKitCore
import VoiceKitUI

let voice = RealVoiceIO()
VoicePickerView(tts: voice) // creates its own VoiceProfilesStore
```

Persistence (VoiceProfilesStore)
- JSON at Application Support/VoiceIO/<filename>
- Fields:
  - defaultVoiceID: String?
  - master: TTSMasterControl
  - profilesByID: [String: TTSVoiceProfile] (Core model: rate: Double; pitch/volume: Float)
  - activeVoiceIDs: [String]
  - hiddenVoiceIDs: [String]  // in newer UI store
- APIs: profile(for:), setProfile(_), toggleActive(_), setHidden(_:_:), save(), load()

Deterministic testing
- Use FakeTTS (conforming to TTSConfigurable) in UI tests. Avoid asserting specific system voices. Keep language filtering deterministic by setting languageFilter directly or using .all.
```

Docs/Testing.md
```md
# Testing

Deterministic tests (recommended)
- Use ScriptedVoiceIO for Core tests: no microphone or speech permissions needed.
- Use FakeTTS for UI tests to avoid environment-specific voices and locales.

Examples
```swift
// Core: ScriptedVoiceIO
let data = try! JSONSerialization.data(withJSONObject: ["hello","world"])
let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!
let r1 = try await io.listen(timeout: 1.0, inactivity: 0.3, record: false)
XCTAssertEqual(r1.transcript, "hello")

// UI: FakeTTS
final class FakeTTS: TTSConfigurable { /* return fixed voices */ }
let vm = VoicePickerViewModel(tts: FakeTTS(), store: VoiceProfilesStore(filename: "t.json"))
vm.languageFilter = .all
XCTAssertFalse(vm.filteredVoices.isEmpty)
```

CI
- GitHub Actions uses macos-14 and Xcode 16.*.
- Avoid tests that depend on “Alex” or device locale. Prefer FakeTTS and ScriptedVoiceIO for reproducibility.
