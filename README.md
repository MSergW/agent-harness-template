# Agent harness template

**English** · [Українська](README.uk.md)

A ready-made set of instructions, state files and checks that makes AI coding agents — Claude Code,
Codex, Antigravity, GitHub Copilot — work on your project the way a careful teammate would. You copy
it into a repository once, then an agent fills it in from your own code.

It grew out of daily work on a real production project: every rule here is there because its absence
once cost time.

## Why

Without a harness, every session starts from zero. The agent does not know the project's rules,
re-discovers the same commands, says «done» after a change it never ran, quietly weakens a failing
test, forgets what was decided yesterday and reviews its own code with the same blind spots it wrote
it with.

The harness answers each of these with a file or a mechanical check, not with a longer prompt:

| Problem | What the harness does |
|---|---|
| The agent does not know the rules | `AGENTS.md`: hard rules with the reason for each, a map of the code, the commands |
| «Done» without evidence | one command, `make check`, and a hook that runs quick checks on changed files before the agent may finish |
| Context is lost between sessions | `PROGRESS.md` (where things stand) and `docs/decisions.md` (why), updated by the `handoff` skill and shown by the session-start hook |
| Long sessions cost more with each turn | «Context economy» in `AGENTS.md`: a large step in its own session, one full check and review per step, short outputs |
| The agent wanders off into unrelated fixes | the scope fence: before its first edit the agent lists the task's files in `.tmp/scope`; a hook refuses an edit of any other file and the stop hook lists changed files outside the list. It talks only to the agent, never asks you |
| The writer reviews its own work | `REVIEW.md` and the `reviewer` subagent: a diff review in a fresh context, at most two rounds |
| Instructions drift from the code | `make check` fails on unfilled markers or broken skill links; the `harness-refresh` skill re-syncs everything on request |
| Each tool wants its own files | one `AGENTS.md` and one `.agents/skills/` read by every tool; Claude Code and Codex share the same hook scripts |

## Quick start

