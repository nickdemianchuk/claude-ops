# claude-ops

Shared [Claude Code](https://code.claude.com) rules for git and GitHub workflows, kept in one place and installed as user-level rules.

## Contents

- `rules/git.md` — commit convention, branch naming, push/force-push policy
- `rules/github.md` — pull request conventions, GitHub Actions pinning and permissions

## Install

```bash
./install.sh
```

Symlinks each file in `rules/` into `~/.claude/rules/` (or `$CLAUDE_CONFIG_DIR/rules/` if set), so Claude Code picks them up as [user-level rules](https://code.claude.com/docs/en/memory#user-level-rules) in every project.

Safe to re-run: existing correct symlinks are left alone, and any pre-existing real file at the destination is backed up (`<name>.bak.<timestamp>`) before being replaced.

## Updating rules

Edit files under `rules/`, commit, and push — since the install is symlink-based, changes apply immediately without re-running `install.sh`.
