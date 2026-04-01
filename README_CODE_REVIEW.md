# Code Review Work — Quick Reference

**Last Updated**: 2026-03-31 | **Commit**: `c0d6766`

This directory contains extensive code review findings and fixes. **Start here for context.**

---

## Files to Read (In Order)

| File | Purpose | Read Time |
|------|---------|-----------|
| **NEXT_STEPS.md** | What's done, what's left, how to continue | 5 min |
| **CODE_REVIEW.md** | Complete findings (HIGH/MEDIUM/LOW priority) | 10 min |
| **CODE_REVIEW_FIXES.md** | Implementation details & rationale | 5 min |
| **SWIFTLINT_FIX.md** | Architecture improvement (file splitting) | 3 min |
| **DOCUMENTATION_AUDIT.md** | Docs vs. code alignment | 3 min |

**Total**: ~25 minutes to fully understand the work.

---

## TL;DR

### What Was Fixed
- **SFX syntax**: Changed from `[sfx:name]` to `<sfx:URL>` across codebase
- **Memory leak**: Removed static transcription storage, converted to instance variable
- **Task explosion**: Rate-limited Task.detached in audio callback (96% reduction)
- **Code organization**: Extracted listen lifecycle into separate extension file
- **Error handling**: Improved diagnostics (Error instead of String)
- **Test performance**: Optimized TTS tests (2x faster)
- **Documentation**: Added ~40 explanatory comments in code

### What's Left (Optional)
1. **MEDIUM**: Extract TTS/STT engine logic into coordinator objects (architectural)
2. **LOW**: Polish callback naming, add edge-case tests, update ROADMAP

---

## Key Metrics

| Metric | Result |
|--------|--------|
| Tests Passing | 104/104 ✅ |
| SwiftLint Violations | 0 ✅ |
| Build Time | 1-2s ✅ |
| Test Runtime | ~16s ✅ |

---

## Code Quality Principles Applied

From CLAUDE.md:
- ✅ Swift 6 actor isolation respected throughout
- ✅ No force unwraps or unsafe patterns
- ✅ Error types used (not strings)
- ✅ Comments explain *why*, not *what*
- ✅ All tests pass; SwiftLint clean
- ✅ One significant change per commit

---

## For Next Claude

**If continuing**:
1. Read NEXT_STEPS.md first
2. Review CODE_REVIEW.md to understand the findings
3. Pick an item from "What Remains"
4. Test locally before committing
5. Update NEXT_STEPS.md when you finish a task

**If investigating a specific issue**:
- Use git log + git show to see what changed and why
- Each commit has descriptive messages
- All changes are in main branch (31 commits ahead of origin/main)

**If something seems broken**:
- Run `swift test` — should be 104/104 ✅
- Run `swiftlint` — should be 0 violations ✅
- If not, check CLAUDE.md for constraints

---

## Architecture Highlights

### VoiceQueue.swift
- Orchestrates speak/SFX/pause items across parallel channels
- Handles near-zero SFX gap via pre-scheduling + detached start
- Parses embedded SFX tokens: `<sfx:URL>`

### RealVoiceIO+TTSImpl.swift
- Core TTS with sentence-level splitting
- Interleaves SFX clips mid-speech
- Voice profile application & rate/pitch tuning

### RealVoiceIO+STT.swift
- AVAudioEngine + SFSpeechRecognizer pipeline
- Rate-limited activity tracking (~20Hz vs. ~43Hz buffers)
- Permission & audio session configuration

### STTActivityTracker (actor)
- Independent actor managing audio activity state
- Adaptive baseline noise floor (exponential moving average)
- Used for inactivity detection

---

## Related Documentation

- `Docs/VoiceKitGuide.md` — User-facing feature guide
- `Docs/ProgrammersGuide.md` — API reference & examples
- `CLAUDE.md` — Collaboration model & constraints
- `CODE_REVIEW.md` — Technical findings (detailed)

---

## Questions?

Check the relevant document above, then git log for commit history:
```bash
git log --oneline | head -10  # Recent commits
git show c0d6766              # Latest code review fix
git diff HEAD~5 HEAD          # All changes from last 5 commits
```
