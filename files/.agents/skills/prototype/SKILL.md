---
name: prototype
description: A throwaway prototype of a UI idea on live data — variants switched by a bar in the local preview, its own `proto/<topic>` worktree, no tests or review, deleted once the owner picks. Use when an idea in docs/plans/ideas.md has an open question about look or placement, or the owner asks to «try», «prototype» or compare variants of a page, card or control.
---

# Prototype

A UI question is answered by trying it on real data, not by discussing it or by static pictures. _Why: in a real
project the first prototype settled in one round a question that had waited a month; variants on live data beat
mockups._

## When

- An idea in `docs/plans/ideas.md` whose open question is how it looks or where it goes, or the owner asks for variants.
- Only with the owner's consent: offer it, do not start it on your own.
- Not for behaviour that needs the backend (new data, an API): a prototype is markup, styles and client code. Data
  that does not exist yet is hard-coded, marked as such.

## Where

- Its own worktree and branch `proto/<topic>` from the main branch (the `worktree` skill; `git worktree add -b
  proto/<topic> <path> <main branch>`, then the local files it needs).
- {{FILL: how the prototype runs — a launch entry `<preview>-proto` in `.claude/launch.json` on its own port, started
  from the worktree, on the same local data as the usual preview (read-only use), and the test account to sign in with.}}

## Skipped and kept

| Skipped | Kept |
|---|---|
| Tests of the variants, `make check`, the `reviewer`, docs, `PROGRESS.md`, commits | UI texts in the project language (the look is the point) |
| Clean code: hard-coded data, quick handlers | No writes to shared local data: no migrations, no buttons changing records |
| | The existing UI unit tests stay green (the stop hook runs them on changed files), so the prototype code must not run in them (below) |
| | No merge into the main branch, no push, no deploy |

## The variant bar

Every prototype gets the same bar at the bottom left: «Prototype: A B C D» and the chosen variant's name. A — what
there is now. The choice is kept in `localStorage` (`proto-<topic>`) and the page reloads. [switcher.js](switcher.js)
draws it (no dependencies; copy it next to the module that draws the thing and fill its names); the code of a variant
reads it as `globalThis.localStorage?.getItem("proto-<topic>") || "A"`.

- **Above dialogs.** A modal `<dialog>` lives in the browser's top layer, above any `z-index`: the bar moves into the
  open dialog (switcher.js does it), or the owner has to close the card to switch.
- **Out of the tests.** UI unit tests often load modules without a browser: the bar starts only on the prototype's
  port, and every read of `localStorage` goes through `globalThis.localStorage?.`.
- **Prefixed names.** Top-level names start with `proto`, CSS classes with `proto-`: a name another module has breaks
  it, a plain class name picks up the app's styles.
- Mark every added block with a `PROTOTYPE (proto/<topic>)` comment.

## Choosing the variants

- A is always what there is now; B–D differ in kind (a card, a list, a picture), not in shades of one layout.
- **Things that come due get a time-scale variant**: when what is shown has a date ahead (scheduled runs,
  certificates, renewals), one variant puts them on a strip from «now» to a horizon. The past does not get it.
- Before inventing a variant, look in `patterns/` (if there is one) — kept variants that were good, each with where
  it fits.
- Say which variant you would pick and why; the owner may pick another — a variant liked but not picked may become a
  pattern in `patterns/<name>.md` (ask).

## Check before showing

Open each variant in the preview (a wide window, 1440×900), open its menus, read the console for errors, then run the
UI unit tests — green as on the main branch. Return the preview to variant A and tell the owner the address, what
each letter is (a short table) and which one you would pick and why.

## The end

1. The owner picks (or drops the idea). The decision goes into `docs/plans/ideas.md` in place of the open question (or
   the item goes away) — a document change on the main branch.
2. The real change is a task of its own by the usual process (tests, `make check`, review, the owner's check). The
   prototype's markup may be a reference: save `git diff <main branch>` to `_DOCS/temp/proto-<topic>/`.
3. Remove the launch entry, the worktree and the branch (`git worktree remove`, `git branch -D proto/<topic>` — it
   was never merged on purpose).
