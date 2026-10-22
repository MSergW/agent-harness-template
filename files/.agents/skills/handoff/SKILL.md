---
name: handoff
description: End-of-session / checkpoint routine — record state in PROGRESS.md, the active plan, tech debt and decisions so the next session (any agent) can resume. Use when a piece of work is finished, before a commit, when context is running low, or when the user says to wrap up.
---

# Handoff

Goal: the next session starts from `PROGRESS.md`, not from reconstructing the chat.
The files below are human-facing — write them in the project language (see `AGENTS.md`).

1. Run `make check`; record the result honestly (green / what exactly is red).
2. `PROGRESS.md`:
   - current state — date, commit (`git rev-parse --short HEAD`), check result, uncommitted
     changes if any, finished work with links and how it was verified;
   - in progress — the active task and where you stopped (file, step);
   - next — 1–3 concrete actions, plus anything not verified at layer 3;
   - open questions — what waits for the owner's decision.
   Keep it short: replace stale content, do not append a log.
3. Active plan in `docs/plans/` — tick steps with evidence (command, commit, where verified).
   Move a finished plan to `docs/plans/done/`.
4. New owner decisions not visible from code → `docs/decisions.md` with the reason.
5. Deferred work or findings outside the task → a row in `docs/plans/tech-debt.md`.
6. Offer a commit (skill `git-commit`), but do not commit unless asked.

Reply to the owner in 3–5 lines in their language: what was done, check status, what is next.
