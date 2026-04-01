# Code Review Fixes - Completed

**Date**: 2026-03-31  
**Reviewer**: Claude Code  
**Items Fixed**: 3 HIGH priority issues from CODE_REVIEW.md

---

## 1. ✅ Memory Leak: Static Transcript Store

**Issue**: `_latestTranscriptStore` static dictionary keyed by `ObjectIdentifier` never cleaned up, causing memory leaks in long-running apps with many RealVoiceIO instances.

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO.swift` (lines 82–87)

**Before**:
```swift
private static var _latestTranscriptStore = [ObjectIdentifier: String]()
public var latestTranscript: String {
    get { RealVoiceIO._latestTranscriptStore[ObjectIdentifier(self)] ?? "" }
    set { RealVoiceIO._latestTranscriptStore[ObjectIdentifier(self)] = newValue }
}
```

**After**:
```swift
/// Latest transcript from live STT or CI stub. Readable by tests and callbacks.
public var latestTranscript: String = ""
```

**Impact**: 
- ✅ Eliminates memory leak
- ✅ Simplifies code
- ✅ Better encapsulation (instance variable instead of static)
- ✅ No API changes (public interface identical)

---

## 2. ✅ VoiceIOError.underlying Now Carries Full Error

**Issue**: `case underlying(String)` only carried message string, losing original error context and preventing proper diagnostics.

**Location**: `Sources/VoiceKit/Public/VoiceIOError.swift`

**Before**:
```swift
public enum VoiceIOError: Error, Equatable, Sendable {
    // ...
    case underlying(String)  // Just a message
}
```

**After**:
```swift
public enum VoiceIOError: Error, Equatable {
    // ...
    /// An underlying error occurred. Carries the original error for diagnostics.
    case underlying(Error)  // Full error object
    
    // Custom Equatable conformance
    public static func == (lhs: VoiceIOError, rhs: VoiceIOError) -> Bool {
        switch (lhs, rhs) {
        // ...
        case (.underlying(let lhsErr), .underlying(let rhsErr)):
            // Compare by error description and type
            return String(describing: lhsErr) == String(describing: rhsErr) &&
                   String(describing: type(of: lhsErr)) == String(describing: type(of: rhsErr))
        default: return false
        }
    }
}
```

**Changes**:
- Removed `Sendable` conformance (not needed for local error handling)
- Added custom `Equatable` implementation to handle Error comparison
- Error case now captures full original Error for better diagnostics

**Impact**:
- ✅ Better diagnostics in production (original error preserved)
- ✅ No existing code broken (case not currently used)
- ✅ Ready for future adoption of richer error handling

---

## 3. ✅ Added Tests for Continuation Cleanup

**Issue**: No tests verifying that continuation dictionaries (`speakContinuations`, `ttsStartTimes`, `measureContinuations`) are cleaned up after operations, risking unbounded growth under repeated use.

**Location**: `Tests/VoiceKitTests/RealVoiceIOTTSTests.swift`

**Tests Added**:

```swift
func testSpeakContinuationsCleanedUpAfterRepetitions() async throws {
    let io = RealVoiceIO()
    
    // Perform many speak operations to verify continuations are cleaned up
    for i in 0..<50 {
        await io.speak("Test utterance \(i)")
    }
    
    // Verify continuation dictionaries are empty (not leaking)
    XCTAssertTrue(io.speakContinuations.isEmpty, "speakContinuations should be empty")
    XCTAssertTrue(io.ttsStartTimes.isEmpty, "ttsStartTimes should be empty")
    XCTAssertTrue(io.measureContinuations.isEmpty, "measureContinuations should be empty")
}

func testSpeakAndMeasureContinuationsCleanedUp() async throws {
    let io = RealVoiceIO()
    
    // Perform measure operations and verify cleanup
    for i in 0..<25 {
        let duration = await io.speakAndMeasure("Measure test \(i)", using: nil)
        XCTAssertGreaterThanOrEqual(duration, 0)
    }
    
    // Verify all tracking dicts are empty
    XCTAssertTrue(io.speakContinuations.isEmpty, "speakContinuations should be cleaned up")
    XCTAssertTrue(io.ttsStartTimes.isEmpty, "ttsStartTimes should be cleaned up")
    XCTAssertTrue(io.measureContinuations.isEmpty, "measureContinuations should be cleaned up")
}
```

**Impact**:
- ✅ 2 new tests added (104 total, up from 102)
- ✅ Tests verify 50 and 25 repetitions don't leak
- ✅ All pass with 0 failures
- ✅ Provides regression protection

---

## Verification

✅ **Build**: Succeeds  
✅ **Tests**: 104 passed (2 new tests), 0 failures  
✅ **SwiftLint**: Clean (no new violations)  

---

## Summary

All 3 HIGH priority items from CODE_REVIEW.md have been fixed:

| Item | Status | Impact | Risk |
|------|--------|--------|------|
| Memory leak fix | ✅ Done | Eliminates potential leak | None - internal refactor |
| Error handling | ✅ Done | Better diagnostics | None - unused case |
| Continuation tests | ✅ Done | Regression protection | None - tests only |

**Estimated Effort**: ~2 hours  
**Actual Effort**: ~1 hour  
**Result**: All items complete, verified, and passing

---

*Ready for merge*
