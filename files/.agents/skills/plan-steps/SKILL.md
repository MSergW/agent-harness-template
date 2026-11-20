---
name: plan-steps
description: How a plan's main session (Claude Code desktop app) starts and follows the sessions of its steps — «Step N» names, the plan's worktree, the model of a step (Sonnet; the reviewer on Opus), the brief's language line, branch names of new sessions, the attack on the plan before step 1 and keeping its files, staying quiet until a step is committed. Use when starting any new session with start_session, and in a plan's main session before starting a step.
---

# Plan steps in their own sessions

Claude Code (desktop app) only: Codex and Antigravity have no `start_session` — there a step is a new session the
owner opens with the same brief. The state between sessions lives in `docs/plans/` and `PROGRESS.md`, never in the
chat (`AGENTS.md`, «Context economy»).

## The plan's main session

- The session where the plan was written stays its main one, named after the plan. Once the plan is written, each
  next large step is offered and started from there (`start_session`); a small one may go on in place («Context
  economy»). _Why: plan and steps stay in one place — no hunting for steps in the session list._
- A step's session is named just «Step 1», «Step 2» (in the project language), with no details.
- A sequential step's session opens in the plan's worktree (`cwd` = its path; the `worktree` skill), not a new one.
- The main session does not relay a step session's intermediate notes (checks running, review back, waiting on the
  owner): the owner follows the step there. It speaks only when the step is committed (verify the hash, offer the
  next step) or when it must act itself. _Why: the relays distract more than they help._
- **Every turn a step session ends wakes the main session** (the app does it), and a wake-up re-reads the whole
  context. Subagents run in the background there, so a step cannot wait for one inside its turn. So the step runs
  `make check` itself through Bash in the foreground with a short output (`make check 2>&1 | tail -30`), not through
  `checker`; only `reviewer`, a UI verifier and `committer` stay subagents — about two or three wake-ups per step
  instead of five to eight. The brief of every step says so.
- **The main session continues on its own only on the owner's explicit word** («run the whole plan without asking»):
  then at each «committed» wake-up it verifies the hash and starts the next step itself, to the end of the plan or to
  the first question to the owner. Without that word, after a commit it only offers the next step.

## Before step 1: the plan under attack

The idea was attacked before the plan was written (the `depth` skill, «Attack the idea before the plan»); the written
plan is attacked again by «The plan under attack» in `docs/plans/README.md` before the first step is offered.

- **Keep the attack for evaluation.** The main session writes the critics' reports and the judge's verdicts verbatim
  to `_DOCS/temp/<plan topic>/critics-<YYYY-MM-DD>.md` (one file per attack; a second one the same day gets `-2`),
  and after the owner's round adds the owner's answers. Number every judged item (`K1`, `K2`…) and write those
  numbers next to the fixes in the plan («(K3)»), so a later reader can trace a plan line to its claim.
- **When the plan is finished** (before `handoff` moves it to `done/`), the main session adds a section «Outcome» to
  each critics file: every accepted item marked `useful` (the step built it and it held), `needless` (built, later
  removed or never needed — name the step or commit that removed it) or `unchecked`. Each `useful` also says who
  would have caught it without the attack: `test`, `review`, `layer 3`, `owner` or `nobody` (it would have reached
  production) — `unknown` when it cannot be told, never a guess dressed as fact. Then: every rejected item that later
  proved right; what the step reviews, layer 3 and the owner found that a lens could have caught from the plan (with
  its lens); a design the owner changed that no critic questioned. One line of counts (with how many were `nobody`)
  goes to the plan. `handoff` keeps the critics files until the owner evaluates the attacks.
- **«After the merge» — at evaluation time, not at the plan's end.** Whoever evaluates the attacks (a later session,
  on the owner's request) adds to each critics file whose plan was merged at least 7 days earlier a section «After
  the merge»: the commits of those 7 days on the feature's files (`git log --since=<merge> --until=<merge+7d> --
  <paths>`) that change its behaviour or model — a fix, a missing piece, a reworked design — each with the lens that
  could have asked for it from the plan, or «none». The owner's own rework the day after a merge is what «Outcome»
  never sees.
- _Why: without the files only counts were left after a few attacks; and nearly every fix marked useful says nothing
  until it says who else would have caught it. The misses were in the idea, not in the steps._

## The brief of a new session

- `prompt` and `background` are English (agent-only text, `AGENTS.md` «Language»); UI labels stay quoted in the
  project language.
- The first line names the language, word for word; the languages themselves come from the owner's settings, which
  the session-start hook prints in every session (`AGENTS.md` «Language»). Any session:
  `Language: follow the owner's language settings printed at session start; product text (UI, docs, commits) stays in the project language, as AGENTS.md says.`
  A plan's step, as the first line of `background` (the app puts `background` before `prompt`), or of `prompt` when
  there is no background:
  `Language: you are a plan step session. Work in the step-session language of the owner's settings printed at session start: every message, note and your thinking, including the short message that ends a turn while you wait for a check, a review or a subagent. The owner's answer language only in a question to the owner and in the one final report when the step is done (done, verified, not verified).`
  _Why: a session does not see its own title, so the language rule must be the brief's first line; without it steps
  drifted between languages, and a line placed after the background was ignored. «Russian» alone next to Ukrainian
  project text drifted into Ukrainian, so the hook names the language it is not._
- A session with its own worktree gets `branch_name` by the `worktree` skill (the app adds a prefix and a suffix).
  A card (`initiation: "own_initiative"`) drops `branch_name` and the app names the branch at random, so a session
  with its own worktree is never proposed as a card: ask in the reply and start it with `user_asked` on the owner's
  yes (or `offer` for a task the owner named). A session the owner started with a generated branch name keeps it.

## The model of a step

- Steps run on Sonnet: the main session stays on Opus (plan, discussion) and starts each step with
  `model: "sonnet"`, except a step marked `[opus]` in the plan (production, secrets, data migrations, a decision
  still open). The `reviewer` runs on Opus: the cheaper model's weak spots are caught by the stronger one.
- A step on Sonnet that meets a decision the plan does not settle stops and asks the owner, never guesses.
- A step whose second review round is still `BLOCK` runs the third (`REVIEW.md`, «Rounds»); a step never reports
  done on a `BLOCK` whose fix no round has reviewed.
- _Why: measured on a real project (44 steps on Sonnet, 22 on Opus, the same Opus reviewer): a Sonnet step cost
  about half; more of its first review rounds were `BLOCK` (50% against 32%), at about the same number of rounds._
