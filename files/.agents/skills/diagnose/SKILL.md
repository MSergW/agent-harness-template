---
name: diagnose
description: Diagnosis loop for a bug or a slowdown whose cause is not known — a command that goes red on the exact symptom first, then a minimal repro, ranked falsifiable hypotheses, one-variable probes, a regression test before the fix, cleanup. Use when the owner reports something broken, failing, flaky or slow, or says «debug», «diagnose», «why does …». Skip when the cause is already known.
---

# Diagnose

Goal: the cause is found from evidence, not from reading code until a theory feels right. _Why: from
Matt Pocock's `diagnosing-bugs` — with a tight pass/fail signal for the bug the cause gets found; without
one, no amount of reading saves you._

Read the module's map and `GLOSSARY.md` (if any) first. Secrets never reach the chat or a file: write
`<REDACTED>` in their place, keep credentials in env vars the loop reads. Long output goes to the
`log-reader` subagent in Claude Code, not into the main context.

## 1. A loop that goes red

Build one command that goes red on **this** bug, in roughly this order of preference: a failing test at
the seam that reaches it; a request (`curl`, an HTTP script) to the local preview or service; the CLI on a
fixture, diffed against a known-good output; a replay of a recorded real input (payload, event log,
command output) through the code path; a throwaway harness of one component with its dependencies faked;
a loop over many random inputs; `git bisect run` between a good and a bad state; old vs new version on the
same input. {{FILL: where real data comes from in this project — a sanitized copy of the database, recorded
outputs of external systems, logs — or delete this sentence.}}

Then tighten it: faster (narrow the scope, skip unrelated setup), sharper (assert the symptom, not «did not
crash»), deterministic (pin time and random seeds, isolate files and network). A flaky bug needs a higher
reproduction rate, not a clean repro: repeat the trigger, add load, narrow the timing window.

**Done when** you can name the command, have run it at least once (show it and its redacted output), and
it is: red-capable — it drives the real code path and asserts the symptom the owner described; the same
verdict every run (or a pinned high rate for a flaky bug); seconds, not minutes; runnable without a person.

No such command — stop, say what you tried, and ask the owner for access to where it reproduces, a captured
artifact (log, request, dump) or a temporary probe in production. Do not go on to hypotheses without a loop.

## 2. Reproduce and minimise

The loop shows the failure the owner described — not a nearby one (wrong bug, wrong fix) — and does so on
every run. Then cut inputs, callers, settings, data and steps one at a time, re-running after each cut,
until every remaining element is needed: removing any one makes the loop green.

## 3. Hypotheses

Write 3–5 ranked hypotheses before testing any. Each states its prediction: «if X is the cause, changing Y
makes the bug disappear / changing Z makes it worse». No prediction — not a hypothesis. Show the list to the
owner in their language (they may know one is ruled out or that something just changed) and go on with
your ranking without waiting.

## 4. Probes

Each probe tests one prediction and changes one variable. A debugger or REPL first, then a log at the
boundary that separates two hypotheses — never «log everything and search». Every temporary log line carries
the tag `[DEBUG-<4 hex>]` (one tag per diagnosis, e.g. derived from the time); `make check` fails while one is
left. A slowdown is measured, not logged: a baseline timing first, then bisect.

## 5. Fix and regression test

Write the regression test before the fix, at a seam where it reproduces the real pattern of the bug (the
same callers, the same chain). Watch it fail, fix, watch it pass, then run the step-1 loop on the original,
not minimised, case. No such seam — that is a finding: name it to the owner and add a row to
`docs/plans/tech-debt.md`; a test at a too-shallow seam gives false confidence.

Two fixes that rest on the same premise fail the same check — stop before a third. Write that premise in
one sentence, name who holds the state it assumes, and test it as a hypothesis (steps 3–4): the premise is
usually the bug. Tell the owner which premise fell. _Why: «Attack the Premise» from Robert Martin's
`ub-mode` — a third fix on a wrong premise only hides the symptom._

## 6. Cleanup

- The step-1 loop is green on the original case; the regression test passes (or the missing seam is recorded).
- No `[DEBUG-` tag is left; throwaway harnesses and scripts are deleted.
- The hypothesis that turned out right is stated in the report to the owner and later in the commit body.
