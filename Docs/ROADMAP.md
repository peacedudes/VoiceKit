# VoiceKit Roadmap (calm, unsurprising)

Goals
- Keep the package small, predictable, and testable.
- Two libraries only: VoiceKit (core) and VoiceKitUI.
- Provide a separate samples repo for demo apps.

Naming
- Library targets stay:
  - VoiceKit (core)
  - VoiceKitUI (UI)
- Public docs should refer to "VoiceKit" (core) and "VoiceKitUI".

Structure (folders by concern)
- VoiceKit (core):
  - Public: VoicePublic.swift, VoiceIOConfig.swift, VoiceIOError.swift, VoiceKitInfo.swift
  - TTS (output): RealVoiceIO.swift and extensions (+TTSImpl, +TTSConformance, +Boosted, +Interruption), SystemVoicesCache.swift, VoiceTempoCalibrator.swift
  - STT (input): SeamsCompat.swift, SeamsLive.swift, PermissionBridge.swift
  - Sequencing: VoiceQueue.swift
  - Utilities: NameMatch.swift, NameResolver.swift, IsCI.swift, VoiceKitTestMode.swift
  - Models/helpers: VoiceProfilesStore+Seed.swift
- VoiceKitUI:
  - Screens: VoiceChooserView.swift
  - ViewModels: VoiceChooserViewModel.swift
  - Stores: VoiceProfilesStore.swift
  - Components: Components/TunerSliderRow.swift, VoiceLanguagePicker.swift, VoiceTuningControls.swift

Status
- Tests: Core and UI tests are wired and green.
- ViewModel: VoiceChooserViewModel added; typealias preserves existing tests.

SFX inlined into spoken text (scope)
- In core, keep a minimal, token-based helper (already present in VoiceQueue.parseTextForSFX).
- Do not auto-parse raw URLs in the core library.
- Rich interpolation (URLs, playlists, named SFX packs) belongs in sample apps.

Samples (separate repo)
- Repo: VoiceKitSamples (to publish later).
- Apps:
  - VoiceKitDemo (SwiftUI): speak, listen, VoiceChooserView.
  - ChorusLab app target (playground UI).
  - Optional: Embedded SFX demo showing parsing/sequencing with real assets.
- These apps depend on the package; no app targets inside the package itself.

Next steps (small, incremental)
1) Reorganize folders (no code changes). Pure git moves to match the structure above.
2) Add VoiceKitSamples repo scaffolding (two SwiftUI apps, minimal content).
3) Document "Embedded SFX patterns" in Docs/ProgrammersGuide.md (point to samples).

Out-of-scope for core (keep it lean)
- Full STT implementation (beyond current CI-friendly shim).
- Background audio session orchestration (belongs in apps).
- URL auto-scraping from text.

Versioning
- Continue tags like v0.1.x.
- Keep "-local" tags for checkpoints.

Workflow note
- Peeks don’t need tee; they should set the clipboard only.
- For builds/tests and other commands, prefer: command | tee >(toClip)
