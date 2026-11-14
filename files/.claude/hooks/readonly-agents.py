#!/usr/bin/env python3
"""PreToolUse: keep the read-only subagents read-only.

The agents in GUARDED (and any `*-verifier`) promise in their prompts to change nothing; this hook makes it so.
Claude Code puts `agent_type` into the hook input only inside a subagent, so the main conversation and the agents
that do write (committer, general-purpose, forks) pass untouched. A new read-only agent goes into GUARDED.

For a guarded agent:
- file tools (Edit, Write, MultiEdit, NotebookEdit) are denied;
- a shell command passes only when every command in it is a known reader (READERS, or a checked program:
  git, go, make, sed, find, ...) called without the options that write, and every write (redirection, tee, cp,
  rm, sed -i, ...) goes to /dev/null or a temporary directory. A temporary directory is a /tmp-like path, a
  variable set in the same command from `mktemp` or such a path (`d=$(mktemp -d)`, `$TMPDIR`), or a relative
  path after `cd` into one. A command it cannot classify is denied, and so is its own failure.
- PROBERS (REVIEW.md «Settle a doubt by running it»: a probe in a temp copy) may also run interpreters and tar.
  Those can write anywhere: for them the hook catches mistakes in the shell itself, not in a script.

Project parts to adjust: MAKE_TARGETS (the project's read/test targets), PROBE_TOOLS (its interpreters), and
check() for a project tool an agent needs (a validator, a CLI with a dry-run flag), and UPDATE_FLAG for the
project's own flags that rewrite golden files or snapshots (a fixed list cannot know every plugin's). The cases are in
tests/readonly-agents.sh of the harness template.

This guards against mistakes, not against an agent set on getting around it. Claude Code only (Codex and
Antigravity have no subagents of this kind), so it is not in .codex/hooks.json or .agents/hooks.json.
"""

import json
import os
import re
import sys

GUARDED = {
    "reviewer", "log-reader", "docs-sync", "plan-critic", "code-auditor", "security-auditor", "checker",
    "ui-sweeper", "ui-auditor", "Explore", "Plan",
}
PROBERS = {"reviewer", "code-auditor", "security-auditor"}
PROBE_TOOLS = {"python3", "python", "bash", "sh", "tar", "faketime", "node", "perl"}
WRITE_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
SHELL_TOOLS = {"Bash", "Monitor"}

READERS = {
    "cat", "head", "tail", "wc", "ls", "pwd", "stat", "du", "df", "rg", "grep", "egrep", "fgrep", "which",
    "type", "echo", "printf", "uname", "whoami", "id", "hostname", "basename", "dirname", "realpath",
    "readlink", "cut", "tr", "column", "diff", "cmp", "comm", "jq", "nl", "od", "hexdump", "xxd", "strings",
    "md5", "md5sum", "shasum", "sha256sum", "base64", "true", "false", "test", "[", "[[", "]]", "uniq",
    "tree", "date", "sleep", "ps", "pgrep", "lsof", "pushd", "popd", "read", "wait", "set", "export", "local",
    "printenv", "seq", "rev", "fold", "fmt", "paste", "expand", "file", "less", "more", "govulncheck",
    "mktemp", "exit", "return", "break", "continue", "shift", ":", "trap", "unset",
}
# Words that only open or close a shell construct; the command after them is checked.
KEYWORDS = {"if", "then", "else", "elif", "fi", "do", "done", "while", "until", "{", "}", "!", "time", "esac"}
# Statements whose words are not a command (for x in a b c; case $x in).
SKIP_STATEMENT = {"for", "case", "select", "function"}
WRAPPERS = {"env", "command", "nice", "nohup", "builtin", "exec"}
# Programs that write the paths they are given; behind xargs those paths come from stdin and cannot be checked.
PATH_WRITERS = {"rm", "mv", "cp", "touch", "mkdir", "ln", "tee", "chmod", "chown", "truncate", "install"}
XARGS_DENY = PATH_WRITERS | {"gofmt", "sed", "gsed", "perl"}

