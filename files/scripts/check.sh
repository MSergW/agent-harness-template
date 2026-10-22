#!/usr/bin/env bash
# The single repository check: `make check`. The repository is consistent when this exits 0.
# Layers run in order; when a layer fails, the next ones are not run.
#   1 — static: harness self-checks, formatting, vet/lint, project static checks
#   2 — behaviour: tests, validators
# Layer 3 (local preview, test server) is manual — see AGENTS.md «Definition of done».
# Stack sections switch on by marker files (go.mod, package.json, pyproject.toml); a tool that is not
# installed is skipped with a message, never faked as passing.
set -uo pipefail
cd "$(dirname "$0")/.."

failed=0
step() { printf '\n== %s\n' "$1"; }
fail() { printf '✗ %s\n  What to do: %s\n' "$1" "$2"; failed=1; }
skip() { printf '%s is not installed — skipped\n' "$1"; }
layer_done() { [ "$failed" -eq 0 ] || { printf '\nLayer %s failed — later layers not run.\n' "$1"; exit 1; }; }
has() { command -v "$1" >/dev/null 2>&1; }

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

# {{FILL: project static checks (language of UI texts, forbidden names, design tokens, …) — each a
# `step` + `fail` with «what to do». Delete this comment if there are none.}}

layer_done 1

# ---------- Layer 2: behaviour ----------

if [ -f go.mod ]; then
  step "go: test"
  out=$(go test ./... 2>&1) || {
    printf '%s\n' "$out" | grep -E '^(--- FAIL|FAIL|panic:)|_test\.go:[0-9]+:' | head -30
    fail "go test" "if a text or template changed on purpose, update the test; otherwise fix the code. Never weaken tests"
  }
fi

if [ -f package.json ] && has npm && npm run 2>/dev/null | grep -qE '^  test$'; then
  step "npm test"
  npm test --silent || fail "npm test" "fix the failing tests"
fi

if [ -f pyproject.toml ]; then
  step "python: pytest"
  if has pytest; then pytest -q || fail "pytest" "fix the failing tests"; else skip pytest; fi
fi

# {{FILL: project behaviour checks (validators, UI unit tests, config/playbook syntax) — or delete.}}

layer_done 2
printf '\n✓ make check: all passed\n'
