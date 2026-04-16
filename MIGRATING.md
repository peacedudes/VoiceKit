# Migrating to VoiceKit v0.2

## Overview

v0.2 is a **breaking change** release. The callback-based `onXxx` closure properties have been removed from `VoiceIO` in favor of `@Observable` stored properties. This aligns with the Swift Observation framework (iOS 17+/macOS 14+) and eliminates the awkward setup/teardown dance required by closures.

---

## What changed

### `VoiceIO` protocol — removed properties

These six `onXxx` callback vars no longer exist:

```swift
// REMOVED — compile errors if you use these
var onSpeakingChanged: ((Bool) -> Void)?
var onListeningChanged: ((Bool) -> Void)?
var onTranscriptChanged: ((String) -> Void)?
var onAudioLevelChanged: ((CGFloat) -> Void)?
var onPulseChanged: ((CGFloat) -> Void)?
var onStatusMessageChanged: ((String?) -> Void)?
```

### `VoiceIO` protocol — new observable properties

The same six values are now observable stored properties:

```swift
var isSpeaking: Bool { get }
var isListening: Bool { get }
var transcript: String { get }
var audioLevel: CGFloat { get }
var pulse: CGFloat { get }
var statusMessage: String? { get }
```

Because `RealVoiceIO` and `ScriptedVoiceIO` are `@Observable`, SwiftUI views track these automatically — no binding or callback wiring required.

---

## Migration guide

### Reading state in a SwiftUI view

**Before:**
```swift
@StateObject private var io = RealVoiceIO()

.onAppear {
    io.onTranscriptChanged = { self.transcript = $0 }
    io.onSpeakingChanged   = { self.isSpeaking = $0 }
}
```

**After:**
```swift
@State private var io = RealVoiceIO()

// Read io.transcript and io.isSpeaking directly in body —
// SwiftUI tracks them automatically via @Observable.
```

### Reacting to state changes

**Before:**
```swift
io.onSpeakingChanged = { isSpeaking in
    if !isSpeaking { handleDone() }
}
```

**After — in a SwiftUI view:**
```swift
.onChange(of: io.isSpeaking) { _, isSpeaking in
    if !isSpeaking { handleDone() }
}
```

**After — in a view model or task:**
```swift
// Poll after an await, or use withObservationTracking for reactive patterns.
await io.speak("Hello.")
handleDone()   // speak() returns when speech is complete
```

### Displaying the live transcript

**Before:**
```swift
@State private var transcript = ""
.onAppear { io.onTranscriptChanged = { self.transcript = $0 } }
Text(transcript)
```

**After:**
```swift
Text(io.transcript)   // live — no intermediate state needed
```

### Observing audio level / pulse for animations

**Before:**
```swift
@State private var level: CGFloat = 0
io.onAudioLevelChanged = { self.level = $0 }
io.onPulseChanged      = { self.pulse = $0 }
```

**After:**
```swift
// Read io.audioLevel and io.pulse directly in your view body.
Circle().scaleEffect(io.pulse)
```

### `latestTranscript` renamed to `transcript`

If you used `latestTranscript` (an earlier name for the transcript property), rename it to `transcript`.

---

## VoiceKitUI migration

### `VoiceChooserView` / `VoiceChooserViewModel`

`VoiceChooserViewModel` is now `@Observable`. In any view that holds a `VoiceChooserViewModel` directly, switch from `@StateObject` / `@ObservedObject` to `@State` / plain stored property.

**Before:**
```swift
@StateObject private var viewModel: VoiceChooserViewModel

init(...) {
    _viewModel = StateObject(wrappedValue: VoiceChooserViewModel(...))
}
```

**After:**
```swift
@State private var viewModel: VoiceChooserViewModel

init(...) {
    _viewModel = State(initialValue: VoiceChooserViewModel(...))
}
```

`VoiceProfilesStore` is also `@Observable`; the same `@StateObject` → `@State` rename applies wherever you hold one.

---

## Required import

If you reference `@Observable` types in non-SwiftUI files, add:

```swift
import Observation
```

SwiftUI files already have this transitively.

---

## Summary of rename changes

| Old | New |
|-----|-----|
| `onSpeakingChanged: ((Bool) -> Void)?` | `isSpeaking: Bool` |
| `onListeningChanged: ((Bool) -> Void)?` | `isListening: Bool` |
| `onTranscriptChanged: ((String) -> Void)?` | `transcript: String` |
| `onAudioLevelChanged: ((CGFloat) -> Void)?` | `audioLevel: CGFloat` |
| `onPulseChanged: ((CGFloat) -> Void)?` | `pulse: CGFloat` |
| `onStatusMessageChanged: ((String?) -> Void)?` | `statusMessage: String?` |
| `latestTranscript` | `transcript` |
| `@StateObject var store: VoiceProfilesStore` | `@State var store: VoiceProfilesStore` |
| `@StateObject var viewModel: VoiceChooserViewModel` | `@State var viewModel: VoiceChooserViewModel` |
