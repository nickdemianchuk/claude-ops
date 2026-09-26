#!/usr/bin/env bash
# Tests bin/claude-ops against a throwaway CLAUDE_CONFIG_DIR:
#   1. a clean install links every rule, skill and hook and merges every setting
#   2. re-running changes nothing (idempotent) and reports "up to date"
#   3. a pre-existing real file is backed up rather than clobbered
#   4. unrelated keys the user already had in settings.json survive both ways
#   5. `status` reports installed, then not installed
#   6. uninstall removes exactly what this repo installed
# The mcps category is skipped: it needs the `claude` CLI, absent in CI.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$REPO_ROOT/bin/claude-ops"
FAILED=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/config"
export NO_COLOR=1

TARGETS=(rules skills hooks settings)

ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }

want_link() { # want_link <path> <target>
  if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then ok "linked $1"; else fail "expected symlink $1 -> $2"; fi
}

want_gone() { # want_gone <path>
  if [ -e "$1" ] || [ -L "$1" ]; then fail "expected $1 to be removed"; else ok "removed $1"; fi
}

want_jq() { # want_jq <label> <filter>
  if jq -e "$2" "$CLAUDE_CONFIG_DIR/settings.json" >/dev/null; then ok "$1"; else fail "$1"; fi
}

# A setting the user had before installing, which must survive install+uninstall.
mkdir -p "$CLAUDE_CONFIG_DIR"
echo '{"theme":"dark","hooks":{"SessionEnd":[{"matcher":"","hooks":[{"type":"command","command":"mine.sh"}]}]}}' \
  > "$CLAUDE_CONFIG_DIR/settings.json"

# A pre-existing real file where a rule symlink wants to go, to exercise backup.
mkdir -p "$CLAUDE_CONFIG_DIR/rules"
echo "mine, not the repo's" > "$CLAUDE_CONFIG_DIR/rules/git.md"

echo "# 1. clean install"
bash "$CLI" install "${TARGETS[@]}" >"$WORK/install.log" 2>&1 || fail "install exited non-zero"
for f in "$REPO_ROOT"/rules/*.md; do
  want_link "$CLAUDE_CONFIG_DIR/rules/$(basename "$f")" "$f"
done
for d in "$REPO_ROOT"/skills/*/; do
  d="${d%/}"
  want_link "$CLAUDE_CONFIG_DIR/skills/$(basename "$d")" "$d"
done
for f in "$REPO_ROOT"/hooks/*; do
  want_link "$CLAUDE_CONFIG_DIR/hooks/$(basename "$f")" "$f"
done
# The skill has to be usable through the link, not just present.
if [ -r "$CLAUDE_CONFIG_DIR/skills/twelve-factor/SKILL.md" ]; then
  ok "SKILL.md readable through the directory symlink"
else
  fail "SKILL.md not readable through the directory symlink"
fi

echo "# 2. pre-existing file was backed up, not clobbered"
if compgen -G "$CLAUDE_CONFIG_DIR/backups/claude-ops/rules/git.md.bak.*" >/dev/null; then
  ok "backed up the pre-existing rules/git.md"
else
  fail "expected a backup of the pre-existing rules/git.md"
fi

echo "# 3. settings merged, user's own keys preserved"
want_jq "merged attribution" '.attribution.commit == ""'
want_jq "merged model"       '.model == "claude-sonnet-5"'
want_jq "merged outputStyle" '.outputStyle == "Concise"'
want_jq "merged permissions" '(.permissions.deny | length) > 0'
want_jq "merged PreToolUse"  '(.hooks.PreToolUse | length) == 2'
want_jq "kept user theme"    '.theme == "dark"'
want_jq "kept user hook"     '.hooks.SessionEnd[0].hooks[0].command == "mine.sh"'

echo "# 4. status reports everything installed"
if bash "$CLI" status "${TARGETS[@]}" 2>&1 | grep -q "not installed"; then
  fail "status still reports something not installed"
else
  ok "status reports no missing items"
fi

echo "# 5. re-running is idempotent"
cp "$CLAUDE_CONFIG_DIR/settings.json" "$WORK/settings.before"
bash "$CLI" install "${TARGETS[@]}" >"$WORK/reinstall.log" 2>&1 || fail "second install exited non-zero"
if jq -en --slurpfile a "$WORK/settings.before" --slurpfile b "$CLAUDE_CONFIG_DIR/settings.json" '$a == $b' >/dev/null; then
  ok "settings.json unchanged on re-run"
else
  fail "settings.json changed on re-run"
fi
if grep -q "up to date" "$WORK/reinstall.log"; then ok "re-run reported up to date"; else fail "re-run did not report up to date"; fi
if [ "$(grep -c 'backing up' "$WORK/reinstall.log")" -eq 0 ]; then ok "re-run made no new backups"; else fail "re-run made a backup it should not have"; fi

echo "# 6. uninstall removes only what this repo installed"
bash "$CLI" uninstall "${TARGETS[@]}" >"$WORK/uninstall.log" 2>&1 || fail "uninstall exited non-zero"
for f in "$REPO_ROOT"/rules/*.md; do
  want_gone "$CLAUDE_CONFIG_DIR/rules/$(basename "$f")"
done
for d in "$REPO_ROOT"/skills/*/; do
  want_gone "$CLAUDE_CONFIG_DIR/skills/$(basename "${d%/}")"
done
for f in "$REPO_ROOT"/hooks/*; do
  want_gone "$CLAUDE_CONFIG_DIR/hooks/$(basename "$f")"
done
want_jq "user theme survived uninstall" '.theme == "dark"'
want_jq "user hook survived uninstall"  '.hooks.SessionEnd[0].hooks[0].command == "mine.sh"'
want_jq "repo attribution gone"         'has("attribution") == false'
want_jq "repo model gone"               'has("model") == false'
want_jq "repo permissions gone"         'has("permissions") == false'
want_jq "repo PreToolUse gone"          '(.hooks | has("PreToolUse")) == false'
if compgen -G "$CLAUDE_CONFIG_DIR/backups/claude-ops/rules/git.md.bak.*" >/dev/null; then
  ok "backups left in place"
else
  fail "uninstall removed the backups"
fi

exit "$FAILED"
