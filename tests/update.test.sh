#!/usr/bin/env bash
# Tests `claude-ops update` in git mode against a local bare remote:
#   1. up to date when the clone matches origin/main
#   2. --check reports a newer commit without changing anything
#   3. a dirty tree blocks the update
#   4. update fast-forwards and keeps installed items linked
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0
ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/config" NO_COLOR=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q --bare -b main "$WORK/remote.git"
# Seed from a copy of the working tree (not a clone: CI checkouts are shallow and can't push,
# and this way uncommitted changes to the CLI are what gets tested).
mkdir "$WORK/seed"
( cd "$REPO_ROOT" && tar --exclude=.git -cf - . ) | tar -xf - -C "$WORK/seed"
( cd "$WORK/seed" && git init -q -b main && git add -A && git commit -qm "chore: seed" \
  && git remote add origin "$WORK/remote.git" && git push -q origin HEAD )
git clone -q "$WORK/remote.git" "$WORK/clone"
CLI="$WORK/clone/bin/claude-ops"
head_of() { ( cd "$1" && git rev-parse HEAD ); }

bash "$CLI" install rules/git >/dev/null 2>&1

echo "# 1. up to date"
out="$(bash "$CLI" update 2>&1)"
case "$out" in "up to date"*) ok "reports up to date" ;; *) fail "expected up to date, got: $out" ;; esac

echo "# 2. --check with a newer commit"
echo "# bump" >> "$WORK/seed/rules/git.md"
( cd "$WORK/seed" && git commit -qam "chore: bump" && git push -q origin HEAD )
before="$(head_of "$WORK/clone")"
out="$(bash "$CLI" update --check 2>&1)"
case "$out" in "update available"*) ok "reports update available" ;; *) fail "expected update available, got: $out" ;; esac
if [ "$(head_of "$WORK/clone")" = "$before" ]; then ok "--check left HEAD alone"; else fail "--check moved HEAD"; fi

echo "# 3. dirty tree blocks"
echo x > "$WORK/clone/junk"
if bash "$CLI" update >/dev/null 2>&1; then fail "update ran on a dirty tree"; else ok "dirty tree refused"; fi
rm "$WORK/clone/junk"

echo "# 4. update"
out="$(bash "$CLI" update 2>&1)" || fail "update exited non-zero: $out"
if [ "$(head_of "$WORK/clone")" = "$(head_of "$WORK/seed")" ]; then ok "fast-forwarded"; else fail "did not fast-forward"; fi
if [ -L "$CLAUDE_CONFIG_DIR/rules/git.md" ]; then ok "rule still linked"; else fail "rule link lost"; fi

exit "$FAILED"
