---
name: codex-delegate
description: Save Claude usage by acting as architect and reviewer while the local Codex CLI (`codex exec`) writes the code, builds, and runs tests. Use when the user wants to save Claude quota/tokens/credits, says "let Codex do it", "delegate to Codex", "Claude plans, Codex codes", "you be the lead/conductor", or asks to hand implementation work to Codex. Covers task-brief writing, running Codex in the background with completion notification, reading its short report, verifying outside the sandbox, and committing.
---

# Codex Delegate: Claude directs, Codex builds

Claude's tokens are the scarce resource. Spend them on judgment (architecture, design,
briefs, review, decisions) and let Codex CLI spend its own tokens on the bulk work
(reading many files, editing, writing tests, build/test loops).

## 0. Preflight (once per session)

Run `scripts/check-setup.sh` (path relative to this skill's directory). It checks that
`codex` is installed and logged in, whether `codex` is a shell function/alias that sets
`CODEX_HOME` (non-interactive shells do not see shell functions), and that `git` exists.
If Codex is missing, tell the user to install it (`npm i -g @openai/codex` or
`brew install codex`) and run `codex login`; do not install it for them unasked.

## 1. Decide: delegate or do it yourself

| Do it yourself (Claude) | Delegate to Codex |
|---|---|
| 1–2 line fixes, renames, config tweaks | New features, multi-file changes, refactors |
| Questions, explanations, decisions | Writing/expanding tests, fixing failing tests |
| Writing the brief, reviewing the result | Build-fix loops, migrations, boilerplate |
| Anything needing the user's live context | Exploratory reading of a large codebase |

Rule of thumb: if writing the brief costs more than the change, just make the change.
Claude keeps ownership of: architecture, API/UX design, trade-offs, acceptance, commits.

## 2. Write the brief

Copy `templates/brief.md` and fill it in. Save it to a **notes directory outside the repo**
(e.g. a scratchpad or shared notes folder), as `<notes>/brief-<task>.md`. A good brief:

- **Hard constraints first**: the user's global no-go rules (copy them verbatim from their
  CLAUDE.md / AGENTS.md), files that must not be touched, "do not commit", "do not edit
  memory/notes files", no new dependencies unless listed.
- **Verified facts**: what you already know (paths, APIs, commands that work, known
  sandbox failures). This stops Codex from re-exploring and burning time.
- **Concrete spec**: what to build, file names, function signatures, UX details. Vague
  briefs produce vague code; precise briefs make review cheap.
- **Verification**: exact commands Codex should run inside its sandbox, and which checks
  it should leave for Claude (things that fail in the sandbox, see `references/pitfalls.md`).
- **Report contract**: absolute path of the report file (in the notes dir, **never in the
  repo**), a hard line limit (10–25 lines), and the format: done / not done / commands run
  with results / what Claude must verify outside the sandbox.

Write the brief in whatever language the user works in; Codex handles any language.

## 3. Run Codex in the background

```bash
<skill-dir>/scripts/run-codex.sh --repo <repo> --notes <notes-dir> --name <task> \
  --brief <notes-dir>/brief-<task>.md [--network] [--codex-home <dir>]
```

Call it with the Bash tool and **`run_in_background: true`**. Claude Code notifies you when
it exits; meanwhile you can keep talking with the user or do other work.

- **Never** background it with `&`, `nohup` or `disown`. The Bash tool then returns at once,
  you get no completion notification, and you end up polling for a file.
- The script wraps the proven command:
  `codex exec -C <repo> -s workspace-write [-c sandbox_workspace_write.network_access=true] --add-dir <notes> -o <notes>/last-<task>.txt - < brief > <notes>/run-<task>.log 2>&1`
  It feeds the brief through stdin (no quoting issues, and no hang on
  "Reading additional input from stdin"), writes `<notes>/<task>.done` with the exit code,
  and prints Codex's last message plus `git status --short` of the repo.
- **stdin must never be left open.** If you ever call `codex exec` directly with the prompt
  as an argument, always append `< /dev/null`. Without it, when stdin is a pipe that never
  closes, Codex waits on it forever after printing "Reading additional input from stdin..."
  (real case: two parallel runs sat idle for 5 hours without writing a line).
- **Stall check:** about a minute after launch, check that `run-<task>.log` is growing and
  does not end with "Reading additional input from stdin...". The script also has a watchdog:
  it aborts with exit code 124 if the log stops growing for `--stall-minutes` (default 30,
  `0` disables) and fails fast on the stdin hang.
- `--network` only when the task truly needs it (package installs, online tests).
- If the user runs `codex` through a shell function that sets `CODEX_HOME` (multiple
  accounts), pass `--codex-home` or export `CODEX_HOME`; check-setup prints the value.
- Do not read `run-<task>.log` unless something failed; it is large. Use `tail -40` if needed.

### Running several Codex tasks in parallel

- One `run-codex.sh` call per task, each its own Bash call with `run_in_background: true`.
  Never chain them in one command with `&` and `wait`.
- Give each task a distinct `--name`, so logs, reports and `.done` files don't collide.
- Split file ownership explicitly: each brief lists the files that task owns and says
  "do not edit files owned by the other task: <list>". Overlapping files → run sequentially.
- Isolate build state per task, e.g. for SwiftPM:
  `--scratch-path .build/<task>`, `CLANG_MODULE_CACHE_PATH=$PWD/.build/<task>/clang-module-cache`,
  `SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.build/<task>/swiftpm-module-cache`. Do the same for
  other tools with a shared build/cache directory (separate `node_modules/.cache`, `target/` dirs).
- Review and commit each task separately, after both have finished.

## 4. Review and accept

1. Read the script's output (Codex's last message) and the report file. Read conclusions,
   not the log.
2. Check `git status --short`: unexpected files? Did Codex drop its report or scratch files
   into the repo? Move/delete them before committing. Did it touch forbidden paths?
3. Skim `git diff --stat`, then read the diff of the critical parts only (public APIs,
   concurrency, security-sensitive code, anything the report flags as uncertain).
4. Run the key verification yourself **outside** the Codex sandbox: the real build, the test
   suite, launching the app — especially everything the report says failed in the sandbox.
5. Decide:
   - Pass → commit (Claude commits, with the user's normal commit conventions).
   - Small defects → fix them yourself if it is a few lines.
   - Larger defects → write a short follow-up brief ("fix-<task>") that lists the exact
     failures and expected behavior, and run Codex again. Reference the previous report
     rather than repeating the whole brief.
6. Record durable conclusions (decisions, pitfalls) wherever the project keeps its memory.

## 5. UI work without burning Claude tokens

Screenshots are expensive for Claude. Have Codex render previews and self-check against a
checklist, and return only final small images plus a pass/fail line per item.
See `references/ui-review.md` for the brief section to paste (Xcode MCP / ImageRenderer for
SwiftUI, Playwright screenshots for web).

## 6. Known pitfalls

Read `references/pitfalls.md` before writing a brief for Swift/Xcode, GUI apps, or anything
needing network. Short version: the Codex `workspace-write` sandbox blocks writes outside
the workspace (global caches), LaunchServices, Apple Events/private frameworks, and usually
network; Codex sometimes writes the report into the repo; builds that resolve packages often
fail there. Plan for Claude to re-run those checks outside the sandbox.
