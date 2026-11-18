#!/usr/bin/env python3
"""PreToolUse(Bash): rules of AGENTS.md that a shell command can break, enforced instead of only written.

Every simple command is checked: after `;`, `&&`, `||`, `|`, inside `$(...)`, backticks, `bash -c '…'` and `eval`,
behind `sudo`/`env`/`timeout`/`xargs`.

- G1 deny  — reading or writing a secret file (`.env`, `.env.*` but ENV_NOT_SECRET, and PROJECT_SECRETS):
  «Do not touch without an explicit request». Naming such a path in `ls`, `test`, `stat`, `echo` or as an `rg`
  pattern passes. A command that names no such path but reads a directory (`rg -uu x secrets/`) is not seen: this
  guards against mistakes, not against an agent set on getting around it. The Read and Edit tools are closed by
  `deny` in .claude/settings.json (keep the two lists in step).
- G2 ask   — `git stash` (but `list`/`show`): hides the owner's uncommitted work.
- G3 ask   — `git reset --hard`: wipes it.
- G4 ask   — `git checkout -- <path>` / `checkout .` / `checkout -f`, `git restore` of the working tree,
  `git clean -f`, `git switch -f`: discard it.
- G5 deny  — force push (`-f`, `--force*`, `--mirror`, `+<ref>`): rewrites history on the server.
- G6 ask   — `git add -A`/`.`/`-u`, `git commit -a`: sweeps the owner's changes into a commit.

«ask» lets the owner approve it in the prompt; with HOOK_ASK_AS_DENY=1 (Codex and Antigravity: no prompt from a hook)
it is a deny.
Each decision goes to the hook journal (journal.sh), without the command text. A command the parser cannot read
passes unless its raw text names a secret path (the other hooks and permission rules still apply).
Tests: .claude/hooks/test_hooks.py (`make check`). Needs python3; readonly-agents.py next to it gives the parser.
"""

import importlib.util
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("readonly_agents", os.path.join(HERE, "readonly-agents.py"))
ra = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ra)

# `.env.<suffix>` files that hold no secret and that agents read (examples; a deploy config without keys).
ENV_NOT_SECRET = ("example", "sample", "template")
# The project's other secret files: regular expressions matched against the end of a path, e.g. r"\.vault_credentials",
# r"secrets\.ya?ml", r"host_vars(?:/.*)?", r"[^/]*\.pem". {{FILL: the project's key, vault and credential files from
# «Do not touch» in AGENTS.md, with a deny case for each in test_hooks.py — or leave the list empty.}}
PROJECT_SECRETS = []
SECRET = re.compile(
    r"(?:^|/)(?:\.env(?:\.(?!(?:" + "|".join(re.escape(s) for s in ENV_NOT_SECRET) + r")$)[^/]*|\*)?"
    + "".join("|(?:" + p + ")" for p in PROJECT_SECRETS) + r")$")
# Options whose value is text, not a path: a pattern, a glob, a count, a message, a title. A short option may end a
# cluster (`-nA 3`). Absent here, -f/--file of rg and grep and -F/--file of git commit and gh stay checked: they read
# the file. Keyed by program; git and gh by the program, whatever the subcommand.
TEXT_VALUE = {
    "rg": ("gtTAmMBCdjrEe", {"--glob", "--iglob", "--type", "--type-not", "--type-add", "--after-context",
                             "--before-context", "--context", "--max-count", "--max-columns", "--max-depth",
                             "--threads", "--replace", "--encoding", "--sort", "--sortr", "--colors", "--regexp",
                             "--context-separator", "--field-match-separator", "--engine"}),
    "grep": ("ABCmedD", {"--after-context", "--before-context", "--context", "--max-count", "--regexp", "--include",
                         "--exclude", "--exclude-dir", "--directories", "--devices", "--label", "--color"}),
    "git": ("mSGe", {"--message", "--grep", "--author", "--committer", "--format", "--pretty", "--since", "--until",
                     "--notes", "--trailer"}),
    "gh": ("bmtqjS", {"--body", "--title", "--message", "--jq", "--template", "--search", "--query"}),
}
TEXT_VALUE["egrep"] = TEXT_VALUE["fgrep"] = TEXT_VALUE["grep"]
# Options that give the pattern, so the first operand is a path.
PATTERN_OPTS = {"-e", "--regexp", "-f", "--file"}
# Programs that only name a path, never read it.
NAMES_ONLY = {"ls", "test", "[", "[[", "stat", "echo", "printf", "du", "which", "basename", "dirname",
              "realpath", "readlink", "file"}
