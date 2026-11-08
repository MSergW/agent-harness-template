# TASK: Fill the agent harness template with this project's real content

`install.sh` has copied the owner's standard harness into this repository and written
`HARNESS_INSTALL.md` (what was copied, what already existed, other agent files, notes). Your job is
to turn the template into this project's harness. You are NOT implementing product features: do not
change application code or behaviour (the only exception: formatting-only fixes, see step 7).
Filling the harness spans the whole repository, so before your first edit write `*` into `.tmp/scope`
(the scope fence refuses edits outside the declared scope — `AGENTS.md`, «One task at a time»).

Every place that needs project content is marked `{{FILL: …}}` (the text after the colon says
what goes there). `make check` fails while any marker is left. Fill each one with real, verified
content, or delete the line/section when it does not apply. Never leave generic template text.

## 1. Discovery (read-only)

- Stack, runtime versions, layout, entry points; how it is built, run, tested, linted, deployed.
  Run each command you will list; record only what you ran, with its result.
- The project language: the language of its UI, user docs and commit history. If unclear, ask.
- Contracts with other systems: outputs, APIs, CLI commands, files that another project or service
  reads. Look at how the code is called (CLI flags, HTTP routes, webhooks, exported formats) and at
  sibling repos the owner mentions. These are the first hard rule.
- Rules that already exist: `README`, docs, comments, commit bodies, and the files listed in
  `HARNESS_INSTALL.md` («Already existed», «Other agent files»). Merge them; a rule you drop is
  named in the report. An existing skill with the same name as a template one is replaced by the
  filled template version, keeping its project-specific content (check it was not copied from
  another project).
- `HARNESS_INSTALL.md` «Notes»: act on each — especially `CASE:` (a directory spelled differently
  only in case: use the project's spelling in every reference, or the check breaks on Linux/CI).
- Where the code lives: a stack in a subdirectory (its own `go.mod`, `package.json`, `*.csproj`)
  is not seen by the root-level auto-detection in the check script and hooks — add it explicitly.
  A toolchain missing on this machine (e.g. .NET on macOS) is skipped with a message, never faked.
- What must never be touched without a request: secrets, data directories, deploy targets, shared
  libraries.

## 2. Past agent sessions (read-only)

The project's history with agents holds what the code does not: what the owner corrected, what
broke more than once, what was decided in a chat. Read it before filling the files.

- **Where.** Claude Code: `~/.claude/projects/<project path, every non-alphanumeric character
  replaced by «-»>/*.jsonl`, plus the directories of its worktrees (the same name followed by
  `--claude-worktrees-…`) and the agent's memory in `memory/` there. Codex:
  `~/.codex/sessions/YYYY/MM/DD/*.jsonl` — the project's sessions are those whose first line
  (`session_meta`) has a `cwd` inside the project. Windows: the same under `%USERPROFILE%`. Other
  tools: only where the owner points. Nothing found — say so in the report and go on.
- **How.** Never read transcripts whole in the main context. Formats change between versions, so
  look at a few lines first; then take the owner's messages (Claude Code: `"type":"user"` lines whose
  `message.content` is a string; Codex: `response_item` lines with `payload.role` `user`, skipping
  injected instructions and environment context) and failed tool results, with `jq`/`rg`. Many
  sessions: hand them to subagents in batches; each returns findings only — date, session file, the
  owner's words in one line, what went wrong.
- **What to look for.**
  - the owner's corrections and repeated requests («no, not like that», «again», «I already said»)
    and rules they stated;
  - mistakes the agent made more than once: a broken build, a weakened test, «done» without running
    anything, a command that does not work here, a file or path it must not touch;
  - code areas where sessions kept getting stuck or breaking things — pitfalls for module maps;
  - decisions taken in a chat and not visible in the code; work left unfinished.
- **What got in the owner's way** — not the agent's mistakes, the owner's friction (the categories of
  Matt Pocock's `retro`):
  - the same permission asked again and again for a safe command (Claude Code: tool calls followed by
    a permission prompt, the same command across sessions) → an allow rule in `.claude/settings.json`;
    a dangerous one stays «ask»;
  - complaints about the answers — too long, the wrong language, a question the agent could have
    answered itself, a summary that hid what was not done → one line on how to answer in `AGENTS.md`
    (or `CLAUDE.md`, when it is about Claude Code only);
  - navigation — the agent searched long for a file or a fact → a pointer in «Map» or a module map;
  - tool economy — whole files or long logs read in the main context, the same expensive call
    repeated → a narrower command in «Commands», a subagent (`log-reader`, `checker`), a script;
  - information access — a fact the agent needed and could not reach (a log, a read-only access, a
    recorded real output) → where it lives, in `AGENTS.md` or the `verify` skill;
  - waiting — the owner waiting on a slow check or a long loop → a narrower check in the stop hook.
