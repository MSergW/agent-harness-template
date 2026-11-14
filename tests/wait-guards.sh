#!/usr/bin/env bash
# Cases of the wait guards (files/.claude/hooks/background-timeout.sh, no-pgrep-wait.sh), the latter also
# through Antigravity's pre-command chain (antigravity.sh). Exits non-zero when a case gets the other decision.
#   bash tests/wait-guards.sh
set -uo pipefail
hooks="$(cd "$(dirname "$0")/.." && pwd)/files/.claude/hooks"
fails=0; n=0
check() {   # name want got
  n=$((n + 1))
  if [ "$2" = "$3" ]; then printf '✓ %-5s %s\n' "$2" "$1"; else printf '✗ want %s, got %s: %s\n' "$2" "$3" "$1"; fails=$((fails + 1)); fi
}
decision() { [ -z "$1" ] && echo allow || jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"$1"; }
bg() {      # want command [background=true]
  local out; out=$(jq -n --arg c "$2" --argjson b "${3:-true}" '{tool_input:{command:$c, run_in_background:$b}}' | bash "$hooks/background-timeout.sh")
  check "background: $2 (bg=${3:-true})" "$1" "$(decision "$out")"
}
pg() {      # want command
  local out; out=$(jq -n --arg c "$2" '{tool_input:{command:$c}}' | bash "$hooks/no-pgrep-wait.sh")
  check "pgrep: $2" "$1" "$(decision "$out")"
}
agy() {     # want command (allow|deny as Antigravity's decision)
  local out; out=$(jq -n --arg c "$2" --arg w "$PWD" '{workspacePaths:[$w], toolCall:{name:"run_command", args:{CommandLine:$c}}}' | bash "$hooks/antigravity.sh" pre-command)
  check "antigravity: $2" "$1" "$(jq -r .decision <<<"$out")"
}

bg allow 'timeout 900 make check > /tmp/c.log 2>&1'
bg allow 'cd sub && timeout 30m npm test'
bg allow 'timeout -k 10 600 bash -c "a; b"'
bg allow 'make check' false
bg deny  'make check'
bg deny  'timeout 2h make check'
bg deny  'timeout --foreground 60 make check'
bg deny  'timeout 60 make check; make deploy'
bg deny  'timeout 60 make check && rm -rf x'
bg deny  'sleep 5 & timeout 60 make check'

pg deny  'while pgrep -f "make check" >/dev/null; do sleep 5; done'
pg deny  'until ! pgrep -lf go; do sleep 1; done'
pg allow 'pgrep -f server'
pg allow 'while kill -0 123; do sleep 1; done'
pg allow $'cat > w.sh <<EOF\nwhile pgrep -f x; do sleep 1; done\nEOF'

agy deny  'while pgrep -f x; do sleep 1; done'
agy deny  'grep -rn foo .'
agy allow 'rg -n foo .'

printf '\n%d cases, %d failed\n' "$n" "$fails"
[ "$fails" -eq 0 ]
