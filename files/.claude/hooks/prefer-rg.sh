#!/usr/bin/env bash
# PreToolUse(Bash): deny grep/egrep/fgrep and ask for rg instead (faster, skips .gitignore'd
# paths and binaries, fewer tokens). Leaves git grep, pgrep and "grep" inside quotes alone.
# Scripts that call grep internally (make check, hooks) are not affected: only the command text is checked.
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
cmd=$(jq -r '.tool_input.command // empty' | tr -d '\r')
[ -z "$cmd" ] && exit 0
stripped=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
re='(^|[;&|(`]|\$\()[[:space:]]*((sudo|env|time|command|xargs)([[:space:]]+-[^[:space:]]+)*[[:space:]]+)*[ef]?grep([[:space:]]|$)'
if printf '%s' "$stripped" | grep -Eq "$re"; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
  permissionDecisionReason:"Use rg instead of grep: grep -rn P dir → rg -n P dir; -E is not needed; -F/-i/-l/-v/-c are the same; --include=*.go → -t go or -g \"*.go\"; in a pipe: cmd | rg P. Note: rg -c prints nothing and exits 1 on zero matches — use rg -c P file || echo 0."}}'
fi
exit 0
