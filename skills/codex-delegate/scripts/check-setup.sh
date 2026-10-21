#!/usr/bin/env bash
# Preflight for the codex-delegate skill. Read-only: installs and changes nothing.
set -u
ok=1
say() { printf '%-8s %s\n' "$1" "$2"; }

if command -v git >/dev/null 2>&1; then say OK "git $(git --version | awk '{print $3}')"
else say MISSING "git"; ok=0; fi

if command -v claude >/dev/null 2>&1; then say OK "claude $(claude --version 2>/dev/null | head -1)"
else say INFO "claude CLI not on PATH (fine if you use the desktop app or IDE)"; fi

# All codex executables on PATH (npm and Homebrew installs can coexist).
bins=$(which -a codex 2>/dev/null | awk '!seen[$0]++')
if [[ -z "$bins" ]]; then
  say MISSING "codex CLI. Install: npm i -g @openai/codex  (or: brew install codex), then: codex login"
  ok=0
else
  while IFS= read -r b; do say OK "codex $b ($("$b" --version 2>/dev/null | head -1))"; done <<< "$bins"
  [[ $(wc -l <<< "$bins") -gt 1 ]] && say NOTE "several codex binaries; the first is used. Set CODEX_BIN to pin one."
fi

# Is `codex` a shell function or alias in the user's interactive shell?
user_shell="${SHELL:-/bin/bash}"
def=$("$user_shell" -ic 'type codex' 2>/dev/null || true)
if grep -qE 'function|alias' <<< "$def"; then
  body=$("$user_shell" -ic 'functions codex 2>/dev/null || declare -f codex; alias codex' 2>/dev/null)
  home=$(grep -oE "CODEX_HOME=(\"[^\"]*\"|'[^']*'|[^ ;]+)" <<< "$body" | head -1 | cut -d= -f2- | tr -d "\"'")
  home="${home//\$HOME/$HOME}"; home="${home//\$\{HOME\}/$HOME}"; home="${home/#\~/$HOME}"
  say NOTE "codex is a shell function/alias in $user_shell; Claude's non-interactive Bash won't load it."
  [[ -n "$home" ]] && say NOTE "it sets CODEX_HOME=$home -> pass --codex-home \"$home\" to run-codex.sh"
fi

home_dir="${CODEX_HOME:-$HOME/.codex}"
if [[ -f "$home_dir/auth.json" ]]; then say OK "codex auth found in $home_dir"
elif [[ -n "$bins" ]]; then say WARN "no $home_dir/auth.json; run: codex login (or check CODEX_HOME)"; fi

[[ $ok -eq 1 ]] && echo "Ready." || { echo "Not ready."; exit 1; }
