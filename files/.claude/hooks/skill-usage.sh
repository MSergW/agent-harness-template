#!/bin/bash
# PostToolUse (Skill) and UserPromptSubmit: append one line per skill use to skill-usage.jsonl in the git common
# directory — one log for the main checkout and every worktree, kept after a worktree is removed, never committed.
# Read by harness-refresh («Skill usage»). Never blocks: any failure exits 0 without output.
input=$(cat)
dir=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
case "$event" in
  PostToolUse)
    skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
    by=model
    ;;
  UserPromptSubmit)
    # Only «/name …» where name is a project skill: built-in commands (/clear, /model…) are not counted.
    skill=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null | sed -n '1s#^/\([a-z0-9:-]*\).*#\1#p')
    [ -n "$skill" ] && [ -d "${CLAUDE_PROJECT_DIR:-.}/.agents/skills/$skill" ] || exit 0
    by=user
    ;;
  *) exit 0 ;;
esac
[ -n "$skill" ] || exit 0
branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)
printf '%s' "$input" | jq -c --arg skill "$skill" --arg by "$by" --arg branch "$branch" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{ts: $ts, skill: $skill, by: $by, agent: (.agent_type // "main"), session: .session_id, branch: $branch}' \
  >>"$dir/skill-usage.jsonl" 2>/dev/null
exit 0
