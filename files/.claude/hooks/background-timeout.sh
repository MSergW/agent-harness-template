#!/usr/bin/env bash
# PreToolUse(Bash): a command run with run_in_background must start with `timeout <limit>` (after an optional
# `cd <dir> &&`), the limit at most 30 minutes. A background command has no time limit of its own, and the agent
# that ends its turn waiting for it is woken only by its exit: a loop that never ends leaves the session hanging
# until the user notices. `timeout` kills the whole process group and exits 124, which wakes the agent.
# Foreground commands are not checked: the Bash tool limits them itself. Claude Code only (Codex has no
# background commands of this kind).
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.tool_input.run_in_background // false')" = true ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0
# Prints "ok", or why the command is refused. Accepted: `[cd <dir> &&] [/usr/bin/]timeout [options] <N>[s|m|h] <cmd>`
# with N ≤ 1800 s; after it only one command (pipes are fine): `;`, `&&`, `||`, a newline or a lone `&` outside
# quotes would start a command the limit does not cover.
why=$(printf '%s' "$cmd" | perl -0777 -ne '
  unless (/\A\s*(?:cd\s+[^;&|\n]+?\s*&&\s*)?(?:\S*\/)?timeout\s+((?:(?:-[a-zA-Z]+(?:\s+(?!-)\S+)?|--[a-z-]+(?:=\S+)?)\s+)*)(\d+(?:\.\d+)?)([smh]?)\s+(\S.*)\z/s) {
    print "it does not start with `timeout <seconds> <command>`"; exit }
  my ($opts, $n, $u, $rest) = ($1, $2, $3, $4);
  if ($opts =~ /--foreground/) { print "`--foreground` does not kill the child processes"; exit }
  my $sec = $n * ($u eq "m" ? 60 : $u eq "h" ? 3600 : 1);
  if ($sec <= 0 || $sec > 1800) { print "the limit ${sec}s is not between 1 s and 30 min"; exit }
  (my $bare = $rest) =~ s/\x27[^\x27]*\x27|"(?:[^"\\]|\\.)*"//g;
  $bare =~ s/[<>]&|&>|\d>&\d//g;
  if ($bare =~ /;|&&|\|\||\n|&/) { print "a command after `;`, `&&`, `||`, `&` or a new line runs without the limit"; exit }
  print "ok"')
[ "$why" = ok ] && exit 0
jq -n --arg why "$why" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
permissionDecisionReason:("A background command needs a time limit (refused: " + $why + "): start it with `timeout <seconds>` (at most 1800), e.g. `timeout 900 make check > <scratch dir>/check.log 2>&1` (a literal path: variables do not carry over between calls), or for several commands `timeout 900 bash -c '"'"'…'"'"'`. On expiry it exits 124 and you are notified: then find why it hung instead of re-running it. A script of your own that loops (a fix loop) also needs a pass limit and an exit.")}}'
exit 0
