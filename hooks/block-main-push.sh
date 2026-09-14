#!/usr/bin/env bash
# PreToolUse(Bash): enforce rules/git.md — never push directly to the repo's
# default branch. Lets the very first push through (a brand-new repo's
# initial commit has nowhere else to go).
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s+push\b' || exit 0

commit_count="$(git rev-list --count HEAD 2>/dev/null || echo "")"
[[ "$commit_count" == "1" ]] && exit 0

default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)"
default_branch="${default_branch:-main}"

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

if [[ "$current_branch" == "$default_branch" ]]; then
  jq -n --arg branch "$default_branch" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("claude-ops rule: never push directly to " + $branch + " (rules/git.md) — open a PR instead.")}}'
  exit 0
fi

exit 0
