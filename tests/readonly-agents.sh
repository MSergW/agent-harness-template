#!/usr/bin/env bash
# Case table of the read-only subagent guard (files/.claude/hooks/readonly-agents.py): each line is
# «allow|deny <agent> <command>» for the Bash tool; file tools and agents that write are checked after it.
# Exits non-zero when a case gets the other decision.
#   bash tests/readonly-agents.sh
set -uo pipefail
hook="$(cd "$(dirname "$0")/.." && pwd)/files/.claude/hooks/readonly-agents.py"
command -v python3 >/dev/null || { echo "python3 is not installed — skipped"; exit 0; }

fails=0; n=0
decide() {   # agent tool command → allow | deny
  local out
  out=$(jq -n --arg a "$1" --arg t "$2" --arg c "$3" \
    '{agent_type:$a, tool_name:$t, tool_input:{command:$c, file_path:"x"}}' | python3 "$hook")
  if jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 <<<"$out"; then echo deny; else echo allow; fi
}
case_() {    # want agent command [tool]
  local got; n=$((n + 1))
  got=$(decide "$2" "${4:-Bash}" "$3")
  if [ "$got" = "$1" ]; then printf '✓ %-5s %-10s %s\n' "$1" "$2" "$3"
  else printf '✗ want %s, got %s: [%s] %s\n' "$1" "$got" "$2" "$3"; fails=$((fails + 1)); fi
}

# Readers and checks
case_ allow reviewer  'git diff HEAD -- src/a.go | head -50'
case_ allow reviewer  'rg -n "foo|bar" src/'
case_ allow reviewer  "rg -n 'a|b' . | wc -l"
case_ allow checker   'make check > /dev/null 2>&1'
case_ allow checker   'CHECK_CACHED=1 make check'
case_ allow checker   'bash scripts/check.sh'
case_ allow checker   'go test -timeout 5m ./...'
case_ allow checker   'npm test'
case_ allow checker   'npm run lint'
case_ allow checker   'pytest -q tests/'
case_ allow checker   'ruff check .'
case_ allow checker   'ruff format --check .'
case_ allow checker   'prettier --check src'
case_ allow checker   'cargo test'
case_ allow checker   'cargo clippy -- -D warnings'
case_ allow log-reader 'tail -200 /tmp/x.log | rg -n ERROR'
case_ allow docs-sync 'find docs -name "*.md" | sort'
case_ allow reviewer  'sed -n 1,40p src/a.go'
case_ allow reviewer  'gofmt -l .'
case_ allow reviewer  'for f in a b; do echo $f; done'
case_ allow ui-verifier 'git log --oneline -5'
# Temporary directories
case_ allow reviewer  'd=$(mktemp -d); git archive HEAD | tar -x -C "$d"; cd "$d" && go test ./...'
case_ allow reviewer  'd=$(mktemp -d) && echo x > "$d/out.txt"'
case_ allow checker   'make check > "$TMPDIR/check.log" 2>&1'
case_ allow reviewer  'cp src/a.go /tmp/probe/a.go'
case_ allow reviewer  'd=$(mktemp -d); (cd "$d" && touch x); echo done'
case_ allow reviewer  'python3 -c "print(1)"'
# Writes
case_ deny reviewer   'x' Edit
case_ deny docs-sync  'x' Write
case_ deny checker    'echo x > src/a.go'
case_ deny reviewer   'echo x | tee notes.md'
case_ deny reviewer   'rm -rf build'
case_ deny reviewer   'sed -i "" s/a/b/ src/a.go'
case_ deny reviewer   "sed -n 's/a/b/w out.txt' src/a.go"
case_ deny reviewer   'gofmt -w src/a.go'
case_ deny reviewer   'git ls-files | xargs gofmt -w'
case_ deny reviewer   'timeout 60 gofmt -w src/a.go'
case_ deny reviewer   'd=$(mktemp -d); (cd "$d" && true); touch x'
case_ deny reviewer   'd=src; echo x > "$d/a.go"'
case_ deny reviewer   'cd /tmp; cd src; echo x > a.go'
case_ deny reviewer   'echo $(touch x)'
case_ deny reviewer   'git commit -am x'
case_ deny reviewer   'git stash'
case_ deny reviewer   'git checkout -- src/a.go'
case_ deny checker    'go build ./...'
case_ deny checker    'go mod tidy'
case_ deny checker    'make deploy'
case_ deny checker    'npm install'
case_ deny checker    'ruff check --fix .'
case_ deny checker    'prettier --write src'
case_ deny checker    'cargo fmt'
case_ deny checker    'python3 -c "print(1)"'
case_ deny reviewer   'find . -name "*.tmp" -delete'
case_ deny reviewer   'curl -o page.html https://example.com'
case_ deny reviewer   'some-unknown-tool --flag'
case_ deny reviewer   "echo 'unbalanced"
case_ deny Explore    'mv a b'
case_ deny plan-critic 'echo x >> docs/plans/p.md'
# Arguments that make a check rewrite files (fresh-context review, round 1)
case_ deny checker    'npm run lint -- --fix'
case_ deny checker    'npm test -- -u'
case_ deny checker    'go test ./... -args -update'
case_ deny checker    'go test ./... -update'
case_ deny checker    'pytest --junitxml=report.xml'
case_ deny checker    'pytest --snapshot-update'
case_ deny checker    'cargo clippy --fix'
case_ deny reviewer   'git reflog expire --expire=now --all'
case_ deny reviewer   'git config --list --unset x'
case_ deny reviewer   'git config --get-regexp x --add y z'
case_ deny checker    'uniq a b'
case_ deny checker    'xxd -r a b'
case_ deny checker    'tree -o out'
case_ deny checker    'mktemp src/fooXXX'
case_ deny checker    'trap "rm -rf src" EXIT'
case_ deny checker    "awk '{print > \$1}' a.txt"
case_ deny reviewer   'd=$(mktemp -d); export d=src; rm -rf $d'
case_ allow reviewer  'git reflog -5'
case_ allow reviewer  'git config --get user.name'
case_ allow reviewer  'd=$(mktemp -d); trap "rm -rf $d" EXIT; echo x > "$d/a"'
case_ allow checker   "awk '\$3 > 5 {print \$1}' a.txt"
case_ allow checker   'uniq -c a.txt'
case_ allow checker   'go test -run TestA -v ./pkg/...'
case_ allow checker   'go test -run TestUpdateUser ./pkg'
case_ allow checker   'pytest -k update tests/test_update.py'
case_ allow checker   'cargo test update_user'
# Agents that write, and the main conversation, are not guarded
case_ allow committer 'git commit -m x'
case_ allow ''        'rm -rf build'
case_ allow general-purpose 'x' Edit

printf '\n%d cases, %d failed\n' "$n" "$fails"
[ "$fails" -eq 0 ]
