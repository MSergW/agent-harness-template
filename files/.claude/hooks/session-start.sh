#!/usr/bin/env bash
# SessionStart: short repository state for the new session's context.
# In a worktree CLAUDE_PROJECT_DIR is the main checkout, so the session's own directory comes first.
[ -t 0 ] || input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"${input:-}" 2>/dev/null | tr -d '\r')
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" || exit 0
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 0
# A new worktree lacks the local files git does not carry (the `worktree` skill, «Local files»).
[ -f scripts/worktree-links.sh ] && bash scripts/worktree-links.sh 2>&1
echo "Branch: $(git branch --show-current)"
echo "Recent commits:"
git log --oneline -5 | sed 's/^/  /'
status=$(git status --short)
if [ -n "$status" ]; then
  echo "Uncommitted changes, $(echo "$status" | wc -l | tr -d ' ') files (treat as the owner's unless you made them):"
  echo "$status" | head -5 | sed 's/^/  /'
fi
# A new task: the scope fence drops the old scope and records the owner's uncommitted work as its baseline.
if [ -f .claude/hooks/scope-fence.sh ]; then
  printf '%s' "${input:-}" | bash .claude/hooks/scope-fence.sh start
  echo "Scope: before the first edit write the files of your task into .tmp/scope (AGENTS.md, «One task at a time»)."
fi
# The owner's language: a personal file outside the repository, one for all projects (AGENTS.md «Language»).
# key=value lines: reply (answers, plans, questions, reports), notes (thinking, working notes), steps (a plan's
# step sessions). ru/uk/en or a language name. The agent writes it when the owner asks; none — it asks once.
langfile="${AGENT_LANGUAGE_FILE:-$HOME/.config/agent-harness/language}"
lang_name() {   # code → name; ru and uk name each other, since the project text around may be the other one
  case "$1" in
    ru) echo "Russian (not Ukrainian)" ;; uk) echo "Ukrainian (not Russian)" ;; en) echo "English" ;;
    *) echo "$1" ;;
  esac
}
# A UTF-8 BOM (Windows editors, PowerShell 5.1 Set-Content) is dropped, or the first key would never match.
lang_get() { sed -e "1s/^$(printf '\357\273\277')//" "$langfile" 2>/dev/null |
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([^#[:space:]]*\).*/\1/p" | tail -1 | tr -d '\r'; }
# Git Bash prints /c/Users/…; PowerShell (Antigravity, Codex on Windows) needs C:\Users\….
langshown="$langfile"; command -v cygpath >/dev/null 2>&1 && langshown="$langfile ($(cygpath -w "$langfile"))"
echo
if [ -f "$langfile" ] && [ -n "$(lang_get reply)" ]; then
  reply=$(lang_name "$(lang_get reply)"); notes=$(lang_name "$(lang_get notes)"); steps=$(lang_name "$(lang_get steps)")
  echo "Language (the owner's settings, $langshown): answers, plans, questions and reports to the owner in $reply;"
  echo "  your thinking and working notes in ${notes:-English}. A plan's step session works in ${steps:-English}, $reply only in"
  echo "  its questions and its final report. Product text stays in the project language (AGENTS.md). When the owner"
  echo "  asks for another language, change that file (keys reply, notes, steps) and follow it from that answer on."
elif [ -f "$langfile" ] && ! tr -d '\000' < "$langfile" | cmp -s - "$langfile"; then   # NUL bytes: UTF-16
  echo "Language: $langshown is not UTF-8 (UTF-16?), its lines cannot be read. Answer in the"
  echo "  language the owner writes in; think in English. Do not overwrite it: tell the owner to save it as UTF-8."
else
  echo "Language: no owner settings in $langshown. Answer in the language the owner writes in; think in English."
  echo "  In your first answer ask once: the language of answers, of thinking and notes, of a plan's step sessions"
  echo "  (ru, uk, en or another); then write the file, lines reply=…, notes=…, steps=… (AGENTS.md «Language»)."
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
