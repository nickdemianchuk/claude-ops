#!/usr/bin/env bash
# Tests hooks/block-direct-push.sh against a matrix of git commands, in a
# throwaway repo whose default branch is `main` with a feature branch checked
# out — so the result doesn't depend on which branch CI happens to be on.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/block-direct-push.sh"
FAILED=0

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

git init -q -b main "$FIXTURE/upstream"
git -C "$FIXTURE/upstream" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git clone -q "$FIXTURE/upstream" "$FIXTURE/work" 2>/dev/null
git -C "$FIXTURE/work" remote set-head origin main
git -C "$FIXTURE/work" checkout -q -b feat/thing
cd "$FIXTURE/work"

run() { # run <deny|allow> <command>
  local expect="$1" cmd="$2" out verdict
  out="$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | bash "$HOOK" 2>&1)"
  if echo "$out" | grep -q '"deny"'; then verdict=deny; else verdict=allow; fi
  if [ "$verdict" = "$expect" ]; then
    printf 'ok   %-5s %s\n' "$verdict" "$cmd"
  else
    printf 'FAIL want=%-5s got=%-5s %s\n' "$expect" "$verdict" "$cmd"
    FAILED=1
  fi
}

echo "# denied: anything that would land on the default branch"
run deny  'git push origin main'
run deny  'git push origin HEAD:main'
run deny  'git push origin feat/thing:main'
run deny  'git push -f origin +feat/x:refs/heads/main'
run deny  'git push --force-with-lease origin HEAD:refs/heads/main'
run deny  'git log main && git push origin main'
run deny  'echo hi; git push origin main'
echo "# denied: a push whose repo this hook cannot inspect"
run deny  'git -C ../other-repo push'
run deny  'git --git-dir=/x/.git push'
echo "# allowed: ordinary feature-branch work"
run allow 'git push -u origin feat/thing'
run allow 'git push origin HEAD:feat/x'
run allow 'git push'
run allow 'git log main && git push origin feat/x'
run allow 'git push origin feat/main-menu'
echo "# allowed: not a push at all"
run allow 'git commit -m "merge main"'
run allow 'git status'
run allow 'echo "git push origin main is forbidden"'

# On the default branch, a bare push is the thing the rule exists to stop.
git checkout -q main
echo "# denied: bare push while the default branch is checked out"
run deny  'git push'
run deny  'git push -u origin main'

exit "$FAILED"
