<!-- {{FILL: write this file in the project language and translate it. Remove this comment.}} -->
# Plans

[← Project overview](../../README.md)

A plan is needed when work takes several sessions, touches several subsystems or has open
decisions. Small tasks from a conversation need no plan.

- Active plans — `docs/plans/<topic>.md`; finished ones — `docs/plans/done/` (for context).
- Deliberately deferred — [tech-debt.md](tech-debt.md).
- Agreed directions, not scheduled — [ideas.md](ideas.md).
- Defects the owner found after the review — [review-misses.md](review-misses.md).
- The current step of the active plan is repeated briefly in [PROGRESS.md](../../PROGRESS.md).

## The idea in the owner's words

A plan written from the agent's retelling of the idea drifts from what the owner meant, and the drift shows only in
the finished work. So:

- A plan has a section **«Owner's words»**: every requirement and decision the plan stands on, as the owner's quote
  with its date (from the chat where it was said), and next to it how the plan understands it. A word the owner and
  the plan use differently gets its own line «for you it is …, in the plan it is …» and goes into `GLOSSARY.md`.
- A decision of the agent the owner has not answered directly («added on my own», «decided myself», a verdict of the
  critics' judge) goes into the same section marked «unconfirmed», with a question to the owner; a «commit» in reply
  to a report does not confirm it.
- What the owner defers («later», «in the next version») goes into [ideas.md](ideas.md) in their words the same day:
  a plan's limits drop out of sight once it moves to `done/`. Before a plan moves to `done/`, go through its «Scope»
  (out), «not verified» and similar lines: each goes to `ideas.md`, `tech-debt.md` or the next plan.
- **Check with the owner**: before step 1 and before a live test the owner reads «Owner's words» (up to ~20 lines)
  and says «yes» or corrects it. Without that word step 1 does not start.

_Why: on a real project four plans had to be checked against the owner's words after the fact (468 ideas, 135
divergences; the owner explained the model for the third and fourth time)._

## Before step 1: the plan under attack

A written plan is never judged by the session that wrote it. Its idea was attacked before the plan was written (the
`depth` skill, «Attack the idea before the plan»); before the first step the plan is attacked again (Claude Code;
elsewhere fresh sessions given `.claude/agents/plan-critic.md`):

- One `plan-critic` per lens in parallel (the lenses in that agent), each given only the plan's path and its lens —
  not the discussion behind the plan. Then one `plan-critic` in judge mode with the plan's path and their reports.
- The plan's session writes the judge's «accept» fixes into the plan, asks the «owner» questions in one numbered
  round (a recommended answer each, as in the `depth` skill) and writes the answers into «Decisions». «reject» stays
  out of the plan and the chat.
- Skipped for a plan of one or two small steps. A plan rewritten in a large part after the attack gets one more.
- The reports and verdicts are kept in `_DOCS/temp/<topic>/critics-<date>.md` and judged after the plan is done — how,
  the `plan-steps` skill.

_Why: a model judges its own work badly; several critics attack, a judge keeps what holds._

## Plan template

```markdown
# <Topic>

**Goal:** what the user gets.
**Scope:** what is in / deliberately out.

## Owner's words
The owner's quotes with dates — the requirements and decisions the plan stands on; the agent's unconfirmed decisions
marked «unconfirmed».

## Depth
The `depth` skill's answers: what a top specialist would do beyond the request (and what was taken), the raw
material it starts from, the methods, what beyond the usual checks verifies it.

## Decisions
- <date> — what was decided and why (later moved to docs/decisions.md).

## Steps
- [x] 1. … — evidence: `make check`, verified on <where>, commit `abc1234`
- [ ] 2. … ← current
- [ ] 3. …

## Verification
What layer 3 needs (preview, test server) and who does it.
```