WRAPPERS = {"sudo", "env", "command", "nice", "nohup", "builtin", "exec", "time"}
# Options of each wrapper whose value is a separate word (sudo -u me, env -u VAR, nice -n 5, xargs -I {}); the
# other options of a wrapper take none (sudo -n, xargs -r).
WRAPPER_VALUE_OPTS = {
    "sudo": {"-u", "-g", "-h", "-p", "-C", "-D", "-U", "-r", "-t", "-R", "-T"},
    "env": {"-u", "-C", "-S", "-P"},
    "nice": {"-n"},
    "xargs": {"-I", "-L", "-P", "-s", "-n", "-d", "-E", "-a", "-J", "-R", "-S"},
}
SHELLS = {"bash", "sh", "zsh"}
STOP = "Do not rephrase the command or look for a way around this hook: tell the owner, they will run it themselves."


class Hit(Exception):
    def __init__(self, rule, decision, reason):
        super().__init__(reason)
        self.rule, self.decision, self.reason = rule, decision, reason


def has_opt(args, *opts):
    return ra.has_opt(args, *opts)


def operands(args):
    return [a for a in args if not a.startswith("-")]


def path_words(prog, args):
    """The arguments that may be paths: without the values of text options, the search pattern, or words with a
    space (a message is text, a path in this repository has no space)."""
    short, long_ = TEXT_VALUE.get(prog, ("", set()))
    sub = git_sub(args)[:1] if prog == "git" else []
    out, i, pattern_given = [], 0, False
    while i < len(args):
        a = args[i]
        i += 1
        if any(c.isspace() for c in a):
            continue
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            pattern_given |= name in PATTERN_OPTS
            if name in long_:
                i += "=" not in a
                continue
        elif re.fullmatch(r"-[A-Za-z]+", a):
            pattern_given |= ("-" + a[-1]) in PATTERN_OPTS
            if a[-1] in short:
                i += 1
                continue
        elif re.fullmatch(r"-[A-Za-z].+", a):  # an attached value: -A3 is text, -F.env a path
            pattern_given |= a[:2] in PATTERN_OPTS
            if a[1] in short:
                continue
            a = a[2:]
        out.append(a)
    if prog in ("rg", "grep", "egrep", "fgrep") or sub == ["grep"]:
        ops = [w for w in out if not w.startswith("-") and w != "grep"]
        if not pattern_given and ops:
            out.remove(ops[0])
    return out


def check_secret_words(prog, args, redirects):
    words = list(redirects)
    if prog not in NAMES_ONLY:
        words += path_words(prog, args)
    for w in words:
        for part in w.split("="):  # --file=.env, KEY=.env, f=@.env (gh api)
            part = part.lstrip("@")
            if SECRET.search(part.rstrip("/")):
                raise Hit("G1", "deny", f"{part!r} is a secret file (AGENTS.md «Do not touch without an explicit "
                                        "request»): its content must not reach the chat or change. " + STOP)


def git_sub(args):
    """The git arguments from the subcommand on, without the global options."""
    while args and args[0].startswith("-"):
        args = args[2:] if args[0] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace") else args[1:]
    return args


def check_git(args, cwd):
    args = git_sub(args)
    if not args:
        return
    sub, rest = args[0], args[1:]
    keep = "It would lose uncommitted changes, and those may be the owner's (AGENTS.md «Session start»). " \
           "Undo your own edits with the Edit tool instead. "
    if sub == "stash" and rest[:1] not in (["list"], ["show"]):
        raise Hit("G2", "ask", "git stash hides the working tree changes. " + keep + STOP)
    if sub == "reset" and has_opt(rest, "--hard"):
        raise Hit("G3", "ask", "git reset --hard. " + keep + STOP)
    if sub == "checkout":
        paths = rest[rest.index("--") + 1:] if "--" in rest else \
            [a for a in operands(rest) if a == "." or os.path.exists(os.path.join(cwd, a))]
        if paths or has_opt(rest, "-f", "--force"):
            raise Hit("G4", "ask", "git checkout of paths (or -f) overwrites the working tree. " + keep + STOP)
    if sub == "restore" and (has_opt(rest, "-W", "--worktree") or not has_opt(rest, "-S", "--staged")):
        raise Hit("G4", "ask", "git restore overwrites the working tree (--staged alone only unstages). "
                  + keep + STOP)
    if sub == "clean" and has_opt(rest, "-f", "--force") and not has_opt(rest, "-n", "--dry-run"):
        raise Hit("G4", "ask", "git clean -f deletes untracked files (git clean -n lists them). " + keep + STOP)
    if sub == "switch" and has_opt(rest, "-f", "--force", "--discard-changes"):
        raise Hit("G4", "ask", "git switch --force discards local changes. " + keep + STOP)
    if sub == "push" and (has_opt(rest, "-f", "--force", "--force-with-lease", "--force-if-includes", "--mirror")
                          or any(a.startswith("+") for a in operands(rest))):
        raise Hit("G5", "deny", "A force push rewrites history on the server (AGENTS.md: git push only on "
                                "request, never forced). " + STOP)
    if sub == "add" and (has_opt(rest, "-A", "--all", "-u", "--update")
                         or any(a in (".", "./", ":/", "*", ":(top)") for a in operands(rest))):
        raise Hit("G6", "ask", "git add of everything sweeps the owner's uncommitted work into the commit. Stage the "
                               "task's files by name: git add <path> …. " + STOP)
    if sub == "commit" and has_opt(rest, "-a", "--all"):
        raise Hit("G6", "ask", "git commit -a commits every changed file, the owner's too. Stage the task's files "
                               "by name and commit without -a. " + STOP)


