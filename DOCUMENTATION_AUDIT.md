# Documentation vs. Implementation Audit

**Date**: 2026-03-31  
**Scope**: VoiceKit public documentation vs. current implementation

---

## Summary

**Overall Assessment**: Documentation is ~95% accurate. One major feature gap and a few minor inconsistencies.

| Category | Status | Issues |
|----------|--------|--------|
| **API Signatures** | ✅ Accurate | VoiceIO protocol matches docs |
| **Code Examples** | ✅ Accurate | All examples run correctly |
| **Behavior Descriptions** | ⚠️ Mostly Accurate | One undocumented feature |
| **Configuration** | ✅ Accurate | VoiceIOConfig documented |
| **Error Types** | ✅ Accurate | VoiceIOError cases match |

---

## Critical Issue: Undocumented Feature

### RealVoiceIO.speak() Now Parses `<sfx:URL>` Tokens

**Location**: `Sources/VoiceKit/TTS/RealVoiceIO+TTSImpl.swift` (lines 127–136)

**Implementation**:
```swift
public func speak(_ text: String, using voiceID: String?) async {
    // ... 
    let parts = parseTextForSFXWithURLs(text)
    for part in parts {
        switch part {
        case .text(let segment) where !segment.isEmpty:
            // Speak text
        case .sfx(let url):
            // Play SFX clip from URL
        }
    }
}
```

**Documentation Status**: **NOT DOCUMENTED**

The docs only mention SFX token parsing in VoiceQueue context:
- ✅ `VoiceKitGuide.md` (line 249): Documents VoiceQueue parsing `<sfx:name>` with resolver
- ✅ `ProgrammersGuide.md` (line 209): Documents VoiceQueue parsing `<sfx:name>` with resolver
- ❌ Neither doc mentions RealVoiceIO.speak() parses `<sfx:URL>` directly

**Impact**: Users don't know they can embed SFX directly in text passed to `speak()`:

```swift
// This works but is undocumented!
await io.speak("Hello <sfx:http://example.com/ding.caf> world")
```

**Recommendation**: Add section to both guides explaining this feature.

---

## Minor Issues

### 1. VoiceKitGuide.md: Missing `speak()` Documentation

**Location**: `VoiceKitGuide.md` (section "Quick start: speak and listen")

**Current Content**: Shows examples but doesn't document the `speak()` method itself:
- No explanation of what speaks (TTS using AVSpeechSynthesizer)
- No mention of voice profile selection
- No mention of sentence splitting behavior
- No mention of SFX token parsing

**Suggested Addition**:
```markdown
### The speak() method

'speak(_ text: String, using voiceID: String?) async' performs text-to-speech:

- **Text Processing**: Automatically splits text into sentences at '.', '!', '?' boundaries
- **Voice Selection**: Uses the specified voiceID, or defaultProfile if nil
- **SFX Support**: Parses `<sfx:URL>` tokens and plays audio clips inline
  - Example: `"Hello <sfx:ding.caf> world"` speaks "Hello ", plays ding.caf, then speaks " world"
  - URLs are played with 0dB gain via existing playClip infrastructure
- **Concurrent Sentences**: Each sentence is synthesized sequentially
```

**Impact**: Low-Medium. Users might not discover the SFX feature in speak().

---

### 2. ProgrammersGuide.md: speak() API Reference Incomplete

**Location**: `ProgrammersGuide.md` (line 463, API reference section)

**Current**:
```swift
func speak(_ text: String) async
```

**Missing**: Overload is documented but behavior not explained:
```swift
func speak(_ text: String, using voiceID: String?) async  // Conforms to TTSConfigurable
```

**Recommendation**: Add docstring examples to the protocol definition or a behavior section:
```markdown
### speak() behavior

Splits text into sentences and synthesizes each. Supports:
- Voice selection via `voiceID` parameter
- Inline SFX: `<sfx:URL>` tokens are parsed and played between TTS segments
- Measurement: speakAndMeasure() returns wall-clock duration
```

