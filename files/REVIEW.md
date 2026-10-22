# {{FILL: project name}} — diff review

Instructions for the reviewer of one change (Claude Code: the `reviewer` agent; another tool: a
fresh session given the same inputs). The writer of the change does not review it in its own
context: it has seen why every line is right.

## Inputs

- the task in a few sentences — what the owner asked for, what was decided;
- the paths of the change. The working tree may also hold the owner's own uncommitted work: review
  only the paths you were given (`git diff HEAD -- <paths>`, plus the untracked new files among them);
- on the second round, the findings of the first and what was done about them.

## Scope

Only the lines the diff adds or changes, and what they break around them (a caller whose
contract changed, a test that no longer asserts what it names). Read the surrounding code to
understand the change, not to audit it.

A defect in code the diff does not touch is not a finding: list it under «Pre-existing», one line
each, at most five — the writer moves them to `docs/plans/tech-debt.md`, never fixes them in this
change.

## What to look for

The project's hard rules (`AGENTS.md`) that `make check` cannot see:
- {{FILL: each hard rule `make check` does not enforce, as what it looks like in a diff — e.g. «a
  permission checked only when the page opened, not right before the action», «form data reaching a
  shell command or a generated config without validation at that boundary», «a contract another
  system reads changed without the same change on its side». A rule `make check` enforces is not
  repeated here.}}
- secrets: in logs, error messages, API responses, command output;
- a test weakened, deleted or asserting less than its name says; a changed UI text without its test.

Correctness in the changed code:
- writes that must be one transaction but are several; read-then-write races; a migration that
  fails on existing data;
- goroutines, threads, timers, connections, files and response bodies without a way to stop or
  close; cancellation not passed down; calls to other systems without a time limit;
- errors swallowed or only logged where the caller needs them; a partial failure reported as success;
- {{FILL: the traps of this stack and domain — its database, its concurrency, its external calls —
  or delete this line}};
- the change does less or more than the task: a missed case the task names, unrelated refactoring.

## What to ignore

- formatting, import order, naming taste, comment wording — {{FILL: the project's formatters and
  linters}} and the other checks in `make check` own these;
- a different but equivalent way to write the same thing;
- hypothetical problems with no concrete input that triggers them.

## Findings

- Each finding names the rule or the failure: the input or state, and the wrong result.
  No scenario — no finding.
- One finding per class: the same mistake in five places is one finding listing the five places.
- Severity: **block** (wrong behaviour, a hard rule broken, data or security at risk) or **note**
  (worth fixing, safe to ship). Only block findings send the change back.

## Rounds

At most two. The second round checks only the fixes and anything they touched; it does not look
for new classes in code the first round already passed. What is still open after the second round
goes to the owner with the change — the writer does not start a third.
