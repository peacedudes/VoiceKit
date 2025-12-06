# TODO / Ideas (VoiceKit + tooling)

This is a lightweight scratchpad for future work. Not a contract; just things worth revisiting.

## ChorusLab / VoiceChorus

- Synchronize behavior
  - Implemented in ChorusLab for 0.1.x:
    - “Synchronize” runs per-voice calibration in parallel.
    - Stop cancels the sync task and stops playback.
  - Later tuning:
    - Tweak iteration counts / tolerances for faster convergence.
    - Consider clearer in-UI status when sync is in progress or cancelled.

- Chorus size / performance
  - Decide on a practical limit for ChorusLab UI (e.g. 8–16 voices).
  - If more voices are allowed:
    - Cap how many voices can be calibrating at once.
    - Consider a soft “too many voices to fully sync” timeout with a friendly message.

- UI polish (ChorusLab)
  - Target time controls:
    - Keep using monospaced digits and a fixed-width frame; revisit only if layout regresses on small devices.
  - Voices list:
    - Ensure labels like “Volume” remain readable (no “V...” truncation) across Dynamic Type sizes.
    - Keep each row single-line; allow slight font shrinking instead of wrapping.
  - Play button:
    - Avoid “Play Ch...” truncation; prefer a short label (“Play all”) over wrapping.
  - Sliders:
    - Global adjustments use a compact vertical style similar to VoiceChooser tuning sliders.
    - Revisit only if discoverability is an issue.
  - Text / keyboard:
    - Make the text box feel good on both macOS and iOS:
      - ~3 visible lines by default.
      - Good keyboard dismissal (tap outside, toolbar Done, FocusState).

- Fun feature idea: “Round / playable chorus” mode
  - A toggle that turns “Play Chorus” into “Play All”.
  - Tapping an individual voice restarts that voice at the current point, enabling manual staggering (rounds).
  - Consider a simple visual indicator of which voices are currently active.

- Pitch / chords behavior
  - Current state (late 0.1.x):
    - Per-voice pitch is correctly stored in TTSVoiceProfile and survives sync.
    - Chorus profiles printed to the console show distinct pitch values.
    - UI now surfaces per-row Speed/Pitch/Vol using formatted() helpers.
  - Later:
    - If chords feel “too similar” on some OS/device combos, consider slightly widening the default pitch offsets used when seeding multiple voices.

## General

- Keep `todo.md` (and `handoff.md` if used locally) up to date when sessions end, so the next assistant has context and can pick up threads without guesswork.

- Structural concurrency warnings:
  - Occasionally see: “Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context.”
  - For now, treat as non-blocking unless reproducible crashes/glitches appear.
  - Future investigation:
    - Capture one of these runtime issues in Xcode with full stack trace.
    - Check whether top user frames are inside VoiceKit or Apple frameworks; only act if we’re clearly crossing actors incorrectly.

## Later / post-0.1.x

- ChorusLab internals
  - The current `vk_` proxy split is a working but slightly awkward compromise:
    - Main view uses @State and non-mutating helpers.
    - Some logic lives in ChorusLabView+Logic, but tuner helpers now live back in the main view.
  - Later refactor ideas:
    - Introduce a small @MainActor view model for ChorusLab and move more logic there.
    - Collapse or rename the `vk_` proxies once SwiftUI / Swift 6 constraints are clearer.
  - Only attempt this with time for:
    - Full test runs (including ChorusLabApp).
    - Manual sanity checks for sync, pitch, and “chords” behavior.

- Docs / Unicode / formatting
  - Current state:
    - README and Docs prose normalized to ASCII punctuation (quotes, dashes, ellipses).
    - Most Swift headers/comments also use plain ASCII now.
  - Later:
    - If tooling and workflow remain stable, continue keeping docs and headers ASCII to simplify search and diffs.
    - Avoid reintroducing “smart” punctuation unless there’s a strong reason.