GIT_READ = {
    "status", "log", "diff", "show", "blame", "grep", "ls-files", "ls-tree", "rev-parse", "rev-list",
    "cat-file", "describe", "shortlog", "merge-base", "name-rev", "for-each-ref", "whatchanged",
    "check-ignore", "var", "help", "version", "count-objects", "show-ref", "diff-tree", "diff-files",
    "diff-index", "range-diff", "archive",
}
GO_READ = {"doc", "list", "version", "env", "vet", "test", "help"}
MAKE_TARGETS = {"check", "test", "lint"}
NPM_SCRIPTS = {"test", "lint", "typecheck", "check"}
CARGO_READ = {"test", "check", "tree", "metadata", "version", "help"}
TMP_PREFIXES = ("/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/")
TMP_ROOTS = {"/tmp", "/private/tmp"}
DEV_OK = {"/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"}
OPS = (";;", "&&", "||", "|&", "&>>", "&>", ">>", ">&", ">|", "<<<", "<&", "<>", ";", "&", "|", "(", ")", ">", "<")


class Deny(Exception):
    pass


class Ctx:
    def __init__(self, agent):
        self.agent = agent
        self.tmpvars = {"TMPDIR"}
        self.cwd_tmp = False
        self.cwd_stack = []

    def is_tmp(self, path):
        if path in DEV_OK or re.fullmatch(r"&?\d|&?-", path):
            return True
        m = re.match(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?(/|$)", path)
        if m:
            return m.group(1) in self.tmpvars and ".." not in path.split("/")
        if path.startswith(("/", "~", "$")):
            tmpdir = os.environ.get("TMPDIR", "")
            ok = (tmpdir and path.startswith(tmpdir)) or path.startswith(TMP_PREFIXES)
            return bool(ok) and ".." not in path.split("/") and path.rstrip("/") not in TMP_ROOTS
        return self.cwd_tmp and ".." not in path.split("/")


def strip_heredocs(cmd):
    # A heredoc body is data, not commands; the line that opens it stays.
    return re.sub(r"<<-?[ \t]*(['\"]?)(\w+)\1([^\n]*)\n.*?^\t*\2[ \t]*$", r" __HEREDOC__ \3", cmd,
                  flags=re.S | re.M)


def mktemp_is_tmp(body):
    """$(mktemp …) makes a temp path unless given a template or -p outside a temp directory."""
    words = body.split()
    if not words or words[0] != "mktemp":
        return False
    probe, rest = Ctx(""), words[1:]
    for i, w in enumerate(rest):
        if w in ("-p", "--tmpdir") and i + 1 < len(rest) and not probe.is_tmp(rest[i + 1].strip("'\"")):
            return False
        if not w.startswith("-") and (i == 0 or rest[i - 1] not in ("-p", "--tmpdir", "-t")) \
                and not probe.is_tmp(w.strip("'\"")):
            return False
    return True


def split_substitutions(cmd):
    """Return (outer text with $(...)/`...`/<(...) replaced by a word, list of inner commands)."""
    out, inner, i, quote = [], [], 0, None
    while i < len(cmd):
        c = cmd[i]
        if quote == "'":
            out.append(c)
            quote = None if c == "'" else quote
            i += 1
            continue
        if c == "\\" and i + 1 < len(cmd):
            out.append(cmd[i:i + 2])
            i += 2
            continue
        if c == "'" and quote is None:
            quote = "'"
        elif c == '"':
            quote = None if quote == '"' else '"'
        if cmd.startswith("$((", i):  # arithmetic, not a command
            end = cmd.find("))", i)
            if end < 0:
                raise Deny("unbalanced $((")
            out.append("0")
            i = end + 2
            continue
        if cmd.startswith("$(", i) or (c in "<>" and quote is None and cmd.startswith("(", i + 1)):
            depth, j = 1, i + 2
            while j < len(cmd) and depth:
                depth += {"(": 1, ")": -1}.get(cmd[j], 0)
                j += 1
            if depth:
                raise Deny("unbalanced $(")
            body = cmd[i + 2:j - 1]
            inner.append(body)
            word = "__MKTEMP__" if mktemp_is_tmp(body) else "__SUBST__"
            out.append(word if c == "$" else c + " __SUBST__")
            i = j
            continue
        if c == "`":
            j = cmd.find("`", i + 1)
            if j < 0:
                raise Deny("unbalanced backtick")
            inner.append(cmd[i + 1:j])
            out.append("__SUBST__")
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out), inner


