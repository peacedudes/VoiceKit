# Handoff — VoiceKit: ChorusLabView polish, a11y, tests

Status (2025-09-17)
- Build: green
- Target of interest: Sources/VoiceKitUI/VoiceChorusPlayground.swift (type renamed to ChorusLabView)
- Key improvements landed:
  - Rename: VoiceChorusPlayground -> ChorusLabView (title shows “Chorus Lab”)
  - Dependency Injection (DI): voicesProvider and engineFactory injected; VoiceChorus uses engineFactory
  - Calibration/tuner now construct RealVoiceIO via engineFactory()
  - availableVoices() pulls from voicesProvider (MainActor)
  - Accessibility: clearer labels/hints, identifiers for tests, decorative chevron hidden
  - Subtle animations: list animates on row count changes
  - Doc polish for key funcs

Why this handoff
- To let a fresh assistant (or human) get up to speed quickly, continue polishing a11y and add meaningful tests that double as example usage docs.

Glossary
- DI = Dependency Injection: pass dependencies into a type (e.g., voicesProvider, engineFactory) instead of creating them inline. Improves testability and clarity.

Repo workflow (clipboard-first)
- Use the docs in this repo:
  - 00-overview.md (why this works, cadence)
  - 01-quick-start.md (Peek → Patch → Apply loop)
  - 02-troubleshooting.md (common issues)
  - 03-scripts.md (helper scripts reference)
- Always request peeks before preparing diffs. Keep patches strictly descending by line number. Single action per step.

Where to look (current bytes)
- Type: struct ChorusLabView: View
- File: Sources/VoiceKitUI/VoiceChorusPlayground.swift (name can be changed later)
- A11y identifiers used by planned tests:
  - vk.add (Add voice button)
  - vk.playStop (Play/Stop)
  - vk.syncAll (Synchronize all)
  - vk.voicesList (List of selected voices)
  - vk.targetStepper (Target time stepper)
  - vk.row.<id> (each selected voice row)

Open items (shortlist)
1) Tests (preferred next)
   - Add ViewInspector as a test-only dependency in Package.swift.
   - Ensure Package.swift declares a VoiceKitUITests test target (currently missing; folder exists).
   - Add Tests/VoiceKitUITests/AccessibilitySmokeTests.swift:
     - Instantiate ChorusLabView with fake voicesProvider (return []) and trivial engineFactory.
     - Assert presence of identifiers: vk.add, vk.playStop, vk.syncAll, vk.voicesList, vk.targetStepper.
     - These tests act as usage docs and lock in the a11y contract.

2) A11y micro-upgrade (optional but recommended)
   - Make the “Actual time” readout politely announce updates during playback/calibration:
     - Add .accessibilityLiveRegion(.polite) to the HStack that shows lastChorusSeconds in targetTimeRow().

3) Subtle animations (optional)
   - Consider .transition(.opacity.combined(with: .scale(scale: 0.98))) on SelectedVoiceRow with the existing list animation to give a tasteful appear/disappear effect. Keep it subtle; avoid distracting motion.

4) Naming (future)
   - If we choose to rename the type to ChorusView later, do a direct rename (no legacy shims needed; no external consumers yet). Consider renaming the file to match the type for discoverability.

5) Docs philosophy (tests as usage docs)
   - Unit tests should demonstrate expected use patterns (DI seams, seeding, calibration flow when feasible).
   - Names must be meaningful; tests should be readable and educational.
   - Add a note in README/overview once tests land to state that tests are canonical usage examples.

Details and guidance
- DI seams already present:
  - voicesProvider: SystemVoicesProvider (MainActor)
  - engineFactory: () -> RealVoiceIO
  - VoiceChorus(makeEngine:) uses engineFactory to create engines
- availableVoices() must remain @MainActor; SystemVoicesCache is MainActor-isolated.
- Tuner presentation:
  - presentAddVoice(): sets tunerEngine = engineFactory()
  - presentEditVoice(index:): sets tunerEngine = engineFactory()
