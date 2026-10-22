---
name: harness-refresh
description: Bring the agent harness (AGENTS.md, module maps, skills, hooks, check.sh, PROGRESS.md, plans) back in sync with the code. Run only on explicit request, e.g. monthly or after a large feature.
disable-model-invocation: true
---

# Harness refresh

Goal: everything an agent reads first matches the current code. Code, schemas and tests win over
every harness file. Do not change application code or behaviour; edit harness files in place,
never regenerate them. Human-facing files stay in the project language; agent-only files English.

## 1. Baseline and window

- `make check`; record the result. Red → report it and ask before continuing.
- Window: commits since the last refresh (`git log -1 --grep='harness'` or the repo's refresh
  subject), else since the last commit that touched `AGENTS.md`. Read `git log --stat <base>..HEAD`.

## 2. Commands and paths

- Re-run the safe commands listed in `AGENTS.md` «Commands» (never deploy, push, reset data or wipe
  build output). A command that fails is reported as failing.
- Every path in `AGENTS.md`, `CLAUDE.md`, module maps, skills and subagents exists:

  ```bash
  bash -c 'rg -o --no-filename "\`[A-Za-z0-9_./*-]+/[A-Za-z0-9_.*/-]*\`" AGENTS.md CLAUDE.md $(git ls-files "*/AGENTS.md") .agents/skills .claude/agents | tr -d "\`" | sort -u | while read -r p; do compgen -G "$p" >/dev/null || compgen -G "${p%/}" >/dev/null || echo "$p"; done'
  ```

  Some hits are fine (paths relative to their section, imports, refs); fix the rest. The «Map»
  table matches the tree. No absolute (`file:///`, `/Users/…`) links anywhere.

## 3. Module maps

- Compare each `*/AGENTS.md` map with its module's diff in the window and current code; fix drifted
  responsibility, contracts, constraints, pitfalls. ≤ 50 lines, no file or function lists.
- Add a map for a module that gained non-obvious boundaries; delete maps of removed modules; keep the
  index under «Map» in sync.

## 4. Rules from experience

- Sources in the window: new `docs/decisions.md` entries, tech debt, audits, review findings in
  commit bodies, the agent's feedback memory, and the agent sessions of the window (Claude Code:
  `~/.claude/projects/<project path, non-alphanumerics → «-»>/*.jsonl`; Codex:
  `~/.codex/sessions/**/*.jsonl` with a `cwd` inside the project) — the owner's corrections and
  mistakes that repeated. Read sessions through `jq`/`rg` or subagents, never whole in the main
  context; never copy secrets or personal data from them.
- A mistake or correction that happened twice becomes a mechanical check in `scripts/check.sh` when
  it can be checked; otherwise one line in `AGENTS.md`, a module map or a skill.
- `REVIEW.md` «What to look for» follows the hard rules: a new rule `make check` cannot see gets a
  line there; a line a check now enforces is removed; a class the reviewer found twice becomes a
  check when it can be checked.
- A decision seen only in memory or a chat goes to `docs/decisions.md`, marked as not confirmed by
  the code when that is the case. Never invent decisions.

## 5. State

- `PROGRESS.md`: close open questions the code now answers; the current state matches HEAD.
- `docs/plans/`: plans with every step done and evidenced move to `done/`.
- `docs/plans/tech-debt.md`: close fixed rows naming the commit. A linter baseline
  (`new-from-rev`) whose debt is closed is removed.

## 6. Tool entry points

- `CLAUDE.md` is `@AGENTS.md` plus Claude-only extras; no rule lives only there.
- `.claude/` is tracked by git (only `settings.local.json` ignored): `git check-ignore -v .claude/settings.json`.
- Hooks use the real format (`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`) and point at
  existing scripts; run each script once by hand.
- Subagents have `tools:` / `disallowedTools:` and alias models (`haiku`, `sonnet`); their commands,
  preview names and test accounts still match the project.

## 7. Size, profile and cold start

- Root `AGENTS.md` ≤ ~150 lines; move detail into skills, module maps or `docs/`.
- A small-profile repo that now has multi-session work or grew past ~5k lines / got a UI gets the
  missing parts of the standard layout, with the standard names.
- Cold-start test: from `AGENTS.md` and its links alone, a new agent can tell the current task, how
  to verify it and what «done» means.

## 8. Finish

- `make check` green, also on a fresh clone (`git clone . <tmp>` and run it there).
- Report to the owner in their language: what drifted and how it was fixed, commands that broke,
  rules added or removed, maps added/changed/deleted, questions for the owner.
- Commit only when asked, separately from other work: `chore(agents): <refresh the harness>` in
  the project language.
