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
