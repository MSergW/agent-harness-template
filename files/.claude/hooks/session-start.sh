#!/usr/bin/env bash
# SessionStart: short repository state for the new session's context.
# In a worktree CLAUDE_PROJECT_DIR is the main checkout, so the session's own directory comes first.
[ -t 0 ] || input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"${input:-}" 2>/dev/null | tr -d '\r')
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" || exit 0
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 0
echo "Branch: $(git branch --show-current)"
echo "Recent commits:"
git log --oneline -5 | sed 's/^/  /'
status=$(git status --short)
if [ -n "$status" ]; then
  echo "Uncommitted changes (treat as the owner's unless you made them):"
  echo "$status" | head -20 | sed 's/^/  /'
fi
# A new task: the scope fence drops the old scope and records the owner's uncommitted work as its baseline.
if [ -f .claude/hooks/scope-fence.sh ]; then
  printf '%s' "${input:-}" | bash .claude/hooks/scope-fence.sh start
  echo "Scope: before the first edit write the files of your task into .tmp/scope (AGENTS.md, «One task at a time»)."
fi
# PROGRESS.md by position, whatever language its headings are in: the first section (current state)
# up to its first blank line after text, the second (in progress) whole, the top of the third (next);
# cut at a line boundary under PROGRESS_MAX_BYTES. The rest is read by section, never whole.
if [ -f PROGRESS.md ]; then
  echo
  echo "PROGRESS.md (latest state; the rest only by section: rg -n '^## ' PROGRESS.md):"
  awk -v max="${PROGRESS_MAX_BYTES:-4000}" -v next_lines=15 '
    function out(line) {
      if (total + length(line) + 1 > max) { print "  … (cut; read PROGRESS.md by section)"; exit }
      total += length(line) + 1; print line
    }
    /^## / { sec++; seen = 0; blank = 0; n = 0; if (sec <= 3) out($0); next }
    sec == 1 {
      if (!seen && /^$/) next
      if (seen && /^$/) blank = 1
      if (!blank) { seen = 1; out($0) }
      next
    }
    sec == 2 { out($0); next }
    sec == 3 { if (n++ <= next_lines) out($0); next }
  ' PROGRESS.md
fi
exit 0
