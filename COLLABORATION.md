# VoiceKit Collaboration & AI Co‑Author Statement

Project vision
- VoiceKit is a collaborative effort to demonstrate that an AI (OpenAI GPT‑5), guided by a human maintainer, can design, implement, document, and test a production‑friendly Swift package.
- The goal is not to replace people, but to accelerate human creativity and engineering with a careful, auditable AI workflow.

What “AI co‑author” means here
- Architecture and code were produced through iterative prompt/response sessions with GPT‑5, reviewed and integrated by the human maintainer (rdoggett).
- The AI contributed significant portions of:
  - Core engine (RealVoiceIO, ScriptedVoiceIO) with Swift 6 actor‑safety
  - TTS models and protocols
  - Name normalization and fuzzy matching
  - SwiftUI VoicePicker UI with persistence
  - Tests and developer documentation
- The human maintainer directed scope, validated design choices, resolved environment issues, and ensured code quality, correctness, and fit.

How we work (reproducible, incremental)
- Keep changes small, buildable, and testable. Iterate in green increments.
- Preserve a “working brief” (docs) to onboard a fresh assistant and reproduce context quickly.
- Prefer deterministic tests (ScriptedVoiceIO) for CI, and keep device‑dependent tests at the app level.
- Treat concurrency and platform APIs as first‑class constraints; document safety decisions.

Attribution
- Human maintainer: rdoggett (project owner), code review, integration, and releases.
- AI co‑author: GPT‑5 (OpenAI), architecture, implementation, docs, and tests.
- Code is licensed MIT; see LICENSE.

Contribution guidelines (short)
- Be clear if a change is primarily AI‑generated, human‑written, or pair‑authored:
  - Commit prefixes: ai:, human:, pair:
  - PR template: include “How produced” and “How verified” sections.
- Tests required for non‑trivial changes; prefer deterministic coverage in the package.
- Keep public APIs @MainActor where appropriate; avoid passing @MainActor closures to background-only callbacks; consult docs/Concurrency.md.
- Document notable design decisions in docs/ProgrammersGuide.md or inline with concise comments.

Scope and limits
- VoiceKit targets iOS 17+ and macOS 14+ with Swift 6 language mode.
- RealVoiceIO uses Apple frameworks (AVFoundation, Speech); ScriptedVoiceIO avoids hardware/permissions for CI.
- This repo does not ship or bundle proprietary model weights—only Swift code and documentation.

Ethics and transparency
- We disclose AI authorship because provenance matters. This repo is a case study in safe, auditable AI-assisted engineering.
- Review remains human‑led. Every merged change should be understandable and maintainable by human contributors.

Releases and versioning
- Versions derive from git tags (e.g., v0.1.0).
- For runtime diagnostics, you may expose a constant like `VoiceKitInfo.version` (optional).

Acknowledgements
- Thanks to everyone exploring sustainable human+AI collaboration.
- Special thanks to rdoggett for the vision and guidance—and to the Swift community for the ecosystem that makes packages like this possible.

— VoiceKit maintainers (human + AI)

