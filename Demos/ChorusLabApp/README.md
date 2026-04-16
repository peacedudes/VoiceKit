# Chorus Lab Demo

A real-time multi-voice synthesis demo showcasing VoiceKit's rate calibration, global tuning, and voice composition capabilities.

## Overview

**Chorus Lab** lets users:

- **Select multiple voices** from the system (Alex, Victoria, Sam, etc.)
- **Tune each voice** individually (rate, pitch, volume) using an interactive voice editor
- **Calibrate rates** to match a target duration for the entire chorus using VoiceTempoCalibrator
- **Apply global adjustments** (speed multiplier, pitch offset) to all voices at once
- **Playback and measure** actual synthesis duration in real-time
- **Export configurations** as Swift code snippets for reuse in other apps

## Architecture

### Core Components

#### `ChorusLabView.swift`
Main UI orchestrator. Manages:
- Voice selection (selectedProfiles) and baseline profiles (baseProfiles)
- Global adjustments (rateScale, pitchOffset)
- Calibration state and playback timing
- Integration with VoiceChooserView for voice tuning
- Integration with VoiceChorus for multi-voice playback

Key data flow:
```
baseProfiles + rateScale/pitchOffset
    ↓
  ChorusMath.applyAdjustments()
    ↓
selectedProfiles (effective profiles sent to VoiceChorus)
```

#### `ChorusLabView+Logic.swift`
Extension extracting non-visual helpers to reduce file size:
- `copyChorusSetup()`: Export current chorus as Swift code
- `resolvedName()`: Map voice ID to display name
- `applyGlobalAdjustments()`: Re-derive selectedProfiles when sliders change
- `startChorus()` / `stopAll()`: Playback control and timing measurement

#### Component Views

- **`ChorusLabActionRowView`**: Play/Stop button + Synchronize button + calibration progress
- **`ChorusLabGlobalAdjustmentsView`**: Rate scale and pitch offset sliders
- **`ChorusLabTargetTimeRow`**: Target duration stepper + measured actual duration display
- **`ChorusLabSelectedVoicesSection`**: List of voices with tap/swipe actions (edit, sync, delete)
- **`ChorusLabSelectedVoiceRow`**: Individual voice row showing name, compact settings, measured duration

### Key Concepts

#### Baseline vs. Effective Profiles

- **Baseline**: The user's chosen rate/pitch/volume for each voice (immutable during slider movement)
- **Effective**: The computed result of applying global adjustments (rateScale, pitchOffset) to baselines
  - When user moves a slider, `ChorusMath.applyAdjustments()` recomputes effective profiles
  - Baseline is preserved for undo-like behavior (restore baseline state after calibration)

#### Rate Calibration

Uses `VoiceTempoCalibrator` to iteratively adjust each voice's rate to match a target duration:
1. User sets target (e.g., 5 seconds)
2. Taps "Sync" to calibrate one or all voices
3. Calibrator measures duration, adjusts rate proportionally
4. Repeats up to 3 times (configurable) until within ±5% tolerance
5. Updates selectedProfiles with new rates; displays measured duration

#### Global Adjustments

`ChorusMath.adjustedRate()` implements asymmetric scaling:
- **Speed up** (rateScale > 1.0): Move baseline toward 1.0 (fastest) by fraction of headroom
- **Slow down** (rateScale < 1.0): Move baseline toward 0.0 (slowest) by fraction of base, dampened by slowRange

This prevents unintuitive behavior where the same multiplier produces different perceptual shifts.

#### Copy-to-Clipboard Export

`makeChorusSnippet()` generates Swift code like:

```swift
// VoiceKit chorus setup example
import VoiceKit

let chorusProfiles = [
    TTSVoiceProfile(id: "...", rate: 0.55, pitch: 1.0, volume: 0.9),
    TTSVoiceProfile(id: "...", rate: 0.61, pitch: 1.1, volume: 0.85),
]
// Use with VoiceChorus:
await VoiceChorus().speak("Your phrase", withVoiceProfiles: chorusProfiles)
```

Users can copy and paste this into their own apps.

### Dependencies

#### Injected (Testable)
- `voicesProvider`: Source of system voices (defaults to SystemVoicesCache)
- `engineFactory`: Factory for RealVoiceIO instances