- **Where it goes.** A repeated mistake that can be checked → a step in `scripts/check.sh` or the
  stop hook. A rule → a hard rule in `AGENTS.md` with `_Why: <what happened> (<date>, session)._`,
  or a line in a skill, `REVIEW.md` or a module map. A decision → `docs/decisions.md`, marked «from a
  session» when the code does not confirm it. Unfinished work → `PROGRESS.md` or tech debt. Check
  each against the current code first: a problem the code has since fixed is not a rule.
- **Apply or propose.** Only what is certain goes in by itself: the owner said it as a rule, or it
  happened in two sessions or more and the code still allows it. The rest — seen once, a preference
  you infer («the owner seems to dislike …»), friction whose fix changes how the owner works (a new
  allow rule, a rule on how to answer, a slower but stricter check) — is a proposal for the report,
  not a file change: the owner chooses.
- **Privacy.** Transcripts hold secrets, passwords, tokens, addresses and personal data. Never copy
  them into any file or the report: the harness is committed and may become public.

## 3. Profile

Full, unless all hold — then small: one deployable binary/package, roughly under 5k lines of own
code, no web UI of its own, tasks usually fit one session. `install.sh --small` installs only the
small subset; if you decide differently from what was installed, tell the owner and stop.

Small profile: no `PROGRESS.md`, decisions, plans, `REVIEW.md`, `GLOSSARY.md`, skills or subagents (they are
added later with the same names); delete from `AGENTS.md` the review paragraph of «Definition of
done», the `depth` line of «Session start» and the «Domain terms» rule; from `CLAUDE.md` the skills line,
the `reviewer` bullet and the «Token efficiency & delegation» block; in its «Commits» the branch rule
keeps the steps (worktree first, then `git branch -d`; a pushed branch with `gh pr merge --delete-branch`)
instead of the pointer to `git-commit`, and «Worktrees» and the `_AUDITS/` row of «Map» go (their skills
are not installed); keep `AGENTS.md` ~40–80 lines and
delete sections that would be empty.

## 4. Fill the files

