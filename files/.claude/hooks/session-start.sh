#!/usr/bin/env bash
# SessionStart: short repository state for the new session's context.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
echo "Branch: $(git branch --show-current)"
echo "Recent commits:"
git log --oneline -5 | sed 's/^/  /'
status=$(git status --short)
if [ -n "$status" ]; then
  echo "Uncommitted changes (treat as the owner's unless you made them):"
  echo "$status" | head -20 | sed 's/^/  /'
fi
if [ -f PROGRESS.md ]; then
  echo
  echo "PROGRESS.md (current state):"
  # From the first second-level heading (the current state), whatever language it is in.
  sed -n '/^## /,$p' PROGRESS.md | head -40
fi
exit 0
