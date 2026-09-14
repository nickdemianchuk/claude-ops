#!/usr/bin/env bash
# Installs this repo's rules/*.md into the Claude Code user rules dir
# (~/.claude/rules/, or $CLAUDE_CONFIG_DIR/rules/ if set) as symlinks,
# so `claude` always sees the latest version from this repo.
# Safe to re-run: existing correct symlinks are left alone, and any
# pre-existing real file is backed up once before being replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/rules"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST_DIR="$CONFIG_DIR/rules"

if [ ! -d "$SRC_DIR" ]; then
  echo "error: $SRC_DIR not found" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

for src in "$SRC_DIR"/*.md; do
  name="$(basename "$src")"
  dest="$DEST_DIR/$name"

  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "up to date: $name"
      continue
    fi
    rm "$dest"
  elif [ -e "$dest" ]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    echo "backing up existing $name -> $(basename "$backup")"
    mv "$dest" "$backup"
  fi

  ln -s "$src" "$dest"
  echo "linked: $name"
done

# Symlink hooks/* scripts into $CONFIG_DIR/hooks, same pattern as rules/.
HOOKS_SRC_DIR="$SCRIPT_DIR/hooks"
HOOKS_DEST_DIR="$CONFIG_DIR/hooks"

if [ -d "$HOOKS_SRC_DIR" ]; then
  mkdir -p "$HOOKS_DEST_DIR"

  for src in "$HOOKS_SRC_DIR"/*; do
    name="$(basename "$src")"
    dest="$HOOKS_DEST_DIR/$name"
    chmod +x "$src"

    if [ -L "$dest" ]; then
      if [ "$(readlink "$dest")" = "$src" ]; then
        echo "up to date: hooks/$name"
        continue
      fi
      rm "$dest"
    elif [ -e "$dest" ]; then
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
HOOKS_CONFIG="$SCRIPT_DIR/hooks.json"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

if [ -f "$HOOKS_CONFIG" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to install hooks.json, skipping" >&2
  else
    [ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"
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
    ' "$SETTINGS_FILE" "$HOOKS_CONFIG" > "$tmp"
    mv "$tmp" "$SETTINGS_FILE"
    echo "merged: hooks.json -> $(basename "$SETTINGS_FILE")"
  fi
fi
