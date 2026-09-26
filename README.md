# claude-ops

Personal [Claude Code](https://code.claude.com) rules, kept in one place and installed as user-level rules.

## Contents

- `rules/` — self-contained rules docs, one per topic (e.g. git/GitHub conventions). Add new topics as new files.
- `hooks/` — scripts that enforce the rules automatically (block a push to `main`, validate commit/PR title format, strip AI attribution, etc). Add new hooks here and wire them up in `settings/hooks.json`.
- `settings/` — fragments merged into `~/.claude/settings.json` on install, one file per topic: `hooks.json` (the `hooks` block), `attribution.json`, `output.json`. Add new topics as new files. Keep machine-specific settings out of them.
- `manifest.json` — the human-readable `summary` and `details` shown for every item in `claude-ops status` and the install picker, plus one line per category. Add an entry whenever you add a rule, hook, setting or mcp; the `lint-manifest` CI job fails if one is missing.
- `mcps/` — one file per MCP server (`<name>.json`, the bare server object `claude mcp add-json` expects), registered as user-scope servers on install. Keep secrets out of them — reference an env var instead (e.g. `"Bearer ${GH_TOKEN}"`), which Claude Code expands at connect time.

## CLI

`bin/claude-ops` manages everything (bash 3.2+ and `jq`). Put it on your `PATH` with `ln -s "$PWD/bin/claude-ops" ~/.local/bin/claude-ops`.

```bash
claude-ops status [target...]             # compact overview; details when targets are given
claude-ops install [target...]            # no targets: interactive picker
claude-ops uninstall [target...]          # no targets: interactive picker
claude-ops --version                      # release tag (git describe), CHANGELOG.md fallback
```

Targets are a category (`rules`, `hooks`, `settings`, `mcps`) or one item (`rules/git.md`, `hooks/secrets-guard.sh`, `settings/model.json`, `mcps/github.json`; extension optional). The picker uses ↑/↓ (or `j`/`k`), space to toggle an item (on a category header: everything in it; on the top `select all` row: everything), `a` to toggle all, enter to apply, `q`/esc to cancel. Install preselects what isn't installed yet; uninstall lists only installed items and preselects none.

- rules are symlinked into `~/.claude/rules/` (or `$CLAUDE_CONFIG_DIR/rules/`).
- hooks are symlinked into `~/.claude/hooks/`, and only that hook's entries from `settings/hooks.json` are merged into `settings.json`.
- settings deep-merge each `settings/*.json` (except `hooks.json`) into `settings.json`: objects recurse, arrays are set-unioned, scalars take the repo's value.
- mcps are registered as user-scope servers via `claude mcp add-json <name> -s user` (removing any existing entry of that name first, so the repo's definition wins). `github.json` points at GitHub's hosted MCP server and authenticates with `Authorization: Bearer ${GH_TOKEN}`; export `GH_TOKEN="$(gh auth token)"` in your shell profile so it's set before `claude` starts. Needs the `claude` CLI.
- uninstall removes only symlinks still pointing into this repo and settings values that exactly match a fragment; backups and anything you added yourself stay. MCP servers are matched by name only, so a same-named user-scope server you defined yourself is removed too.

Safe to re-run: correct symlinks are left alone, a pre-existing real file is backed up first, and `settings.json` is backed up once per run if it changes. Backups go to `~/.claude/backups/claude-ops/{rules,hooks,settings}/<name>.bak.<timestamp>`.

After installing or updating hooks, open `/hooks` once (or restart) to make Claude Code pick up the change.

## Updating rules

Edit files under `rules/`, commit, and push — since the install is symlink-based, changes apply immediately without re-running `claude-ops install`.

## Updating hooks

Editing an existing `hooks/*.sh` script applies immediately (symlinked). Adding a new hook or changing anything in `settings/` requires re-running `claude-ops install` to merge the change into `~/.claude/settings.json`.

## CI

`ci.yml` lints PR titles and commit messages, its `lint-settings` job validates every `settings/*.json` against the [Claude Code settings schema](https://json.schemastore.org/claude-code-settings.json) with `ajv-cli`, and its `lint-mcps` job checks that every `mcps/*.json` is valid JSON with a `type` of `stdio`, `sse`, or `http`. To check locally:

```bash
curl -fsSL -o /tmp/schema.json https://json.schemastore.org/claude-code-settings.json
npx ajv-cli@5.0.0 validate --strict=false --validate-formats=false -s /tmp/schema.json -d "settings/*.json"

for f in mcps/*.json; do jq -e '.type | IN("stdio", "sse", "http")' "$f"; done
```

## Releases

`cd.yml` runs [`nickdemianchuk/actions`'s `release.yml`](https://github.com/nickdemianchuk/actions#releaseyml) on every push to `main`, authenticating as the [Octo Buddy](https://github.com/apps/octo-buddy) GitHub App via the repo's `OCTO_BUDDY_CLIENT_ID` variable and `OCTO_BUDDY_PRIVATE_KEY` secret (registered in `github-ops`).
