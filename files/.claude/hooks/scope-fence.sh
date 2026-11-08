#!/usr/bin/env bash
# Scope fence: the agent stays inside its task. Before its first edit it writes the files it intends
# to change into .tmp/scope (one path or glob per line, `dir/` = everything under it, `#` comments);
# an edit of any other file is refused with a reason. It talks only to the agent, never to the owner.
#   scope-fence.sh start  SessionStart: a new task — drop the old scope, record the baseline
#                         (on resume/compact the scope is kept)
#   scope-fence.sh pre    PreToolUse on file edits (Claude Code Edit/Write, Codex apply_patch,
#                         Antigravity through antigravity.sh): deny an edit outside the scope
#   scope-fence.sh stop   from stop-check.sh: files changed in this task outside the scope →
#                         exit 2, the reason on stderr (catches edits made by shell commands)
# The baseline (.tmp/scope-base) is HEAD plus every uncommitted file with its content hash when the
# task began: the owner's own uncommitted work is not counted against the scope unless it changes
# again. A commit (HEAD moves) ends the task: the scope is dropped and a new baseline recorded.
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
mode=${1:-}
input=$(cat 2>/dev/null)
scope=.tmp/scope base=.tmp/scope-base
# Always editable: the scope itself and scratch files, and the state files where out-of-task findings
# (tech debt) and the handoff go.
free=('.tmp/*' 'PROGRESS.md' 'docs/progress/*' 'docs/plans/*' 'docs/decisions.md')

# The session's own directory first (a worktree), as in stop-check.sh; a directory outside this
# project is not fenced.
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null | tr -d '\r')
command -v cygpath >/dev/null && [ -n "$cwd" ] && cwd=$(cygpath -u "$cwd")
root=""
for dir in ${cwd:+"$cwd"} "${CLAUDE_PROJECT_DIR:-.}"; do
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -f "$root/.claude/hooks/scope-fence.sh" ] && break
  root=""
done
[ -n "$root" ] && root=$(cd "$root" 2>/dev/null && pwd -P) && cd "$root" || exit 0

head_id() { git rev-parse -q --verify HEAD 2>/dev/null || echo none; }
# Uncommitted files (tracked and untracked, not ignored), each as "<content hash> <path>".
snapshot() {
  { git -c core.quotePath=false diff --name-only HEAD 2>/dev/null || git -c core.quotePath=false ls-files
    git -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u |
  while IFS= read -r f; do
    if [ -e "$f" ]; then printf '%s %s\n' "$(git hash-object -- "$f" 2>/dev/null)" "$f"; else printf 'deleted %s\n' "$f"; fi
  done
}
new_base() { mkdir -p .tmp && { echo "HEAD $(head_id)"; snapshot; } >"$base"; }
# A commit since the baseline ends the task; a missing baseline is recorded now.
current_base() {
  if [ ! -f "$base" ]; then new_base
  elif [ "$(head -1 "$base")" != "HEAD $(head_id)" ]; then rm -f "$scope"; new_base; fi
}
in_scope() {
  local p
  for p in "${free[@]}"; do case $1 in $p) return 0 ;; esac; done
  [ -f "$scope" ] || return 1
  while IFS= read -r p || [ -n "$p" ]; do
    p=${p%$'\r'}; p=${p%%#*}
    p=$(printf '%s' "$p" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s#^\./##')
    [ -n "$p" ] || continue
    case $p in */) p="$p*" ;; esac
    # shellcheck disable=SC2254  # $p is a glob on purpose
    case $1 in $p) return 0 ;; esac
  done <"$scope"
  return 1
}
declared() { [ -f "$scope" ] && sed -E 's/#.*//' "$scope" | grep -q '[^[:space:]]'; }
# A path as the tool gave it → relative to the repository root; fails for a path outside it.
relpath() {
  local f=$1 d tail
  command -v cygpath >/dev/null && f=$(cygpath -u "$f")
  case $f in /*) ;; *) f="${cwd:-$root}/$f" ;; esac
  d=$(dirname "$f")
  while [ ! -d "$d" ]; do d=$(dirname "$d"); done   # a new file in a new directory
  tail=${f#"$d"}; d=$(cd "$d" && pwd -P); f="$d$tail"
  while [[ $f == */./* ]]; do f=${f/\/.\//\/}; done
  case $f in "$root"/*) printf '%s\n' "${f#"$root"/}" ;; *) return 1 ;; esac
}
how='Write the files of this task into .tmp/scope before editing: one path or glob per line (`dir/` for a whole directory).'
fix='If it truly belongs to the task, add it to .tmp/scope deliberately and say so in your report; otherwise leave it alone and note what you wanted to change in docs/plans/tech-debt.md. Finish the task first.'

case "$mode" in
  start)
    case $(jq -r '.source // empty' <<<"$input" 2>/dev/null) in
      resume|compact) current_base ;;
      *) rm -f "$scope"; new_base ;;
    esac
    ;;
  pre)
    files=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" | tr -d '\r')
    # Codex apply_patch: the paths are in the patch text.
    [ -n "$files" ] || files=$(jq -r '.tool_input.command // .tool_input.input // empty | strings' <<<"$input" |
      sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p; s/^\*\*\* Move to: (.*)$/\1/p' | tr -d '\r')
    [ -n "$files" ] || exit 0
    current_base
    out=()
    while IFS= read -r f; do
      rel=$(relpath "$f") || continue
      in_scope "$rel" || out+=("$rel")
    done <<<"$files"
    [ ${#out[@]} -eq 0 ] && exit 0
    if declared; then reason="${out[*]} is outside this task's scope (.tmp/scope). $fix"
    else reason="No scope declared for this task. $how Then retry this edit."; fi
    jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    ;;
  stop)
    current_base
    out=$(snapshot | awk 'NR == FNR { if (FNR > 1) { h = $1; sub(/^[^ ]+ /, ""); was[$0] = h }; next }
      { h = $1; sub(/^[^ ]+ /, ""); if (was[$0] != h) print }' "$base" - |
      while IFS= read -r f; do in_scope "$f" || echo "  $f"; done)
    [ -z "$out" ] && exit 0
    {
      if declared; then echo "Changed outside this task's scope (.tmp/scope):"
      else echo "Files changed in this task, but no scope declared (.tmp/scope):"; fi
      echo "$out"
      if declared; then
        echo "Undo your edits of them (a file that also holds the owner's uncommitted work: undo only your lines, never git checkout it)."
        echo "If one truly belongs to the task, add it to .tmp/scope deliberately and say so in your report; what you wanted to change outside the task goes to docs/plans/tech-debt.md."
      else
        echo "$how List the files above that belong to the task; undo the rest."
      fi
      echo "If a file is the owner's change, not yours, leave it and report it."
    } >&2
    exit 2
    ;;
esac
exit 0
