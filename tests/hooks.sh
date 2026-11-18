#!/usr/bin/env bash
# The hook rules' stop and pass cases (files/.claude/hooks/test_hooks.py: git-guard.py, prefer-rg.sh, the wait guards,
# readonly-agents.py, the hook journal), as a project's make check runs them; then git-guard.py with a project secret
# list filled in, and through Antigravity's pre-command chain. Exits non-zero on a failed case.
#   bash tests/hooks.sh
set -uo pipefail
hooks="$(cd "$(dirname "$0")/.." && pwd)/files/.claude/hooks"
command -v python3 >/dev/null || { echo "python3 is not installed — skipped"; exit 0; }
export HOOK_JOURNAL=/dev/null
fails=0; n=0
python3 "$hooks/test_hooks.py" || fails=$((fails + 1)); n=$((n + 1))

check() {   # name want got
  n=$((n + 1))
  if [ "$2" = "$3" ]; then printf '✓ %-5s %s\n' "$2" "$1"; else printf '✗ want %s, got %s: %s\n' "$2" "$3" "$1"; fails=$((fails + 1)); fi
}
# A filled PROJECT_SECRETS (as FILL_PROMPT asks): its paths are denied, a longer name and a bare mention pass.
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
cp "$hooks/git-guard.py" "$hooks/readonly-agents.py" "$hooks/journal.sh" "$d/"
sed -i.bak 's/^PROJECT_SECRETS = \[\]$/PROJECT_SECRETS = [r"secrets\\.ya?ml", r"host_vars(?:\/.*)?"]/' "$d/git-guard.py"
grep -q '^PROJECT_SECRETS = \[r' "$d/git-guard.py" || { echo "✗ could not fill PROJECT_SECRETS in the copy"; exit 1; }
gg() { local out; out=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | python3 "$d/git-guard.py")
  [ -z "$out" ] && echo allow || jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"; }
for c in 'cat conf/secrets.yml' 'cat ansible/host_vars/web1.yml' 'rg x ansible/host_vars/'; do check "project secret: $c" deny "$(gg "$c")"; done
for c in 'cat conf/secrets.yml.example' 'rg -l host_vars ansible' 'cat docs/secrets.md'; do check "project secret: $c" allow "$(gg "$c")"; done

# Antigravity: git-guard.py in the pre-command chain, its «ask» turned into a deny.
agy() { jq -n --arg c "$1" --arg w "$PWD" '{workspacePaths:[$w], toolCall:{name:"run_command", args:{CommandLine:$c}}}' | bash "$hooks/antigravity.sh" pre-command | jq -r .decision; }
check "antigravity: cat .env" deny "$(agy 'cat .env')"
check "antigravity: git stash (ask → deny)" deny "$(agy 'git stash')"
check "antigravity: git status" allow "$(agy 'git status')"

echo "$((n - fails))/$n passed"
[ "$fails" -eq 0 ]