Requirements: `git`, `bash`, [`jq`](https://jqlang.org) (used by hooks), [`ripgrep`](https://github.com/BurntSushi/ripgrep), `make` (optional).

1. Get the template once:
   ```bash
   git clone https://github.com/MSergW/agent-harness-template ~/agent-harness-template
   ```
2. Copy it into your project. Nothing is overwritten and nothing is committed; existing files are
   listed in `HARNESS_INSTALL.md` to merge:
   ```bash
   ~/agent-harness-template/install.sh /path/to/your/project
   ```
   For a small project (one binary, under ~5k lines, no web UI) add `--small`. The template commit
   is recorded in the project's `.harness-version` (commit it with the harness): updates start from it.
3. Open the project in your agent and give it the whole of [FILL_PROMPT.md](FILL_PROMPT.md). It
   replaces every `{{FILL: …}}` marker with real content from your code, merges rules from older
   agent files, makes `make check` green and reports back. It also reads your past Claude Code and
   Codex sessions on this project: your corrections and the agent's repeated mistakes become rules
   and checks, decisions made in a chat go to `docs/decisions.md` (secrets from transcripts are never
   copied). What got in your way — the same permission asked again, answers you complained about, slow
   loops — and anything seen only once comes as a numbered «Proposed — your choice» list in the report:
   nothing from it changes until you pick it.
4. Read the report, then ask the agent to commit.

While a single `{{FILL` marker is left, `make check` is red, so a half-filled harness cannot slip
through.

## How a task goes with the harness

1. **Session start** — the hook shows the branch, recent commits, uncommitted changes and the state
   from `PROGRESS.md`.
2. **Work** — the agent follows `AGENTS.md`: one task at a time, the smallest solution that meets the
   task, nothing outside the task changed (that goes to `docs/plans/tech-debt.md`). It first writes the
   files it will change into `.tmp/scope`; the scope fence holds it to them (a new session or a commit
   starts a new scope; your own uncommitted work from before is not counted).
3. **Layers 1–2** — `make check`: formatting, vet and lint, then tests. It stops at the first red
   layer and says what to do.
4. **Review** — the `reviewer` subagent reads only the diff, in a fresh context, against `REVIEW.md`.
   Block findings are fixed and reviewed once more.
5. **Layer 3** — what tests cannot reach (a UI in a local preview, a test server), and an explicit
   list of what was not verified.
6. **Handoff** — `PROGRESS.md`, plans and decisions are updated so the next session starts from them.

## What's inside

| File | Purpose |
|---|---|
| `AGENTS.md` | the main instructions for every agent: hard rules, definition of done, map, commands |
| `CLAUDE.md` | `@AGENTS.md` plus what exists only in Claude Code (hooks, skills, subagents) |
| `GEMINI.md` | imports `AGENTS.md` and adds for Gemini (Antigravity): declare the scope, look for parallel work in other worktrees and branches, search wider than the task's examples, «not verified» instead of unchecked claims, no polling, the diff review in its own subagent, a four-part report |
| `REVIEW.md` | the diff review: what to look for (rules `make check` cannot see, more code than the task needs, the owner's principles, correctness of the changed lines), settling a doubt by running it in a temp copy, what to ignore, at most two rounds |
| `PROGRESS.md` | the current state for the next session (five latest entries, under 40 KB); older entries — `docs/progress/` by week |
| `docs/decisions.md` | decisions not visible from the code, with their reasons |
| `.harness-version` | the template commit the project was installed or last updated from (written by `install.sh`) |
| `docs/plans/` | multi-session plans (attacked by `plan-critic` before step 1), tech debt, ideas, what the review missed (`review-misses.md`) |
| `scripts/check.sh` | the single check behind `make check`: harness self-checks, a secret scan, Go/Node/Python by marker files, the project's own checks; a 25-minute bound when not run in a terminal; `CHECK_CACHED=1` skips a tree that already passed |
| `.agents/skills/` | skills: `verify`, `handoff`, `depth` (four questions before a big task, open decisions in rounds), `diagnose` (a bug of unknown cause: a command that goes red first, then hypotheses), `worktree` (a plan in its own git worktree, a small fix straight on the main branch), `audit` (code, security and UI audits; the finder never confirms its own finding) and `audit-fix` (triage of an audit), `git-commit`, `harness-refresh`, `session-title` (a title from what the session became; renames it where the tool allows) |
| `GLOSSARY.md` | the project's domain terms, one word per concept and the words to avoid; the reviewer flags the avoided ones |
| `.claude/` | hooks (session state, the scope fence before an edit, formatter after an edit, checks before finishing, `rg` instead of `grep`, read-only subagents kept read-only, a time limit on background commands, no wait loops on `pgrep -f`), a deny on force push, and subagents (`checker`, `log-reader`, `docs-sync`, `reviewer`, `plan-critic`, `committer`, `code-auditor`, `security-auditor`; examples for a web UI: a UI verifier, `ui-sweeper`, `ui-auditor`) |
| `.codex/hooks.json` | the same hooks for Codex (without the formatter: `apply_patch` has no `file_path`; without the subagent and background guards, which are Claude Code's). Codex runs project hooks only after you trust them: `/hooks` in the CLI |
| `.agents/hooks.json` | the same hooks for Antigravity, through the adapter `.claude/hooks/antigravity.sh` (no subagent or background guards) |

A small project gets only `AGENTS.md`, `CLAUDE.md`, `scripts/check.sh`, the hooks and tech debt; the
rest is added later under the same names when the project grows.

**Scope fence limits.** The hook before an edit sees only the file-edit tools (Claude Code
`Edit`/`Write`/`MultiEdit`/`NotebookEdit`, Codex `apply_patch`, Antigravity `write_to_file`/`replace_file_content`/
`multi_replace_file_content`); a file changed by a shell command (`sed -i`, a generator) is caught only by the
stop hook, after the fact, and only once per reply (it never blocks twice in a row). A file you change in your
editor during the agent's session counts as the agent's. The template's test: `bash tests/scope-fence.sh`.

**Guard limits.** The read-only guard (`readonly-agents.py`, Claude Code only, needs `python3`) catches mistakes,
not an agent set on getting around it: a command it cannot classify is refused, and an interpreter run by the
reviewer or an auditor (a probe in a temp copy) can still write anywhere. Its cases: `bash tests/readonly-agents.sh`;
the wait guards: `bash tests/wait-guards.sh`.

Agent-only files are in English; human-facing files (`PROGRESS.md`, plans, decisions, commit
messages) are written in your project's language when the template is filled.

## Windows

Everything runs in Git Bash (installed with Git for Windows); there are no separate `.bat`/`.ps1`
files. Once per machine:

```powershell
winget install jqlang.jq BurntSushi.ripgrep.MSVC   # hooks need jq; without it they silently switch off
git config --global core.symlinks true              # needs Developer Mode (Settings → For developers)
```

- Run `install.sh` from Git Bash: `bash ~/agent-harness-template/install.sh /c/path/to/project`.
- Without `make`, run `bash scripts/check.sh` — it is the same check.
- The installer adds `*.sh text eol=lf` to the project's `.gitattributes`, otherwise scripts break
  under `autocrlf=true` (`bash\r: not found`). If they are already checked out with CRLF:
  `git add --renormalize .`.
- Without symlink support the installer does not create `.claude/skills/*` and says so in
  `HARNESS_INSTALL.md`; `check.sh` skips the symlink check on such a clone.
- Antigravity runs hook commands with `cmd /c` on Windows, where `bash` is usually not on `PATH`
  (or is WSL's). So `.agents/hooks.json` starts them as a git shell alias:
  `git -c alias.harness-hook="!bash …" harness-hook <event>` — git is on `PATH` in `cmd` and `sh`
  alike, runs the alias in its own Git Bash and from the repository root.

## Updating

When the template improves, take its changes into a project that already has the harness:

```bash
git -C ~/agent-harness-template pull
```

```bash
~/agent-harness-template/install.sh --update /path/to/your/project
```

Then give the agent the whole of [UPDATE_PROMPT.md](UPDATE_PROMPT.md).

The update compares the template at the project's recorded commit with the template now, and touches
only what changed between them:

- new template files are copied;
- a file the project never changed is replaced by the new version;
- a file the project filled is not touched: `HARNESS_UPDATE.md` lists it with the template's own diff, and
  the agent applies that change to the project's version (hook wiring in `settings.json`/`hooks.json`
  included);
- files removed or renamed in the template are listed for the agent to remove or move, with their references;
- files the project deleted on purpose are not brought back;
- files the template did not change are not listed at all.

When the merge is done, the agent deletes `HARNESS_UPDATE.md` and runs `install.sh --done <project>`, which
moves `.harness-version` to the new commit. Until then `make check` is red.

A project installed before `.harness-version` existed has no record. `--update` then refuses and
guesses the starting commit: the last template commit before the harness was first committed in the
project. Confirm it with the owner, then run `install.sh --update <project> --from <commit>`.

## Keeping it alive

- Once a month or after a big feature, ask the agent to run `harness-refresh`.
- A mistake that happened twice becomes a check in `scripts/check.sh`, not another paragraph.
- An improvement found in one project goes back into this template's `files/`, so the next project
  gets it from the start.

## Credits

The harness is put together from other people's ideas and the author's own practice; the borrowed parts:

- [Matt Pocock's skills](https://github.com/mattpocock/skills) (MIT) — `diagnose` follows his
  `diagnosing-bugs`, the decisions in rounds of `depth` his `grilling`, the format of `GLOSSARY.md` his
  `domain-modeling`, the categories `harness-refresh` and the fill prompt walk past sessions by his `retro`.
- Felix Rieseberg, «How to be more ambitious: a tutorial for humans with models»
  ([felixrieseberg.com](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/)) — the four questions of `depth`.
- [Robert Martin's ub-mode](https://github.com/unclebob/ub-mode) — the review finding for a test that would
  pass on an empty result, and «Attack the Premise» in `diagnose`.
- [AGENTS.md](https://agents.md) and the `SKILL.md` format of agent skills — one set of instructions and
  skills that Claude Code, Codex, Copilot and other agents read.

The rest — the hard rules with their reasons, `make check` and the stop hook, the diff review in a fresh
context, the handoff — grew out of daily work on a production project.

## License

[MIT](LICENSE)
