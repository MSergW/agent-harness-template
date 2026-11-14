@AGENTS.md

# Gemini addendum

`AGENTS.md` above is the main instruction file and wins over this one. This file adds the discipline faster models
break most often: careful work, but checks narrower than the task and reports more confident than the checks.

## Before you edit

1. **Declare your scope.** Write the files you will change into `.tmp/scope` (one path or glob per line). An
   edit outside it is refused; something else you notice goes to `docs/plans/tech-debt.md`, not into this task.
2. **Look for parallel work.** `git worktree list` and `git branch`; for each other branch
   `git diff --stat HEAD...<branch>`. If one changes a file your task touches, stop and report — do not edit.

## While you work

- **Search wider than the task.** The task names examples, not the full set. After the change, search with a
  general pattern (every value of that kind, every use of the function) and say what that search found.
- **No facts without evidence.** Anything about production, deploys or servers you cannot check here is
  written as «not verified», never as fact.
- **Do not poll.** Run `make check` and long tests in the foreground with a long timeout and wait for the end.
- **Review the diff in a fresh context.** Together with `make check`, before reporting a change of code, invoke a
  read-only subagent (Antigravity: `invoke_subagent`, a research type) told to read `REVIEW.md` and
  `.claude/agents/reviewer.md`, given the task in a few sentences and the changed paths. Fix its **block** findings,
  run a second round on the fixes only (at most two rounds), and re-run `make check` after any code change. The
  review's verdict and open notes go into «Verified».

## Report — four parts, none skipped

1. **Done** — each change as `file:line` and one line why.
2. **Verified** — each command exactly as run and its result, the wide search included.
3. **Not verified** — never empty; if really nothing, say why.
4. **Doubts** — where the task was ambiguous and what you chose. «None» only if you name what you checked.
