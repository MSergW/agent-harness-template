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
- Skills (`.claude/skills/` → symlinks to `.agents/skills/`): `verify`, `handoff`, `depth` (four
  questions before a big task), `git-commit` and `harness-refresh` (the last two only on explicit
  request){{FILL: , project skills}}.
- Agents (`.claude/agents/`, none of them edits files or pushes; only `committer` commits): `checker` (haiku; runs
  `make check`, returns GREEN or the failure verbatim — prefer it over running the check in the main
  conversation), `log-reader` (haiku; root cause from long output), `docs-sync` (sonnet; stale docs
  after a change), `reviewer` (sonnet; the review of one change by `REVIEW.md` — give it the task in
  a few sentences and the paths of the change, never the whole tree: the owner's own uncommitted work
  may be there; on the second round add the first round's findings and what was done. The main
  conversation counts the rounds and stops after two), `committer` (haiku; atomic commits by the
  `git-commit` skill, only when asked){{FILL: , `ui-verifier` (sonnet; a scenario in the `<name>`
  preview) — or delete}}.
{{FILL: - Local preview: `.claude/launch.json` → `<name>` (port, throwaway database, test account) — or delete this line}}
- Commits and PRs carry no `Co-Authored-By` trailer and no «Generated with Claude Code» line: this
  overrides the attribution reminder of the harness (see «Commits» in `AGENTS.md`).
- Token efficiency & delegation:
  - Never read long logs or test outputs in the main conversation — delegate to `log-reader`.
  - Before finishing a reply, verify through `checker` instead of running `make check` in the main
    conversation.
  - Delegate documentation checks to `docs-sync`.
  - Delegate commits to `committer`, in the background, and go on with read-only work (reading code,
    `rg`, `git log`/`git show`, planning). Until it reports, change nothing in the working tree or the
    index — the commit is built from what is on disk; when the next step needs an edit, wait for the
    report and check the hash and `git status` it gives. The same holds for a background `checker`:
    an edit during the check makes its result say nothing about the tree.
