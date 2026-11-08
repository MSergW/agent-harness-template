---
name: verify
description: Verification before claiming work is done — make check (static + tests), then layer 3 (local preview, test server) when the change crosses components. Use after implementing a change, before a commit or deploy, or when asked to check or test the project.
---

# Verify

Done means runnable evidence, not confidence.

## Layers 1–2: `make check`

Run `make check` (in Claude Code prefer the `checker` subagent). It stops at the first red layer and
prints «What to do» for each failure. Red → the work is not done: fix the cause, never weaken or
delete a test, never disable a check. A warning about a module map means: update the map if the
module's responsibility, contracts or constraints changed.

{{FILL: anything specific to this project's check — slow steps, tools that must be installed,
known environment caveats (e.g. tests that need network or a sandbox exception).}}

## Review of the diff

Together with `make check` and before layer 3: the review of the diff in a fresh context by
`REVIEW.md` (Claude Code: the `reviewer` subagent; another tool: a new session given the same
inputs) — the task in a few sentences and the paths of the change. Block findings are fixed and go
back through `make check`, then the second round gets the first round's findings and what was done.
At most two rounds; what is still open goes to the owner with the change. «Pre-existing» findings
go to `docs/plans/tech-debt.md`, not into this change.

## Layer 3: system

Needed when a change crosses components or touches something tests cannot reach:
{{FILL: per area — how to verify it here. E.g. «UI: the `<name>` preview from `.claude/launch.json`
(in Claude Code — the `<app>-verifier` subagent); check the console, the interaction and a narrow
viewport». «Playbooks / deploy: only on a test server — ask the owner». «Integration with X: …».}}

UI checks run one after another, never in parallel (one browser pane, one local database), and only the main
conversation hands work on (a subagent cannot start subagents). A verifier on a cheap model fits a step-by-step
scenario on data that has every state it needs; give it a stronger model from the start (Claude Code: `model:` in the agent call) when a state exists only
in the code (a count above zero, a server error, a missing right) or the change crosses rights, server
validation or several pages. Its `NOT CHECKED` steps go to a second run on a stronger model, those steps only.
Confirm its `FAIL` in the main conversation (code, or one look in the browser) before it counts: a cheap model also
reports behaviour the scenario does not describe. A full audit of a section — the `audit` skill.

## Report

Say what was verified and how (command, preview, server), and explicitly what was not verified.
Record the unverified items in `PROGRESS.md` «Next».
