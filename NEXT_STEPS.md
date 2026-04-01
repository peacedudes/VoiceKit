# Next Steps for VoiceKit Code Review Fixes

**Status**: Code review implementation in progress. All HIGH and most MEDIUM priority items complete.

---

## What's Been Done

### HIGH Priority (✅ Complete)
- ✅ SFX token syntax migration: `[sfx:name]` → `<sfx:URL>`
- ✅ Updated VoiceQueue parsing for new syntax
- ✅ Updated RealVoiceIO+TTSImpl.swift to parse embedded SFX in speak()
- ✅ Fixed memory leak: removed static `_latestTranscriptStore`, converted to instance variable
- ✅ Improved error diagnostics: VoiceIOError now carries full `Error` instead of String
- ✅ Code organization: extracted listen lifecycle into `RealVoiceIO+ListenLifecycle.swift`
- ✅ Logger consolidation: unified duplicate initialization in RealVoiceIO.swift
- ✅ Documentation: added explanatory comments to all `try?` calls
- ✅ Test optimization: optimized TTS tests for speed/volume/tolerance

### MEDIUM Priority (✅ Complete)
- ✅ **Rate-limit Task.detached in audio callback**: Added ~50ms rate-limiting to prevent task explosion in `installRecognitionTap()` (RealVoiceIO+STT.swift:132-134)

---

## What Remains

### MEDIUM Priority (Optional but valuable)
From `CODE_REVIEW.md`:

**Item**: Extract TTS/STT engine logic into internal coordinator objects
- **Why**: Post-1.0 architectural improvement; separate engine orchestration from VoiceIO wrapper
- **Scope**: This is significant refactoring; likely 3-4 files
- **Risk**: Low (not touching concurrency)
- **Status**: Not yet started

### LOW Priority (Polish/Optional)
From `CODE_REVIEW.md`:

1. **Callback naming consistency**: 
   - Rename `onTTSSpeakingChanged` and `onTTSPulse` to follow pattern (e.g., `onSpeakingStateChanged`, `onSpeakingPulse`)
   - 2-3 files affected
   
2. **Edge case tests**:
   - Very short audio clips (< 100ms)
   - Malformed SFX URLs in tokens
   - Back-to-back listen calls with no reset
   
3. **Documentation**:
   - Update ROADMAP.md reference to new parsing functions (parseTextForSFXWithURLs)
   - Consolidate CI detection documentation (spread across 3 files currently)

---

## Current State

### Build Status
- ✅ Compiles cleanly
- ✅ All 104 tests pass (~16s runtime)
- ✅ SwiftLint: 0 violations, 0 warnings

### Files Modified in This Session
- `Sources/VoiceKit/STT/RealVoiceIO+STT.swift` — Added rate-limiting
- `Sources/VoiceKit/Sequencing/VoiceQueue.swift` — Updated SFX parsing + comments
- `Sources/VoiceKit/TTS/RealVoiceIO+TTSImpl.swift` — Added SFX parsing + comments
- `Sources/VoiceKit/TTS/RealVoiceIO.swift` — Logger consolidation, memory leak fix
- `Sources/VoiceKit/STT/RealVoiceIO+ListenLifecycle.swift` — New file (extracted lifecycle)
- `Sources/VoiceKit/Public/VoiceIOError.swift` — Enhanced error diagnostics
- `Tests/VoiceKitTests/RealVoiceIOTTSTests.swift` — Optimized tests
- `Tests/VoiceKitTests/VoiceQueueTests.swift` — Updated for new syntax
- `Docs/` — Updated guide and programmer reference

### Untracked/New Files (Ready to Add)
- `CODE_REVIEW.md` — Full code review findings (categorized by priority)
- `CODE_REVIEW_FIXES.md` — Detailed implementation notes
- `DOCUMENTATION_AUDIT.md` — Review of docs vs. code
- `SWIFTLINT_FIX.md` — Explanation of file-splitting architecture improvement

---

## For the Next Claude Instance

### Quick Start
1. Review `CODE_REVIEW.md` for context (all findings are documented there)
2. Check `CODE_REVIEW_FIXES.md` for what was implemented and why
3. Look at `SWIFTLINT_FIX.md` if curious about the listen lifecycle extraction

### If Continuing Work
**Recommended next item**: Extract TTS/STT engine logic into coordinator objects
- Not urgent, but architecturally sound post-1.0 improvement
- Low concurrency risk (no actor changes needed)
- Start by reading comments in RealVoiceIO.swift and RealVoiceIO+TTSImpl.swift that describe the engine setup flow

**If you want something quicker**: Polish callback naming (1-2 hours)
- Affects: RealVoiceIO.swift, RealVoiceIO+TTSImpl.swift, tests
- Low risk, high clarity improvement

### Known Constraints
- **Swift 6 concurrency is fragile**: Previous work showed extreme care is needed. The codebase achieved isolation only through careful pattern usage. Avoid touching concurrency primitives unless absolutely certain.
- **No new dependencies**: Explicit approval required.
- **SwiftLint zero violations**: Non-negotiable before any commit.
- **All tests must pass**: Standard gate.

### Key Files to Understand
- `VoiceQueue.swift` — Orchestrates speak/SFX/pause across channels
- `RealVoiceIO.swift` — Main interface; delegates to extension modules
- `RealVoiceIO+STT.swift` — Live speech recognition pipeline
- `RealVoiceIO+TTSImpl.swift` — Text-to-speech synthesis with SFX interleaving
- `STTActivityTracker.swift` — Tracks audio activity (independent actor)

---

## Session Summary

This session completed the code review's HIGH and MEDIUM priority fixes:

| Item | Status | File(s) |
|------|--------|---------|
| SFX syntax migration | ✅ Complete | VoiceQueue, RealVoiceIO+TTSImpl, tests, docs |
| Memory leak fix | ✅ Complete | RealVoiceIO.swift |
| Error diagnostics | ✅ Complete | VoiceIOError.swift |
| File organization | ✅ Complete | New ListenLifecycle extension |
| Code clarity (comments) | ✅ Complete | VoiceQueue, RealVoiceIO+TTSImpl |
| Test performance | ✅ Complete | RealVoiceIOTTSTests |
| Logger consolidation | ✅ Complete | RealVoiceIO.swift |
| **Rate-limit Task.detached** | ✅ Complete | RealVoiceIO+STT.swift |

**Result**: Codebase is cleaner, faster, more maintainable, and ready for v1.0 release.
