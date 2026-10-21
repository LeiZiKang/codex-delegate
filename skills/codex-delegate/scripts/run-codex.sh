#!/usr/bin/env bash
# Run one Codex CLI task non-interactively and wait for it to finish.
# Meant to be launched by Claude Code's Bash tool with run_in_background: true
# (do NOT add '&' — the foreground exit is what triggers Claude's notification).
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: run-codex.sh --repo DIR --notes DIR --brief FILE [--name TASK]
                    [--network] [--codex-home DIR] [--model M] [--stall-minutes N]
                    [-- EXTRA_CODEX_ARGS...]

  --repo        Repository Codex works in (passed as -C, writable).
  --notes       Notes dir outside the repo (passed as --add-dir, writable).
                Receives run-<task>.log, last-<task>.txt and <task>.done.
  --brief       Task brief file; fed to Codex on stdin.
  --name        Task name used in output file names (default: brief file name).
  --network     Allow network inside the workspace-write sandbox.
  --codex-home  Set CODEX_HOME (for users whose `codex` is a shell function).
  --model       Override the Codex model.
  --stall-minutes  Abort (exit 124) if the log stops growing for N minutes
                (default 30; 0 disables). A run stuck on "Reading additional
                input from stdin..." is aborted after about a minute.
Env: CODEX_BIN pins the codex executable; CODEX_HOME is passed through.
EOF
}

repo="" notes="" brief="" name="" network=0 model="" stall_min=30 extra=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --notes) notes="$2"; shift 2 ;;
    --brief) brief="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --network) network=1; shift ;;
    --codex-home) export CODEX_HOME="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --stall-minutes) stall_min="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; extra=("$@"); break ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$repo" && -n "$notes" && -n "$brief" ]] || { usage >&2; exit 2; }
[[ -d "$repo" ]] || { echo "Repo not found: $repo" >&2; exit 2; }
[[ -f "$brief" ]] || { echo "Brief not found: $brief" >&2; exit 2; }
mkdir -p "$notes"
repo="$(cd "$repo" && pwd)"
notes="$(cd "$notes" && pwd)"
if [[ -z "$name" ]]; then
  name="$(basename "$brief")"; name="${name%.*}"; name="${name#brief-}"
fi

codex_bin="${CODEX_BIN:-$(command -v codex || true)}"
[[ -n "$codex_bin" && -x "$codex_bin" ]] || {
  echo "codex CLI not found. Install: npm i -g @openai/codex (or brew install codex), then codex login." >&2
  exit 127
}

log="$notes/run-$name.log"
last="$notes/last-$name.txt"
done_file="$notes/$name.done"
rm -f "$done_file" "$last"

args=(exec -C "$repo" -s workspace-write --add-dir "$notes" -o "$last")
(( network )) && args+=(-c sandbox_workspace_write.network_access=true)
[[ -n "$model" ]] && args+=(-m "$model")
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || args+=(--skip-git-repo-check)
args+=("${extra[@]+"${extra[@]}"}" -)

echo "codex: $codex_bin ($("$codex_bin" --version 2>/dev/null | head -1))"
echo "CODEX_HOME: ${CODEX_HOME:-<default ~/.codex>}"
echo "repo: $repo"
echo "notes: $notes"
echo "log: $log"
start=$(date +%s)

# Brief goes in on stdin: no argv quoting problems, and Codex never waits on an open stdin.
"$codex_bin" "${args[@]}" < "$brief" > "$log" 2>&1 &
pid=$!

# Watchdog: Codex runs in the background of THIS script only; the script itself stays in the
# foreground so Claude Code still gets its completion notification.
stalled=""
last_size=-1 last_change=$(date +%s) checked_stdin=0
while kill -0 "$pid" 2>/dev/null; do
  sleep 5
  now=$(date +%s)
  size=$(wc -c < "$log" 2>/dev/null || echo 0)
  if [[ "$size" != "$last_size" ]]; then last_size=$size; last_change=$now; fi
  if (( !checked_stdin && now - start >= 60 )); then
    checked_stdin=1
    if [[ "$(grep -v '^[[:space:]]*$' "$log" | tail -1)" == *"Reading additional input from stdin"* ]]; then
      stalled="stuck waiting on stdin (prompt passed as argument without < /dev/null?)"
    fi
  fi
  if [[ -z "$stalled" ]] && (( stall_min > 0 && now - last_change >= stall_min * 60 )); then
    stalled="log has not grown for ${stall_min} min"
  fi
  if [[ -n "$stalled" ]]; then
    kill "$pid" 2>/dev/null; sleep 3; kill -9 "$pid" 2>/dev/null
    break
  fi
done
wait "$pid" 2>/dev/null
code=$?
[[ -n "$stalled" ]] && code=124
secs=$(( $(date +%s) - start ))
echo "$code" > "$done_file"

echo
echo "=== codex exit code: $code (${secs}s) ==="
[[ -n "$stalled" ]] && echo "=== ABORTED by watchdog: $stalled ==="
if [[ -s "$last" ]]; then
  echo "=== last message ($last) ==="
  cat "$last"; echo
else
  echo "=== no last message; tail of log ==="
  tail -n 30 "$log"
fi
tokens=$(grep -A1 '^tokens used' "$log" 2>/dev/null | tail -1)
[[ -n "$tokens" ]] && echo "=== codex tokens used: $tokens ==="
if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  echo
  echo "=== git status --short ($repo) ==="
  git -C "$repo" status --short
fi
exit "$code"
