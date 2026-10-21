# Codex task <NAME>: <one-line goal>

Repo: <absolute repo path>  (work only inside it, plus the notes dir below)
Notes dir: <absolute notes path>  (outside the repo)

## Hard constraints (highest priority)
- <Copy the user's global no-go rules verbatim, e.g. "Never touch <tool X>: do not read or change its config, do not disable proxies or change proxy env vars.">
- Do NOT commit, push, create branches, or rewrite git history.
- Do NOT edit memory/notes files: <e.g. .agent-memory/, CLAUDE.md, AGENTS.md>.
- Only change: <files/dirs>. Do not touch: <files/dirs>.
- No new dependencies unless listed here: <list or "none">.

## Background
<2–5 lines: what the project is, why this task exists.>

## Verified facts (do not re-investigate)
- <Key paths, types, entry points.>
- <Commands that are known to work, e.g. `swift test --disable-sandbox ...`.>
- <Things known to fail in your sandbox; skip them and leave them to Claude.>

## What to do
1. <Precise step, with file names / signatures / behavior.>
2. <...>
Out of scope: <what NOT to do, to stop scope creep.>

## Verification (inside your sandbox)
- <exact build/test/lint commands> must pass.
- Leave for Claude (fails in sandbox): <e.g. xcodebuild with package resolution, launching the app, network calls>.

## Report
Write the report ONLY to `<notes>/report-<NAME>.md` (absolute path; NEVER inside the repo), at most <N> lines:
- Done / not done (one line each)
- Files changed
- Commands run and their result (pass/fail, counts)
- What Claude must verify outside the sandbox
- Open questions or risks
Keep your final chat message to 3–5 lines; the report is the source of truth.
