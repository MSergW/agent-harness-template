#!/usr/bin/env bash
# Copies the harness template into a project, then the fill prompt (FILL_PROMPT.md) makes it real.
#   install.sh <project-dir> [--small]
# Never overwrites a file: existing ones are listed in HARNESS_INSTALL.md for the agent to merge.
# Never commits. Safe to re-run.
set -euo pipefail

tpl="$(cd "$(dirname "$0")" && pwd)"
dest="${1:-}"; profile="${2:-full}"
[ -n "$dest" ] && [ -d "$dest" ] || { echo "usage: $0 <project-dir> [--small]"; exit 1; }
dest="$(cd "$dest" && pwd)"
git -C "$dest" rev-parse --git-dir >/dev/null 2>&1 || { echo "$dest is not a git repository"; exit 1; }
[ "$profile" = --small ] && profile=small

# Files the small profile does not get (they are added later, with these names, when it grows).
small_skip='^(PROGRESS\.md|REVIEW\.md|GLOSSARY\.md|docs/decisions\.md|docs/plans/(README|ideas)\.md|docs/plans/done/|\.agents/|\.claude/agents/|\.claude/launch\.json\.example)'

copied=(); kept=(); notes=()

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
while IFS= read -r f; do
  f="${f#./}"
  [ "$profile" = small ] && [[ "$f" =~ $small_skip ]] && continue
  if [ -e "$dest/$f" ]; then cmp -s "$f" "$dest/$f" || kept+=("$f"); continue; fi
  mkdir -p "$dest/$(dirname "$f")"
  cp -p "$f" "$dest/$f"
  copied+=("$f")
done < <(find . -type f ! -name .DS_Store | sort)

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
for pat in '.claude/settings.local.json' '.claude/.stop-check' '.tmp/'; do
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
else
  notes+=("Makefile already has a check target — make it run scripts/check.sh or merge its steps into it")
fi

# Other agents' instruction files to merge into AGENTS.md.
others=()
for f in GEMINI.md .cursorrules .cursor/rules .github/copilot-instructions.md .windsurfrules RULES.md .agent .codex/instructions.md; do  # .codex/ itself is ours now (hooks.json)
  [ -e "$dest/$f" ] && others+=("$f")
done

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
