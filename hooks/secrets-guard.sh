#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write): defense-in-depth — refuse to read/edit obvious
# secret files even if the sandbox/permissions would otherwise allow it.
set -euo pipefail

input="$(cat)"
path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ -n "$path" ]] || exit 0

pattern='(^|/)\.env(\..*)?$|\.pem$|\.key$|(^|/)id_rsa$|(^|/)id_ed25519$|credentials\.json$|\.npmrc$|\.netrc$|/\.aws/credentials$|service-account.*\.json$'

if echo "$path" | grep -qEi "$pattern"; then
  jq -n --arg path "$path" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("claude-ops guard: refusing to touch likely secret file: " + $path + ". Confirm with the user if this is intentional.")}}'
  exit 0
fi

exit 0
