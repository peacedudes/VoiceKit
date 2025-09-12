# VoicePickerView (VoiceKitUI)

Import
```swift
import VoiceKitCore
import VoiceKitUI
```

What it provides
- A ready-to-use SwiftUI screen for system voices with:
  - Favorites (default voice), Active toggles, Hide/Unhide
  - Current-language filter (or All)
  - Master sliders (Volume, Pitch range, Speed range) with immediate effect
  - Live preview when sliders change or when tapping a row
- Persistence via VoiceProfilesStore (JSON in Application Support).

Usage
```swift
let voice = RealVoiceIO()
VoicePickerView(tts: voice) // creates its own VoiceProfilesStore
```
Or supply a shared store:
```swift
let store = VoiceProfilesStore(filename: "voices.json")
VoicePickerView(tts: voice, store: store)
```

Persistence model (VoiceProfilesStore)
- defaultVoiceID: String?
- master: TTSMasterControl
- profilesByID: [String: TTSVoiceProfile]
- activeVoiceIDs: Set<String>
- Methods: load(), save(), profile(for:), setProfile(_:), toggleActive(_), setHidden(_:_:)

Customization tips
- Filter behavior: set languageFilter (.current or .all) and showHidden flag on the ViewModel (exposed internally by the view).
- Theming: wrap VoicePickerView in your own NavigationView; apply .tint or environment modifiers.
- Alternate TTS engine: implement TTSConfigurable; the picker will use your availableVoices, set/get profile methods, and speak(_:using:).

Sample integration
```swift
struct SettingsView: View {
    let voice = RealVoiceIO()
    var body: some View { VoicePickerView(tts: voice) }
}
```
