---
name: git-commit
description: Use only when the user explicitly asks to create one or more Git commits in this repository. Handles task-owned staging, atomic grouping, validation, and the project's Conventional Commit style. Do not trigger for implementation, status, review, or a request to merely suggest a commit message; never push unless explicitly requested.
disable-model-invocation: true
---

# Create project commits

## 1. Decide what is yours

Run `git status` and `git log --oneline -5` right before staging, not from memory: the owner may
work and commit in parallel. Pre-existing modifications and untracked files are the owner's unless
this task clearly created them. If a file you changed was already committed by the owner, say so
instead of re-committing it. Never `git add .` / `-A`; stage explicit paths.

If one file mixes your edits with the owner's, stop and explain the overlap — do not commit it whole.

## 2. Validate

`make check` must be green for what you commit (in Claude Code prefer the `checker` subagent).
Red → do not commit; report. Same-commit rules from `AGENTS.md`: a changed UI string goes with the
test that asserts it, a behaviour or label change with its docs page, a changed module contract with
its map.

## 3. Group

One logical change per commit, in an order where each commit builds. Code + its tests + its docs
together; `PROGRESS.md`/plan bookkeeping separately; formatting-only changes separately (`style`).

## 4. Message

```text
type(scope): {{FILL: subject language}} subject, lowercase, no trailing period
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`{{FILL: , others this repo uses}}.

Scope — the area the change belongs to:

| Change in | Scope |
|---|---|
| {{FILL: one row per component, derived from the directory layout and `git log` history}} | |
| `docs/*.md`, `README.md` | `docs` |
| `PROGRESS.md`, `docs/plans/` | `docs(plans)` |
| `AGENTS.md`, `CLAUDE.md`, skills text | `docs(agents)` |
| `.claude/` hooks and subagents, `scripts/check.sh` | `chore(agents)` |

Examples from this repo's history: {{FILL: 2–3 real subjects}}.

- Subject: imperative, in the project language{{FILL: , naming rules (e.g. product names) — or delete}}.
- Body only when the why is not obvious: the reason, compatibility, how it was verified.
- End with the attribution trailer your tool is configured to add, if any.

## 5. Commit and report

Review `git diff --cached`, commit, then `git status` again. Report the hashes and subjects. Do not
amend, rebase, force, push or clean files unless the user asked for exactly that. A commit request
is not a push request; if push is asked, push the current branch normally and report the result.