- `AGENTS.md` — summary, hard rules (contracts first, each incident/decision rule with `_Why:_`),
  definition of done (the project's real layers), «Map» table, «Commands» (verified only),
  commit language, profile. ≤ ~150 lines. Relative links only — never `file:///` or `/Users/…`.
- `CLAUDE.md` — project skills that run only on explicit request, the local preview; skills and
  agents themselves are not listed there (their own descriptions are). In the full profile, detail
  only some tasks need (deploy steps, worktrees, audits) goes into a skill, `AGENTS.md` keeping a
  one-line pointer: every session reads `AGENTS.md` and `CLAUDE.md` whole.
- `REVIEW.md` — «What to look for»: every hard rule of `AGENTS.md` that `make check` cannot see,
  written as what it looks like in a diff (a rule a check enforces is not repeated), and the traps of
  this stack (its database transactions, concurrency, calls to other systems); «What to ignore»
  names the real formatters and linters. Keep the rest (scope, findings, two rounds) as it is.
- `GLOSSARY.md` — the project's own terms from the UI, docs, code names and the owner's decisions (and
  past sessions' corrections of a word), each with the words to avoid; the rules comment at the top stays
  English. Few or none found — keep only the headings.
- `PROGRESS.md`, `docs/decisions.md`, `docs/plans/*` — in the project language, headings translated;
  the first decision entry records the harness, others come from what you found (marked when only
  from a chat or memory).
- `scripts/check.sh` — keep the harness self-checks; check that the auto-detected stack sections fit
  (Go/Node/Python switch on by marker files); add the project's own static and behaviour checks;
  delete sections that cannot apply; translate the user-visible messages into the project language.
- `.claude/hooks/stop-check.sh` — add quick checks keyed on changed paths (templates → their tests,
  UI → UI unit tests, configs → validator); `.claude/hooks/format.sh` — add the project's formatter
  if it is not there; `.claude/settings.json` — add allow/ask/deny rules for this project's safe and
  dangerous commands and secret files.
- Skills: fill `verify` (real layer-3 procedures) and `git-commit` (scope table from the directory
  layout and `git log --format=%s | sort | uniq -c`, real examples), `worktree` (the local files a
  worktree needs and how it gets them). Add a project skill only for a recurring task with rules not
  obvious from the code; symlink it into `.claude/skills/`.
- Audit agents: fill `code-auditor` and `security-auditor` (the project line, the stack's traps, the
  project's own security risks — from the code, past incidents and earlier audits); keep their fixed
  coverage lists, an item that cannot apply gets «n/a» in the report, not a deletion.
- Web UI: rename `.claude/agents/ui-verifier.md.example` to `<app>-verifier.md`, `ui-sweeper.md.example`
  and `ui-auditor.md.example` to `ui-sweeper.md` and `ui-auditor.md`, fill them, and create
  `.claude/launch.json` from `launch.json.example` — the service on a throwaway database in an
  ignored directory (`.tmp/`), a test admin seeded from env or fixtures, never real data. No UI:
  delete every `.example` file, the UI bullet of the `audit` skill, the paragraph on UI checks in
  `verify`, and the other mentions of `ui-auditor` and UI findings (the `audit` description,
  `report-format.md`, `code-auditor`, step 5 of `audit-fix`).

## 5. Module maps (full profile)

For each module with non-obvious boundaries (cross-module contracts, security constraints, behaviour
others rely on) create `<module>/AGENTS.md`, ≤ 50 lines, English:

```markdown
# <module> — module map

Read before editing this module.

## Responsibility
## Contracts        (what other code or systems rely on)
## Constraints (and why)
## Pitfalls
```

No file or function lists, nothing repeated from the root. Check every claim against the code
before writing it. Fewer accurate maps beat full coverage. Index them in the root «Map».

## 6. Other tools

Codex, Antigravity and Copilot read `AGENTS.md` and `.agents/skills/`; Gemini also reads `GEMINI.md`, a
short addendum. A `GEMINI.md` the project already had is listed under «Already existed»: move its
project rules into `AGENTS.md`, then replace it with the template's version plus its Gemini-only rules.
Other agent files found in
`HARNESS_INSTALL.md`: move their rules into `AGENTS.md`; ask the owner whether to delete the old
file or keep it as a one-line pointer to `AGENTS.md`.

## 7. Make it green

- `make check` must pass. Formatting-only fixes (gofmt, ruff format, prettier) are allowed; show
  that the diff is whitespace-only (`git diff -w --stat` empty).
- A linter with many old findings gets a baseline (golangci-lint `issues.new-from-rev: <HEAD before
  the harness>`, or the tool's equivalent) and a tech-debt row «fix, then remove the baseline».
- Failing tests or real bugs: do not fix them here — report them, record them in tech debt, and ask
  the owner how to proceed. Never disable a check or weaken a test.

## 8. Acceptance

1. No `{{FILL` markers left; `make check` green.
2. `.claude/` is tracked: `git check-ignore -v .claude/settings.json` prints nothing.
3. Each hook run once by hand with sample input (`echo '{}' | bash .claude/hooks/stop-check.sh`,
   and the commands from `.codex/hooks.json` from a subdirectory — Codex may start there;
   `echo '{"tool_input":{"file_path":"<a source file>"}}' | sh .claude/hooks/format.sh`;
   `echo '{}' | bash .claude/hooks/antigravity.sh stop` prints `{"decision":"stop"}` on a clean tree;
   `echo '{"tool_input":{"file_path":"<a file not in .tmp/scope>"}}' | bash .claude/hooks/scope-fence.sh pre`
   prints a deny); the UI
   preview (if any) started once and its login page loads.
4. Cold start: from `AGENTS.md` and its links alone, a new agent can tell the current task, how to
   verify it and what «done» means.
5. Delete `HARNESS_INSTALL.md`.
6. Report to the owner in their language: profile, files filled or merged, commands verified and
   their results, rules merged or dropped, contracts found, what the past sessions gave (how many
   were read; rules, checks and decisions taken from them), what was not verified, open questions.
   Then, apart, **«Proposed — your choice»**: the proposals from the past sessions (section 2), most
   costly first, each one line — what keeps happening (how often, an example with its date), what
   would change and in which file; numbered, so the owner can answer «take 1 and 3». Nothing from
   this list is in the files until the owner picks it.
7. Commit only when the owner asks, separately from other work: formatting-only fixes in their own
   commit, then the harness with `.harness-version` (`chore(agents): …` in the project language).
   After the commit, run `make check` on a fresh clone (`git clone . <tmp>`).
