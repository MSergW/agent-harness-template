---
name: depth
description: Four questions before a big task — what a top specialist would do beyond the request, the rawest material to start from, the methods and tools, and what beyond the usual checks will verify the result; then the task restated with the answers. Use before writing a plan in docs/plans/ or starting a feature that touches several modules, pages or integrations. Skip for a text change, a one-file fix or a bug with a known cause.
---

# Depth

Goal: the task is set the way the best specialist would set it, before the first line of code — not made
bigger. _Why: from Felix Rieseberg, «How to be more ambitious» — an agent given a task restates it at the
level of the request; asked what an expert would do, it finds the missing states, the real data and the
check that proves the result._

Read the code the task touches first (and the module's map), then answer each question in one to three lines,
concretely for this task — no generic advice:

1. **What would a top specialist do that was not asked for?** The states nobody named (empty, error, no
   right, a slow or absent dependency, two people at the same time), what the user sees while something
   waits, what the change does to existing data, who else is affected (other services, clients).
   At most 3–4 proposals, the weightiest first, each marked: «project rule» — a hard rule of `AGENTS.md`
   demands it, so it goes into the work; «optional» — the owner decides. _Why: a longer list buries the
   few that matter, and the owner has to turn down the rest one by one._
2. **What is the rawest material to start from?** Not a guess about the data: the real database (a sanitized
   copy, if the project keeps one), the real output of the external system or command, the logs, the run
   history. Name what to look at and look before designing, not after.
3. **Which methods and tools?** What this codebase already has for it («Solution sizing»), and how a specialist
   in that field works (a parser — from recorded real output; speed — measured, not judged by eye; a
   migration — with counts before and after).
4. **What will verify it — beyond the usual?** `make check`, the review and the owner's check always happen;
   do not list them. Name only what this task needs on top, with the state and the expected result: a test
   on recorded real output, a UI scenario for a state the local data lacks, a run on a test server, a
   comparison with what the external system itself shows. Nothing on top — say so in one line.

Then restate the task in one paragraph: the goal, what it starts from, how it is done, how it is verified.

- Show the answers and the restated task to the owner in their language, short (up to ~10 lines), **before
  the work starts** — before the first code edit or the plan — and wait for the owner's word on the
  «optional» proposals; with none, go on without waiting. _Why: answers shown only in the final report come
  after the decisions they were for._
- When the answers leave decisions open (how a case behaves, which of two ways, what the owner wants
  shown), settle them in **rounds** before the work starts. The decisions form a tree: one answer opens
  the questions that hang off it. A round asks every question whose prerequisites are already settled —
  numbered, each with your recommended answer, worded so that «yes» accepts it; a question that depends
  on another one still open waits for a later round. Facts are your job, never the owner's: look them
  up in the code, data or logs (a subagent, in parallel) and ask only the decisions. Done when no branch
  is left open or silently assumed. _Why: from Matt Pocock's `grilling` — one list at the end asks the
  owner to guess at answers that depend on each other._
- A session started to work on its own (from a brief, nobody waiting at the keyboard) takes only the
  «project rule» proposals and names the «optional» ones in its report, undone.
- Nothing beyond the request is added silently («One task at a time»). Unchosen proposals go to
  `docs/plans/ideas.md` or `docs/plans/tech-debt.md` only if the owner wants them kept.
- With a plan in `docs/plans/`, write the answers into its «Depth» section (in the project language).