def tokens(cmd):
    """Shell words and operators as (text, is_operator); quotes removed, quoted text is never an operator."""
    toks, i, word, has_word = [], 0, [], False
    cmd = cmd.replace("\\\n", " ")

    def end_word():
        nonlocal word, has_word
        if has_word:
            toks.append(("".join(word), False))
        word, has_word = [], False

    while i < len(cmd):
        c = cmd[i]
        if c == "'":
            j = cmd.find("'", i + 1)
            if j < 0:
                raise Deny("unbalanced quote")
            word.append(cmd[i + 1:j])
            has_word, i = True, j + 1
        elif c == '"':
            j, buf = i + 1, []
            while j < len(cmd) and cmd[j] != '"':
                if cmd[j] == "\\" and j + 1 < len(cmd):
                    j += 1
                buf.append(cmd[j])
                j += 1
            if j >= len(cmd):
                raise Deny("unbalanced quote")
            word.append("".join(buf))
            has_word, i = True, j + 1
        elif c == "\\" and i + 1 < len(cmd):
            word.append(cmd[i + 1])
            has_word, i = True, i + 2
        elif c == "\n":
            end_word()
            toks.append((";", True))
            i += 1
        elif c.isspace():
            end_word()
            i += 1
        elif c == "#" and not has_word:
            while i < len(cmd) and cmd[i] != "\n":
                i += 1
        elif c in ";&|()<>":
            if c in "<>" and has_word and "".join(word).isdigit():
                word, has_word = [], False  # 2> — the descriptor number is part of the operator
            else:
                end_word()
            op = next(o for o in OPS if cmd.startswith(o, i))
            toks.append((op, True))
            i += len(op)
        else:
            word.append(c)
            has_word, i = True, i + 1
    end_word()
    return toks


def simple_commands(toks, ctx):
    """Split into simple commands; check redirection targets on the way. Yields lists of words."""
    cur, i = [], 0
    while i < len(toks):
        t, op = toks[i]
        if op and ">" in t:
            target = toks[i + 1][0] if i + 1 < len(toks) and not toks[i + 1][1] else ""
            if not ctx.is_tmp(target):
                raise Deny(f"output redirection to {target!r}: only /dev/null or a temporary directory")
            i += 2
            continue
        if op and t in ("<", "<&", "<<<", "<>"):
            if t == "<>":
                raise Deny("<> opens a file for writing")
            i += 2
            continue
        if op:
            if cur:
                yield cur
            cur = []
            if t == "(":
                ctx.cwd_stack.append(ctx.cwd_tmp)
            elif t == ")" and ctx.cwd_stack:
                ctx.cwd_tmp = ctx.cwd_stack.pop()
        else:
            cur.append(t)
        i += 1
    if cur:
        yield cur


def has_opt(args, *opts):
    for a in args:
        for o in opts:
            if a == o or (o.startswith("--") and a.startswith(o + "=")):
                return True
            if len(o) == 2 and o[0] == "-" and re.fullmatch(r"-[A-Za-z]+", a) and o[1] in a[1:]:
                return True
    return False


def operands(args):
    return [a for a in args if not a.startswith("-")]


def check_git(args, ctx):
    while args and args[0] in ("-C", "-c", "--no-pager", "--git-dir", "--work-tree", "-P"):
        args = args[2:] if args[0] in ("-C", "-c", "--git-dir", "--work-tree") else args[1:]
    if not args:
        return
    sub, rest = args[0], args[1:]
    if sub in GIT_READ:
        for i, a in enumerate(rest):
            if a in ("-o", "--output") and i + 1 < len(rest) and not ctx.is_tmp(rest[i + 1]):
                raise Deny(f"git {sub} {a} writes a file outside a temporary directory")
            if a.startswith("--output=") and not ctx.is_tmp(a.split("=", 1)[1]):
                raise Deny(f"git {sub} --output writes a file outside a temporary directory")
        return
    if sub == "branch" and all(a in ("-a", "-r", "-v", "-vv", "--list", "--show-current", "--all",
                                       "--remotes", "--contains", "--merged", "--no-merged")
                               or a.startswith(("--format", "--sort", "--contains=", "--points-at"))
                               for a in rest):
        return
    if sub == "worktree" and rest[:1] == ["list"]:
        return
    if sub == "stash" and rest[:1] in (["list"], ["show"]):
        return
    if sub == "remote" and (not rest or rest[0] in ("-v", "show", "get-url")):
        return
    if sub == "reflog" and operands(rest)[:1] in ([], ["show"]):
        return
    if sub == "config" and has_opt(rest, "--get", "--get-all", "--list", "-l", "--get-regexp") and not has_opt(
            rest, "--unset", "--unset-all", "--add", "--replace-all", "--rename-section", "--remove-section",
            "--edit", "-e"):
        return
    raise Deny(f"git {sub} changes the repository (allowed: {', '.join(sorted(GIT_READ))}, "
               "branch/stash/worktree listing)")


