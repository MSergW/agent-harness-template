#!/usr/bin/env bash
# Copies the harness template into a project, then the fill prompt (FILL_PROMPT.md) makes it real.
#   install.sh <project-dir> [--small]                   first install
#   install.sh --update <project-dir> [--from <commit>]  take the template's changes since the project's
#                                                        version; the update prompt (UPDATE_PROMPT.md) merges them
#   install.sh --done <project-dir>                      after the merge: record the new version
# The template commit a project came from is kept in its .harness-version (tracked in git).
# Never overwrites a file the project changed: install lists existing files in HARNESS_INSTALL.md,
# update lists in HARNESS_UPDATE.md only the files the template changed, each with the template's own diff.
# Never commits. Safe to re-run.
set -euo pipefail

tpl="$(cd "$(dirname "$0")" && pwd)"
usage() { echo "usage: $0 <project-dir> [--small] | --update <project-dir> [--from <commit>] | --done <project-dir>"; exit 1; }
mode=install; profile=full; dest=""; from=""
while [ $# -gt 0 ]; do
  case $1 in
    --small) profile=small ;;
    --update) mode=update ;;
    --done) mode=done ;;
    --from) [ $# -ge 2 ] || usage; from=$2; shift ;;
    -*) usage ;;
    *) [ -z "$dest" ] || usage; dest=$1 ;;
  esac
  shift
done
[ -n "$dest" ] && [ -d "$dest" ] || usage
dest="$(cd "$dest" && pwd)"
git -C "$dest" rev-parse --git-dir >/dev/null 2>&1 || { echo "$dest is not a git repository"; exit 1; }

# .harness-version: «commit <template commit>», «profile <full|small>», and «pending <commit>» while an
# update is being merged.
ver="$dest/.harness-version"
notes=()
ver_get() { [ -f "$ver" ] || return 0; sed -n "s/^$1 //p" "$ver" | tr -d '\r' | head -1; }
ver_put() {   # commit profile [pending]
  { echo "# The agent harness template commit this project was installed or last updated from."
    echo "# Written by install.sh; update: install.sh --update <project>, then UPDATE_PROMPT.md."
    echo "commit $1"; echo "profile $2"; [ -z "${3:-}" ] || echo "pending $3"; } >"$ver"
}
to=$(git -C "$tpl" rev-parse -q --verify HEAD 2>/dev/null || echo unknown)
short() { git -C "$tpl" log -1 --format='%h (%ad, %s)' --date=short "$1" 2>/dev/null || echo "$1"; }

# A project installed before .harness-version existed: the last template commit before the harness was
# first committed there is a guess, never applied without the owner.
guess_from() {
  local d c
  d=$(git -C "$dest" log --diff-filter=A --format=%cI -- .claude/hooks/stop-check.sh 2>/dev/null | tail -1)
  if [ -z "$d" ]; then echo "The harness is not committed in this project yet — ask the owner which template commit it came from."; return; fi
  c=$(git -C "$tpl" rev-list -1 --before="$d" HEAD 2>/dev/null)
  [ -n "$c" ] && echo "Probably $(short "$c"): the last template commit before the harness was committed here on ${d%%T*}."
  echo "Check it with the owner, or compare a file the project never fills (.claude/hooks/prefer-rg.sh) with \`git -C $tpl log -p -- files/<that file>\`."
}
no_version() {
  echo "$dest has the harness but no .harness-version: the template commit it came from is not recorded."
  guess_from
  echo "Then: $0 --update $dest --from <commit>"
  exit 1
}

if [ "$mode" = done ]; then
  pending=$(ver_get pending)
  [ -n "$pending" ] || { echo "No update pending in $dest (.harness-version has no «pending» line)."; exit 1; }
  [ ! -e "$dest/HARNESS_UPDATE.md" ] || { echo "HARNESS_UPDATE.md is still there: finish the merge (UPDATE_PROMPT.md), delete it, then run --done again."; exit 1; }
  ver_put "$pending" "$(ver_get profile)"
  echo "Recorded template $(short "$pending") in $ver — commit it with the merged harness."
  exit 0
fi

