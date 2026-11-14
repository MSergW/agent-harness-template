# {{FILL: project name}} — diff review

Instructions for the reviewer of one change (Claude Code: the `reviewer` agent; Gemini in Antigravity: a
subagent given `.claude/agents/reviewer.md` and this file; another tool: a fresh session given the same inputs). The writer of the change does not review it in its own
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
- a test weakened, deleted or asserting less than its name says; a changed UI text without its test;
- a new or changed test that would still pass if the code under it returned zero values or did
  nothing — it asserts only «no error», a length, that a mock was called, or the value it set up
  itself; the test must fail on a wrong result the code's user would see;
- a word `GLOSSARY.md` lists under «Avoid» in a new name, UI text or doc; a new domain term not added there;
- more code than the task needs: new code that a helper already in this codebase, the standard library or an
  installed dependency does («Solution sizing» in `AGENTS.md`); a wrapper, abstraction, option or «for later» branch
  the task does not ask for — name what to reuse or delete.

{{FILL: the owner's principles — distilled from `docs/decisions.md` and confirmed by the owner, one bullet each:
the principle in bold, then what breaking it looks like in a diff (e.g. «**one fact, one place** — a new field or
cache copies a value another store already holds instead of keeping its key and resolving it at read time»). Lead
them with: «The owner's principles (confirmed <date>). A finding under one still needs its scenario; the principle
is the rule it names.» New ones only through the `harness-refresh` skill, with the owner's yes. Delete this
paragraph if there are none yet.}}

Correctness in the changed code:
- writes that must be one transaction but are several; read-then-write races; a migration that
  fails on existing data;
- goroutines, threads, timers, connections, files and response bodies without a way to stop or
  close; cancellation not passed down; calls to other systems without a time limit;
- errors swallowed or only logged where the caller needs them; a partial failure reported as success;
- {{FILL: the traps of this stack and domain — its database, its concurrency, its external calls —
  or delete this line}};
- the change does less or more than the task: a missed case the task names, unrelated refactoring;
- **input set aside before a destructive step** — an item the change rejects, skips or fails to parse (untrusted,
  invalid, unread) must not count as «absent» where absence disables, deletes or revokes: follow the rejected item
  to the step that acts on the list;
- **a reference kept by name** — a stored name, title or label that points at another record: rename or delete
  that record and say what the stale copies do;
- **a rollback undoes everything the run changed** — an error branch, `defer`, `finally` or rescue puts back each
  thing created, locked, written or reloaded before the failure (not only the last one), and the failure says what it
  could not put back;
- **a mark with a life cycle** — for a flag, hold, lock, window or expiry set by an action and cleared by a fact or a
  timer, list every writer and every clearer and walk each pair: set by a person, then overwritten by an automatic
  action; the action fails after the mark changed (is the previous value restored, with its author and reason?); two
  actions in sequence (does the late end of the first clear the mark the second one set?);
- **the same rule on every path** — a threshold, a refusal condition, an actor in the audit log, a permission check
  or a re-read of the real state that holds on the main path must hold on every other path to the same write
  (confirmation step, retry, empty list, schedule vs person); probe a threshold just below, at and above its limit;
- **one value, every reader** — when the change adds a default, inheritance or a «none» marker (`"-"`, `""`, `null`)
  for a stored field, check every reader of that field (server, client, exports, validators, migrations): empty, the
  marker and an explicit value must mean the same in each of them.

## Settle a doubt by running it

Reading is not checking. Where a finding or a «Not checked» line turns on what code computes — a regex or an escape,
date and time arithmetic, a parser on real input, a query condition, a boundary — run it before the verdict
(an interpreter one-liner, one test by name, a read-only query). Try more than one input: the edges (empty, one, the
limit, year end, both clock changes), not the one example the change's test already uses; code that reads the current
time runs with the clock set to several dates (patch the time call or `faketime`). A probe that patches code or adds a
scratch test runs in a temp copy, never in the repository (no `git stash` or `git checkout` there):
`d=$(mktemp -d); git archive HEAD | tar -x -C "$d"; tar -cf - <paths of the change> | tar -x -C "$d"` (the second
`tar` takes the change from the working tree, untracked files included; skip it to see whether a failure already
happens on `HEAD`), `rm -rf "$d"` when done. Never skip a probe because the repository is read-only. A doubt you could
have run and did not is a miss.

## What to ignore

- formatting, import order, naming taste, comment wording — {{FILL: the project's formatters and
  linters}} and the other checks in `make check` own these;
- a different but equivalent way to write the same thing;
- hypothetical problems with no concrete input that triggers them.

## Findings

- Each finding names the rule or the failure: the input or state, and the wrong result.
  No scenario — no finding.
- One finding per class: the same mistake in five places is one finding listing the five places.
- Severity: **block** (wrong behaviour, a hard rule broken, data or security at risk, a person's setting or data
  lost or overwritten including on a failure path, a state that never ends or ends wrongly, a failure reported as
  success, a write path that skips a threshold, refusal or actor, a stored value whose meaning differs across
  readers) or **note** (worth fixing, safe to ship: a stale comment, a test weaker than the feature, a cosmetic slip
  with nothing lost or wrong). Re-grade any note whose scenario says data is lost, silently overwritten or a result is
  wrong before writing `OK`. Only block findings send the change back.

## Rounds

At most two. The second round checks only the fixes and anything they touched; it does not look
for new classes in code the first round already passed. What is still open after the second round
goes to the owner with the change — the writer does not start a third.
