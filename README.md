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
   For a small project (one binary, under ~5k lines, no web UI) add `--small`.
3. Open the project in your agent and give it the whole of [FILL_PROMPT.md](FILL_PROMPT.md). It
   replaces every `{{FILL: …}}` marker with real content from your code, merges rules from older
   agent files, makes `make check` green and reports back.
4. Read the report, then ask the agent to commit.

While a single `{{FILL` marker is left, `make check` is red, so a half-filled harness cannot slip
through.

## How a task goes with the harness

1. **Session start** — the hook shows the branch, recent commits, uncommitted changes and the state
   from `PROGRESS.md`.
2. **Work** — the agent follows `AGENTS.md`: one task at a time, the smallest solution that meets the
   task, nothing outside the task changed (that goes to `docs/plans/tech-debt.md`).
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
| `REVIEW.md` | the diff review: what to look for (rules `make check` cannot see, correctness of the changed lines), what to ignore, at most two rounds |
| `PROGRESS.md` | the current state for the next session |
| `docs/decisions.md` | decisions not visible from the code, with their reasons |
| `docs/plans/` | multi-session plans, tech debt, ideas |
| `scripts/check.sh` | the single check behind `make check`: harness self-checks, Go/Node/Python by marker files, the project's own checks |
| `.agents/skills/` | skills: `verify`, `handoff`, `git-commit`, `harness-refresh` |
| `.claude/` | hooks (session state, formatter after an edit, checks before finishing, `rg` instead of `grep`) and subagents (`checker`, `log-reader`, `docs-sync`, `reviewer`, an example UI verifier) |
| `.codex/hooks.json` | the same hooks for Codex (without the formatter: `apply_patch` has no `file_path`). Codex runs project hooks only after you trust them: `/hooks` in the CLI |

A small project gets only `AGENTS.md`, `CLAUDE.md`, `scripts/check.sh`, the hooks and tech debt; the
rest is added later under the same names when the project grows.

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

## Keeping it alive

- Once a month or after a big feature, ask the agent to run `harness-refresh`.
- A mistake that happened twice becomes a check in `scripts/check.sh`, not another paragraph.
- An improvement found in one project goes back into this template's `files/`, so the next project
  gets it from the start.

## License

[MIT](LICENSE)
