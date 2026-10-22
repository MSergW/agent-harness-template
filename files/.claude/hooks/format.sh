#!/bin/sh
# PostToolUse(Edit|Write): format the edited file with its language's formatter, if installed.
# A formatter error (usually a syntax error) is reported back at once. Add stacks as needed.
command -v jq >/dev/null || exit 0   # jq is not bundled with Git for Windows: winget install jqlang.jq
file=$(jq -r '.tool_input.file_path // empty' | tr -d '\r')
command -v cygpath >/dev/null && file=$(cygpath -u "$file")   # Git Bash: C:\path → /c/path
[ -n "$file" ] && [ -f "$file" ] || exit 0
run() { out=$("$@" 2>&1) || { echo "Formatter failed on $file:" >&2; echo "$out" >&2; exit 1; }; }
case "$file" in
  *.go) command -v gofmt >/dev/null && run gofmt -w "$file" ;;
  *.py) command -v ruff >/dev/null && run ruff format -q "$file" ;;
  *.rs) command -v rustfmt >/dev/null && run rustfmt "$file" ;;
  *.js|*.jsx|*.ts|*.tsx|*.css|*.scss|*.json|*.vue)
    [ -x node_modules/.bin/prettier ] && run node_modules/.bin/prettier --write --log-level warn "$file" ;;
esac
exit 0
