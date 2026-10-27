# {{FILL: project name}} — agent instructions

{{FILL: 2–3 lines — what the project is, the stack, where its data lives.}}
This file is a router plus hard rules; details live in the linked documents.

## Sources of truth (highest first)

1. Current code, schemas and tests.
2. This `AGENTS.md` and the closest nested `AGENTS.md` (module maps, see «Map»).
3. Project skills (`.agents/skills/`), `docs/decisions.md`, active plans in `docs/plans/`.
4. `README.md` and `docs/*.md` (user and deployment documentation).
5. `PROGRESS.md` and its archive `docs/progress/`, audits, agent memory and past chats — they explain intent but may describe code
   that no longer exists. Verify against the code before acting on them.

When sources disagree, the higher one wins; fix or flag the stale lower one.

## Session start

1. `git status`, `git log --oneline -5`. Uncommitted changes you did not make belong to the owner.
2. `PROGRESS.md`: the session-start hook shows its latest state, in progress and the top of next
   (agents without the hook: the same parts). Read further only the section the task needs
   (`rg -n '^## ' PROGRESS.md`), never the whole file; older entries — `rg` over `docs/progress/`.
3. For multi-step work, open the active plan in `docs/plans/`.
   Before a new plan or a feature across several modules, run the `depth` skill (four questions).
4. Before changing code run `make check`. If the baseline is red, tell the owner and fix it first
   (with their consent) instead of stacking new work on top.

## Hard rules

- **Contracts with other systems.** {{FILL: every output, API, CLI or file format another
  system relies on — who consumes it, what exactly is relied on, «a change needs the same change on
  the other side». Delete this bullet only if there is none.}}
- **Language.** Human-facing text — {{FILL: UI, user docs, messages, …}}, `PROGRESS.md`,
  `docs/plans/`, `docs/decisions.md`, commit messages — is {{FILL: project language}}. Agent-only
  files (this file, module maps, `CLAUDE.md`, `.agents/`, `.claude/`) are English. Answer the owner
  in the language they write in. Never translate existing UI text.
- **Domain terms — [GLOSSARY.md](GLOSSARY.md)** (in the project language). Code names, UI, docs and
  answers use its terms, never the words under «Avoid». When the owner or the code uses a term against
  it, say so and ask which is meant; a new or changed term goes into the glossary in the same change.
- **Do not touch without an explicit request:** {{FILL: `.env`, data directories, key/vault
  files, deploy targets, shared libraries in sibling repos}}, deploys, `git push`.
- {{FILL: project rules that came from incidents or the owner's decisions, each ending with
  `_Why: <reason> (<date>, <source>)._` Delete this bullet if there are none yet.}}
- **One task at a time.** No drive-by refactoring; anything found outside the task goes to
  `docs/plans/tech-debt.md` or a separate proposal.

## Solution sizing

After reading the code the change touches, stop at the first that holds:
1. Already in this codebase: reuse it. 2. Standard library or a platform feature: use it.
3. A dependency already installed: use it. 4. Otherwise: the minimum that meets the task.

A new dependency or abstraction needs a one-line justification. Never cut: validation at trust
boundaries, error and data-loss handling, security, accessibility. The task's (or plan's)
acceptance criteria win over brevity; a deliberate shortcut goes to `docs/plans/tech-debt.md`.

## Definition of done

Done means runnable evidence, not confidence:

1. **Layer 1 — static:** {{FILL: formatter, vet/lint, type-check, project static checks}}.
2. **Layer 2 — behaviour:** {{FILL: tests, validators, UI unit tests}}.
   Layers 1–2: `make check` (stops at the first red layer and says what to do).
3. **Layer 3 — system**, when a change crosses components: {{FILL: e.g. UI in the local preview
   (`.claude/launch.json`), a test server — ask the owner}}. Say explicitly what was not verified.