- Calibration: both bulk and per-voice paths now use engineFactory() to construct the temporary IO.
- Accessibility:
  - Add button remains icon-only visually, but has an accessibilityLabel “Add voice” and identifier “vk.add”.
  - Play/Stop button’s label toggles (“Play Chorus” vs “Stop”) and has identifier “vk.playStop”.
  - Synchronize all has label/hint and identifier “vk.syncAll”.
  - Each SelectedVoiceRow gets “vk.row.<id>”.
  - Decorative chevron is .accessibilityHidden(true).
  - Stepper labeled “Target time” with identifier “vk.targetStepper”.
  - TextEditor labeled “Chorus text” with a clarifying hint.
  - List has identifier “vk.voicesList”.

Testing plan (step-by-step)
1) Peek Package.swift and confirm test target/config:
   - Expect VoiceKitCoreTests present; VoiceKitUITests directory exists but not declared.
   - Add ViewInspector dependency in dependencies (test-only usage via test target product).
   - Add a testTarget VoiceKitUITests depending on VoiceKitUI, TestSupport, and ViewInspector product.
2) Add Tests/VoiceKitUITests/AccessibilitySmokeTests.swift with ViewInspector:
   - extension ChorusLabView: Inspectable
   - Instantiate view with EmptyVoicesProvider and engineFactory { RealVoiceIO() }.
   - Assert the above identifiers exist using .find(viewWithAccessibilityIdentifier:).
3) Build and run tests. Expect green.

Peeks to request (templates)
~~~bash
{
  echo "=== Package.swift (1-240) ==="
  nl -ba Package.swift | sed -n '1,240p'
  echo
  echo "=== VoiceChorusPlayground.swift (header and targetTimeRow) ==="
  nl -ba Sources/VoiceKitUI/VoiceChorusPlayground.swift | sed -n '1,160p'
  echo
  echo "=== VoiceChorusPlayground.swift (selected list and actions) ==="
  nl -ba Sources/VoiceKitUI/VoiceChorusPlayground.swift | sed -n '200,520p'
} | toClip
~~~

Patches to prepare (descending order within each file)
- Package.swift:
  - Add ViewInspector package dependency
  - Add VoiceKitUITests test target
- Tests/VoiceKitUITests/AccessibilitySmokeTests.swift:
  - New file via /dev/null diff
- Sources/VoiceKitUI/VoiceChorusPlayground.swift:
  - Optional: add .accessibilityLiveRegion(.polite) to “Actual time” HStack
  - Optional: minimal .transition on SelectedVoiceRow

Commit message style
- Keep under 80 chars, e.g.:
  - “UI: ChorusLabView tests (a11y IDs, ViewInspector), live region”

Known gotchas
- MainActor isolation: SystemVoicesCache.all() is MainActor; ensure provider/all() and callers match.
- SwiftUI testing: ViewInspector must be added as a test-only dependency; never in production targets.
- Patch discipline: Always peek just before preparing a diff; strictly descending hunks.

Future opportunities
- Add a seeded-rows test with a FakeVoicesProvider (matching preferred language base code) to demonstrate seeding behavior and row identifiers (vk.row.<id>).
- Consider a micro-utility to format seconds uniformly for a11y value (we currently use SecondsFormatter.twoDecimals).
- If adding more animations, adhere to Reduce Motion settings implicitly (SwiftUI defaults are fine; keep effects subtle).

Contact notes for successor
- The operator prefers: short, anchored peeks; single-file diffs; descending order; small, guaranteed steps.
- Tests should be meaningful and double as example documentation. Favor clear naming and readable assertions over sheer quantity.

End state definition for this tranche
- Package.swift declares VoiceKitUITests and test-only ViewInspector
- AccessibilitySmokeTests.swift added and passing
- (Optional) Polite live region set for actual time updates
- Commit with a short, descriptive message under 80 chars
