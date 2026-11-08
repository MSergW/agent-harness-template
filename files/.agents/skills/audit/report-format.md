# Audit report format

Shared by the three audits — `security-auditor`, `code-auditor`, `ui-auditor` — so `audit-fix` triages any of them
the same way. The auditor returns the report as text; the caller saves it as `_AUDITS/<KIND>_AUDIT_<YYYY-MM-DD>.md`
(`SECURITY`, `CODE`, `UI`; a second one that day gets a suffix, e.g. `_2`). `_AUDITS/` is not in git.

The report is in the project language (the section names below translated, the same in every report), with UI
labels quoted «like this»:

1. **Header** — the kind of audit, the date, the commit (`git rev-parse --short HEAD`) and whether the tree was
   clean, the scope (a commit range or the whole tree), the tools used and their versions.
2. **Summary** — 3–5 sentences: the overall state and the most important finding.
3. **Coverage** — a table over the auditor's fixed coverage list, every item present: «item · 🟢/🟡/🔴 · briefly ·
   evidence». The evidence is `file:line`, a command, or (UI) a page and a role. 🟢 in order, 🟡 a risk worth
   strengthening, 🔴 a defect.
4. **Findings** — a table «№ · P1/P2/P3 · problem · evidence», P1 first. P1 — exploitable, data loss or a broken
   main path; P2 — a real defect under narrower conditions; P3 — hardening, clarity, polish.
5. **Per finding** — `### N. <title>`: where (`file:line`, or page · role · steps), conditions, reproduction (the
   test, command or browser steps that showed it), fix options with a recommendation. Never a working exploit
   against a real system.
6. **Checked, not confirmed** — suspicions that did not hold, one line each with why.
7. **Not checked** — what could not be checked and why (a tool missing, a real server needed). A suspicion traced
   in the code that stops at one open fact goes here too: that fact stated exactly («does X reach Y without the
   check Z»), with no priority — the next audit or triage settles it.

Every finding is confirmed by reproducing it, not only by reading. Temporary tests live in a temporary directory
or are removed before returning; never run anything on real servers.