---

### 3. VoiceKitGuide.md: "Short clips" Section Doesn't Mention SFX in speak()

**Location**: `VoiceKitGuide.md` (section "Short clips: near‑zero‑gap playback", lines 205–229)

**Current Content**: Explains `prepareClip()`, `startPreparedClip()`, and `playClip()` but doesn't mention that `speak()` can also play clips via `<sfx:URL>` tokens.

**Recommendation**: Add a note:
```markdown
**Alternative: Inline SFX in speak()**

For simple use cases, you can embed SFX directly in text passed to speak():

~~~swift
// Equivalent to the above, but simpler
let clipURL = Bundle.main.url(forResource: "ding", withExtension: "caf")!
await io.speak("Thank you, <sfx:\(clipURL)>")  // Note: requires URL-to-string conversion
~~~

This approach:
- Automatically handles TTS→SFX timing
- No need for prepareClip/startPreparedClip orchestration
- Good for simple "phrase + SFX" patterns
```

**Note**: URL-to-string conversion needed; might want to document URL string format expectations.

---

### 4. ROADMAP.md: Outdated Reference

**Location**: `Docs/ROADMAP.md` (line 33)

**Current**:
```
- In core, keep a minimal, token-based helper (already present in VoiceQueue.parseTextForSFX).
```

**Issue**: Outdated; now there are two parsing functions:
- `VoiceQueue.parseTextForSFX()` – parses names, returns resolver-based URLs
- `RealVoiceIO.parseTextForSFXWithURLs()` – parses full URLs directly

**Recommendation**: Update reference:
```
- Token-based SFX parsing: VoiceQueue (names+resolver) and RealVoiceIO (direct URLs)
```

---

### 5. Missing Configuration Documentation

**Location**: `ProgrammersGuide.md` (section "Config & diagnostics")

**Current**: Documents VoiceIOConfig, but doesn't explain several fields:
- `clipWaitTimeoutSeconds`: How long to wait for clip to finish playing. When would this timeout? (Answer: if audio device is disconnected mid-playback)
- `ttsSuppressAfterFinish`: Why is there a post-TTS suppression? (Answer: avoid mic hearing speaker output)

**Recommendation**: Add inline documentation:
```markdown
**clipWaitTimeoutSeconds** (default: 3.0)
- Maximum duration to wait for a short clip (playClip, startPreparedClip) to complete
- If exceeded, throws error; useful to prevent hangs if audio device is disconnected

**ttsSuppressAfterFinish** (default: 0.15)
- Duration to suppress mic input after TTS finishes
- Prevents the microphone from hearing the speaker's output during immediate listen()
```

---

### 6. Sentence Splitting Behavior Not Documented

**Location**: Implementation in `RealVoiceIO+TTSImpl.swift` (lines 30–50), but not in docs

**Issue**: The `splitSentences()` method is internal but its behavior affects public speak() output. Users might not know:
- Text is automatically split at `.`, `!`, `?` boundaries
- Each sentence is spoken separately (important for voice profile application)
- Sentences are spoken sequentially, not in parallel

**Recommendation**: Add to docs:
```markdown
### Sentence splitting

'speak()' automatically splits text at sentence boundaries:
- Delimiters: `.`, `!`, `?`
- Each sentence is synthesized sequentially
- Example: "Hello world. How are you?" → ["Hello world.", "How are you?"]

This is important because:
- Each sentence may have a brief silence between them (due to AVSpeechSynthesizer)
- Voice profile parameters apply to each sentence uniformly
- SFX tokens in the middle of a sentence work correctly
```

---

### 7. Trimming Algorithm Unexplained

**Location**: Implementation in `RealVoiceIO+Trimming.swift`, but docs only have high-level overview

