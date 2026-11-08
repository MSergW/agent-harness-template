#!/usr/bin/env bash
# Test of the scope fence (files/.claude/hooks/scope-fence.sh) through every entry point:
# Claude Code (Edit/Write), Codex (apply_patch), Antigravity (antigravity.sh pre-edit) and the stop hook.
# Installs the template into a throwaway repository; exits non-zero on the first failed case.
#   bash tests/scope-fence.sh
set -uo pipefail
tpl="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/scope-fence.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; mkdir -p "$repo/src" "$repo/docs"
cd "$repo" && git init -q && git config user.email t@t && git config user.name t
echo a >src/a.txt; echo b >src/b.txt; echo r >README.md; echo o >docs/owner.md
git add -A && git commit -qm init
bash "$tpl/install.sh" "$repo" >/dev/null && git add -A && git commit -qm harness
echo "owner's draft" >>docs/owner.md   # the owner's uncommitted work, made before the task

fails=0
ok()   { printf '✓ %s\n' "$1"; }
bad()  { printf '✗ %s\n%s\n' "$1" "${2:-}"; fails=$((fails + 1)); }
hook() { bash .claude/hooks/scope-fence.sh "$@"; }
claude_edit() { jq -n --arg f "$repo/$1" --arg c "$repo" '{cwd:$c, tool_name:"Edit", tool_input:{file_path:$f}}' | hook pre; }
codex_patch() { jq -n --arg p "$1" --arg c "$repo/src" '{cwd:$c, tool_name:"apply_patch", tool_input:{command:$p}}' | hook pre; }
agy_edit() { jq -n --arg f "$repo/$1" --arg w "$repo" '{workspacePaths:[$w], toolCall:{name:"replace_file_content", args:{TargetFile:$f}}}' | bash .claude/hooks/antigravity.sh pre-edit; }
denied()  { jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null <<<"$1"; }
stop()    { jq -n --arg c "$repo" '{cwd:$c, stop_hook_active:false}' | bash .claude/hooks/stop-check.sh 2>&1 >/dev/null; }

jq -n --arg c "$repo" '{cwd:$c, source:"startup"}' | bash .claude/hooks/session-start.sh >/dev/null
[ -f .tmp/scope-base ] && ok "session start records a baseline" || bad "no .tmp/scope-base after session start"

out=$(claude_edit src/a.txt); denied "$out" && grep -q 'No scope declared' <<<"$out" \
  && ok "no scope: the first edit is refused with «declare your scope»" || bad "edit without a scope passed" "$out"
out=$(claude_edit .tmp/scope); [ -z "$out" ] && ok "writing .tmp/scope itself is allowed" || bad "writing the scope was refused" "$out"

printf 'src/a.txt\n# a comment\ndocs/new/\n' >.tmp/scope
out=$(claude_edit src/a.txt);       [ -z "$out" ] && ok "in-scope file passes" || bad "in-scope edit refused" "$out"
out=$(claude_edit docs/new/x.md);  [ -z "$out" ] && ok "a new file under a scoped dir/ passes" || bad "dir/ scope refused" "$out"
out=$(claude_edit src/b.txt);       denied "$out" && grep -q 'src/b.txt is outside' <<<"$out" \
  && ok "out-of-scope file is refused, named in the reason" || bad "out-of-scope edit passed" "$out"
out=$(claude_edit docs/plans/tech-debt.md); [ -z "$out" ] && ok "tech debt is always editable" || bad "tech-debt refused" "$out"
out=$(jq -n '{tool_input:{file_path:"/etc/hosts"}}' | hook pre); [ -z "$out" ] && ok "a file outside the repository is not fenced" || bad "outside file refused" "$out"

out=$(codex_patch $'*** Begin Patch\n*** Update File: a.txt\n@@\n-a\n+a2\n*** End Patch')
[ -z "$out" ] && ok "codex apply_patch on an in-scope file (path relative to cwd src/) passes" || bad "codex in-scope refused" "$out"
out=$(codex_patch $'*** Begin Patch\n*** Add File: b.txt\n+x\n*** End Patch')
denied "$out" && ok "codex apply_patch on an out-of-scope file is refused" || bad "codex out-of-scope passed" "$out"

out=$(agy_edit src/b.txt); jq -e '.decision == "deny"' >/dev/null <<<"$out" \
  && ok "antigravity pre-edit refuses an out-of-scope file" || bad "antigravity out-of-scope passed" "$out"
out=$(agy_edit src/a.txt); jq -e '.decision == "allow"' >/dev/null <<<"$out" \
  && ok "antigravity pre-edit allows an in-scope file" || bad "antigravity in-scope refused" "$out"

# Stop: edits made around the fence (a shell command) are caught; the owner's earlier work is not.
echo a2 >src/a.txt
out=$(stop); [ -z "$out" ] && ok "stop: in-scope change and the owner's prior work pass" || bad "stop blocked a clean task" "$out"
echo b2 >src/b.txt
out=$(stop); grep -q 'src/b.txt' <<<"$out" && ! grep -q 'docs/owner.md' <<<"$out" \
  && ok "stop: an out-of-scope change is reported, the owner's file is not" || bad "stop missed src/b.txt" "$out"
git checkout -q src/b.txt
echo "agent line" >>docs/owner.md
out=$(stop); grep -q 'docs/owner.md' <<<"$out" && ok "stop: an agent edit of the owner's dirty file is reported" || bad "stop missed owner file edit" "$out"
printf 'o\nowner'"'"'s draft\n' >docs/owner.md   # undo the agent's line

# A commit ends the task: the scope is dropped.
git add src/a.txt && git commit -qm step
out=$(claude_edit src/a.txt); denied "$out" && grep -q 'No scope declared' <<<"$out" && [ ! -f .tmp/scope ] \
  && ok "after a commit the scope is dropped" || bad "scope survived a commit" "$out"

# Resume keeps the scope; a new session drops it.
echo src/a.txt >.tmp/scope
jq -n --arg c "$repo" '{cwd:$c, source:"resume"}' | bash .claude/hooks/session-start.sh >/dev/null
[ -f .tmp/scope ] && ok "resume keeps the scope" || bad "resume dropped the scope"
jq -n --arg c "$repo" '{cwd:$c, source:"startup"}' | bash .claude/hooks/session-start.sh >/dev/null
[ ! -f .tmp/scope ] && ok "a new session drops the scope" || bad "new session kept the scope"

[ "$fails" -eq 0 ] && echo "scope fence: all passed" || { echo "scope fence: $fails failed"; exit 1; }
