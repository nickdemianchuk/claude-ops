#!/usr/bin/env bash
# PreToolUse(Bash): enforce rules/git.md — never skip hooks (--no-verify) or
# signing (--no-gpg-sign / commit.gpgsign=false) unless the user explicitly asked.
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s+' || exit 0

if echo "$cmd" | grep -qE -- '--no-verify|--no-gpg-sign|commit\.gpgsign=false'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"claude-ops rule: never skip hooks or signing (--no-verify/--no-gpg-sign) unless the user explicitly asked (rules/git.md)."}}'
  exit 0
fi

exit 0
