# claude-ops

Personal [Claude Code](https://code.claude.com) rules, kept in one place and installed as user-level rules.

## Contents

Each file in `rules/` is a self-contained rules doc for one topic (e.g. git workflow, GitHub conventions). Add new topics as new files.

## Install

```bash
./install.sh
```

Symlinks each file in `rules/` into `~/.claude/rules/` (or `$CLAUDE_CONFIG_DIR/rules/` if set), so Claude Code picks them up as [user-level rules](https://code.claude.com/docs/en/memory#user-level-rules) in every project.

Safe to re-run: existing correct symlinks are left alone, and any pre-existing real file at the destination is backed up (`<name>.bak.<timestamp>`) before being replaced.

## Updating rules

Edit files under `rules/`, commit, and push — since the install is symlink-based, changes apply immediately without re-running `install.sh`.
