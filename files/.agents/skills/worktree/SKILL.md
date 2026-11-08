---
name: worktree
description: Where a task's work lives — its own git worktree for a plan or a parallel step, straight on the main branch for a small fix; branch names, local files a worktree needs from the main checkout, deploying from a branch. Use when starting a plan or a multi-step task, creating a branch or a worktree, starting a step's session, or deploying from a worktree.
---

# Worktrees

A task of several steps (a plan) works in its own git worktree, so an unfinished feature never blocks a fix on
the main branch.

- **One worktree per plan:** steps that follow one another run in it in turn, each its own commit on the plan's
  branch. A step gets a worktree of its own only when it runs at the same time as another. _Why: a worktree per
  sequential step only chains branches to merge in order and clean up._
- **A small fix** (one session, one commit) goes straight to the main branch in the main checkout, no branch. It
  gets a worktree only when the main checkout is busy (uncommitted work, another writing session) or the fix grows
  past one session. _Why: worktrees keep the main branch free for exactly these fixes._
- **Local files** git does not carry: {{FILL: the env files, local databases and preview configs a worktree
  needs, and how it gets them — e.g. «links to the main checkout's copies, made by `scripts/worktree-links.sh`
  after `git worktree add`», so a local database stays one for all branches (a branch's migrations change it for
  the main branch too) — or «none»}}.
- **Names say the task:** the branch is the plan's file name; a parallel step adds its number (`search-index`,
  `search-index-2`); a one-off task — two or three English words in kebab-case. Never a generated name.
- **Deploy from a branch:** bring it up to date with the main branch first — a build from behind rolls
  production back. Say when what goes out is not the main branch or has uncommitted changes.
- **Once merged**, the worktree and then the branch are deleted — never an unmerged branch or one the agent did
  not create; the steps — the `git-commit` skill, «Branches and worktrees». A session working in a worktree of its
  own ends with its work in commits (or a patch) and says so in its report.
