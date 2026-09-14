#!/usr/bin/env bash
# PreToolUse(Bash): enforce rules/git.md — never push directly to main, and
# force pushes need explicit user confirmation first (never auto-approved).
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s+push\b' || exit 0

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

if echo "$cmd" | grep -qE -- '(--force(-with-lease)?\b|(^|[[:space:]])-f([[:space:]]|$))'; then
  deny "claude-ops rule: force push needs explicit user confirmation first (rules/git.md) — ask before retrying."
fi

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
target_branch=""

if echo "$cmd" | grep -qE '\bmain\b'; then
  target_branch="main"
elif echo "$cmd" | grep -qE '\bmaster\b'; then
  target_branch="master"
elif [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  # No explicit branch name in the command (main/master already ruled out
  # above) — figure out if an explicit *other* branch was given after the
  # remote, e.g. `git push origin feat/foo`. If so this isn't targeting main.
  read -ra tokens <<< "$cmd"
  remote_seen=false
  branch_arg=""
  for ((i = 2; i < ${#tokens[@]}; i++)); do
    t="${tokens[$i]}"
    [[ "$t" == -* ]] && continue
    if ! $remote_seen; then
      remote_seen=true
      continue
    fi
    branch_arg="$t"
    break
  done
  if [[ -z "$branch_arg" || "$branch_arg" == "HEAD" ]]; then
    target_branch="$current_branch"
  fi
fi

if [[ "$target_branch" == "main" || "$target_branch" == "master" ]]; then
  deny "claude-ops rule: never push directly to main (rules/git.md) — open a PR instead."
fi

exit 0
