#!/usr/bin/env bash
# Installs this repo's rules/*.md and hooks/* into the Claude Code user config
# dir (~/.claude/, or $CLAUDE_CONFIG_DIR if set) as symlinks, so `claude`
# always sees the latest version from this repo, and merges settings/*.json
# into the config dir's settings.json.
# Safe to re-run: existing correct symlinks are left alone, any pre-existing
# real file is backed up once before being replaced, and settings.json is
# backed up once per run if the merge changes it.
#
# Usage: ./install.sh [--rules] [--hooks] [--settings]
#   --rules     install rules/*.md only
#   --hooks     install hooks/*, merge settings/hooks.json only
#   --settings  merge settings/*.json except hooks.json only
#   (no flags installs all)
set -euo pipefail

DO_RULES=false
DO_HOOKS=false
DO_SETTINGS=false

if [ "$#" -eq 0 ]; then
  DO_RULES=true
  DO_HOOKS=true
  DO_SETTINGS=true
fi

for arg in "$@"; do
  case "$arg" in
    --rules) DO_RULES=true ;;
    --hooks) DO_HOOKS=true ;;
    --settings) DO_SETTINGS=true ;;
    *)
      echo "error: unknown flag $arg (expected --rules, --hooks, --settings)" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS_BACKED_UP=false

install_rules() {
  local src_dir="$SCRIPT_DIR/rules"
  local dest_dir="$CONFIG_DIR/rules"

  if [ ! -d "$src_dir" ]; then
    echo "error: $src_dir not found" >&2
    exit 1
  fi

  mkdir -p "$dest_dir"

  for src in "$src_dir"/*.md; do
    local name dest
    name="$(basename "$src")"
    dest="$dest_dir/$name"

    if [ -L "$dest" ]; then
      if [ "$(readlink "$dest")" = "$src" ]; then
        echo "up to date: $name"
        continue
      fi
      rm "$dest"
    elif [ -e "$dest" ]; then
      local backup
      backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
      echo "backing up existing $name -> $(basename "$backup")"
      mv "$dest" "$backup"
    fi

    ln -s "$src" "$dest"
    echo "linked: $name"
  done
}

install_hooks() {
  local hooks_src_dir="$SCRIPT_DIR/hooks"
  local hooks_dest_dir="$CONFIG_DIR/hooks"

  if [ -d "$hooks_src_dir" ]; then
    mkdir -p "$hooks_dest_dir"

    for src in "$hooks_src_dir"/*; do
      local name dest
      name="$(basename "$src")"
      dest="$hooks_dest_dir/$name"
      chmod +x "$src"

      if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
          echo "up to date: hooks/$name"
          continue
        fi
        rm "$dest"
      elif [ -e "$dest" ]; then
        local backup
        backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
        echo "backing up existing hooks/$name -> $(basename "$backup")"
        mv "$dest" "$backup"
      fi

      ln -s "$src" "$dest"
      echo "linked: hooks/$name"
    done
  fi

  merge_settings_file "$SCRIPT_DIR/settings/hooks.json"
}

# Deep-merges a settings/*.json fragment into $CONFIG_DIR/settings.json:
# objects merge recursively, arrays are set-unioned (so re-running never
# duplicates hook entries), and for scalars this repo's value wins. Keys absent
# from the fragment (e.g. machine-specific hooks) are preserved.
merge_settings_file() {
  local src="$1"
  local settings_file="$CONFIG_DIR/settings.json"

  [ -f "$src" ] || return 0

  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to install $(basename "$src"), skipping" >&2
    return 0
  fi

  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$settings_file" ]; then
    echo '{}' > "$settings_file"
    SETTINGS_BACKED_UP=true # nothing to back up
  fi
  local tmp
  tmp="$(mktemp)"
  jq -s '
    def merge($a; $b):
      if ($a | type) == "object" and ($b | type) == "object" then
        reduce ($b | keys[]) as $k ($a; .[$k] = merge($a[$k]; $b[$k]))
      elif ($a | type) == "array" and ($b | type) == "array" then
        $a + ($b - $a)
      else $b end;
    merge(.[0]; .[1])
  ' "$settings_file" "$src" > "$tmp"

  # Compare as JSON so formatting/key-order differences don't count as changes.
  if jq -en --slurpfile a "$settings_file" --slurpfile b "$tmp" '$a == $b' >/dev/null; then
    rm "$tmp"
    echo "up to date: settings/$(basename "$src")"
    return 0
  fi

  if ! $SETTINGS_BACKED_UP; then
    local backup
    backup="$settings_file.bak.$(date +%Y%m%d%H%M%S)"
    echo "backing up existing $(basename "$settings_file") -> $(basename "$backup")"
    cp "$settings_file" "$backup"
    SETTINGS_BACKED_UP=true
  fi

  mv "$tmp" "$settings_file"
  echo "merged: settings/$(basename "$src") -> $(basename "$settings_file")"
}

install_settings() {
  local src_dir="$SCRIPT_DIR/settings"

  if [ ! -d "$src_dir" ]; then
    echo "error: $src_dir not found" >&2
    exit 1
  fi

  for src in "$src_dir"/*.json; do
    # hooks.json is owned by --hooks
    [ "$(basename "$src")" = "hooks.json" ] && continue
    merge_settings_file "$src"
  done
}

$DO_RULES && install_rules
$DO_HOOKS && install_hooks
$DO_SETTINGS && install_settings

exit 0
