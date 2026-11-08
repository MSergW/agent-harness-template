# TASK: Merge a harness template update into this project

`install.sh --update` has compared the template at this project's recorded version (`.harness-version`)
with the template now, and written `HARNESS_UPDATE.md`. It lists only what the template changed, each
changed file with the template's own diff. Your job is to bring those changes into this project's
harness while keeping its filling. You are NOT doing product work: do not change application code.

Before the first edit write `*` into `.tmp/scope`: the update may touch any harness file.

## 1. Read

Read `HARNESS_UPDATE.md` whole. «Template commits» says why each change was made. Keep this rule in
mind: the template's diff shows the template's intent, and the project's file holds the project's facts.

## 2. Merge, section by section

- **Copied** — new files, already in place. Fill their `{{FILL: …}}` markers the way `FILL_PROMPT.md`
  section 4 describes for that kind of file, or delete a file that does not apply (the same rules as
  the fill: no UI → no UI files). A new hook script runs only once it is wired in: its wiring comes in the
  diffs of `.claude/settings.json`, `.codex/hooks.json` and `.agents/hooks.json` under «Merge».
- **Updated in place** — the project had never changed these files, so the template's version was copied.
  Nothing to do; mention them in the report.
- **Merge** — for each file, apply the diff to the project's version. The `-` lines are the
  template's old text, which the project may have filled, reworded or translated: find the place by
  meaning, not by exact text. Keep everything the project put in (filled markers, its own rules, checks,
  allow lists, translated messages). A hunk that changes a `{{FILL: …}}` marker the project has filled:
  keep the filling and take only what the hunk adds around it. A hunk that does not fit (the project
  removed that part on purpose — the small profile, no UI, a section it deleted) is skipped, with the
  reason in the report. Never replace a whole file with the template's version.
- **New in the template, but the project has its own file of that name** — the project's file is not
  the template's: merge the template's version (path given) into it, or ask the owner.
- **Removed** — delete the file, then remove every reference to it: `rg -n '<file name>'` over the
  harness (`.claude/settings.json`, `.codex/hooks.json`, `.agents/hooks.json`, `AGENTS.md`, `CLAUDE.md`,
  `.agents/skills/`, `scripts/check.sh`). A removed skill: its `.claude/skills/<name>` link too. If
  the project changed the file for its own needs, ask the owner before deleting.
- **Renamed** — move the project's file to the new path (keeping its content), apply the diff, and
  update every reference to the old path. A renamed skill: re-create its `.claude/skills/` link.
- **Skipped** — the project had deleted these. Leave them out unless the owner asks for them.
- **Notes** — act on each.

## 3. Finish

1. Run each changed hook once with sample input, as in `FILL_PROMPT.md` «Acceptance» item 3.
2. Delete `HARNESS_UPDATE.md`, then run the `install.sh --done` command named at the top of it: it
   records the new template commit in `.harness-version` and refuses while the report file still exists.
3. `make check` must be green: its «unfinished update» step stays red until step 2 is done. Fix what
   the update broke; never weaken a check.
4. Report to the owner in their language: from which template commit to which; per file — merged,
   updated in place, removed, renamed, copied and filled; every hunk skipped and why; what was not
   verified; open questions.
5. Commit only when the owner asks, as one commit (`chore(agents): …` in the project language),
   `.harness-version` included.
