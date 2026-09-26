#!/usr/bin/env bash
# Tests hooks/log-instructions.sh: it appends one tab-separated line per
# InstructionsLoaded payload, fills in placeholders for missing fields, stays
# silent on stdout so it costs no context, and creates its log directory.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/log-instructions.sh"
FAILED=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/cfg"
LOG="$CLAUDE_CONFIG_DIR/logs/instructions.log"

ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }

feed() { # <json>
  bash "$HOOK" <<<"$1"
}

payload='{"hook_event_name":"InstructionsLoaded","file_path":"/home/u/.claude/rules/comments.md","memory_type":"User","load_reason":"path_glob_match"}'

out="$(feed "$payload" 2>&1)"
if [ -z "$out" ]; then ok "silent on stdout"; else fail "wrote to stdout: $out"; fi
if [ -f "$LOG" ]; then ok "created the log and its directory"; else fail "no log at $LOG"; fi

line="$(tail -n1 "$LOG")"
if [ "$(awk -F'\t' '{print NF}' <<<"$line")" -eq 4 ]; then ok "line has 4 tab-separated fields"; else fail "expected 4 fields, got: $line"; fi
if awk -F'\t' '$2=="User" && $3=="path_glob_match" && $4 ~ /comments\.md$/ {exit 0} {exit 1}' <<<"$line"; then
  ok "recorded memory_type, load_reason and path"
else
  fail "fields wrong: $line"
fi

feed '{"hook_event_name":"InstructionsLoaded","file_path":"/x/CLAUDE.md","memory_type":"Project","load_reason":"session_start"}' >/dev/null 2>&1
if [ "$(wc -l < "$LOG")" -eq 2 ]; then ok "appends rather than truncating"; else fail "expected 2 lines, got $(wc -l < "$LOG")"; fi

# A payload missing the optional fields must not abort the hook or the tool call.
if feed '{"hook_event_name":"InstructionsLoaded"}' >/dev/null 2>&1; then
  ok "survives a payload with no memory_type/load_reason/file_path"
else
  fail "exited non-zero on a sparse payload"
fi
if [ "$(awk -F'\t' 'END{print $2"/"$3"/"$4}' "$LOG")" = "?/?/?" ]; then
  ok "substitutes ? for missing fields"
else
  fail "expected ?/?/? placeholders, got $(awk -F'\t' 'END{print $2"/"$3"/"$4}' "$LOG")"
fi

exit "$FAILED"
