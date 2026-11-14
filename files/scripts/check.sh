#!/usr/bin/env bash
# The single repository check: `make check`. The repository is consistent when this exits 0.
# Layers run in order; when a layer fails, the next ones are not run.
#   1 — static: harness self-checks, formatting, vet/lint, project static checks
#   2 — behaviour: tests, validators
# Layer 3 (local preview, test server) is manual — see AGENTS.md «Definition of done».
# Stack sections switch on by marker files (go.mod, package.json, pyproject.toml); a tool that is not
# installed is skipped with a message, never faked as passing.
#   CHECK_CACHED=1 make check — passes at once when the tree is the same as at the last fully green run.
set -uo pipefail

# An overall bound: a hung step ends the check with exit 124 instead of holding the agent that waits for it.
# Only when stdout is not a terminal: `timeout` (macOS too) runs the check in a process group of its own, so
# Ctrl-C in a terminal would no longer stop it. Without `timeout` (older macOS: brew install coreutils) — unbounded.
if [ -z "${CHECK_BOUNDED:-}" ] && [ ! -t 1 ] && command -v timeout >/dev/null 2>&1; then
  CHECK_BOUNDED=1 timeout 1500 bash "$0" "$@"; s=$?
  [ "$s" -ne 124 ] || printf '\n✗ make check ran over 25 min — something hangs: find why (the last «==» step above) instead of re-running it\n'
  exit "$s"
fi
cd "$(dirname "$0")/.."

failed=0
# Steps skipped for a missing tool: a green result without them is partial, so the summary names them.
skipped=""
step() { printf '\n== %s\n' "$1"; }
fail() { printf '✗ %s\n  What to do: %s\n' "$1" "$2"; failed=1; }
skip() { printf '%s is not installed — skipped\n' "$1"; skipped="${skipped:+$skipped, }$1"; }
layer_done() { [ "$failed" -eq 0 ] || { printf '\nLayer %s failed — later layers not run.\n' "$1"; exit 1; }; }
has() { command -v "$1" >/dev/null 2>&1; }

if [ -f go.mod ] && has go; then
  # -trimpath: the build cache key holds no path to the tree, so worktrees share one Go cache instead of growing it.
  export GOFLAGS="${GOFLAGS:+$GOFLAGS }-trimpath"
  # Tools from `go install` (golangci-lint, govulncheck) live in GOBIN or GOPATH/bin, often not on an agent's PATH.
  gobin=$(go env GOBIN 2>/dev/null)
  [ -n "$gobin" ] || gobin="$(go env GOPATH 2>/dev/null)/bin"
  [ -d "$gobin" ] && export PATH="$gobin:$PATH"
fi

# The tree's print: the commit, every change since it and the untracked files (not the ignored ones). A fully
# green run stores it next to this tree's git data (a worktree has its own); CHECK_CACHED=1 checks nothing when
# the tree has not changed since: the same code would give the same result.
tree_print() {
  { git rev-parse HEAD; git diff HEAD --binary
    git ls-files --others --exclude-standard
    git ls-files --others --exclude-standard | git hash-object --stdin-paths
  } 2>/dev/null | git hash-object --stdin
}
green_stamp=$(git rev-parse --git-path harness-check-green 2>/dev/null)
tree_at_start=$(tree_print)
# RACE=all runs more than the stored run did, so it is never skipped.
if [ "${CHECK_CACHED:-}" = 1 ] && [ "${RACE:-}" != all ] && [ -n "$green_stamp" ] && [ "$(cat "$green_stamp" 2>/dev/null)" = "$tree_at_start" ]; then
  printf '✓ make check: the tree has not changed since the last fully green run — not checked again (CHECK_CACHED=1)\n'
  exit 0
fi

# ---------- Layer 1: static ----------

step "harness: skill symlinks"
# Skills live in .agents/skills/; .claude/skills/ holds only symlinks to them, so copies cannot drift.
# Git for Windows without symlink support checks them out as text files — nothing to verify there.
skills=""
if [ "$(git config core.symlinks)" = false ]; then
  echo "core.symlinks=false — skipped (Windows: enable Developer Mode, then git config core.symlinks true)"
