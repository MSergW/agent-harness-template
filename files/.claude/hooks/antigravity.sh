#!/usr/bin/env bash
# Antigravity adapter: .agents/hooks.json calls this with an event name; it turns Antigravity's
# camelCase input (workspacePaths, toolCall.name/args) into the input the shared scripts in
# .claude/hooks/ read, and their answers into Antigravity's JSON (decision, injectSteps).
#   antigravity.sh session-start | pre-command | pre-edit | post-edit | stop
command -v jq >/dev/null || { case ${1:-} in pre-command|pre-edit) echo '{"decision":"allow"}' ;; esac; exit 0; }   # Windows: winget install jqlang.jq
event=${1:-}
input=$(cat)
hooks=$(cd "$(dirname "$0")" && pwd)

# The workspace: the first workspace path (a Windows path or a file:// URI on some setups), else here.
ws=$(jq -r '.workspacePaths[0] // empty' <<<"$input" | tr -d '\r')
ws=${ws#file://}
command -v cygpath >/dev/null && [ -n "$ws" ] && ws=$(cygpath -u "$ws")   # Git Bash: C:\path → /c/path
root=$(git -C "${ws:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${ws:-$PWD}")
export CLAUDE_PROJECT_DIR="$root"

case "$event" in
  session-start)
    out=$(jq -n --arg cwd "$root" '{cwd:$cwd}' | bash "$hooks/session-start.sh")
    [ -n "$out" ] || { echo '{}'; exit 0; }
    jq -n --arg m "$out" '{injectSteps:[{systemMessage:{systemMessage:$m}}]}'
    ;;
  pre-command)
    # run_command → prefer-rg.sh; "allow" hands the call on to the user's own approval settings.
    out=$(jq '{tool_input:{command:(.toolCall.args.CommandLine // "")}}' <<<"$input" | bash "$hooks/prefer-rg.sh")
    reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
    if [ -n "$reason" ]; then jq -n --arg r "$reason" '{decision:"deny",reason:$r}'; else echo '{"decision":"allow"}'; fi
    ;;
  pre-edit)
    # write_to_file / replace_file_content / multi_replace_file_content → scope-fence.sh (the task's
    # declared files); "deny" goes back to the agent with the reason, it never asks the owner.
    out=$(jq --arg cwd "$root" '{cwd:$cwd, tool_input:{file_path:(.toolCall.args.TargetFile // "")}}' <<<"$input" | bash "$hooks/scope-fence.sh" pre)
    reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
    if [ -n "$reason" ]; then jq -n --arg r "$reason" '{decision:"deny",reason:$r}'; else echo '{"decision":"allow"}'; fi
    ;;
  post-edit)
    # A formatter error cannot be reported back here (PostToolUse takes only {}); the stop check sees it.
    file=$(jq -r '.toolCall.args.TargetFile // empty' <<<"$input" | tr -d '\r')
    [ -n "$file" ] && (cd "$root" && jq -n --arg f "$file" '{tool_input:{file_path:$f}}' | sh "$hooks/format.sh" >/dev/null 2>&1)
    echo '{}'
    ;;
  stop)
    # Antigravity has no stop_hook_active: a block is remembered per conversation and user message,
    # so the next stop in the same turn passes (never blocks twice in a row, as in Claude Code).
    mark="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null)/antigravity-stop-blocked"
    turn=$(jq -r '[.conversationId, .lastUserInput] | tostring' <<<"$input" | cksum | cut -d' ' -f1)
    active=false
    [ "$(cat "$mark" 2>/dev/null)" = "$turn" ] && { active=true; rm -f "$mark"; }
    errs=$(jq -n --arg cwd "$root" --argjson a "$active" '{cwd:$cwd, stop_hook_active:$a}' | bash "$hooks/stop-check.sh" 2>&1 >/dev/null)
    if [ $? -eq 2 ]; then
      echo "$turn" >"$mark" 2>/dev/null
      jq -n --arg r "$errs" '{decision:"continue",reason:$r}'
    else
      echo '{"decision":"stop"}'
    fi
    ;;
  *) echo '{}' ;;
esac
exit 0