if [ "$mode" = update ]; then
  [ "$to" != unknown ] || { echo "$tpl is not a git clone: an update needs the template's history (git clone, then git pull)."; exit 1; }
  [ -z "$(ver_get pending)" ] || { echo "An update to $(short "$(ver_get pending)") is not finished: merge HARNESS_UPDATE.md (UPDATE_PROMPT.md), then $0 --done $dest."; exit 1; }
  [ -n "$from" ] || from=$(ver_get commit)
  if [ -z "$from" ] || [ "$from" = unknown ]; then
    [ -f "$ver" ] || [ -e "$dest/.claude/hooks/stop-check.sh" ] || { echo "$dest has no harness: install it first ($0 $dest)."; exit 1; }
    no_version
  fi
  from=$(git -C "$tpl" rev-parse -q --verify "$from^{commit}" 2>/dev/null) || { echo "The template has no commit $from (git -C $tpl pull?)."; exit 1; }
  p=$(ver_get profile); [ -z "$p" ] || profile=$p
  # No record: a project without PROGRESS.md was installed --small (it has none of the full profile's state files).
  [ -n "$p" ] || [ -e "$dest/PROGRESS.md" ] || { profile=small; notes+=("profile: no record and no PROGRESS.md — taken as small"); }
  if [ "$from" = "$to" ]; then
    [ -f "$ver" ] || ver_put "$to" "$profile"
    echo "Up to date: $dest is at the template's $(short "$to")."; exit 0
  fi
else
  # A project that already has the harness without a version would get every filled file listed.
  [ -f "$ver" ] || [ ! -e "$dest/.claude/hooks/stop-check.sh" ] || no_version
fi

# Files the small profile does not get (they are added later, with these names, when it grows).
small_skip='^(PROGRESS\.md|REVIEW\.md|GLOSSARY\.md|docs/decisions\.md|docs/plans/(README|ideas)\.md|docs/plans/done/|\.agents/skills/|\.claude/agents/|\.claude/launch\.json\.example)'

copied=(); kept=()
updated=(); merge=(); removed=(); renamed=(); skipped=()
[ "$mode" = install ] || [ -z "$(git -C "$tpl" status --porcelain -- files 2>/dev/null)" ] ||
  notes+=("The template has uncommitted changes in files/: they are not part of this update (only commits are)")

# A project directory that differs from a template one only in case (Scripts/ vs scripts/) is the
# same directory on macOS/Windows but not on Linux/CI: files land in the project's spelling, while the
# template's references (Makefile, AGENTS.md, settings.json, skills) use its own.
for t in $(ls -A "$tpl/files"); do
  for d in $(ls -A "$dest"); do
    if [ "$d" != "$t" ] && [ "$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')" ]; then
      notes+=("CASE: the project has \`$d/\`, the template uses \`$t/\` — files go into \`$d/\`; change every \`$t/\` reference (Makefile, AGENTS.md, CLAUDE.md, .claude/settings.json, skills, check script) to \`$d/\`")
    fi
  done
done

cd "$tpl/files"
copy() { mkdir -p "$dest/$(dirname "$1")" && cp -p "$1" "$dest/$1"; }
if [ "$mode" = install ]; then
  while IFS= read -r f; do
    f="${f#./}"
    [ "$profile" = small ] && [[ "$f" =~ $small_skip ]] && continue
    if [ -e "$dest/$f" ]; then cmp -s "$f" "$dest/$f" || kept+=("$f"); continue; fi
    copy "$f"; copied+=("$f")
  done < <(find . -type f ! -name .DS_Store | sort)
  [ -f "$ver" ] || { ver_put "$to" "$profile"; copied+=(".harness-version (template $to)"); }
else
  # Only what the template changed between the project's version and now. A file the project deleted
  # (an .example it did not need, a part the small profile lacks) is not brought back.
  old() { git -C "$tpl" show "$from:files/$1" 2>/dev/null; }
  new() { git -C "$tpl" show "$to:files/$1" 2>/dev/null; }
  # Copied from the commit recorded as the new version, not the working tree; the executable bit kept.
  copy() {
    mkdir -p "$dest/$(dirname "$1")" && new "$1" >"$dest/$1"
    [ "$(git -C "$tpl" ls-tree "$to" -- "files/$1" | cut -d' ' -f1)" != 100755 ] || chmod +x "$dest/$1"
  }
  while IFS=$'\t' read -r st a b; do
    a=${a#files/}; b=${b#files/}
    case $st in
      A|C*)
        [ "${st#C}" = "$st" ] || a=$b
        [ "$profile" = small ] && [[ "$a" =~ $small_skip ]] && continue
        if [ ! -e "$dest/$a" ]; then copy "$a"; copied+=("$a")
        elif ! new "$a" | cmp -s - "$dest/$a"; then kept+=("$a"); fi ;;
      M|T)
        if [ ! -e "$dest/$a" ]; then
          [ "$profile" = small ] && [[ "$a" =~ $small_skip ]] || skipped+=("$a")
        elif new "$a" | cmp -s - "$dest/$a"; then :
        elif old "$a" | cmp -s - "$dest/$a"; then copy "$a"; updated+=("$a")   # the project never changed it
        else merge+=("$a"); fi ;;
      D) [ -e "$dest/$a" ] && removed+=("$a") ;;
      R*)
        if [ -e "$dest/$a" ]; then renamed+=("$a"$'\t'"$b")
        elif [ ! -e "$dest/$b" ] && ! { [ "$profile" = small ] && [[ "$b" =~ $small_skip ]]; }; then skipped+=("$a → $b"); fi ;;
    esac
  done < <(git -C "$tpl" -c core.quotePath=false diff --name-status -M "$from" "$to" -- files/)
  ver_put "$from" "$profile" "$to"