UPDATE_FLAG = re.compile(r"-+(u|update[\w-]*|[\w-]*snapshot[\w-]*|bless|fix|write|w|output[\w-]*|o)(=.*)?")


def updates_files(args):
    """A test or lint run told to rewrite its inputs: golden files, snapshots, fixes, a report written into the tree."""
    return any(UPDATE_FLAG.fullmatch(a) or (a.startswith("-") and "update" in a.lower()) for a in args)


def check_go(args, ctx):
    sub = args[0] if args else ""
    if sub == "env" and has_opt(args, "-w", "-u"):
        raise Deny("go env -w/-u changes the Go configuration")
    if sub == "run" and ctx.agent in PROBERS:
        return
    if sub == "test" and ("-args" in args or any(a.startswith("-") and "update" in a.lower() for a in args)):
        raise Deny("go test with -args or an update flag can rewrite golden files")
    if sub in GO_READ or sub == "build":
        for i, a in enumerate(args):
            for flag in ("-o", "-coverprofile", "-cpuprofile", "-memprofile", "-blockprofile", "-trace",
                         "-mutexprofile", "-outputdir"):
                if a == flag and i + 1 < len(args) and not ctx.is_tmp(args[i + 1]):
                    raise Deny(f"go {sub} {flag} writes outside a temporary directory")
                if a.startswith(flag + "=") and not ctx.is_tmp(a.split("=", 1)[1]):
                    raise Deny(f"go {sub} {flag} writes outside a temporary directory")
        writes_binary = sub == "build" or (sub == "test" and "-c" in args)
        if writes_binary and "-o" not in args and not ctx.cwd_tmp:
            raise Deny(f"go {sub} writes a binary here: add -o /dev/null (or a temporary path)")
        return
    if sub == "mod" and args[1:2] in (["why"], ["graph"], ["verify"]):
        return
    raise Deny(f"go {sub} is not a read (allowed: {', '.join(sorted(GO_READ))}, build -o /dev/null, mod why/graph)")


def check_sed(args, ctx):
    args = [a for i, a in enumerate(args) if not (a == "" and i > 0 and args[i - 1] == "-i")]
    ops = operands(args)
    script = ops[0] if ops and not has_opt(args, "-e", "-f") else ""
    scripts = [script] + [args[i + 1] for i, a in enumerate(args[:-1]) if a in ("-e", "--expression")]
    for s in scripts:
        # the w/W command or the w flag of s///: writes a file
        if re.search(r"(^|[;{}\n]|^\s*\d*,?\$?\d*|/)\s*[wW]\s+\S", s) or re.search(r"[gpIi0-9]w\s+\S", s):
            raise Deny("sed w writes a file")
    if has_opt(args, "-i", "--in-place") or any(a.startswith("-i") for a in args):
        files = ops[1:] if script else ops
        if not files or not all(ctx.is_tmp(f) for f in files):
            raise Deny("sed -i edits files outside a temporary directory")


