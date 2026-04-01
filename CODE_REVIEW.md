# VoiceKit Code Review & Improvement Plan

**Date**: 2026-03-31  
**Reviewer**: Claude Code  
**Scope**: Complete codebase review (VoiceKit, VoiceKitUI, Tests, Docs)

---

## Executive Summary

VoiceKit is a **well-engineered package** with excellent Swift 6 concurrency practices, comprehensive testing, and thoughtful API design. The codebase is production-ready with strong fundamentals. This review identifies opportunities for polish and identifies some edge cases that warrant attention.

**Overall Grade: A–** (minor improvements needed; no blocking issues)

---

## 1. Architecture & Design

### 1.1 Static Dictionary for Transcript Storage (MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO.swift` (lines 83–87)

**Issue**: 
```swift
private static var _latestTranscriptStore = [ObjectIdentifier: String]()
```

Using a static dictionary keyed by `ObjectIdentifier` creates a **potential memory leak** in long-running apps that create/destroy multiple RealVoiceIO instances. The dictionary entries are never cleaned up.

**Risk**: 
- Memory leaks proportional to instance count
- Pattern violates encapsulation (instance state stored on type)

**Recommendation**:
```swift
// Change to instance variable
private var latestTransript: String = ""

// Remove static entirely; access from instance methods
```

**Impact**: Easy fix; improves safety and maintainability.

---

### 1.2 RealVoiceIO Class Size (MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO*.swift`

**Issue**: Single class with 7 extension files (1500+ lines total):
- `RealVoiceIO.swift` (main)
- `RealVoiceIO+TTSImpl.swift`
- `RealVoiceIO+TTSConformance.swift`
- `RealVoiceIO+Trimming.swift`
- `RealVoiceIO+Boosted.swift`
- `RealVoiceIO+Interruption.swift`
- `RealVoiceIO+STT.swift`
- `RealVoiceIO+Numeric.swift`

Responsible for: TTS, STT, clip playback, session management, permissions, state tracking.

**Problem**: 
- Hard to see the full picture; feels like a "ViewController"
- Difficult for new contributors to understand responsibilities
- Mixing concerns: audio I/O, permissions, configuration, measurements

**Recommendation**: Consider extracting internal components:
```swift
// Internal engine objects
internal class TTSEngine { ... }      // Handle synthesis, utterances
internal class STTEngine { ... }      // Handle recognition, listening
internal class AudioSessionManager { ... }

// RealVoiceIO remains the public facade
@MainActor
public final class RealVoiceIO: VoiceIO {
    private let ttsEngine: TTSEngine
    private let sttEngine: STTEngine
    // ...
}
```

