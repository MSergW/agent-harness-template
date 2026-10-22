@AGENTS.md

## Claude Code extras

- Hooks (`.claude/settings.json`, scripts in `.claude/hooks/`):
  - session start — branch, recent commits, uncommitted changes and the state from `PROGRESS.md`;
  - before a Bash command — `grep`/`egrep`/`fgrep` are denied with an `rg` cheat sheet;
  - after editing a file — the formatter for its language (a syntax error is reported at once);
  - before finishing a reply — quick checks of the changed files only. Red means the work is not done.
  - Codex runs the same scripts through `.codex/hooks.json` (session start, `rg` instead of `grep`,
    the check before finishing) — except the formatter: Codex edits through `apply_patch`, whose
    input has no `file_path`, so formatting there is left to the check before finishing.
- Skills (`.claude/skills/` → symlinks to `.agents/skills/`): `verify`, `handoff`, `git-commit`
  and `harness-refresh` (the last two only on explicit request){{FILL: , project skills}}.
- Agents (`.claude/agents/`, none of them edits, commits or pushes): `checker` (haiku; runs
  `make check`, returns GREEN or the failure verbatim — prefer it over running the check in the main
  conversation), `log-reader` (haiku; root cause from long output), `docs-sync` (sonnet; stale docs
  after a change), `reviewer` (sonnet; the review of one change by `REVIEW.md` — give it the task in
  a few sentences and the paths of the change, never the whole tree: the owner's own uncommitted work
  may be there; on the second round add the first round's findings and what was done. The main
  conversation counts the rounds and stops after two){{FILL: , `ui-verifier` (sonnet; a scenario in
  the `<name>` preview) — or delete}}.
{{FILL: - Local preview: `.claude/launch.json` → `<name>` (port, throwaway database, test account) — or delete this line}}
