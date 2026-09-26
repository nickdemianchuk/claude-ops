#!/usr/bin/env bash
# InstructionsLoaded: append one line per instruction file Claude Code loads, to
# answer "did that rule actually load, and why" without guessing.
#
# Each line is: <timestamp> <memory_type> <load_reason> <path>. `load_reason` is
# the useful field — `session_start` for an unconditional rule, `path_glob_match`
# for one whose `paths` frontmatter matched a file Claude just read.
#
# Emits nothing to the conversation, so it costs no context. Install it while
# debugging rule loading and uninstall it after; it appends indefinitely.
set -euo pipefail

input="$(cat)"
log="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/logs/instructions.log"

mkdir -p "$(dirname "$log")"
jq -r '[(now | todate), (.memory_type // "?"), (.load_reason // "?"), (.file_path // "?")] | @tsv' \
  <<<"$input" >> "$log"