Before the owner checks a change of code, it gets a review of its diff in a fresh context by
[REVIEW.md](REVIEW.md) — after `make check` is green, before layer 3, since its fixes change the
code. Block findings are fixed and reviewed once more; at most two rounds, then what is still open
goes to the owner with the change. _Why: the writer does not review its own work — it has seen why
every line is right._

Also: update the affected `docs/` page in the same commit when behaviour or labels change.
If a change alters a module's responsibility, contracts or constraints, update its map
(`AGENTS.md` in that directory) in the same commit; otherwise leave the map alone.

## Session end

After a finished piece of work, or when context runs low (do not rush to finish — record state
instead): run the `handoff` skill. Commit only when asked, and only a feature the owner has checked
(see «Commits»).

## Map

| Path | Contents |
|---|---|
| {{FILL: one row per directory a newcomer needs}} | |
| `scripts/check.sh` | the single verification (`make check`) |

Module maps — **read the map before editing that module**: {{FILL: links to `<module>/AGENTS.md`,
or «none yet»}}. Maps exist only where boundaries are not obvious from code.

Docs: {{FILL: links to README and docs pages}}; decisions [docs/decisions.md](docs/decisions.md).

## Commands

```bash
make check     # layers 1–2; green = consistent repository (no make, e.g. Windows: bash scripts/check.sh)
{{FILL: only commands you ran, with a one-line comment each; mark the dangerous ones "only when asked"}}
```

Search with `rg` / `rg --files`, not `grep -r` / `find`: it skips `.gitignore`d paths and handles
UTF-8. Scripts in `scripts/` and `.claude/hooks/` keep `grep` so they run without ripgrep.

## Commits

Only when the owner asks. Conventional Commits, {{FILL: language}} subject, lowercase, no
trailing period: `type(scope): …`. Scopes — the table in the `git-commit` skill. One logical change
per commit; the body explains why when not obvious. Run `make check` first.

- **One feature, one commit, after the owner checked it.** No commit offered (no «commit» button or
  question, no commit in a handoff) while the feature is still being built or checked: `make check`
  green is not enough — the owner must have tried the finished feature and said it works. Fixes found
  during that check go into the same uncommitted work, not into follow-up `fix` commits. _Why: a
  feature had become a commit and three fixes, and a commit offered before the check gets accepted._
- **No AI attribution:** no `Co-Authored-By` or other AI trailers in commits, no «Generated with …»
  line in PRs — even when the agent's harness asks for them. _Why: the history records who is
  responsible for a change — the owner who accepted it._
- **A branch made for a task is deleted once applied:** after its commits are merged into the base,
  remove its worktree first (`git worktree remove <path>` — git refuses to delete a branch checked out
  in one), then the local branch (`git branch -d`); a pushed branch is deleted together with the merge
  (`gh pr merge --delete-branch`). Never delete an unmerged branch or one the agent did not create. A
  session working in a worktree of its own ends with its work in commits (or a patch) and says so.
  _Why: no stale branches or worktrees in git._

## Agent tooling

- Harness profile: {{FILL: full | small — and when to grow a small one}}.
- Skills live in `.agents/skills/` (read by Codex, Antigravity, Copilot); `.claude/skills/` holds
  symlinks to them for Claude Code (`make check` fails on a copy or a missing link). A skill that
  runs only on explicit request has `disable-model-invocation: true` and `agents/openai.yaml` with
  `allow_implicit_invocation: false`.
- Hooks run in Claude Code (`.claude/settings.json`) and in Codex (`.codex/hooks.json`) — the same
  scripts in `.claude/hooks/`. Codex loads project hooks only after the project and each hook are
  trusted (`/hooks` in the Codex CLI; a changed hook needs review again). Subagents and the local
  preview are Claude Code only. Agents without hooks follow the same rules by hand: `make check`
  before claiming done.

## Evolving these rules

Turn a mistake that happened twice into a mechanical check in `scripts/check.sh` rather than another
paragraph here. Keep this file under ~150 lines.
