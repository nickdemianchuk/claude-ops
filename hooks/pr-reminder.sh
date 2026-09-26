#!/usr/bin/env bash
# PostToolUse(Bash): after a git push, nudge Claude to verify the PR body still
# matches the pushed changes (rules/github.md PR body rules).
#
# Only fires when the branch already had an upstream before this push, i.e. it
# has been pushed before and a PR plausibly exists. That keeps the nudge off the
# first push of a branch, when there is nothing to refresh yet.
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s' || exit 0
echo "$cmd" | grep -qE '\bpush\b' || exit 0

# A `-u`/`--set-upstream` push is the first one for this branch by definition.
echo "$cmd" | grep -qE '(-u|--set-upstream)\b' && exit 0

git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || exit 0

jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Pushed to an already-tracked branch. If a PR is open for it, check whether the body still describes these changes (1-2 sentences or a short bullet list, backticks for code/values, per rules/github.md) and update it with the GitHub MCP update_pull_request tool if it is stale. If no PR is open, ignore this."}}'