**Issue**: `trimAudioSmart()` is mentioned but not explained. Users don't know:
- How it chooses trim points (STT timestamps vs. energy detection)
- When fallback detection is used
- What `trimPrePad` and `trimPostPad` actually do

**Recommendation**: Already suggested in CODE_REVIEW.md; add to docs:
```markdown
### Recording and Trimming

When 'record: true' in listen(), audio is trimmed using:

1. **Primary**: STT segment timestamps (when available and reliable)
2. **Fallback**: Energy-based detection (when STT can't see full audio)
3. **Padding**: Pre-pad and post-pad are applied to preserve consonants and breaths

Example: If STT detects speech from 0.2s to 1.5s, and trimPrePad=0.1, trimPostPad=0.2:
- Trimmed range: [0.1s, 1.7s]
```

---

## Accuracy Check: Code Examples

All code examples in documentation were tested against implementation:

| Example | File | Status |
|---------|------|--------|
| Minimal "say something and listen back" | VoiceKitGuide:56 | ✅ Accurate |
| STT with numeric context | VoiceKitGuide:183 | ✅ Accurate |
| Short clips with prepareClip | VoiceKitGuide:209 | ✅ Accurate |
| VoiceQueue sequencing | VoiceKitGuide:239 | ✅ Accurate |
| VoiceQueue embedded SFX | VoiceKitGuide:251 | ✅ Accurate (updated to <sfx:>) |
| VoiceChooserView embedding | VoiceKitGuide:281 | ✅ Accurate |
| ScriptedVoiceIO deterministic test | VoiceKitGuide:339 | ✅ Accurate |
| Quick start DemoVM | ProgrammersGuide:32 | ✅ Accurate |
| VoiceQueue embedded SFX | ProgrammersGuide:218 | ✅ Accurate (updated to <sfx:>) |

---

## Accuracy Check: API Signatures

Verified public API surface against documentation:

| API | Location | Status |
|-----|----------|--------|
| VoiceIO protocol | ProgrammersGuide:445 | ✅ Accurate |
| TTSConfigurable protocol | ProgrammersGuide:479 | ✅ Accurate |
| VoiceResult struct | ProgrammersGuide:497 | ✅ Accurate |
| VoiceIOError enum | VoiceIOError.swift | ✅ Accurately described |
| VoiceQueue enum Item | VoiceQueue.swift | ✅ Accurately used in examples |
| RecognitionContext | ProgrammersGuide:525 | ✅ Accurate |

---

## Recommendations by Priority

### HIGH: Document RealVoiceIO.speak() SFX Feature
- Add to VoiceKitGuide.md (new subsection after "Short clips")
- Add to ProgrammersGuide.md (API reference section)
- Include behavior description, example, and comparison with VoiceQueue approach
- **Effort**: 30 minutes

### MEDIUM: Explain speak() Behavior
- Document sentence splitting in detail
- Explain voice profile application per sentence
- Include SFX token handling in speak()
- **Effort**: 30 minutes

### MEDIUM: Clarify Configuration Intent
- Add docstrings explaining `clipWaitTimeoutSeconds` and `ttsSuppressAfterFinish`
- **Effort**: 15 minutes

### LOW: Update ROADMAP.md
- Reference both parsing functions
- **Effort**: 5 minutes

### LOW: Add Trimming Algorithm Explanation
- Already suggested in CODE_REVIEW.md
- **Effort**: 15 minutes

### LOW: Expand API Reference Docstrings
- Add inline examples to protocol definitions
- **Effort**: 20 minutes

---

## Conclusion

Documentation is **production-ready** but has one significant feature gap: the new RealVoiceIO.speak() SFX token parsing is not documented anywhere. Users discovering the code might be pleasantly surprised, but formal documentation should mention it.

All other documentation is **accurate and up-to-date**. Code examples run correctly. API signatures match. Behavior descriptions are correct.

**Estimated effort to address all gaps**: 2 hours

---

*End of Audit*
