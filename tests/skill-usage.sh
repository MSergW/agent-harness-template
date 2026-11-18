#!/usr/bin/env bash
# Cases of the skill-usage log (files/.claude/hooks/skill-usage.sh) in a throwaway repository with a worktree.
# Exits non-zero when a case logs something else.
#   bash tests/skill-usage.sh
set -uo pipefail
hook="$(cd "$(dirname "$0")/.." && pwd)/files/.claude/hooks/skill-usage.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
git init -q "$d/r" && git -C "$d/r" commit -q --allow-empty -m init && git -C "$d/r" worktree add -q -b wt "$d/wt"
mkdir -p "$d/r/.agents/skills/verify" "$d/wt/.agents/skills/verify"
log="$d/r/.git/skill-usage.jsonl"
fails=0; n=0
case_() {   # name project_dir input want(last log line as "skill by agent branch", or "-" for no new line)
  n=$((n + 1))
  local before after got
  before=$(wc -l 2>/dev/null <"$log" || echo 0)
  printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" bash "$hook"
  local rc=$?
  after=$(wc -l 2>/dev/null <"$log" || echo 0)
  if [ "$before" -eq "$after" ]; then got=-; else got=$(tail -1 "$log" | jq -r '"\(.skill) \(.by) \(.agent) \(.branch)"'); fi
  [ $rc -eq 0 ] || got="exit $rc"
  if [ "$got" = "$4" ]; then printf '✓ %s\n' "$1"; else printf '✗ want %s, got %s: %s\n' "$4" "$got" "$1"; fails=$((fails + 1)); fi
}
main=$(git -C "$d/r" branch --show-current)

case_ 'Skill call'            "$d/r"  '{"hook_event_name":"PostToolUse","tool_input":{"skill":"verify"},"session_id":"s"}' "verify model main $main"
case_ 'Skill call, subagent'  "$d/r"  '{"hook_event_name":"PostToolUse","tool_input":{"skill":"handoff"},"agent_type":"reviewer"}' "handoff model reviewer $main"
case_ 'typed /skill'          "$d/r"  '{"hook_event_name":"UserPromptSubmit","prompt":"/verify now"}' "verify user main $main"
case_ 'built-in /clear'       "$d/r"  '{"hook_event_name":"UserPromptSubmit","prompt":"/clear"}' -
case_ '/skill mid-text'       "$d/r"  '{"hook_event_name":"UserPromptSubmit","prompt":"run /verify"}' -
case_ 'not JSON'              "$d/r"  'not json' -
case_ 'worktree → one log'    "$d/wt" '{"hook_event_name":"PostToolUse","tool_input":{"skill":"verify"}}' "verify model main wt"
[ ! -e "$d/wt/skill-usage.jsonl" ] || { echo '✗ the worktree got its own log'; fails=$((fails + 1)); }

echo "$((n - fails))/$n passed"
[ "$fails" -eq 0 ]
