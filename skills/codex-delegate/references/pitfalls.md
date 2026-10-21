# Known pitfalls (from real runs)

## Running Codex from Claude Code
- **Use `run_in_background: true`, not `&`.** With `&`/`nohup` the Bash tool returns at once,
  Claude gets no completion notification, and has to poll for a marker file.
- **Close stdin: always `< /dev/null` (or feed the brief via stdin).** When stdin is a pipe
  that stays open, `codex exec` treats it as extra input and waits forever after printing
  `Reading additional input from stdin...`, even when the prompt was passed as an argument.
  Real case: `( codex exec ... ) & codex exec ...; wait` started two runs that sat idle for
  5 hours without writing a line. `run-codex.sh` feeds the brief via stdin and its watchdog
  aborts this hang after ~60 s (exit 124).
- **Stall detection.** ~1 minute after launch, the run log should be growing. The
  watchdog also aborts if the log stops growing for `--stall-minutes` (default 30).
- **Parallel runs** need separate task names, separate build dirs and caches
  (SwiftPM `--scratch-path .build/<task>` plus per-task `CLANG_MODULE_CACHE_PATH` /
  `SWIFTPM_MODULECACHE_OVERRIDE`), and disjoint file ownership written into each brief.
  Launch each as its own background Bash call, not with `&` + `wait`.
- **`codex` may be a shell function.** Users with several accounts often define
  `codex() { CODEX_HOME=~/.codex-x command codex "$@"; }` in `~/.zshrc`. Claude Code's Bash
  is non-interactive and does not load it, so the wrong account may be used. Pass
  `--codex-home` / export `CODEX_HOME`. `check-setup.sh` detects this.
- **Two `codex` binaries** (npm vs Homebrew) can coexist with different versions;
  `check-setup.sh` lists all of them. Set `CODEX_BIN` to pin one.
- Huge logs: a run log is often 100–300 KB. Don't read it; read the report and the last message.

## Codex `workspace-write` sandbox
- Writable: the `-C` workspace, `/tmp`, `$TMPDIR`, and each `--add-dir`. Everything else is
  read-only, including `~/Library/Caches`, `~/.cache`, global package caches.
- Network is off by default. `-c sandbox_workspace_write.network_access=true` enables it, but
  some proxies/system network paths can still fail. Treat online tests as Claude's job.
- **Reports land in the repo.** Codex sometimes writes the report (or scratch files) at the
  repo root instead of the notes dir. Give an absolute path, say "never in the repo", and
  always check `git status --short` during review.

## Swift / Xcode
- SwiftPM inside the sandbox needs its own sandbox disabled and caches inside the workspace:
  ```bash
  export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
  export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swiftpm-module-cache"
  swift build --disable-sandbox --cache-path .build/swiftpm
  swift test  --disable-sandbox --cache-path .build/swiftpm
  ```
  Put these lines in the brief's "Verified facts".
- `xcodebuild` package resolution writes to `~/.cache/clang/ModuleCache` and
  `~/Library/Caches/org.swift.swiftpm` and fails. Have Codex type-check instead
  (`swiftc -typecheck ...`) and let Claude run `xcodebuild ... -derivedDataPath .build/xcode`
  outside the sandbox.
- `open Foo.app` fails with LaunchServices error `-10827`; GUI launch is Claude's job.
- Private frameworks (e.g. MediaRemote), Apple Events / `osascript` automation, TCC-protected
  APIs fail or behave differently in the sandbox. Verify on the real machine.
- XcodeGen projects: remind Codex to run `xcodegen generate` after adding files.

## Web / Node / Python (general guidance)
- Package installs need `--network`; prefer having dependencies installed before delegating.
- Browsers for e2e tests (Playwright) may need to be pre-installed outside the sandbox.

## Briefs
- Tell Codex what NOT to explore (verified facts) or it will spend 10+ minutes re-reading.
- Put a line limit on the report, or you will pay Claude tokens to read an essay.
- Ask for "what Claude must verify outside the sandbox" explicitly; Codex is honest about it.