else
for d in .agents/skills/*/; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  [ "$(readlink ".claude/skills/$n")" = "../../.agents/skills/$n" ] || skills+="missing symlink .claude/skills/$n
"
done
for f in .claude/skills/*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  n=$(basename "$f")
  if [ ! -L "$f" ]; then skills+="$f is not a symlink (a copy of a skill)
"
  elif [ ! -d ".agents/skills/$n" ]; then skills+="$f points nowhere
"
  fi
done
fi
[ -z "$skills" ] || fail "skills out of sync:
$skills" "put a skill in .agents/skills/<name>/ and link it: ln -s ../../.agents/skills/<name> .claude/skills/<name>"

step "harness: unfilled template markers"
marker='{{FI''LL'
left=$(git grep -nIF "$marker" -- . 2>/dev/null; git ls-files --others --exclude-standard -z | xargs -0 grep -nIF "$marker" 2>/dev/null)
[ -z "$left" ] || fail "template markers left:
$left" "fill them with real project content (or delete the line) — see the harness fill prompt"

step "harness: unfinished update"
# install.sh --update writes HARNESS_UPDATE.md and a «pending» line in .harness-version; both go away
# only when the template's changes are merged (UPDATE_PROMPT.md) and install.sh --done has run.
if [ -e HARNESS_UPDATE.md ] || grep -q '^pending ' .harness-version 2>/dev/null; then
  fail "a harness template update is not finished" "merge HARNESS_UPDATE.md by the template's UPDATE_PROMPT.md, delete it, then run <template>/install.sh --done ."
fi

step "harness: module maps (warning)"
# A directory with AGENTS.md has a module map. Its source changed but the map did not — a reminder,
# not an error: update the map only when responsibility, contracts or constraints changed.
changed=$({ git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u)
src_re='\.(go|py|js|ts|tsx|jsx|rs|java|kt|cs|rb|php|swift)$'
test_re='(_test\.go|_test\.py|test_[^/]*\.py|\.test\.[jt]sx?|\.spec\.[jt]sx?)$'
for map in $({ git ls-files '*/AGENTS.md'; git ls-files --others --exclude-standard '*/AGENTS.md'; } | sort -u); do
  dir=$(dirname "$map")
  code=$(printf '%s\n' "$changed" | grep "^$dir/" | grep -E "$src_re" | grep -vE "$test_re" || true)
  if [ -n "$code" ] && ! printf '%s\n' "$changed" | grep -qx "$map"; then
    printf '⚠ code in %s changed, its map %s did not — update it if contracts or constraints changed\n' "$dir" "$map"
  fi
done

step "harness: PROGRESS.md size"
# State, not a log: the current state keeps the five latest pieces, older ones go to docs/progress/
# by week (the handoff skill). The session-start hook shows only its top; the rest is read by section.
if [ -f PROGRESS.md ]; then
  progress_bytes=$(wc -c < PROGRESS.md | tr -d ' ')
  [ "$progress_bytes" -le 40960 ] || fail "PROGRESS.md is $progress_bytes bytes (limit 40960)" \
    "move older current-state entries to docs/progress/<year>-W<week>.md, drop done items from next (the handoff skill)"
fi

step "debug probes left"
# The diagnose skill tags every temporary log line with [DEBUG-<4 hex>]; none may outlive the diagnosis.
# The pattern is split so this line does not match itself.
probe='\[DE''BUG-[0-9a-f]{4}\]'
left=$(git grep -nIE "$probe" -- . 2>/dev/null; git ls-files --others --exclude-standard -z | xargs -0 grep -HnIE "$probe" 2>/dev/null)
[ -z "$left" ] || fail "debug probes left:
$left" "remove the temporary log lines (the diagnose skill, step 6)"

if [ -f go.mod ]; then
  step "go: gofmt"
  unformatted=$(gofmt -l $(go list -f '{{.Dir}}' ./... 2>/dev/null) 2>/dev/null)
  [ -z "$unformatted" ] || fail "not formatted: $unformatted" "gofmt -w <file>"
  step "go: vet"
  go vet ./... || fail "go vet" "fix the findings above"
  step "go: golangci-lint"
  if has golangci-lint; then
    golangci-lint run ./... || fail "golangci-lint" "fix the findings; exceptions only in .golangci.yml with a reason"
  else skip golangci-lint; fi
  # Known vulnerabilities the code actually calls (modules and stdlib), from vuln.go.dev, a few seconds.
  # Exit 3 — a vulnerability found; any other non-zero — the tool did not run (no network, built with
  # an older Go): a skip with a note, not a red line.
  step "go: govulncheck"
  if has govulncheck; then
    out=$(govulncheck ./... 2>&1)
    case $? in
      0) ;;
      3) printf '%s\n' "$out" | sed -n '/^Vulnerability #/,/^$/p' | head -30
         fail "govulncheck" "upgrade the module to the fixed version (go get <module>@<version>) or Go; govulncheck -show verbose ./..." ;;
      *) printf '%s\n' "$out" | head -5
         echo "govulncheck did not run — skipped (rebuild: go install golang.org/x/vuln/cmd/govulncheck@latest)"
         skipped="${skipped:+$skipped, }govulncheck" ;;
    esac
  else skip govulncheck; fi
fi

if [ -f package.json ] && has npm; then
  for s in lint typecheck; do
    if npm run 2>/dev/null | grep -qE "^  $s$"; then
      step "npm run $s"
      npm run --silent "$s" || fail "npm run $s" "fix the findings above"
    fi
  done
fi

if [ -f pyproject.toml ]; then
  step "python: ruff"
  if has ruff; then
    ruff format --check . || fail "ruff format" "ruff format <file>"
    ruff check . || fail "ruff check" "fix the findings above"
  else skip ruff; fi
