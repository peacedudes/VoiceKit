# TODO / Ideas (VoiceKit + tooling)

This is a lightweight scratchpad for future work. Not a contract; just things worth revisiting.

## ChorusLab / VoiceChorus

- Synchronize behavior
  - (Implemented in ChorusLab for 0.1.3: “Synchronize” runs per‑voice calibration in parallel, and Stop cancels the sync task.)
  - After real‑world usage, consider:
    - Tweaking iteration counts / tolerances for faster convergence.
    - Surfacing clearer status when sync is in progress or cancelled.

- Chorus size / performance
  - Decide on a practical limit for ChorusLab UI (e.g. 8–16 voices).
  - If more voices are allowed:
    - Cap how many voices can be calibrating at once.
    - Consider a soft “too many voices to fully sync” timeout with a friendly message.

- UI polish (ChorusLab)
  - Target time controls:
    - Current controls already use monospaced digits and a fixed-width frame; revisit only if layout regresses on smaller devices.
  - Voices list:
    - Ensure labels like “Volume” remain readable (no “V...” truncation) across Dynamic Type sizes.
    - Keep each row single-line; allow slight font shrinking instead of wrapping.
  - Play button:
    - Avoid “Play Ch...” truncation; consider “Play all” or allow slight scaling if needed.
  - Sliders:
    - Global adjustments now use a compact vertical style similar to VoiceChooser tuning sliders; revisit only if discoverability is an issue.
  - Text / keyboard:
    - Make the text box feel good on both macOS and iOS:
      - 3-ish visible lines by default.
      - Good keyboard dismissal (tap outside, toolbar Done, FocusState).

- Fun feature idea: “Round / playable chorus” mode
  - A toggle that turns “Play Chorus” into “Play All”.
  - Tapping an individual voice restarts that voice at the current point, enabling manual staggering (rounds).
  - Consider a simple visual indicator of which voices are currently active.

## General

- Keep `handoff.md` and this file up to date when sessions end abruptly, so the next assistant has context and can pick up threads without guesswork.

- Structural concurrency warnings:
  - Occasionally see: “Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context.”
  - For now, treat as non-blocking unless reproducible crashes/glitches appear.
  - Future investigation:
    - Capture one of these runtime issues in Xcode with full stack trace.
    - Check whether top user frames are inside VoiceKit or Apple frameworks; only act if we’re clearly crossing actors incorrectly.

## Later / post‑0.1.3

- ChorusLab internals
  - Consider removing or reducing the `vk_` proxy properties in `ChorusLabView` by:
    - Moving more logic into a dedicated view model, or
    - Restructuring helpers so they can work directly with `@State` without proxy names.
  - Only attempt this when there is time to re-run all tests and do focused manual QA; current code is correct but a bit awkward.

- Docs / Unicode
  - If future tooling makes it trivial, optionally normalize “smart” punctuation in markdown docs to plain ASCII (quotes, dashes, ellipses).
  - This is purely cosmetic; do not risk breaking diffs or tooling for it.
