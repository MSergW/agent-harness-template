---
name: audit-fix
description: Triage an audit from `_AUDITS/*_AUDIT_*.md` (code, security or UI) — confirm or reject each finding against the current code, propose fixes, then fix the items the owner picks. Use when the owner asks to look at, check or fix an audit.
---

# Audit triage

1. Take the given file (or the newest `_AUDITS/*_AUDIT_*.md`; the format is
   [report-format.md](../audit/report-format.md), older ones may be free-form). Compare the audited commit with
   `git log` — what has changed since.
2. For each finding read the cited code and decide: **confirmed** / **partly** / **not confirmed** (already fixed
   or wrong). Confirm by reproducing (a test, rendering the template), not only by reading.
3. Answer the owner in their language, briefly: a table «№ · priority · status · how to fix · size». For
   trade-offs (security vs convenience) ask a question with a recommendation.
4. Wait for the owner's pick. Fix in the groups they ask for (e.g. "1, 3 and 6").
5. Every fix comes with a regression test reproducing the audit defect (a UI finding: a UI test where the
   behaviour is testable, and the steps re-checked in the preview). Protect the boundary where untrusted data
   turns into code or config (a query, a shell line, a generated file), not only the form that sends it.
6. After each group run the `verify` skill; commit only when asked (the `git-commit` skill).
7. Unpicked or deferred items → a row in `docs/plans/tech-debt.md`; the owner's trade-off decisions →
   `docs/decisions.md`. If a defect class can be caught mechanically, propose a check in `scripts/check.sh`.
8. When every finding is fixed, rejected or has its row in `docs/plans/tech-debt.md`, tell the owner the audit is
   closed and offer to delete its file from `_AUDITS/`; delete only on their yes. A security audit leaves its
   coverage first: overwrite `_AUDITS/SECURITY_COVERAGE.md` with its header (date, commit), «Coverage» and «Not
   checked», no findings — the next `security-auditor` starts from it.

Never edit the audit file itself.
