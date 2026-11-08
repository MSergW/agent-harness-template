---
name: audit
description: Running a new audit — code, security or UI (a commit range, a section or the whole tree) — with the project's audit agents, so that the finder never confirms its own finding, and saving the report to `_AUDITS/`. Use when the owner asks for a code, security or UI audit, or a full UI audit of a section. Triage of an audit that already exists is the `audit-fix` skill.
---

# Audit

Reports follow [report-format.md](report-format.md) and go to `_AUDITS/CODE_AUDIT_<date>.md`,
`SECURITY_AUDIT_<date>.md`, `UI_AUDIT_<date>.md` (`_AUDITS/` is not in git). Only the main conversation hands
work from one agent on to the next: a subagent cannot start subagents. A tool without subagents runs each pass
as a new session given the same inputs.

- **Code:** `code-auditor`.
- **Security:** `security-auditor`, then a fresh `security-auditor` in its verify mode with only the findings (each
  one's place, conditions and reproduction, not the finder's reasoning). Before saving `SECURITY_AUDIT_*`:
  `confirmed` stay findings, `needs_validation` go to «Not checked» with their open fact, `rejected` to «Checked,
  not confirmed». _Why: the finder never confirms its own finding — it has seen why every step looked right
  (idea from Cloudflare's security-audit-skill)._
- **UI, a full audit of a section** (projects with a web UI): `ui-sweeper`, then `ui-auditor` with its report;
  merge the two in the main conversation. A finding only the sweeper has is confirmed before it goes into
  `UI_AUDIT_*`. Browser agents run one after another, never in parallel (one browser pane, one local database).

Then triage with the `audit-fix` skill.
