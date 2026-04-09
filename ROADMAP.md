# Roadmap

## Package scope (permanent constraints)
- Two libraries only: `VoiceKit` (core) and `VoiceKitUI`. No additions without explicit decision.
- No new dependencies.
- Version series: v0.1.x continuing until a breaking API change warrants v0.2.

## What's shipped (v0.1.3)
- **Core**: `RealVoiceIO` (TTS, live STT, recording+trimming, clip path), `ScriptedVoiceIO` (CI stub), `VoiceQueue`, `VoiceChorus`
- **UI**: `VoiceChooserView`, `VoiceChooserViewModel`, `VoiceProfilesStore`, `ChorusLabView` (in demo)
- **Tests**: 109 passing, deterministic, no hardware dependency in package tests
- **Docs**: ProgrammersGuide.md, VoiceKitGuide.md, Concurrency.md

## Near-term
1. **VoiceKitSamples repo**: Extract `Demos/ChorusLabApp` from this repo; add a minimal `VoiceKitDemo` SwiftUI app. These apps should depend on the package, not live inside it.
2. **Docs fix**: Update `Docs/Concurrency.md` with current callback names.
3. **VoiceOpGate**: Replace spin-poll with proper async suspension (low priority — not causing problems today).

## Future ideas (no commitment)
- ChorusLab UI polish: target time controls, label truncation, keyboard handling (details in `notes/todo.md`)
- Wider ChorusLab voice count with calibration cap
- "Round" / staggered chorus mode (manual per-voice re-trigger)
- Structural concurrency warning investigation (`nonisolated` tap → actor hop pattern)

## Out of scope (core stays lean)
- Full production STT (beyond current live pipeline + CI stub)
- Background audio session orchestration (belongs in apps)
- URL auto-scraping from text
- Rich SFX packs / named playlists (belong in sample apps)
