# codex-delegate

**Claude directs, Codex builds.** A Claude Code skill for when your Claude usage is tight:
Claude does the architecture, design, task briefs, review and key decisions, and hands the
token-heavy work (coding, refactoring, writing tests, build/test loops) to the
[Codex CLI](https://github.com/openai/codex) running on your machine.

[中文说明](README.zh-CN.md)

## Why

Most of the tokens in a coding session go to reading files, editing, and iterating on
build and test failures. Judgment (what to build, how, and whether the result is right) takes far fewer.
This skill splits the work along that line:

| Claude (scarce tokens) | Codex CLI (its own quota) |
|---|---|
| Architecture, design, trade-offs | Implementation, refactors |
| Writes a precise brief | Writes tests, runs build/test loops |
| Reads a ≤ 25-line report | Writes the report |
| Verifies outside the sandbox, commits | Never commits |

Small changes (one or two lines) are still done by Claude directly, because writing a brief would cost more.

## How it works

```
 you ──► Claude: plan + brief ──► run-codex.sh (background) ──► codex exec (workspace-write sandbox)
                                                               │ edits repo, runs tests
 Claude ◄── completion notification ◄── last message + report + git status
   └─► verify build/tests/app outside the sandbox ─► commit, or a short follow-up brief
```

- The brief template puts **hard constraints** first (your global no-go rules, "don't commit",
  "don't edit memory files"), then **verified facts** so Codex doesn't re-explore, then a precise
  spec, verification commands, and a **report contract** (path outside the repo, line limit).
- `run-codex.sh` runs `codex exec` in the foreground of a Claude Code **background** Bash task,
  so Claude gets a completion notification instead of polling.
- Claude reads only the conclusions, checks `git status` for stray files, re-runs what the
  sandbox can't do (e.g. `xcodebuild`, launching GUI apps, network), then commits.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (CLI, desktop app or IDE extension)
- Codex CLI, logged in:
  ```bash
  npm i -g @openai/codex
  ```
  ```bash
  codex login
  ```
  (or `brew install codex`)
- `git`, `bash`. Tested on macOS; the scripts are POSIX-ish bash and should work on Linux.

Check your setup (read-only):
```bash
skills/codex-delegate/scripts/check-setup.sh
```
It also detects when `codex` is a shell function/alias that sets `CODEX_HOME` (common with
multiple accounts), which Claude Code's non-interactive shell would not load.

## Install

**As a plugin (recommended)**, inside Claude Code:
```
/plugin marketplace add LeiZiKang/codex-delegate
/plugin install codex-delegate@codex-delegate
```

**As a plain skill**, copy the skill folder into your personal skills:
```bash
git clone https://github.com/LeiZiKang/codex-delegate
```
```bash
cp -R codex-delegate/skills/codex-delegate ~/.claude/skills/
```
(or into `<project>/.claude/skills/` for one project).

## Usage

Just say it in Claude Code, for example:

- "My Claude quota is low. You plan, let Codex write the code."
- "Delegate the settings page to Codex and review what it does."
- "Use codex-delegate for this refactor."

Claude will then:
1. Run the preflight check.
2. Write a brief from `templates/brief.md` into a notes folder outside your repo.
3. Run `scripts/run-codex.sh --repo … --notes … --brief …` as a background task.
4. On completion, read Codex's short report, check `git status`, run the real build/tests,
   and commit only after it passes, or send a short follow-up brief.

### run-codex.sh

```
run-codex.sh --repo DIR --notes DIR --brief FILE [--name TASK]
             [--network] [--codex-home DIR] [--model M] [--stall-minutes N]
             [-- EXTRA_CODEX_ARGS...]
```
Writes `run-<task>.log`, `last-<task>.txt` and `<task>.done` (exit code) into the notes dir,
then prints Codex's last message, its token usage and `git status --short`.

## What's inside

```
.claude-plugin/          plugin.json + marketplace.json
skills/codex-delegate/
  SKILL.md               the workflow Claude follows
  templates/brief.md     task brief template
  references/pitfalls.md sandbox and tooling pitfalls from real projects
  references/ui-review.md render-and-self-check loop for UI work
  scripts/run-codex.sh   runs one Codex task, prints the result
  scripts/check-setup.sh preflight (read-only)
examples/                a real brief + Codex report from the demo run
```

## Lessons baked in

- Don't background with `&`: you lose the completion notification. Use Claude Code's
  `run_in_background`.
- `codex exec` waits on an open stdin pipe forever ("Reading additional input from stdin...";
  two parallel runs once idled 5 hours). Always `< /dev/null` or feed the brief via stdin; the
  script also has a watchdog that aborts stalled runs (exit 124).
- Parallel runs: one background task each, disjoint files, separate build dirs and caches.
- In Codex's `workspace-write` sandbox, SwiftPM needs `--disable-sandbox` and module caches
  inside the repo; `xcodebuild` package resolution, LaunchServices (`open` → `-10827`),
  private frameworks, Apple Events and often the network fail. Claude re-checks those outside.
- Codex sometimes writes the report into the repo. The brief says "never in the repo" and
  review always checks `git status`.
- For UI, Codex renders previews (Xcode MCP `xcrun mcpbridge` or SwiftUI `ImageRenderer`),
  self-checks against a list, and returns only final small images and pass/fail lines.

## Safety

Codex runs with `-s workspace-write`: it can write only to the repo, the notes dir and
temp dirs. Network is off unless you pass `--network`. The skill never uses
`--dangerously-bypass-approvals-and-sandbox`. Review the diff before committing; Claude does.

## License

MIT