def check(argv, ctx):
    while argv and argv[0] in KEYWORDS:
        argv = argv[1:]
    while argv and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", argv[0]):
        name, value = argv[0].split("=", 1)
        if value == "__MKTEMP__" or (value and ctx.is_tmp(value) and not value.startswith("&")):
            ctx.tmpvars.add(name)
        else:
            ctx.tmpvars.discard(name)
        argv = argv[1:]
    if argv and argv[0] in ("for", "select") and len(argv) > 1:
        ctx.tmpvars.discard(argv[1])
    if argv and argv[0] == "read":
        ctx.tmpvars.difference_update(operands(argv[1:]))
    if not argv or argv[0] in SKIP_STATEMENT or argv[0] in ("__SUBST__", "__HEREDOC__", "__MKTEMP__"):
        return
    prog, args = os.path.basename(argv[0]), argv[1:]
    if prog in WRAPPERS:
        while args and (args[0].startswith("-") or "=" in args[0]):
            args = args[1:]
        return check(args, ctx) if args else None
    if prog == "timeout":
        i = 0
        while i < len(args) and args[i].startswith("-"):
            i += 2 if args[i] in ("-s", "-k", "--signal", "--kill-after") else 1
        return check(args[i + 1:], ctx)  # args[i] is the duration
    if prog == "xargs":
        i = 0
        while i < len(args) and args[i].startswith("-"):
            i += 2 if args[i] in ("-I", "-n", "-P", "-L", "-d", "-E", "-s") else 1
        inner = args[i:]
        if inner and os.path.basename(inner[0]) in XARGS_DENY and (
                os.path.basename(inner[0]) in PATH_WRITERS or has_opt(inner[1:], "-w", "-i", "--in-place")
                or any(a.startswith("-i") for a in inner[1:])):
            raise Deny(f"xargs {inner[0]}: the paths come from stdin and cannot be checked")
        return check(inner, ctx) if inner else None
    if prog == "cd":
        target = operands(args)[:1]
        ctx.cwd_tmp = bool(target) and ctx.is_tmp(target[0])
        return
    if ctx.agent in PROBERS and prog in PROBE_TOOLS:
        return
    if prog == "uniq" and len(operands(args)) > 1 and not ctx.is_tmp(operands(args)[1]):
        raise Deny("uniq writes its second operand")
    if prog == "xxd" and has_opt(args, "-r") and len(operands(args)) > 1 and not ctx.is_tmp(operands(args)[-1]):
        raise Deny("xxd -r writes its second operand")
    if prog in ("tree", "base64") and has_opt(args, "-o", "--output"):
        raise Deny(f"{prog} -o writes a file")
    if prog == "mktemp" and not mktemp_is_tmp(" ".join(["mktemp"] + args)):
        raise Deny("mktemp outside a temporary directory creates a file")
    if prog == "trap":
        if len(args) > 1 and args[0] != "-":   # trap <command> <signals>: the command runs later, here
            check_command(args[0], ctx, 1)
        return
    if prog in ("export", "local", "declare", "readonly", "typeset"):
        for a in args:
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", a):
                check([a], ctx)
        return
    if prog in READERS:
        return
    if prog == "journalctl":
        if has_opt(args, "--vacuum-size", "--vacuum-time", "--vacuum-files", "--rotate", "--flush"):
            raise Deny("journalctl maintenance options write")
        return
    if prog == "git":
        return check_git(args, ctx)
    if prog == "go":
        return check_go(args, ctx)
    if prog == "make":
        targets = [a for a in operands(args) if "=" not in a]
        if targets and all(t in MAKE_TARGETS for t in targets):
            return
        raise Deny(f"make {' '.join(targets) or '(default)'}: allowed targets are {', '.join(sorted(MAKE_TARGETS))}")
    if prog in ("sed", "gsed"):
        return check_sed(args, ctx)
    if prog in ("awk", "gawk"):
        if any(re.search(r"system\s*\(|[|>]\s*\"|inplace|\bprintf?\b[^;}]*[>|]|getline\s*<", a) for a in args):
            raise Deny("awk program writes files or runs commands")
        return
    if prog == "sort":
        if has_opt(args, "-o", "--output", "--compress-program"):
            raise Deny("sort -o writes a file")
        return
    if prog == "find":
        bad = {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprint0", "-fprintf", "-fls"}
        if bad & set(args):
            raise Deny("find -exec/-delete runs or deletes: list with find, then read with rg/cat")
        return
    if prog == "fd":
        if has_opt(args, "-x", "-X", "--exec", "--exec-batch"):
            raise Deny("fd --exec runs commands")
        return
    if prog == "cp":  # copying out of the repository is a read; only the destination must be temporary
        dest = operands(args)[-1:]
        if dest and ctx.is_tmp(dest[0]) and not has_opt(args, "-t", "--target-directory"):
            return
        raise Deny("cp into a non-temporary directory changes files")
    if prog in PATH_WRITERS:
        paths = operands(args)
        if prog in ("chmod", "chown"):
            paths = paths[1:]
        if paths and all(ctx.is_tmp(p) for p in paths):
            return
        raise Deny(f"{prog} outside a temporary directory changes files")
    if prog == "gofmt":
        files = operands(args)
        if has_opt(args, "-w") and not (files and all(ctx.is_tmp(p) for p in files)):
            raise Deny("gofmt -w rewrites files: use gofmt -l / -d")
        return
    if prog == "golangci-lint":
        if args[:1] == ["run"] and not has_opt(args, "--fix"):
            return
        raise Deny("golangci-lint: only `run` without --fix")
    if prog == "node":
        if has_opt(args, "--test", "--check", "--version"):
            return
        raise Deny("node: only --test or --check")
    if prog == "sqlite3":
        if has_opt(args, "-readonly"):
            return
        raise Deny("sqlite3 only with -readonly: sqlite3 -readonly <file> '…'")
    if prog == "npm":
        ops = operands(args)
        if "--" in args or updates_files(args):
            raise Deny("npm: arguments passed on to the script (--fix, -u, an output file) can write; run the bare script")
        if ops[:1] in (["test"], ["t"], ["ls"], ["outdated"], ["view"]) or (
                ops[:1] == ["run"] and ops[1:2] and ops[1] in NPM_SCRIPTS) or (
                ops[:1] == ["audit"] and "fix" not in ops):
            return
        raise Deny(f"npm: only test, ls, audit, run {'/'.join(sorted(NPM_SCRIPTS))}")
    if prog in ("pytest", "mypy"):
        if updates_files(args) or any(re.match(r"--(junit|html|json-report|cov-report|result-log|[\w-]*-report)", a)
                                      for a in args):
            raise Deny(f"{prog}: report and update options write files; run it without them")
        return
    if prog == "ruff":
        sub = operands(args)[:1]
        if sub == ["check"] and not has_opt(args, "--fix", "--unsafe-fixes", "--add-noqa", "-w", "--watch"):
            return
        if sub == ["format"] and has_opt(args, "--check", "--diff"):
            return
        raise Deny("ruff: only `check` without --fix, `format --check` / `--diff`")
    if prog in ("prettier", "eslint", "tsc", "biome"):
        if prog == "prettier" and has_opt(args, "--check", "-c", "--list-different", "-l") \
                and not has_opt(args, "--write", "-w"):
            return
        if prog == "eslint" and not has_opt(args, "--fix", "--fix-dry-run", "-o", "--output-file", "--cache"):
            return
        if prog == "tsc" and has_opt(args, "--noEmit"):
            return
        if prog == "biome" and operands(args)[:1] in (["check"], ["lint"], ["ci"]) \
                and not has_opt(args, "--write", "--fix", "--apply", "--apply-unsafe"):
            return
        raise Deny(f"{prog}: only checks (prettier --check, eslint without --fix, tsc --noEmit, biome check)")
    if prog == "cargo":
        if updates_files(args) and not (operands(args)[:1] == ["fmt"] and "--check" in args):
            raise Deny("cargo: --fix, --bless or an update flag rewrites files")
        sub = operands(args)[:1]
        if sub and sub[0] in CARGO_READ:
            return
        if sub == ["clippy"] and not has_opt(args, "--fix"):
            return
        if sub == ["fmt"] and "--check" in args:
            return
        raise Deny(f"cargo: only {', '.join(sorted(CARGO_READ))}, clippy without --fix, fmt --check")
    if prog in ("bash", "sh", "zsh"):
        if has_opt(args, "-n") or args[:1] == ["scripts/check.sh"]:
            return
        raise Deny(f"{prog}: only -n (syntax) or scripts/check.sh")
    if prog == "curl":
        if has_opt(args, "-o", "-O", "--output", "--remote-name", "-T", "--upload-file", "-D", "--dump-header",
                   "-c", "--cookie-jar"):
            raise Deny("curl writes a file: print to stdout instead")
        return
    raise Deny(f"{prog!r} is not on the read-only list of this agent")


def check_command(cmd, ctx, depth=0):
    if depth > 5:
        raise Deny("command substitution nested too deep")
    outer, inner = split_substitutions(strip_heredocs(cmd))
    for sub in inner:
        saved = ctx.cwd_tmp
        check_command(sub, ctx, depth + 1)
        ctx.cwd_tmp = saved
    for argv in simple_commands(tokens(outer), ctx):
        check(argv, ctx)


def deny(reason, agent):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            f"Read-only agent {agent}: {reason}. You change nothing in the repository: read with rg/cat/git log, "
            "run make check/test; scratch files only in a temporary directory, e.g. "
            "d=$(mktemp -d) in the same command, then \"$d/…\". If the task truly needs this command, say so in "
            "your report instead of working around this hook."),
    }}))
    sys.exit(0)


def main():
    data = json.load(sys.stdin)
    agent = data.get("agent_type") or ""
    if agent not in GUARDED and not agent.endswith("-verifier"):
        return
    tool = data.get("tool_name", "")
    try:
        if tool in WRITE_TOOLS:
            raise Deny(f"{tool} edits files")
        if tool in SHELL_TOOLS:
            check_command(data.get("tool_input", {}).get("command", ""), Ctx(agent))
    except Deny as e:
        deny(str(e), agent)
    except Exception as e:  # the guard fails closed
        deny(f"the guard could not check this command ({type(e).__name__}: {e})", agent)


if __name__ == "__main__":
    main()
