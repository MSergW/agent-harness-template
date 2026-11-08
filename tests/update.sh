#!/usr/bin/env bash
# Test of install.sh --update / --done: a project installed from an older template commit and filled,
# then updated. Only files the template changed are listed (with the template's own diff), the
# project's filling is untouched, new files are copied, removed and renamed ones are listed.
# Builds a throwaway template repository from this working tree; exits non-zero on a failed case.
#   bash tests/update.sh
set -uo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/harness-update.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
tpl="$tmp/template" proj="$tmp/project"
fails=0
ok()  { printf '✓ %s\n' "$1"; }
bad() { printf '✗ %s\n%s\n' "$1" "${2:-}"; fails=$((fails + 1)); }
at()  { GIT_AUTHOR_DATE="$1T12:00:00Z" GIT_COMMITTER_DATE="$1T12:00:00Z" git "${@:2}"; }
section() { awk -v h="## $1" 'index($0, h) == 1 { on = 1; next } /^## / { on = 0 } on' "$proj/HARNESS_UPDATE.md"; }

# Template v1: this working tree, committed.
mkdir -p "$tpl" && cp -R "$src/install.sh" "$src/files" "$tpl/"
cd "$tpl" && git init -q && git config user.email t@t && git config user.name t
git add -A && at 2026-01-01 commit -qm v1; v1=$(git rev-parse HEAD)

# The project: installed from v1, filled, a file it did not need deleted, committed.
mkdir -p "$proj" && cd "$proj" && git init -q && git config user.email t@t && git config user.name t
echo app >main.txt && git add -A && at 2026-01-01 commit -qm init
bash "$tpl/install.sh" "$proj" >/dev/null
grep -qx "commit $v1" .harness-version && ok "install records the template commit in .harness-version" || bad "no version recorded" "$(cat .harness-version)"
sed -i.bak 's/^# {{FILL: project name}} — agent instructions$/# Acme — agent instructions/' AGENTS.md && rm AGENTS.md.bak
echo "- our own review rule" >>REVIEW.md
echo "- our idea" >>docs/plans/ideas.md
rm .claude/agents/ui-auditor.md.example
git add -A && at 2026-01-02 commit -qm harness

# Template v2: one change of each kind.
cd "$tpl"
sed -i.bak 's/^Turn a mistake that happened twice into/Turn a mistake that happened TWICE into/' files/AGENTS.md && rm files/AGENTS.md.bak   # project filled this file
echo "# v2 note" >>files/.claude/hooks/prefer-rg.sh             # project never touched it
git rm -q files/.claude/hooks/format.sh                          # removed
printf '#!/bin/sh\nexit 0\n' >files/.claude/hooks/new-hook.sh     # added
git mv files/docs/plans/ideas.md files/docs/plans/backlog.md && echo "<!-- v2 -->" >>files/docs/plans/backlog.md   # renamed + changed
echo "v2" >>files/.claude/agents/ui-auditor.md.example            # project deleted it
git add -A && at 2026-01-03 commit -qm v2; v2=$(git rev-parse HEAD)

# A harness without .harness-version: refused, with a guess of the starting commit.
cd "$proj" && mv .harness-version "$tmp/ver"
out=$(bash "$tpl/install.sh" --update "$proj" 2>&1); rc=$?
[ $rc -ne 0 ] && grep -q "Probably ${v1:0:7}" <<<"$out" && ok "no version: update refused, v1 guessed from the commit date" || bad "no-version guess" "$out"
out=$(bash "$tpl/install.sh" "$proj" 2>&1); rc=$?
[ $rc -ne 0 ] && grep -q 'no .harness-version' <<<"$out" && ok "no version: a plain re-install is refused too" || bad "plain re-install ran" "$out"
mv "$tmp/ver" .harness-version

before_agents=$(cat AGENTS.md)
bash "$tpl/install.sh" --update "$proj" >/dev/null || bad "update failed"
[ -f HARNESS_UPDATE.md ] && ok "HARNESS_UPDATE.md written" || bad "no HARNESS_UPDATE.md"

m=$(section 'Merge')
grep -q '^### `AGENTS.md`' <<<"$m" && grep -q '^+Turn a mistake that happened TWICE into' <<<"$m" && grep -q '^--- a/AGENTS.md' <<<"$m" \
  && ok "a filled file the template changed is listed with the template's diff (project paths)" || bad "AGENTS.md merge entry" "$m"
[ "$(cat AGENTS.md)" = "$before_agents" ] && ok "the project's filling is untouched" || bad "AGENTS.md was changed"
! grep -q 'REVIEW.md' HARNESS_UPDATE.md && ok "a file the template did not change is not listed (REVIEW.md, filled)" || bad "REVIEW.md listed"
! grep -q 'stop-check.sh\|session-start.sh' HARNESS_UPDATE.md && ok "untouched template files are not listed" || bad "unchanged files listed"
section 'Updated in place' | grep -q 'prefer-rg.sh' && cmp -s "$tpl/files/.claude/hooks/prefer-rg.sh" .claude/hooks/prefer-rg.sh \
  && ok "a file the project never changed is updated in place" || bad "prefer-rg.sh not updated in place"
[ -f .claude/hooks/new-hook.sh ] && section 'Copied' | grep -q 'new-hook.sh' && ok "a new template file is copied" || bad "new-hook.sh not copied"
section 'Removed' | grep -q 'format.sh' && [ -f .claude/hooks/format.sh ] \
  && ok "a removed template file is listed, not deleted by the installer" || bad "format.sh removal"
r=$(section 'Renamed'); grep -q 'docs/plans/ideas.md` → `docs/plans/backlog.md' <<<"$r" && grep -q '^+<!-- v2 -->' <<<"$r" && [ ! -e docs/plans/backlog.md ] \
  && ok "a renamed file is listed with its diff, the project's file left in place" || bad "rename entry" "$r"
section 'Skipped' | grep -q 'ui-auditor.md.example' && [ ! -e .claude/agents/ui-auditor.md.example ] \
  && ok "a file the project deleted is skipped, not brought back" || bad "deleted file came back or not listed"
grep -qx "commit $v1" .harness-version && grep -qx "pending $v2" .harness-version && ok "version stays v1, v2 pending" || bad "version file" "$(cat .harness-version)"

out=$(bash scripts/check.sh 2>&1); grep -q 'harness template update is not finished' <<<"$out" && ok "make check is red while the update is unfinished" || bad "check.sh did not flag the update"
out=$(bash "$tpl/install.sh" --update "$proj" 2>&1); [ $? -ne 0 ] && grep -q 'not finished' <<<"$out" && ok "a second update waits for the first" || bad "second update ran" "$out"
out=$(bash "$tpl/install.sh" --done "$proj" 2>&1); [ $? -ne 0 ] && grep -q 'still there' <<<"$out" && ok "--done refuses while HARNESS_UPDATE.md exists" || bad "--done ran early" "$out"
rm HARNESS_UPDATE.md
bash "$tpl/install.sh" --done "$proj" >/dev/null && grep -qx "commit $v2" .harness-version && ! grep -q '^pending' .harness-version \
  && ok "--done records v2" || bad "--done" "$(cat .harness-version)"
out=$(bash scripts/check.sh 2>&1); ! grep -q 'update is not finished' <<<"$out" && ok "the check is green on the update once done" || bad "check still flags the update"
out=$(bash "$tpl/install.sh" --update "$proj" 2>&1); grep -q 'Up to date' <<<"$out" && ok "a second update is a no-op" || bad "no-op update" "$out"

[ "$fails" -eq 0 ] && echo "update: all passed" || { echo "update: $fails failed"; exit 1; }
