#!/usr/bin/env bash
# Tests hooks/pr-reminder.sh: the nudge fires only after a push on a branch that
# already tracked an upstream, so it stays quiet on a branch's first push and on
# commands that aren't a push at all.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/pr-reminder.sh"
FAILED=0

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

git init -q -b main "$FIXTURE/upstream"
git -C "$FIXTURE/upstream" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git clone -q "$FIXTURE/upstream" "$FIXTURE/work" 2>/dev/null
cd "$FIXTURE/work" || exit 1

run() { # run <nudge|quiet> <command>
  local expect="$1" cmd="$2" out verdict
  out="$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | bash "$HOOK" 2>&1)"
  if echo "$out" | grep -q 'additionalContext'; then verdict=nudge; else verdict=quiet; fi
  if [ "$verdict" = "$expect" ]; then
    printf 'ok   %-5s %s\n' "$verdict" "$cmd"
  else
    printf 'FAIL want=%-5s got=%-5s %s\n' "$expect" "$verdict" "$cmd"
    FAILED=1
  fi
}

echo "# a tracked branch: a push may need the PR body refreshed"
git checkout -q main
run nudge 'git push'
run nudge 'git push origin main'
run nudge 'git push --force-with-lease'

echo "# an untracked branch: nothing to refresh yet"
git checkout -q -b feat/fresh
run quiet 'git push'
run quiet 'git push -u origin feat/fresh'
run quiet 'git push --set-upstream origin feat/fresh'

echo "# a tracked branch, but -u means it is the first push of one"
git checkout -q main
run quiet 'git push -u origin main'

echo "# not a push"
run quiet 'git status'
run quiet 'git commit -m "wip"'
run quiet 'echo "git push"'
run quiet 'npm test'

exit "$FAILED"
