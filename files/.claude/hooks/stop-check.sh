#!/usr/bin/env bash
# Stop: before the agent says "done", check only what changed in the working tree.
# Full verification is `make check`. The result is cached by diff state, so without new changes
# the hook runs nothing. It never blocks twice in a row (stop_hook_active) to avoid loops.
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input" | tr -d '\r')" = true ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

changed=$({ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)
[ -z "$changed" ] && exit 0

cache=.claude/.stop-check
sum=shasum; command -v sha1sum >/dev/null && sum=sha1sum   # macOS: shasum, Linux/Git Bash: sha1sum
key=$({ git diff HEAD; git ls-files --others --exclude-standard -z | xargs -0 $sum 2>/dev/null; } | $sum | cut -d' ' -f1)
[ "$(cat "$cache" 2>/dev/null)" = "$key" ] && exit 0

errs=""
add() { errs+="✗ $1"$'\n'; }
existing() { while read -r f; do [ -f "$f" ] && echo "$f"; done; }

# Go: format, vet and test the changed packages.
gofiles=$(grep '\.go$' <<<"$changed" | existing)
if [ -n "$gofiles" ] && command -v go >/dev/null; then
  bad=$(gofmt -l $gofiles)
  [ -z "$bad" ] || add "gofmt: $bad"
  pkgs=$(for f in $gofiles; do echo "./$(dirname "$f")"; done | sort -u)
  out=$(go vet $pkgs 2>&1) || add "go vet:"$'\n'"$(head -20 <<<"$out")"
  out=$(go test $pkgs 2>&1) || add "go test:"$'\n'"$(grep -E '^(--- FAIL|FAIL|panic:)|_test\.go:[0-9]+:' <<<"$out" | head -30)"
fi

# Python: lint the changed files.
pyfiles=$(grep '\.py$' <<<"$changed" | existing)
if [ -n "$pyfiles" ] && command -v ruff >/dev/null; then
  out=$(ruff check $pyfiles 2>&1) || add "ruff:"$'\n'"$(head -20 <<<"$out")"
fi

# {{FILL: project-specific quick checks keyed on changed paths (templates → their tests, UI → UI unit
# tests, configs → validator, playbooks → --syntax-check) — or delete this comment.}}

if [ -n "$errs" ]; then
  {
    echo "Checks of the changed files failed — the work is not done:"
    echo "$errs"
    echo "Fix the cause (never weaken tests). If these are the owner's changes, not yours, do not fix them — report them."
  } >&2
  exit 2
fi
echo "$key" >"$cache"
exit 0
