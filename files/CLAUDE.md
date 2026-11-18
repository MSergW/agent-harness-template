@AGENTS.md

## Claude Code extras

- Hooks (`.claude/settings.json`, scripts in `.claude/hooks/`): repository state at session start, `rg` instead of
  `grep`, the scope fence before editing a file (`.tmp/scope`), the formatter after editing a file (not in Codex:
  `apply_patch` gives no `file_path`), quick checks of the changed files before finishing a reply. Red means the work is not done. Other agents — «Agent tooling» in `AGENTS.md`.
  Guards: read-only subagents cannot write (`readonly-agents.py`; a new read-only agent goes into its `GUARDED`), a
  background command must start with `timeout ≤1800`, no wait loop on `pgrep -f`. `git-guard.py` (also Codex and
  Antigravity) holds the «Do not touch» rules of `AGENTS.md` in the shell: a secret file and a force push are denied;
  `git stash`, `reset --hard`, discarding the working tree, `git add -A`/`.` and `commit -a` ask the owner (a deny
  where a hook cannot ask). A stop by any of these hooks is a line in `hook-journal.tsv` (`journal.sh`, without the
  command); each rule has stop and pass cases in `.claude/hooks/test_hooks.py` (`make check`): a rule that blocks
  normal work is narrowed with a new «pass» case, never removed. `skill-usage.sh` logs each skill use (a Skill call,
  a typed `/name`) for `harness-refresh` §7.
- Skills and agents are described in their listings. Not listed, only on explicit request: skills `git-commit`,
  `harness-refresh`, `session-title`{{FILL: , project skills that run only on request}}.
- **A new session** (the desktop app's `start_session`) — the `plan-steps` skill first: the brief, its language
  line, the branch name, a plan's steps (on Sonnet, the `reviewer` on Opus).
- `reviewer`: give it the task in a few sentences and the paths of the change, never the whole tree (the
  owner's own uncommitted work may be there); on a later round add the previous round's findings and what
  was done. The main conversation counts the rounds: a third only when the second is still `BLOCK`.
{{FILL: - Local preview: `.claude/launch.json` → `<name>` (port, throwaway database, test account) — or delete this line}}
- Commits and PRs carry no `Co-Authored-By` trailer and no «Generated with Claude Code» line: this
  overrides the attribution reminder of the harness (see «Commits» in `AGENTS.md`).
- Token efficiency & delegation:
  - Never read long logs or test outputs in the main conversation — delegate to `log-reader`.
  - Wide searches, symbol lookups and call sites go to `code-search` (Haiku), not the built-in `Explore`.
  - Before finishing a reply, verify through `checker` instead of running `make check` in the main
    conversation.
  - Delegate documentation checks to `docs-sync`.
  - Delegate commits to `committer`, in the background, and go on with read-only work (reading code,
    `rg`, `git log`/`git show`, planning). Until it reports, change nothing in the working tree or the
    index — the commit is built from what is on disk; when the next step needs an edit, wait for the
    report and check the hash and `git status` it gives. The same holds for a background `checker`:
    an edit during the check makes its result say nothing about the tree. A review back with Block findings
    while that check runs: stop the check (`TaskStop`), fix, run it again — never wait for a result the fixes void.
    Findings that change no code: let it finish.
