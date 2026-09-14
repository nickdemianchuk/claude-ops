#!/usr/bin/env bash
# PostToolUse(Bash): after a git push, nudge Claude to verify the PR body
# still matches the pushed changes (rules/github.md PR body rules).
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s+push\b' || exit 0

jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Just pushed. Check whether the PR body still accurately describes these changes (1-2 sentences or bullet list, backticks for code/values, per rules/github.md) and update it with the GitHub MCP update_pull_request tool if it is stale."}}'
