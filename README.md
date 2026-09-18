# claude-ops

Personal [Claude Code](https://code.claude.com) rules, kept in one place and installed as user-level rules.

## Contents

- `rules/` — self-contained rules docs, one per topic (e.g. git/GitHub conventions). Add new topics as new files.
- `hooks/` — scripts that enforce the rules automatically (block a push to `main`, validate commit/PR title format, strip AI attribution, etc). Add new hooks here and wire them up in `settings/hooks.json`.
- `settings/` — fragments merged into `~/.claude/settings.json` on install, one file per topic: `hooks.json` (the `hooks` block), `attribution.json`, `output.json`. Add new topics as new files. Keep machine-specific settings out of them.

## Install

```bash
./install.sh             # rules + hooks + settings (default when no flags given)
./install.sh --rules     # rules/*.md only
./install.sh --hooks     # hooks/* + settings/hooks.json only
./install.sh --settings  # settings/*.json except hooks.json only
```

- `--rules` symlinks each file in `rules/` into `~/.claude/rules/` (or `$CLAUDE_CONFIG_DIR/rules/` if set), so Claude Code picks them up as [user-level rules](https://code.claude.com/docs/en/memory#user-level-rules) in every project.
- `--hooks` symlinks each file in `hooks/` into `~/.claude/hooks/` and merges `settings/hooks.json` into `~/.claude/settings.json`, so the enforcement hooks run in every project. The merge is a set union per hook event — your existing hooks are preserved, and re-running never duplicates entries.

- `--settings` deep-merges the other `settings/*.json` fragments into `~/.claude/settings.json` the same way: objects merge recursively, arrays are set-unioned, and for scalars (e.g. `outputStyle`) the repo's value wins. Keys not in the repo files are preserved.

Safe to re-run: existing correct symlinks are left alone, and any pre-existing real file at the destination is backed up before being replaced. `~/.claude/settings.json` is likewise backed up once per run, and only if the merge would change it. Backups go to `~/.claude/backups/claude-ops/{rules,hooks,settings}/<name>.bak.<timestamp>`, separate from Claude Code's own files in `backups/`.

After installing or updating hooks, open `/hooks` once (or restart) to make Claude Code pick up the change.

## Uninstall

```bash
./uninstall.sh             # rules + hooks + settings (default when no flags given)
./uninstall.sh --rules     # rules/*.md only
./uninstall.sh --hooks     # hooks/* + settings/hooks.json only
./uninstall.sh --settings  # settings/*.json except hooks.json only
```

Mirrors `install.sh` in reverse: removes symlinks that still point into this repo, and un-merges `settings/*.json` entries from `~/.claude/settings.json`. Only removes what this repo manages — backups, edited symlinks, and hooks you added yourself are left alone.

## Updating rules

Edit files under `rules/`, commit, and push — since the install is symlink-based, changes apply immediately without re-running `install.sh`.

## Updating hooks

Editing an existing `hooks/*.sh` script applies immediately (symlinked). Adding a new hook or changing anything in `settings/` requires re-running `./install.sh` to merge the change into `~/.claude/settings.json`.

## CI

`ci.yml` lints PR titles and commit messages, and its `lint-settings` job validates every `settings/*.json` against the [Claude Code settings schema](https://json.schemastore.org/claude-code-settings.json) with `ajv-cli`. To check locally:

```bash
curl -fsSL -o /tmp/schema.json https://json.schemastore.org/claude-code-settings.json
npx ajv-cli@5.0.0 validate --strict=false --validate-formats=false -s /tmp/schema.json -d "settings/*.json"
```

## Releases

`cd.yml` runs [`nickdemianchuk/actions`'s `release.yml`](https://github.com/nickdemianchuk/actions#releaseyml) on every push to `main`, authenticating as the [Octo Buddy](https://github.com/apps/octo-buddy) GitHub App via the repo's `OCTO_BUDDY_CLIENT_ID` variable and `OCTO_BUDDY_PRIVATE_KEY` secret (registered in `github-ops`).