fi

step "secrets in files"
# Tokens and private keys by their known shape, in tracked and new (not ignored) files. Tests and fixtures hold
# made-up values, so they are not scanned; a deliberate exception (a hint, a sample) carries a secret-ok comment.
# Only file:line is printed: a found secret must not land in the check's output too.
secret_re='[0-9]{8,10}:AA[0-9A-Za-z_-]{33}|-----BEGIN [A-Z ]*PRIVATE KEY( BLOCK)?-----|gh[pousr]_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{22,}|glpat-[0-9A-Za-z_-]{20,}|sk-ant-[a-z]{3}[0-9]{2}-[0-9A-Za-z_-]{20,}|sk-(proj-)?[0-9A-Za-z_-]{40,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}'
x=':(exclude,glob)'   # glob: «**/» also matches the top level
secrets=$(git ls-files -co --exclude-standard -z -- . "${x}scripts/check.sh" "${x}**/*_test.go" "${x}**/testdata/**" \
    "${x}**/test/**" "${x}**/tests/**" "${x}**/__tests__/**" "${x}**/fixtures/**" "${x}**/*.test.*" "${x}**/*.spec.*" \
    "${x}**/test_*.py" "${x}**/*_test.py" "${x}**/conftest.py" |
  xargs -0 grep -HnIE -e "$secret_re" 2>/dev/null | grep -v 'secret-ok' | cut -d: -f1,2)
[ -z "$secrets" ] || fail "something like a token or a private key in files:
$secrets" "move the secret out of the file (into .env or the secret store) and rotate it if it was ever committed; a hint or a sample — a secret-ok comment"
# Files that hold secrets stay local (.gitignore), never in git — the secret files of AGENTS.md «Do not touch».
# {{FILL: add the project's other secret files (key or vault files, secrets.yml) to secret_paths as git pathspecs, then delete this comment}}
secret_paths=(.env '**/.env')
secret_files=$(git ls-files -- "${secret_paths[@]}")
[ -z "$secret_files" ] || fail "files with secrets are in git:
$secret_files" "git rm --cached <file> and add it to .gitignore: these files stay local; rotate what they held"

# {{FILL: project static checks (language of UI texts, forbidden names, design tokens, …) — each a
# `step` + `fail` with «what to do». Delete this comment if there are none.}}

layer_done 1

# ---------- Layer 2: behaviour ----------

if [ -f go.mod ]; then
  # With the race detector. A package much slower under it can go to race_slow (import paths, one per
  # line): it then runs without -race, and `make check RACE=all` runs everything with it (before a release).
  race_slow=""
  # A package that hangs past the limit fails with its goroutine stacks (panic: test timed out) instead of
  # holding the check; RACE=all runs the slow packages under -race too, so it gets more.
  test_limit=5m
  [ "${RACE:-}" = all ] && test_limit=15m
  step "go: test (-race)"
  go_tests() {
    if [ "$(go env CGO_ENABLED)" != 1 ]; then
      echo "cgo is off — the race detector needs it; tests run without -race"
      go test -timeout "$test_limit" ./...
    elif [ -z "$race_slow" ] || [ "${RACE:-}" = all ]; then
      go test -race -timeout "$test_limit" ./...
    else
      # Package paths have no spaces: splitting the list into arguments is intended.
      # shellcheck disable=SC2046
      go test -race -timeout "$test_limit" $(go list ./... | grep -vxF "$race_slow") && go test -timeout "$test_limit" $race_slow
    fi
  }
  out=$(go_tests 2>&1) || {
    printf '%s\n' "$out" | grep -E -A3 '^(--- FAIL|FAIL|panic:)|_test\.go:[0-9]+:|^WARNING: DATA RACE' | head -40
    fail "go test" "if a text or template changed on purpose, update the test; DATA RACE — synchronise the shared data; otherwise fix the code. Never weaken tests"
  }
fi

if [ -f package.json ] && has npm && npm run 2>/dev/null | grep -qE '^  test$'; then
  step "npm test"
  # A script running `node --test` gives it --test-timeout=60000 (package.json), so one hung test fails alone.
  npm test --silent || fail "npm test" "fix the failing tests"
fi

if [ -f pyproject.toml ]; then
  step "python: pytest"
  if has pytest; then pytest -q || fail "pytest" "fix the failing tests"; else skip pytest; fi
fi

# {{FILL: project behaviour checks (validators, UI unit tests, config/playbook syntax) — or delete.}}

layer_done 2
if [ -n "$skipped" ]; then
  printf '\n✓ make check: passed, but skipped (no tool): %s\n' "$skipped"
else
  printf '\n✓ make check: all passed\n'
  # Only a full run, and only when the tree did not change during it: otherwise the result is about another tree.
  [ -n "$green_stamp" ] && [ "$(tree_print)" = "$tree_at_start" ] && printf '%s\n' "$tree_at_start" >"$green_stamp"
fi
exit 0
