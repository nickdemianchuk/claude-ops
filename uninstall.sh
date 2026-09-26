#!/usr/bin/env bash
# Reverses install.sh: removes symlinks in the Claude Code user config dir
# (~/.claude/, or $CLAUDE_CONFIG_DIR if set) that point back into this repo,
# un-merges settings/*.json from the config dir's settings.json, and removes
# the user-scope MCP servers named by mcps/*.json.
# Only removes what this repo manages: a symlink is removed only if it still
# points at this repo's copy, and settings.json entries are removed only if
# they exactly match a settings/*.json fragment. MCP servers are matched by
# name only (the `claude mcp` CLI has no way to diff a stored server's
# content), so a user-scope server you redefined yourself under the same name
# is removed too — re-add it after if that happens. Anything else (backups,
# edited symlinks, hooks or settings you changed yourself) is left alone.
#
# Usage: ./uninstall.sh [--rules] [--hooks] [--settings] [--mcps]
#   --rules     remove rules/*.md symlinks only
#   --hooks     remove hooks/* symlinks, un-merge settings/hooks.json only
#   --settings  un-merge settings/*.json except hooks.json only
#   --mcps      remove the user-scope MCP servers named by mcps/*.json only
#   (no flags removes all)
set -euo pipefail

DO_RULES=false
DO_HOOKS=false
DO_SETTINGS=false
DO_MCPS=false

if [ "$#" -eq 0 ]; then
  DO_RULES=true
  DO_HOOKS=true
  DO_SETTINGS=true
  DO_MCPS=true
fi

for arg in "$@"; do
  case "$arg" in
    --rules) DO_RULES=true ;;
    --hooks) DO_HOOKS=true ;;
    --settings) DO_SETTINGS=true ;;
    --mcps) DO_MCPS=true ;;
    *)
      echo "error: unknown flag $arg (expected --rules, --hooks, --settings, --mcps)" >&2
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

  unmerge_settings_file "$SCRIPT_DIR/settings/hooks.json"
}

# Reverses merge_settings_file: removes values that exactly match a
# settings/*.json fragment (objects recurse, arrays subtract, scalars drop only
# if equal), pruning containers left empty. Values you changed since
# installing, and entries added by you or other tools, are kept.
unmerge_settings_file() {
  local src="$1"
  local settings_file="$CONFIG_DIR/settings.json"

  [ -f "$src" ] && [ -f "$settings_file" ] || return 0

  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to uninstall $(basename "$src"), skipping" >&2
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  jq -s '
    def unmerge($a; $b):
      if ($a | type) == "object" and ($b | type) == "object" then
        (reduce ($b | keys[]) as $k ($a;
          if has($k) then
            unmerge($a[$k]; $b[$k]) as $r
            | if $r == null then del(.[$k]) else .[$k] = $r end
          else . end)) as $out
        | if $out == {} then null else $out end
      elif ($a | type) == "array" and ($b | type) == "array" then
        ($a - $b) as $out | if $out == [] then null else $out end
      elif $a == $b then null
      else $a end;
    unmerge(.[0]; .[1]) // {}
  ' "$settings_file" "$src" > "$tmp"
  mv "$tmp" "$settings_file"
  echo "unmerged: settings/$(basename "$src") -> $(basename "$settings_file")"
}

uninstall_settings() {
  local src_dir="$SCRIPT_DIR/settings"

  [ -d "$src_dir" ] || return 0

  for src in "$src_dir"/*.json; do
    # hooks.json is owned by --hooks
    [ "$(basename "$src")" = "hooks.json" ] && continue
    unmerge_settings_file "$src"
  done
}

uninstall_mcps() {
  local src_dir="$SCRIPT_DIR/mcps"

  [ -d "$src_dir" ] || return 0

  if ! command -v claude >/dev/null 2>&1; then
    echo "error: claude CLI is required to uninstall mcps/*.json, skipping" >&2
    return 0
  fi

  for src in "$src_dir"/*.json; do
    local name
    name="$(basename "$src" .json)"

    if claude mcp remove "$name" -s user >/dev/null 2>&1; then
      echo "removed: mcps/$(basename "$src") -> $name (user scope)"
    else
      echo "skipped (not configured in user scope): $name"
    fi
  done
}

$DO_RULES && uninstall_rules
$DO_HOOKS && uninstall_hooks
$DO_SETTINGS && uninstall_settings
$DO_MCPS && uninstall_mcps

exit 0
