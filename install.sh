#!/usr/bin/env bash
# Installs this repo's rules/*.md and hooks/* into the Claude Code user config
# dir (~/.claude/, or $CLAUDE_CONFIG_DIR if set) as symlinks, so `claude`
# always sees the latest version from this repo.
# Safe to re-run: existing correct symlinks are left alone, and any
# pre-existing real file is backed up once before being replaced.
#
# Usage: ./install.sh [--rules] [--hooks]
#   --rules  install rules/*.md only
#   --hooks  install hooks/*, merge hooks.json only
#   (no flags installs both)
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

  # Merge hooks.json into $CONFIG_DIR/settings.json (set-union per event, so
  # re-running never duplicates entries and untouched hooks are preserved).
  local hooks_config="$SCRIPT_DIR/hooks.json"
  local settings_file="$CONFIG_DIR/settings.json"

  if [ -f "$hooks_config" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "error: jq is required to install hooks.json, skipping" >&2
    else
      [ -f "$settings_file" ] || echo '{}' > "$settings_file"
      local tmp
      tmp="$(mktemp)"
      jq -s '
        .[0] as $existing | .[1] as $new |
        $existing * {
          hooks: (
            ($existing.hooks // {}) as $eh |
            ($new.hooks // {}) as $nh |
            (($eh|keys) + ($nh|keys) | unique) as $allkeys |
            reduce $allkeys[] as $k ({};
              . + { ($k): ( ($eh[$k] // []) + ( ($nh[$k] // []) - ($eh[$k] // []) ) ) }
            )
          )
        }
      ' "$settings_file" "$hooks_config" > "$tmp"
      mv "$tmp" "$settings_file"
      echo "merged: hooks.json -> $(basename "$settings_file")"
    fi
  fi
}

$DO_RULES && install_rules
$DO_HOOKS && install_hooks

exit 0
