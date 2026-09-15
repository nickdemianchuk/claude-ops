#!/usr/bin/env bash
# Reverses install.sh: removes symlinks in the Claude Code user config dir
# (~/.claude/, or $CLAUDE_CONFIG_DIR if set) that point back into this repo,
# and un-merges hooks.json from settings.json.
# Only removes what this repo manages: a symlink is removed only if it still
# points at this repo's copy, and settings.json entries are removed only if
# they exactly match hooks.json. Anything else (backups, edited symlinks,
# hooks you added yourself) is left alone.
#
# Usage: ./uninstall.sh [--rules] [--hooks]
#   --rules  remove rules/*.md symlinks only
#   --hooks  remove hooks/* symlinks, un-merge hooks.json only
#   (no flags removes both)
set -euo pipefail

DO_RULES=false
DO_HOOKS=false

if [ "$#" -eq 0 ]; then
  DO_RULES=true
  DO_HOOKS=true
fi

for arg in "$@"; do
  case "$arg" in
    --rules) DO_RULES=true ;;
    --hooks) DO_HOOKS=true ;;
    *)
      echo "error: unknown flag $arg (expected --rules, --hooks)" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

uninstall_rules() {
  local src_dir="$SCRIPT_DIR/rules"
  local dest_dir="$CONFIG_DIR/rules"

  [ -d "$dest_dir" ] || return 0
  [ -d "$src_dir" ] || return 0

  for src in "$src_dir"/*.md; do
    local name dest
    name="$(basename "$src")"
    dest="$dest_dir/$name"

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      rm "$dest"
      echo "removed: $name"
    else
      echo "skipped (not a managed symlink): $name"
    fi
  done
}

uninstall_hooks() {
  local hooks_src_dir="$SCRIPT_DIR/hooks"
  local hooks_dest_dir="$CONFIG_DIR/hooks"

  if [ -d "$hooks_src_dir" ] && [ -d "$hooks_dest_dir" ]; then
    for src in "$hooks_src_dir"/*; do
      local name dest
      name="$(basename "$src")"
      dest="$hooks_dest_dir/$name"

      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        rm "$dest"
        echo "removed: hooks/$name"
      else
        echo "skipped (not a managed symlink): hooks/$name"
      fi
    done
  fi

  # Un-merge hooks.json from $CONFIG_DIR/settings.json: drop entries that
  # exactly match hooks.json from each event's array, per-event key removed
  # entirely if it becomes empty. Entries not present in hooks.json (added by
  # the user or other tools) are left untouched.
  local hooks_config="$SCRIPT_DIR/hooks.json"
  local settings_file="$CONFIG_DIR/settings.json"

  if [ -f "$hooks_config" ] && [ -f "$settings_file" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "error: jq is required to uninstall hooks.json, skipping" >&2
    else
      local tmp
      tmp="$(mktemp)"
      jq -s '
        .[0] as $existing | .[1] as $old |
        $existing + {
          hooks: (
            ($existing.hooks // {}) as $eh |
            ($old.hooks // {}) as $oh |
            ($eh|keys) as $allkeys |
            reduce $allkeys[] as $k ({};
              (($eh[$k] // []) - ($oh[$k] // [])) as $remaining |
              if ($remaining | length) > 0 then . + { ($k): $remaining } else . end
            )
          )
        }
      ' "$settings_file" "$hooks_config" > "$tmp"
      mv "$tmp" "$settings_file"
      echo "unmerged: hooks.json -> $(basename "$settings_file")"
    fi
  fi
}

$DO_RULES && uninstall_rules
$DO_HOOKS && uninstall_hooks

exit 0
