# Command Snippets (Copy/Paste Safe)

Top SwiftLint rule counts to clipboard (zsh/bash):
```
swiftlint || true
swiftlint --reporter json | jq -r '.[].rule_id' | sort | uniq -c | sort -nr | head -15 | pbcopy
```

Peeking ranges (copy to clipboard):
```
nl -ba PATH/To/File.swift | sed -n 'START,ENDp' | pbcopy
```

Minimal diff from specific files (avoid clipboard noise):
```
git diff --no-color -- path/to/A.swift path/to/B.swift | pbcopy
```

Apply a patch from clipboard:
```
./applyPatch
```

Heredoc pattern (use only when necessary to avoid zsh quoting issues):
```
bash <<'BASH'
set -euo pipefail
# your commands here, no zsh interpolation hazards
BASH
```

Common errors and remedies
- “patch does not apply”
  - Re-run peeks for the failing area; regenerate unified diff with fresh context.
- “deleted file X still has contents”
  - Your clipboard diff included unrelated changes. Limit `git diff` to intended files.
- zsh complaining about `(` or `{`
  - Use a heredoc to run a bash subshell for those specific commands.

