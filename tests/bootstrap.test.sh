#!/usr/bin/env bash
# Tests that claude-ops fetches missing jq/claude through mise, and that `update` defers to mise:
#   1. missing jq and claude are requested from mise at the versions pinned in mise.toml, from /
#   2. with no jq and no mise, the command fails with a clear message
#   3. `update` refuses inside a mise install dir and prints the mise commands
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0
ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/config" NO_COLOR=1
CLI="$REPO_ROOT/bin/claude-ops"
REAL_JQ="$(command -v jq)"

# A PATH with the system utilities but no jq or claude, so "missing" is real wherever this runs.
BASE="$WORK/base"; mkdir "$BASE"
for d in /usr/bin /bin; do
  for f in "$d"/*; do
    n="${f##*/}"
    case "$n" in jq|claude|mise) continue ;; esac
    [ -e "$BASE/$n" ] || ln -s "$f" "$BASE/$n"
  done
done

# What the stub mise hands back: a PATH dir holding the real jq and a fake claude.
TOOLS="$WORK/tools"; mkdir "$TOOLS"
ln -s "$REAL_JQ" "$TOOLS/jq"
printf '#!/bin/sh\nexit 0\n' > "$TOOLS/claude"; chmod +x "$TOOLS/claude"

STUB="$WORK/stub"; mkdir "$STUB"
cat > "$STUB/mise" <<STUBEOF
#!/bin/sh
echo "cwd=\$(pwd) args=\$*" >> "$WORK/mise.log"
printf '%s' "$TOOLS:$BASE"
STUBEOF
chmod +x "$STUB/mise"

pins() { sed -n "s/^$1 = \"\\([^\"]*\\)\".*/\\1/p" "$REPO_ROOT/mise.toml" | head -n1; }

echo "# 1. missing tools come from mise, pinned, run from /"
out="$(cd "$WORK" && env PATH="$STUB:$BASE" "$BASH" "$CLI" install rules/git 2>&1)"
log="$(cat "$WORK/mise.log" 2>/dev/null)"
case "$log" in *"cwd=/ "*) ok "ran mise from /" ;; *) fail "mise not run from /: $log" ;; esac
case "$log" in *"jq@$(pins jq)"*) ok "requested pinned jq" ;; *) fail "jq pin missing: $log" ;; esac
case "$log" in *"claude@$(pins claude)"*) ok "requested pinned claude" ;; *) fail "claude pin missing: $log" ;; esac
if [ -L "$CLAUDE_CONFIG_DIR/rules/git.md" ]; then ok "install completed"; else fail "install did not complete: $out"; fi

echo "# 2. no jq and no mise"
out="$(env PATH="$BASE" "$BASH" "$CLI" status 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then ok "fails"; else fail "expected failure"; fi
case "$out" in *"jq is required"*) ok "says jq is required" ;; *) fail "unclear error: $out" ;; esac

echo "# 3. update defers to mise"
MROOT="$WORK/share/mise/installs/github-nickdemianchuk-claude-ops/0.0.0"
mkdir -p "$MROOT"
( cd "$REPO_ROOT" && tar --exclude=.git -cf - . ) | tar -xf - -C "$MROOT"
out="$(env PATH="$TOOLS:$BASE" "$BASH" "$MROOT/bin/claude-ops" update 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then ok "refuses"; else fail "expected refusal"; fi
case "$out" in *"mise use -g --pin github:nickdemianchuk/claude-ops@latest"*) ok "prints the mise command" ;; *) fail "no mise hint: $out" ;; esac

exit "$FAILED"