fi

# Skill symlinks for Claude Code (Git for Windows without symlink support cannot make them).
if [ "$(git -C "$dest" config core.symlinks)" = false ]; then
  notes+=("SYMLINKS: core.symlinks=false, so .claude/skills/* links were NOT created. Windows: enable Developer Mode, run \`git config core.symlinks true\`, then re-run install.sh")
elif [ -d "$dest/.agents/skills" ]; then
  mkdir -p "$dest/.claude/skills"
  for d in "$dest"/.agents/skills/*/; do
    n=$(basename "$d")
    [ -e "$dest/.claude/skills/$n" ] || [ -L "$dest/.claude/skills/$n" ] || { ln -s "../../.agents/skills/$n" "$dest/.claude/skills/$n"; copied+=(".claude/skills/$n -> symlink"); }
  done
fi

# .gitignore: the harness must be tracked; only personal and scratch files are ignored.
gi="$dest/.gitignore"; touch "$gi"
eol=$'\n'; grep -q $'\r$' "$gi" && eol=$'\r\n'   # keep the file's line endings
[ -s "$gi" ] && [ -n "$(tail -c 1 "$gi")" ] && printf '%s' "$eol" >>"$gi"   # no newline at EOF → add one
for pat in '.claude' '.claude/' '.claude/*' '.agents' '.agents/' '.agents/*' '.codex' '.codex/' '.codex/*'; do
  if grep -qxF "$pat" "$gi" || grep -qxF "$pat"$'\r' "$gi"; then
    crlf=0; [ "$eol" = $'\r\n' ] && crlf=1
    awk -v p="$pat" -v crlf="$crlf" '{ l=$0; sub(/\r$/, "", l); if (l == p) printf "# harness: tracked now (was: %s)%s\n", p, (crlf ? "\r" : ""); else print $0 }' "$gi" >"$gi.tmp" && mv "$gi.tmp" "$gi"
    notes+=(".gitignore: '$pat' was ignored — commented out, the harness must be in git")
  fi
done
ignore=('.claude/settings.local.json' '.claude/.stop-check' '.tmp/')
[ "$profile" = small ] || ignore+=('_AUDITS/')   # audit reports; the small profile has no audit skill
for pat in "${ignore[@]}"; do
  grep -qF "$pat" "$gi" || { printf '%s%s' "$pat" "$eol" >>"$gi"; notes+=(".gitignore: added $pat"); }
done

# .gitattributes: shell scripts and Makefiles must stay LF, or CRLF checkouts on Windows break them.
ga="$dest/.gitattributes"; touch "$ga"
for pat in '*.sh text eol=lf' 'Makefile text eol=lf'; do
  grep -qxF "$pat" "$ga" || { [ -s "$ga" ] && [ -n "$(tail -c 1 "$ga")" ] && echo >>"$ga"; echo "$pat" >>"$ga"; notes+=(".gitattributes: added '$pat' (Windows CRLF); files already checked out with CRLF need \`git add --renormalize .\`"); }
done

# make check → scripts/check.sh
mk="$dest/Makefile"
if [ ! -f "$mk" ]; then
  printf '.PHONY: check\n\n## check: full verification (layers 1-2); green = done\ncheck:\n\t@bash scripts/check.sh\n' >"$mk"
  notes+=("Makefile created with a check target")
elif ! grep -qE '^check:' "$mk"; then
  printf '\n## check: full verification (layers 1-2); green = done\ncheck:\n\t@bash scripts/check.sh\n' >>"$mk"
  notes+=("Makefile: check target added — add it to .PHONY")
elif [ "$mode" = install ]; then
  notes+=("Makefile already has a check target — make it run scripts/check.sh or merge its steps into it")
fi

# Other agents' instruction files to merge into AGENTS.md.
others=()
for f in .cursorrules .cursor/rules .github/copilot-instructions.md .windsurfrules RULES.md .agent .codex/instructions.md; do  # .codex/ and GEMINI.md are ours now
  [ -e "$dest/$f" ] && others+=("$f")
done

if [ "$mode" = update ]; then
  fence='`````'   # longer than any code fence inside the template's markdown files
  tdiff() { git -C "$tpl" diff -M --relative=files "$from" "$to" -- "${@/#/files/}"; }
  list() { local f n=0; for f in "$@"; do [ -z "$f" ] || { echo "- \`$f\`"; n=1; }; done; [ $n = 1 ] || echo "- none"; }
  {
    echo "# Harness update report"
    echo
    echo "Template: \`$tpl\` · profile: **$profile** · $(date +%F)"
    echo "From $(short "$from") to $(short "$to")."
    echo "Next: run the update prompt (\`$tpl/UPDATE_PROMPT.md\`) in this project. When everything below is merged,"
    echo "delete this file and run \`$tpl/install.sh --done $dest\` — it records the new version in \`.harness-version\`."
    echo
    echo "## Template commits"
    git -C "$tpl" log --reverse --format='- %h %s' "$from..$to" -- files/
    echo
    echo "## Copied — new in the template (fill their template markers)"; list "${copied[@]:-}"
    echo
    echo "## Updated in place — the project had not changed them"; list "${updated[@]:-}"
    echo
    echo "## Merge — apply the template's change to the project's version"
    echo "The \`-\` lines are the template's old text; the project may have filled or reworded it."
    [ ${#merge[@]} -gt 0 ] || echo "- none"
    for f in "${merge[@]:-}"; do
      [ -n "$f" ] || continue
      echo; echo "### \`$f\`"; echo; echo "${fence}diff"; tdiff "$f"; echo "$fence"
    done
    echo
    echo "## New in the template, but the project has its own file of that name — merge by hand (template version: \`$tpl/files/<path>\`)"
    list "${kept[@]:-}"
    echo
    echo "## Removed from the template — remove from the project, with every reference to it"; list "${removed[@]:-}"
    echo
    echo "## Renamed in the template — move the project's file, then apply the diff"
    [ ${#renamed[@]} -gt 0 ] || echo "- none"
    for r in "${renamed[@]:-}"; do
      [ -n "$r" ] || continue
      a=${r%%$'\t'*}; b=${r#*$'\t'}
      echo; echo "### \`$a\` → \`$b\`"; echo; echo "${fence}diff"; tdiff "$a" "$b"; echo "$fence"
    done
    echo
    echo "## Skipped — changed in the template, deleted in this project (bring back only if the owner wants it)"
    list "${skipped[@]:-}"
    echo
    echo "## Notes"; for n in "${notes[@]:-}"; do [ -n "$n" ] && echo "- $n"; done
  } >"$dest/HARNESS_UPDATE.md"
  echo "Updated $dest from $(short "$from") to $(short "$to"):"
  echo "  copied: ${#copied[@]}, updated in place: ${#updated[@]}, to merge: ${#merge[@]}, removed: ${#removed[@]}, renamed: ${#renamed[@]}, own file of a new name: ${#kept[@]}"
  echo "  report: $dest/HARNESS_UPDATE.md"
  echo "Next: open the project in your agent and run the prompt from $tpl/UPDATE_PROMPT.md"
  exit 0
fi

{
  echo "# Harness install report"
  echo
  echo "Template: \`$tpl\` · profile: **$profile** · $(date +%F)"
  echo "Next: run the fill prompt (\`$tpl/FILL_PROMPT.md\`) in this project. Delete this file when done."
  echo
  echo "## Copied"; for f in "${copied[@]:-}"; do [ -n "$f" ] && echo "- \`$f\`"; done
  echo
  echo "## Already existed — merge by hand (template version: \`$tpl/files/<path>\`)"
  for f in "${kept[@]:-}"; do [ -n "$f" ] && echo "- \`$f\`"; done
  echo
  echo "## Other agent files — merge their rules into AGENTS.md, then keep them as thin pointers or delete (ask the owner)"
  for f in "${others[@]:-}"; do [ -n "$f" ] && echo "- \`$f\`"; done
  echo
  echo "## Notes"; for n in "${notes[@]:-}"; do [ -n "$n" ] && echo "- $n"; done
} >"$dest/HARNESS_INSTALL.md.new"
# A re-run that copies nothing keeps the first report.
if [ ${#copied[@]} -eq 0 ] && [ -f "$dest/HARNESS_INSTALL.md" ]; then rm -f "$dest/HARNESS_INSTALL.md.new"
else mv "$dest/HARNESS_INSTALL.md.new" "$dest/HARNESS_INSTALL.md"; fi

echo "Installed ($profile) into $dest:"
echo "  copied: ${#copied[@]}, already existed: ${#kept[@]}, other agent files: ${#others[@]}"
echo "  report: $dest/HARNESS_INSTALL.md"
echo "Next: open the project in your agent and run the prompt from $tpl/FILL_PROMPT.md"
