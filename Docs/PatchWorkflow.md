# Patch Workflow (Any Developer, Any Mac)

This repo favors clean, portable patch files over ad-hoc scripts.

Prereqs (macOS)
- git, bash/zsh (default on macOS)
- pbcopy/pbpaste (built-in)
- jq, SwiftLint (brew recommended)
- fixDiffCounts.swift on PATH (used by applyPatch to auto-correct hunk counts)

Helper: applyPatch
- applyPatch reads a unified diff from the clipboard by default and:
  1) runs fixDiffCounts.swift to correct offsets,
  2) runs `git apply --check`,
  3) runs `git apply`.
- Usage:
  - ./applyPatch              # clipboard
  - ./applyPatch patch.diff   # from file
  - pbpaste | ./applyPatch    # stdin

Standard cadence
1) Peek
   - Developer runs `nl -ba … | sed … | pbcopy` and pastes peeks into chat.
2) Patch
   - Assistant returns ONE unified diff for only those files.
3) Apply
   - Developer: `./applyPatch`
4) Verify
   - Developer runs SwiftLint and posts top rule counts.

Generating peeks quickly
```
nl -ba Sources/…/File.swift | sed -n 'LINE-8,LINE+8p' | pbcopy
```

Troubleshooting
- error: patch does not apply
  - Likely stale context or wrong path. Re-peek the exact failing range; regenerate patch.
- error: deleted file X still has contents
  - Clipboard diff included unrelated local changes. Ask for a minimal diff (only intended files).
- zsh quoting issues
  - Prefer simple one-liners or a heredoc that launches a subshell `bash <<'BASH' … BASH` only when truly necessary.

Do and Don’t
- Do: keep patches small and focused; always cite paths as `git ls-files` would.
- Don’t: include repo-wide diffs or local experimental changes.

