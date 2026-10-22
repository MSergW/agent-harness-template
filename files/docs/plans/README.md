<!-- {{FILL: write this file in the project language and translate it. Remove this comment.}} -->
# Plans

[← Project overview](../../README.md)

A plan is needed when work takes several sessions, touches several subsystems or has open
decisions. Small tasks from a conversation need no plan.

- Active plans — `docs/plans/<topic>.md`; finished ones — `docs/plans/done/` (for context).
- Deliberately deferred — [tech-debt.md](tech-debt.md).
- Agreed directions, not scheduled — [ideas.md](ideas.md).
- The current step of the active plan is repeated briefly in [PROGRESS.md](../../PROGRESS.md).

## Plan template

```markdown
# <Topic>

**Goal:** what the user gets.
**Scope:** what is in / deliberately out.

## Decisions
- <date> — what was decided and why (later moved to docs/decisions.md).

## Steps
- [x] 1. … — evidence: `make check`, verified on <where>, commit `abc1234`
- [ ] 2. … ← current
- [ ] 3. …

## Verification
What layer 3 needs (preview, test server) and who does it.
```
