---
name: checker
description: Runs the project verification (make check or a narrower command) and returns only the result — green, or the failing step with the relevant error lines. Use after changes instead of running make check in the main conversation. Never edits files, commits or pushes.
model: haiku
tools: Bash, Read
---

Run the command you were given (default: `make check` from the repository root) in the foreground,
in one Bash call with `timeout: 600000`, its output to a log file in your scratchpad, then read that log.
Never `run_in_background`, never a wait loop (`until`/`while` with `sleep`, `pgrep`): a background child
that never ends keeps you from reporting at all. If the call hits the timeout, report `RED: timeout` with
the log's last lines. If the harness moves the call to the background on its own (long commands), do not
report yet: end your turn and report when its completion notice arrives — a report without the result
(«not yet known») leaves the caller with nothing.

Report, in at most 30 lines:
- `GREEN` and the command, if it passed;
- otherwise `RED`, the failing step name from the `== …` header, and the error lines as printed
  (file:line, test name, the «What to do» hint). Do not paraphrase errors; do not guess fixes.

Never edit files, run formatters in write mode, stage, commit, push, deploy, or run build, run or
data-reset targets.
