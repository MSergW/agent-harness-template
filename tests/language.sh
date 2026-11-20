#!/usr/bin/env bash
# The owner's language block of files/.claude/hooks/session-start.sh: no file — ask once; ru/uk name the other
# language they are not; notes and steps default to English; the last line of a key wins, comments are ignored;
# a UTF-8 BOM is dropped; a UTF-16 file is never to be overwritten.
#   bash tests/language.sh
set -uo pipefail
hook="$(cd "$(dirname "$0")/.." && pwd)/files/.claude/hooks/session-start.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
git -C "$d" init -q   # session-start.sh reads the repository state first
fails=0; n=0
run() { echo '{}' | (cd "$d" && AGENT_LANGUAGE_FILE="$1" bash "$hook" 2>/dev/null) | sed -n '/^Language/,/^  .*(AGENTS.md\|^  asks/p'; }
has() {   # name output pattern
  n=$((n + 1))
  if grep -qF -- "$3" <<<"$2"; then printf '✓ %s\n' "$1"; else printf '✗ %s: no «%s» in\n%s\n' "$1" "$3" "$2"; fails=$((fails + 1)); fi
}
out=$(run "$d/none"); has "no file: asks once" "$out" "ask once"; has "no file: names the path" "$out" "$d/none"
printf 'reply=\n' >"$d/empty"; out=$(run "$d/empty"); has "empty reply: asks" "$out" "ask once"
printf '# mine\nreply = ru   # answers\n' >"$d/ru"; out=$(run "$d/ru")
has "ru: not Ukrainian" "$out" "to the owner in Russian (not Ukrainian)"; has "ru: notes default English" "$out" "notes in English"
has "ru: steps default English" "$out" "step session works in English"
printf 'reply=uk\r\nnotes=uk\r\nsteps=en\r\n' >"$d/uk"; out=$(run "$d/uk")
has "uk (CRLF): not Russian" "$out" "in Ukrainian (not Russian);"; has "uk: notes Ukrainian" "$out" "notes in Ukrainian (not Russian)"
printf 'reply=ru\nreply=en\nsteps=Polish\n' >"$d/en"; out=$(run "$d/en")
has "last key wins" "$out" "to the owner in English;"; has "a language name passes as is" "$out" "works in Polish"
printf '\357\273\277reply=uk\r\nnotes=en\r\n' >"$d/bom"; out=$(run "$d/bom")
has "UTF-8 BOM: reply still read" "$out" "to the owner in Ukrainian (not Russian);"
printf '\377\376r\000=\000' >"$d/utf16"; out=$(run "$d/utf16")
has "unreadable file: not overwritten" "$out" "Do not overwrite it"
echo "$((n - fails))/$n passed"
[ "$fails" -eq 0 ]
