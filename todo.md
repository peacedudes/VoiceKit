# TODO / Ideas (VoiceKit + tooling)

This is a lightweight scratchpad for future work. Not a contract; just things worth revisiting.

## ChorusLab / VoiceChorus

- Synchronize behavior
  - Make “Synchronize” tune all voices concurrently (like an orchestra warming up), instead of voice-by-voice.
  - Run each voice’s 3-attempt calibration loop in parallel tasks.
  - Wire the existing Stop button to cancel the sync Task and call stopAll() on the engines.
  - Add guardrails for very large chorus sizes (e.g. throttle concurrent tuning, or warn above N voices).

- Chorus size / performance
  - Decide on a practical limit for ChorusLab UI (e.g. 8–16 voices).
  - If more voices are allowed:
    - Cap how many voices can be calibrating at once.
    - Consider a soft “too many voices to fully sync” timeout with a friendly message.

- UI polish (ChorusLab)
  - Target time controls:
    - Prevent +/- buttons from shifting as the formatted time text changes width.
    - Use monospaced digits and/or a fixed-width frame for the numeric display.
  - Voices list:
    - Ensure labels like “Volume” are readable (no “V…” truncation).
    - Keep each row single-line; allow slight font shrinking instead of wrapping.
  - Play button:
    - Avoid “Play Ch…” truncation; consider “Play all” or allow slight scaling.
  - Sliders:
    - Use a more compact vertical style (similar to VoiceChooser tuning sliders).
  - Text / keyboard:
    - Make the text box multi-line (e.g. 3 lines) or grow slightly when focused.
    - Improve keyboard dismissal (tap outside, toolbar Done, FocusState).

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
