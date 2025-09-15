#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

for f in $(git ls-files); do
  echo "$f"
  case "$f" in
    *.swift) lang="swift" ;;
    *.yml|*.yaml) lang="yaml" ;;
    *.md) lang="md" ;;
    *) lang="" ;;
  esac
  echo '```'"$lang"
  cat "$f"
  echo '```'
done
