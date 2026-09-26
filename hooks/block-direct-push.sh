#!/usr/bin/env bash
# PreToolUse(Bash): enforce rules/git.md — never push directly to the repo's
# default branch, including the initial commit (do that push yourself).
#
# Denies a push whose refspec names the default branch (`git push origin main`,
# `git push origin HEAD:main`, `git push -f o +x:refs/heads/main`), and a push
# with no refspec while the default branch is checked out. Also denies a push
# that retargets the repo with -C/--git-dir/--work-tree, since the branch check
# below can't see that repo.
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)"
default_branch="${default_branch:-main}"
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

base="claude-ops rule: never push directly to $default_branch (rules/git.md) — open a PR instead. If this is the initial commit, push it yourself outside Claude Code."

# Split the command into segments on ; & | and newlines, so tokens from a
# neighbouring command (e.g. `git log main && git push origin feat/x`) can't be
# mistaken for this push's refspec. `tr` rather than a sed bracket expression:
# `\n` inside `[...]` is a GNU extension that BSD sed reads as a literal `n`.
# `&&` and `||` just become an empty segment, which the loop skips.
segments="$(printf '%s' "$cmd" | tr ';&|' '\n')"

while IFS= read -r segment; do
  echo "$segment" | grep -qE '^[[:space:]]*(.*[[:space:]])?git[[:space:]]' || continue
  echo "$segment" | grep -qE '[[:space:]]push([[:space:]]|$)' || continue

  if echo "$segment" | grep -qE 'git[[:space:]]+(-C[[:space:]]|--git-dir|--work-tree)'; then
    deny "claude-ops rule: refusing a git push that retargets the repository with -C/--git-dir/--work-tree — the default-branch check (rules/git.md) can't be verified there. Run it from the target repo's own directory."
  fi

  # Tokens after `push`, with flags dropped — but not a flag's separate value,
  # so `-o ci.skip` can take the remote slot. Harmless: every later token is
  # still checked as a refspec, so that only shifts the slot, it can't hide one.
  args="$(echo "$segment" | sed -E 's/.*[[:space:]]push([[:space:]]|$)/ /')"
  refspecs=()
  remote_seen=false
  for token in $args; do
    case "$token" in
      -*) continue ;;
    esac
    if ! $remote_seen; then
      remote_seen=true
      continue
    fi
    refspecs+=("$token")
  done

  if [ "${#refspecs[@]}" -eq 0 ]; then
    # No explicit destination: git pushes the current branch.
    [ "$current_branch" = "$default_branch" ] && deny "$base"
    continue
  fi

  for refspec in "${refspecs[@]}"; do
    dest="${refspec##*:}"     # `src:dest` -> dest; a bare ref is its own dest
    dest="${dest#+}"          # force-push marker
    dest="${dest#refs/heads/}"
    [ "$dest" = "$default_branch" ] && deny "$base"
  done
done <<<"$segments"

exit 0
