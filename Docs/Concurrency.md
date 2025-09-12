# Concurrency and Thread Safety (Swift 6)

Design
- Public API is @MainActor (VoiceIO protocol, RealVoiceIO, ScriptedVoiceIO).
- UI callbacks (onTranscriptChanged, onLevelChanged, etc.) are invoked on the main actor.

Permission callbacks (TCC)
- Apple’s TCC APIs may deliver on background queues. Passing @MainActor closures causes libdispatch assertions.
- Solution: PermissionBridge (nonisolated) wraps:
  - iOS 17+: AVAudioApplication.requestRecordPermission(completionHandler:)
  - macOS: AVCaptureDevice.requestAccess(for: .audio, completionHandler:)
  - Speech: SFSpeechRecognizer.requestAuthorization(_:)
- We await withCheckedContinuation and resume; execution returns to @MainActor after suspension safely.

Audio engine tap
- Core Audio calls back on a real-time thread.
- We avoid capturing @MainActor self; we compute meter levels and post to main via a tiny @unchecked Sendable LevelSink wrapper.

AVSpeechSynthesizer delegate
- We avoid sending AVSpeechUtterance across actors by:
  - Computing ObjectIdentifier(utterance) and copying Strings inside the delegate.
  - Hopping to @MainActor with those Sendable values.

Notifications (iOS)
- Interruption/route-change notifications are observed on the main queue to avoid queue assertions in handlers.

Do / Don’t
- Do call VoiceIO methods from @MainActor contexts (SwiftUI actions, @MainActor ViewModels).
- Don’t mutate UI/SwiftData from background contexts around VoiceIO callbacks.
- Don’t pass @MainActor closures into TCC/AVFoundation callbacks; use nonisolated bridges instead.
