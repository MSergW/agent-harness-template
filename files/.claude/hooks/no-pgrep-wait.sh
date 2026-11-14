#!/usr/bin/env bash
# PreToolUse(Bash, Monitor): deny wait loops built on `pgrep -f` (while/until/for ... pgrep -f ...).
# `pgrep -f` matches the full command line, including the shell running the loop itself (its own
# command text contains the pattern), so the loop never sees the process end and hangs.
# Heredoc bodies are ignored (a script written to a file may mention it without running it).
# Claude Code (Bash, Monitor), Codex (Bash) and Antigravity (run_command, through antigravity.sh pre-command).
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0
stripped=$(printf '%s' "$cmd" | perl -0777 -pe 's/<<-?[ \t]*([\x27"]?)(\w+)\1([^\n]*)\n.*?^\t*\2[ \t]*$/$3/msg')
if printf '%s' "$stripped" | perl -0777 -ne 'exit(/\b(?:while|until|for)\b(?:(?!\bdone\b).)*?\bpgrep\b(?:\s+-[A-Za-z0-9-]+)*?\s+(?:-[A-Za-z]*f[A-Za-z]*|--full)\b/s ? 0 : 1)'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
  permissionDecisionReason:"No wait loops on pgrep -f: it matches full command lines, including this shell and the loop text itself, so the loop never ends. Run the long command with run_in_background, starting with `timeout <seconds>` (you are notified on exit), or wait on a PID: tail --pid=<pid> -f /dev/null / wait <pid>, or Monitor with an until-loop on a file or exit-code condition."}}'
fi
exit 0