**Timeline**: Post-1.0 refactor (don't block current work)

---

### 1.3 VoiceChooserView Initialization Redundancy (LOW PRIORITY)

**Location**: `Sources/VoiceKitUI/VoiceChooserView.swift` (lines 37–51)

**Issue**: Two initializers with overlapping logic:
```swift
init(tts: TTSConfigurable, store: VoiceProfilesStore) { ... }
init(tts: TTSConfigurable, store: VoiceProfilesStore, onDismiss: @escaping () -> Void) { ... }
```

Second delegates to first, creating maintenance burden.

**Recommendation**: Consolidate to single initializer:
```swift
init(
    tts: TTSConfigurable,
    store: VoiceProfilesStore,
    onDismiss: (() -> Void)? = nil
) { ... }
```

---

## 2. Code Quality

### 2.1 Silent Error Suppression Without Context (MEDIUM PRIORITY)

**Locations**:
- `Sources/VoiceKitUI/Stores/VoiceProfilesStore.swift` (lines 103, 111–112, 131–132)
- `Sources/VoiceKit/STT/RealVoiceIO+STT.swift` (lines 81, 121)
- `Sources/VoiceKit/Sequencing/VoiceQueue.swift` (lines 160, 171, 176)

**Issue**: Pervasive use of `try?` without explanation:
```swift
try? FileManager.default.createDirectory(...)  // Why is this safe to ignore?
try? data.write(to: fileURL, options: [.atomic])  // Silent failure?
try? await channel.io.prepareClip(url: url, gainDB: gain)  // Acceptable?
```

While many are intentional, readers can't tell. Some *should* log; others are pragmatically fine.

**Recommendation**: Add comments explaining intent:
```swift
// Safe to ignore: profiles directory may already exist
try? FileManager.default.createDirectory(...)

// Intentional: SFX preparation failures are non-fatal; audio continues without it
try? await channel.io.prepareClip(url: url, gainDB: gain)
```

---

### 2.2 Logger Initialization Duplication (LOW PRIORITY)

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO.swift` (lines ~140–154)

**Issue**: Logger setup duplicated in both `init()` and `init(config:)`:
```swift
// in init()
if ProcessInfo.processInfo.environment["VOICEKIT_LOG"] == "1" { ... }

// again in init(config:)
if ProcessInfo.processInfo.environment["VOICEKIT_LOG"] == "1" { ... }
```

**Recommendation**: Extract to a private method:
```swift
private func setupLogger() {
    if ProcessInfo.processInfo.environment["VOICEKIT_LOG"] == "1" {
        self.logger = { level, msg in ... }
    }
}

// Call from both inits
```

---

### 2.3 Trimming Timestamp Off-by-One (LOW-MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO+Trimming.swift` (line 144)

**Issue**:
```swift
let ts = Double(inFile.framePosition - Int64(frames)) / sampleRate
```

Frame position is already advanced after reading; subtracting `frames` again may compute timestamps slightly in the past. For very short clips (<100ms), this could cause clipping of the audio start.

**Recommendation**: Add test for very short clips and verify timestamp logic:
```swift
// Test: Record 50ms of audio and trim; ensure no clipping
func testTrimVeryShortAudio() async throws {
    // ...
}
```

---

## 3. Error Handling

### 3.1 VoiceIOError.underlying Loses Context (MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/Public/VoiceIOError.swift` (line ~25)

**Issue**:
```swift
case underlying(String)  // Only carries a message
```

This loses the original error, stack trace, and context information. Hard to debug production issues.

**Recommendation**:
```swift
case underlying(Error)  // Carry the full error

// Usage:
catch {
    throw VoiceIOError.underlying(error)
}
```

**Impact**: Better diagnostics; easier production debugging.

---

### 3.2 Missing Error Context in STT Failures (LOW PRIORITY)

**Location**: `Sources/VoiceKit/STT/RealVoiceIO+STT.swift` (lines 138–142)

**Issue**: Errors from `AVAudioEngine.startAndReturnError()` are logged but not wrapped with useful context (which engine? which device?).

**Recommendation**: Include context in log:
```swift
log(.error, "STT audio engine start failed for \(device.name): \(error)")
```

---

## 4. Testing Gaps

### 4.1 Memory Management: Continuation Cleanup (MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO.swift` (lines ~58–59)

**Issue**: Continuation dictionaries (`speakContinuations`, `measureContinuations`) are cleaned up on success, but no test verifies they don't leak on error paths or rapid repeated calls.

**Missing Test**:
```swift
func testSpeakContinuationsCleanedUpAfterManyRepetitions() async throws {
    let io = RealVoiceIO()
    for _ in 0..<100 {
        await io.speak("test")
    }
    // Verify dict is empty: assert(io.speakContinuations.isEmpty)
}
```

---

### 4.2 Edge Cases: Very Short Audio (LOW PRIORITY)

**Missing Tests**:
- Recording < 50ms
- Single-frame clips
- Corrupted audio files
- Trimming with aggressive pre/post-pads

---

### 4.3 Permission Denied Simulation (LOW PRIORITY)

**Issue**: `ScriptedVoiceIO` doesn't simulate permission-denied state, limiting test coverage.

**Recommendation**: Add permission scenario support:
```swift
// Extend ScriptedVoiceIO to support failure modes
ScriptedVoiceIO(failWith: .permissionDenied)
```

---

## 5. Documentation

### 5.1 Rate Semantics Unclear (LOW PRIORITY)

**Location**: Comments scattered across `RealVoiceIO+TTSImpl.swift`

**Issue**: Difference between `TTSVoiceProfile.rate` (normalized 0.0–1.0) and system `AVSpeechUtteranceMinimumSpeechRate`/`Maximum` is explained but not consolidated.

**Recommendation**: Add to public docstring:
```swift
/// Speak text using an optional voice profile.
/// 
/// Rate mapping:
/// - Profile.rate (0.0-1.0): User's preferred normalized rate
/// - System range: AVSpeechUtterance{Minimum,Maximum}SpeechRate
/// - Conversion: normalized * (sysMax - sysMin) + sysMin
```

---

### 5.2 Trimming Algorithm Not Documented (LOW PRIORITY)

**Issue**: `trimAudioSmart()` implementation is complex but only has line-level comments. High-level logic missing.

**Recommendation**: Add summary comment:
```swift
/// Trim audio to detected speech, using STT timestamps when reliable,
/// falling back to energy-based detection. Apply pre/post-padding
/// to preserve consonants and breathing.
```

---

### 5.3 CI Detection Consolidated (LOW PRIORITY)

**Issue**: Relationship between `IsCI.running`, `VOICEKIT_FORCE_CI`, simulator detection is scattered.

**Recommendation**: Add single doc comment to `IsCI`:
```swift
/// IsCI.running is true when:
/// 1. VOICEKIT_FORCE_CI environment variable is set to "1"
/// 2. Running in GitHub Actions, GitLab CI, or other known CI environments
/// 3. macOS Simulator and processInfo.environment["CI"] is set
```

---

## 6. Performance

### 6.1 Voice List Filtering Not Cached (LOW PRIORITY)

**Location**: `Sources/VoiceKitUI/VoiceChooserViewModel.swift` (lines 75–91)

**Issue**: `filteredVoices` recomputes on every access rather than caching.

**Assessment**: Pragmatic for simplicity; voice lists are typically < 50 entries, so negligible performance impact. Only optimize if profiling shows a problem.

---

### 6.2 System Voice Cache Never Invalidates (LOW PRIORITY)

**Location**: `Sources/VoiceKit/TTS/SystemVoicesCache.swift`

**Issue**: New system voices installed after app launch won't be detected.

**Recommendation**: Document this as intended:
```swift
/// System voice cache is per-app-session. New voices installed
/// after launch won't be available until the app restarts.
```

---

## 7. Concurrency Safety

### 7.1 Task.detached in Audio Callback (MEDIUM PRIORITY)

**Location**: `Sources/VoiceKit/STT/RealVoiceIO+STT.swift` (line 132)

**Issue**:
```swift
Task.detached {
    await activityTracker.observe(db: db, at: now)
}
```

Creates untracked task from realtime audio queue. If many buffers arrive quickly, could create task explosion.

**Recommendation**: Use structured task group with bounds:
```swift
// Use an actor to serialize observations
private let activityActor: ActivityObserver

// In audio callback:
Task.detached { @MainActor [weak self] in
    await self?.activityActor.observe(db: db, at: now)
}

// Or rate-limit observations (e.g., max 10/sec):
private var lastObservationTime: TimeInterval = 0

if now - lastObservationTime > 0.1 {  // 100ms throttle
    Task { await activityTracker.observe(...) }
    lastObservationTime = now
}
```

---

### 7.2 Overall Concurrency Assessment: GOOD

- ✅ Proper use of `@MainActor` isolation
- ✅ Correct `@preconcurrency` imports for AVFoundation
- ✅ Proper `nonisolated` marking for delegate entry points
- ✅ Explicit actor hops with no implicit assumptions

The codebase demonstrates strong Swift 6 safety practices.

---

## 8. API Consistency

### 8.1 Callback Naming Inconsistency (LOW PRIORITY)

**Current naming**:
- `onTranscriptChanged` ✓
- `onListeningChanged` ✓
- `onTTSSpeakingChanged` (mixing protocol prefix)
- `onTTSPulse` (no "Changed")

**Recommendation**: Standardize to one pattern:
```swift
// Option A: consistent "Changed" suffix
onTTSSpeakingChanged, onTTSPulseChanged

// Option B: drop protocol prefix
onSpeakingChanged, onPulseChanged

// Recommend Option B for simplicity:
var onSpeakingChanged: ((Bool) -> Void)?
var onPulseChanged: ((CGFloat) -> Void)?
```

**Note**: Low-priority; maintain backward compatibility if public API.

---

## 9. File Organization

### 9.1 Unclear File Purpose (LOW PRIORITY)

**Location**: `Sources/VoiceKit/Models/VoiceProfilesStore+Seed.swift`

**Issue**: File name doesn't clearly indicate it's actually a bootstrap utility, not a model extension.

**Recommendation**: Rename to `VoiceProfileBootstrap.swift` or move to `Utilities/`.

---

## Priority Recommendations Summary

| Priority | Item | Effort | Benefit |
|----------|------|--------|---------|
| **HIGH** | Move `_latestTranscriptStore` to instance | 15 min | Prevent memory leaks |
| **HIGH** | Change `VoiceIOError.underlying` to carry Error | 30 min | Better diagnostics |
| **HIGH** | Add tests for continuation cleanup | 1 hour | Verify no leaks under load |
| **MEDIUM** | Add comments to all `try?` silencing | 30 min | Clarify intent |
| **MEDIUM** | Consolidate logger initialization | 15 min | DRY principle |
| **MEDIUM** | Rate-limit Task.detached in audio callback | 1 hour | Prevent task explosion |
| **LOW** | Extract TTS/STT engines (post-1.0) | 4–6 hours | Simplify architecture |
| **LOW** | Add trimming edge-case tests | 2 hours | Verify correctness |
| **LOW** | Consolidate CI detection documentation | 15 min | Clarity |
| **LOW** | Standardize callback naming | 1 hour | Consistency |

---

## What's Already Excellent ✅

1. **Swift 6 Safety**: Exemplary use of actor isolation and concurrency patterns
2. **Testing**: 38 test files, excellent use of deterministic doubles (ScriptedVoiceIO)
3. **API Design**: Clean public interfaces that hide complexity well
4. **Error Recovery**: Graceful degradation with CI stubs and fallbacks
5. **Maintenance**: POLISH.md and Concurrency.md show thoughtful stewardship
6. **No External Dependencies**: Keeps the package lean and focused
7. **Comprehensive Documentation**: Public APIs well-documented with examples

---

## Recommended Work Stream

### Phase 1: Safety & Correctness (1–2 weeks)
1. ✅ Move `_latestTranscriptStore` to instance
2. ✅ Change `VoiceIOError.underlying(Error)` 
3. ✅ Add continuation cleanup tests
4. ✅ Add trimming edge-case tests

### Phase 2: Polish (1 week)
1. ✅ Document all `try?` silencing
2. ✅ Consolidate logger setup
3. ✅ Rate-limit audio callback tasks
4. ✅ Standardize callback naming

### Phase 3: Refactoring (Post-1.0)
1. Extract TTS/STT engines
2. Simplify RealVoiceIO

---

## Conclusion

VoiceKit is a **production-ready, professionally-engineered package**. The recommendations above are mostly polish and edge-case handling. The core design is sound, testing is comprehensive, and safety practices are exemplary.

**Estimated effort to address all items**: 10–12 hours  
**Estimated effort for HIGH + MEDIUM items**: 4–5 hours

---

*End of Review*