#### Internal
- `chorus`: VoiceChorus for multi-voice playback
- `tunerEngine`: RealVoiceIO for voice tuning preview

### Design System (Metrics Enum)

All hardcoded values are grouped in a `Metrics` enum for easy modification:

- **Padding**: iOS vs. macOS safe areas
- **Layout**: Spacing, cell widths
- **Controls**: Slider step granularity
- **Defaults**: New voice fallback values (0.55 rate, 1.0 pitch, 1.0 volume)
- **Buttons**: Sizes, styling
- **Calibration**: Tolerance (5%), max iterations (3)
- **Timing**: Target range (1–20s), step (0.25s)
- **Adjustments**: Speed range (0.05×–2.0×), pitch offset range (±0.9), slow-down dampening
- **Pitch**: Clamp bounds (0.5–2.0)

## Usage

### Running the App

1. Open `ChorusLabApp.xcodeproj`
2. Select the ChorusLabApp scheme
3. Build and run on iOS or macOS

### Using the Interface

1. **Tap "+** to add a voice
   - VoiceChooserView opens
   - Select a voice and adjust pitch/volume
   - Tap Save (or unnamed "done" button) to add to chorus

2. **Adjust global sliders**
   - Speed (0.05×–2.0×): Scales all voice rates
   - Pitch Offset (±0.9): Shifts all voice pitches

3. **Tap "Play all"** to hear the chorus
   - Measured duration appears on the right

4. **Swipe a voice row right**
   - **Sync**: Calibrate that voice to target duration
   - **Delete**: Remove from chorus

5. **Tap "Synchronize"** to calibrate all voices at once
   - Progress spinner shows during calibration
   - Measured durations update in real-time

6. **Tap "Copy Setup"** to copy Swift code
   - Code appears in console and clipboard
   - Paste into your own app to recreate the chorus

## Architecture Patterns

### State Management
- `@State` for all voice/playback/calibration state
- Explicit proxies (`vk_*`) for extension access
- No external `@ObservedObject` or `@EnvironmentObject`

### Task Cancellation
- Single `calibrationTask` handle allows stopping calibration mid-flight
- `Task.isCancelled` checks prevent race conditions

### Concurrency
- All methods are `@MainActor`
- Calibration tasks use `async/await` and structured concurrency
- Parallel rate calibration via `withTaskGroup` for all voices

### Testability
- Dependency injection: voicesProvider, engineFactory
- Pure math functions: `ChorusMath.adjustedRate()`, `applyAdjustments()`
- Fake implementations can inject test voices and mock TTS

### Accessibility
- VoiceOver labels and hints on all controls
- Voice row marked as button for interaction feedback
- Live region (polite) for status messages

## Files

```
Demos/ChorusLabApp/
├── ChorusLabApp/
│   ├── ChorusLabAppApp.swift          # App entry point
│   ├── ContentView.swift               # Root view (wraps ChorusLabView in NavigationStack)
│   ├── ChorusLabView.swift             # Main UI + state (842 lines)
│   ├── ChorusLabView+Logic.swift       # Non-visual helpers
│   ├── Clipboard.swift                 # Cross-platform clipboard wrapper
│   ├── Components/
│   │   ├── ChorusLabActionRowView.swift
│   │   ├── ChorusLabGlobalAdjustmentsView.swift
│   │   ├── ChorusLabTargetTimeRow.swift
│   │   ├── ChorusLabTargetTimeRow+Init.swift
│   │   ├── ChorusLabSelectedVoicesSection.swift
│   │   └── ChorusLabSelectedVoiceRow.swift
│   └── Assets/
└── ChorusLabApp.xcodeproj
```

## Future Improvements

- **Persistent state**: Save and load chorus configurations
- **Undo/redo**: Restore previous profile states
- **More calibration algorithms**: Different rate fitting strategies
- **Audio recording**: Export the mixed chorus as an audio file
- **Presets**: Built-in chorus configurations
- **Harmony assistant**: Auto-generate complementary pitch offsets

## Testing

Chorus Lab is designed for manual testing in the simulator or on device. Core math (`ChorusMath`) is tested via unit tests in VoiceKitTests.

To verify builds without errors or SwiftLint warnings:

```bash
swiftlint --strict
swift test
```

## License

Part of the VoiceKit framework. See parent LICENSE file.
