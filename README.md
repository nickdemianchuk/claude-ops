# claude-ops

Personal [Claude Code](https://code.claude.com) rules, kept in one place and installed as user-level rules.

## Contents

- `rules/` — self-contained rules docs, one per topic (e.g. git/GitHub conventions). Add new topics as new files.
- `hooks/` — scripts that enforce the rules automatically (block a push to `main`, validate commit/PR title format, strip AI attribution, etc). Add new hooks here and wire them up in `hooks.json`.
- `hooks.json` — the `hooks` block merged into `settings.json` on install.

## Install

```bash
./install.sh
```

- Symlinks each file in `rules/` into `~/.claude/rules/` (or `$CLAUDE_CONFIG_DIR/rules/` if set), so Claude Code picks them up as [user-level rules](https://code.claude.com/docs/en/memory#user-level-rules) in every project.
- Symlinks each file in `hooks/` into `~/.claude/hooks/` and merges `hooks.json` into `~/.claude/settings.json`, so the enforcement hooks run in every project. The merge is a set union per hook event — your existing hooks are preserved, and re-running never duplicates entries.

Safe to re-run: existing correct symlinks are left alone, and any pre-existing real file at the destination is backed up (`<name>.bak.<timestamp>`) before being replaced.

After installing or updating hooks, open `/hooks` once (or restart) to make Claude Code pick up the change.

## Updating rules

Edit files under `rules/`, commit, and push — since the install is symlink-based, changes apply immediately without re-running `install.sh`.

## Updating hooks

Editing an existing `hooks/*.sh` script applies immediately (symlinked). Adding a new hook or changing `hooks.json` requires re-running `./install.sh` to merge the change into `settings.json`.

## Releases

`cd.yml` runs [`nickdemianchuk/actions`'s `release.yml`](https://github.com/nickdemianchuk/actions#releaseyml) on every push to `main`, authenticating as the [Octo Buddy](https://github.com/apps/octo-buddy) GitHub App via the repo's `OCTO_BUDDY_CLIENT_ID` variable and `OCTO_BUDDY_PRIVATE_KEY` secret (registered in `github-ops`).
