# Golden Rule: Always Peek Before Patch

Purpose: ensure patches are correct, minimal, and apply cleanly on any machine.

Principles
- Peek first: share exact file paths and tight line ranges before generating a patch.
- One patch per batch: deliver a single unified diff using repo-real paths (`--- a/...`, `+++ b/...`).
- No hidden edits: avoid in-place mutations or helper scripts unless there’s a blocking reason.
- Keep the developer’s cadence: make copy/paste steps obvious and minimal.

Peeking (copy to clipboard)
```
nl -ba PATH/To/File.swift | sed -n 'START,ENDp' | pbcopy
```
Guidelines
- Prefer ±8–12 lines around the flagged lines.
- Use absolute repo paths (what `git ls-files` outputs).
- If a patch fails, re-peek the failed hunk and regenerate.

What a valid patch looks like
- Unified diff with `--- a/...` and `+++ b/...` headers.
- Targets only the discussed files.
- No unrelated hunks or local noise.

Out of scope
- Large refactors without peeks.
- Renaming public APIs without explicit agreement and repo-wide peeks.

