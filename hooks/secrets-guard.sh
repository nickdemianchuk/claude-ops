#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write|NotebookEdit|Bash): defense-in-depth on top of the
# `permissions.deny` rules in settings/permissions.json.
#
# The deny rules are the real enforcement for file tools; they're checked by the
# client and can't be reasoned around. This hook covers the two gaps they leave:
# NotebookEdit paths, which file permission checks don't consult, and Bash
# commands that read a secret file instead of going through a file tool.
set -euo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"
path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

secret='(^|/)\.env(\..*)?$|\.pem$|\.key$|(^|/)id_rsa$|(^|/)id_ed25519$|credentials\.json$|\.npmrc$|\.netrc$|/\.aws/credentials$|service-account.*\.json$'
# Same set, matched mid-command rather than anchored at end of string.
secret_in_cmd='(^|[[:space:]=/"'"'"'])(\.env([.][^[:space:]"'"'"']*)?|[^[:space:]"'"'"']*\.(pem|key|npmrc|netrc)|id_rsa|id_ed25519|credentials\.json|service-account[^[:space:]"'"'"']*\.json)([[:space:]"'"'"']|$)'
readers='(cat|less|more|head|tail|bat|nl|strings|xxd|od|base64|jq|yq|source|\.)'

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

if [[ -n "$path" ]] && echo "$path" | grep -qEi "$secret"; then
  deny "claude-ops guard: refusing to touch likely secret file: $path. Confirm with the user if this is intentional."
fi

# Best-effort: a reader command naming a secret file. Only the listed readers
# match, so `grep TOKEN .env` gets through — the deny rules are the enforcement.
if [[ "$tool" == "Bash" ]] && [[ -n "$cmd" ]]; then
  if echo "$cmd" | grep -qE "(^|[;&|[:space:]])$readers([[:space:]]|$)" \
    && echo "$cmd" | grep -qEi "$secret_in_cmd"; then
    deny "claude-ops guard: refusing a shell command that reads a likely secret file. Confirm with the user if this is intentional, or read the specific value you need another way."
  fi
fi

exit 0
