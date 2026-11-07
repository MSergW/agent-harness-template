---
name: session-title
description: Use only when the user explicitly asks to rename or retitle the current session or conversation (e.g. «/session-title», «переименуй сессию»). Proposes a short title from what the session actually became and sets it where the tool allows. Do not trigger on your own.
disable-model-invocation: true
model: haiku
---

# Session title

Goal: the user finds this session weeks later by its title. The title says what the session **ended up** doing, not
the message it started with (a session that began with «gateway alerts» and produced two plans is titled by the plans).

1. Read the conversation, not the code. Take the outcome: the plans, commits, decisions or findings it produced; if
   there are several, name the main one and the cause it grew from in brackets.
2. Write one title: the user's language, at most ~60 characters, nouns first, no quotes, no date, no «Обсуждение…»,
   no ending period. Project terms as the project writes them (`GLOSSARY.md` if there is one). An argument passed to
   the skill is the user's own title or a hint — use it as given or build on it.
3. Set it:
   - **Claude Code desktop app:** the session tool that renames this session (`set_session_title` with
     `session_id: "self"`; load it first if it is deferred). If the user set the current title themselves, the app
     asks them to approve the new one.
   - **Claude Code in a terminal:** the user runs the built-in `/rename <title>`; give the command ready to copy.
   - **Codex:** rename the current thread itself.
   - **Antigravity (IDE and app), other tools:** the agent cannot rename the session; print the title for the user to
     paste into the tool's own rename.
4. Answer in one line: the old title → the new one (or the title to paste), nothing else.

A subagent cannot rename the session it runs in: this skill runs in the session itself, never delegated.
