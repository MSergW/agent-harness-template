<!-- {{FILL: write this file in the project language and translate it. Remove this comment.}} -->
# What the review missed

[← Plans](README.md)

Defects the owner found in their own check after the change had passed the review (`reviewer`) and `make check`.
This compares the owner's judgement with the agent's: where they differ, the review needs tuning. The session that
fixed the defect adds the row (the `handoff` skill); the `harness-refresh` skill turns it into a line in `REVIEW.md`
or a check in `scripts/check.sh` and deletes the row (git keeps the history).

| Date | Change | What the owner found | Why the review missed it | Lesson |
|---|---|---|---|---|
