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

## Before step 1: the plan under attack

A written plan is never judged by the session that wrote it. Before the first step (Claude Code; elsewhere fresh
sessions given `.claude/agents/plan-critic.md`):

- One `plan-critic` per lens in parallel (the lenses in that agent), each given only the plan's path and its lens —
  not the discussion behind the plan. Then one `plan-critic` in judge mode with the plan's path and their reports.
- The plan's session writes the judge's «accept» fixes into the plan, asks the «owner» questions in one numbered
  round (a recommended answer each, as in the `depth` skill) and writes the answers into «Decisions». «reject» stays
  out of the plan and the chat.
- Skipped for a plan of one or two small steps. A plan rewritten in a large part after the attack gets one more.

_Why: a model judges its own work badly; several critics attack, a judge keeps what holds._

## Plan template

```markdown
# <Topic>

**Goal:** what the user gets.
**Scope:** what is in / deliberately out.

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
