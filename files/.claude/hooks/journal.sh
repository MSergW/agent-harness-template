#!/usr/bin/env bash
# Hook journal: `journal.sh <rule> <decision>` appends one line «time, rule, decision, agent» to hook-journal.tsv in
# the git common directory — one log for the main checkout and every worktree, never committed. The command text
# is never written (it may hold a secret). The hook input (JSON) comes on stdin and gives the agent; it may be empty.
# Read by harness-refresh («Hook journal»): a rule that fires on normal work is narrowed with a test, never removed.
# HOOK_JOURNAL overrides the path (the hook tests point it at a temp file). Never fails the hook that calls it.
rule=$1 decision=$2
agent=$(jq -r '.agent_type // "main"' 2>/dev/null | tr -d '\r') || agent=main
log=${HOOK_JOURNAL:-}
if [ -z "$log" ]; then
  dir=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
  log="$dir/hook-journal.tsv"
fi
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rule" "$decision" "${agent:-main}" >>"$log" 2>/dev/null
exit 0