def check_argv(argv, redirects, cwd, depth, hits):
    try:
        _check_argv(argv, redirects, cwd, depth, hits)
    except Hit as h:
        hits.append(h)


def _check_argv(argv, redirects, cwd, depth, hits):
    while argv and (argv[0] in ra.KEYWORDS or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", argv[0])):
        if "=" in argv[0]:
            check_secret_words("", [argv[0].split("=", 1)[1]], [])
        argv = argv[1:]
    if not argv or argv[0] in ra.SKIP_STATEMENT:
        check_secret_words("", [], redirects)
        return
    prog, args = os.path.basename(argv[0]), argv[1:]
    if prog in WRAPPERS or prog == "xargs":
        while args and (args[0].startswith("-") or "=" in args[0]):
            if prog == "xargs" and args[0].startswith("-a"):  # xargs -a <file> reads its input from the file
                check_secret_words("", [args[0][2:] or (args[1:] or [""])[0]], [])
            args = args[2:] if args[0] in WRAPPER_VALUE_OPTS.get(prog, ()) else args[1:]
        return _check_argv(args, redirects, cwd, depth, hits)
    if prog == "timeout":
        while args and args[0].startswith("-"):
            args = args[2:] if args[0] in ("-s", "-k", "--signal", "--kill-after") else args[1:]
        return _check_argv(args[1:], redirects, cwd, depth, hits)
    if prog in SHELLS and "-c" in args[:-1]:
        check_secret_words("", [], redirects)
        return check_text(args[args.index("-c") + 1], cwd, hits, depth + 1)
    if prog == "eval":
        return check_text(" ".join(args), cwd, hits, depth + 1)
    check_secret_words(prog, args, redirects)
    if prog == "git":
        check_git(args, cwd)


def check_text(cmd, cwd, hits, depth=0):
    if depth > 5:
        return
    outer, inner = ra.split_substitutions(ra.strip_heredocs(cmd))
    for sub in inner:
        check_text(sub, cwd, hits, depth + 1)
    argv, redirects, toks, i = [], [], ra.tokens(outer), 0
    while i < len(toks):
        t, op = toks[i]
        if op and t in ("<", "<<<", "<>", ">", ">>", ">|", "&>", "&>>"):
            if i + 1 < len(toks) and not toks[i + 1][1]:
                redirects.append(toks[i + 1][0])
            i += 2
            continue
        if op and t in (">&", "<&"):  # 2>&1
            i += 2
            continue
        if op:
            check_argv(argv, redirects, cwd, depth, hits)
            argv, redirects = [], []
        else:
            argv.append(t)
        i += 1
    check_argv(argv, redirects, cwd, depth, hits)


def decide(cmd, cwd):
    """The first deny, else the first ask, else None. Exposed for the tests."""
    hits = []
    try:
        check_text(cmd, cwd, hits)
    except ra.Deny:  # unbalanced quote or $(: the parser cannot read it
        for w in re.split(r"[\s'\"`;&|()<>]+", cmd):
            if SECRET.search(w.rstrip("/")):
                hits.append(Hit("G1", "deny", f"{w!r} looks like a secret file and the command cannot be "
                                              "parsed. " + STOP))
                break
    hits.sort(key=lambda h: h.decision != "deny")
    return hits[0] if hits else None


def main():
    raw = sys.stdin.read()
    data = json.loads(raw or "{}")
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd:
        return
    hit = decide(cmd, data.get("cwd") or os.getcwd())
    if not hit:
        return
    decision = "deny" if hit.decision == "ask" and os.environ.get("HOOK_ASK_AS_DENY") == "1" else hit.decision
    subprocess.run(["bash", os.path.join(HERE, "journal.sh"), hit.rule, decision], input=raw, text=True,
                   check=False)
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": f"git-guard {hit.rule}: {hit.reason}",
    }}))


if __name__ == "__main__":
    main()
