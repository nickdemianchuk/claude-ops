# claude-ops

Personal [Claude Code](https://code.claude.com) rules, hooks, settings and MCP servers, kept in one repo and installed into `~/.claude/` with one command.

`claude-ops` is a small CLI that shows what is installed and lets you install or uninstall everything, a whole category, or individual items, from an interactive picker or the command line.

```
$ claude-ops install

claude-ops install  space selects, enter applies

❯ [x] select all  Every rule, hook, setting and mcp
  [x] rules  Instructions Claude follows in every session
    [x]   git.md                 Commit, branch and push conventions
    [x]   github.md              Pull request and GitHub Actions conventions
  [x] hooks  Scripts that run around tool calls to enforce the rules
    [x]   block-direct-push.sh   Blocks git pushes to the default branch
  ...
```

## What it manages

| Category | Source | Applied to your machine by |
| --- | --- | --- |
| `rules` | `rules/*.md` | symlinking into `~/.claude/rules/`, where Claude Code loads them as [user-level rules](https://code.claude.com/docs/en/memory#user-level-rules) |
| `hooks` | `hooks/*` | symlinking into `~/.claude/hooks/` and merging that hook's entries from `settings/hooks.json` into `settings.json` |
| `settings` | `settings/*.json` (except `hooks.json`) | deep-merging into `~/.claude/settings.json` |
| `mcps` | `mcps/*.json` | registering as user-scope servers with `claude mcp add-json` |

If `CLAUDE_CONFIG_DIR` is set, it replaces `~/.claude` everywhere above.

## Requirements

- bash 3.2 or newer (the macOS default works) and a POSIX userland (`sed`, `awk`, `fold`, `stty`, `dd`)
- [`jq`](https://jqlang.org)
- the [`claude` CLI](https://code.claude.com/docs/en/quickstart), only for the `mcps` category
- git, only if you install from a clone

## Installation

### From a clone (recommended)

Rules and hooks are symlinked back into the clone, so editing a file or running `git pull` updates them immediately.

```bash
git clone git@github.com:nickdemianchuk/claude-ops.git ~/Code/claude-ops
mkdir -p ~/.local/bin
ln -s ~/Code/claude-ops/bin/claude-ops ~/.local/bin/claude-ops   # any directory on your PATH
claude-ops --version
```

### From a release

Each [release](https://github.com/nickdemianchuk/claude-ops/releases) attaches `claude-ops-<version>.tar.gz` and a `.sha256` checksum. Keep the extracted directory: installed rules and hooks point back into it.

```bash
gh release download --repo nickdemianchuk/claude-ops --pattern 'claude-ops-*'
shasum -a 256 -c claude-ops-*.tar.gz.sha256      # sha256sum -c on Linux
mkdir -p ~/.local/share ~/.local/bin
tar -xzf claude-ops-*.tar.gz -C ~/.local/share
ln -s ~/.local/share/claude-ops-*/bin/claude-ops ~/.local/bin/claude-ops
```

Without a PATH symlink, run `bin/claude-ops` directly.

## Quick start

```bash
claude-ops status         # what is installed right now
claude-ops install        # pick what to install
claude-ops status hooks   # details for a category or item
```

After installing or changing hooks, open `/hooks` in Claude Code once (or restart it) so the change is picked up.

## Usage

```
claude-ops <command> [target...]

commands:
  status     [target...]  what's installed (details when targets are given)
  install    [target...]  install items; interactive picker with no targets
  uninstall  [target...]  uninstall items; interactive picker with no targets

options:
  -v, --version  print the current version
  -h, --help     show this help
```

### Targets

A target is a category (`rules`, `hooks`, `settings`, `mcps`) or a single item written as `category/name`. The file extension is optional, and a bare name works if it is unambiguous.

```bash
claude-ops install rules                           # every rule
claude-ops install hooks/secrets-guard settings/model
claude-ops uninstall mcps
claude-ops install github                          # error: matches rules/github.md and mcps/github.json
```

With no targets, `install` and `uninstall` open the picker (it needs a terminal). With targets they run straight through, so they are safe to script.

### The picker

| Key | Action |
| --- | --- |
| `↑` `↓` or `j` `k` | move |
| `space` | toggle the highlighted item; on a category, everything in it; on `select all`, everything |
| `a` | toggle everything, from anywhere |
| `enter` | apply the selection |
| `q`, `esc` or `ctrl-c` | cancel without changing anything |

`install` preselects what is not installed yet. `uninstall` lists only what is installed and preselects nothing. Long lists scroll, and the highlighted item's description appears below the list.

### Item states

| State | Meaning |
| --- | --- |
| `installed` | present and matching this repo |
| `not installed` | nothing of it is present |
| `partial` | some pieces are present, for example a hook's symlink without its `settings.json` entry |
| `modified` | present but different from this repo: a symlink pointing elsewhere, a real file in the way, or a setting or MCP server with another value |

`install` fixes `partial` and `modified` items (backing up first, see below).

### Exit codes

`0` success or cancelled with `q`/`esc`, `1` error (unknown command or target, missing `jq`, no targets without a terminal), `130` interrupted with `ctrl-c`.

## Safety

- Installing is idempotent: re-running reports `up to date` for anything already correct.
- A real file at a symlink destination is moved to `~/.claude/backups/claude-ops/{rules,hooks}/<name>.bak.<timestamp>` before it is replaced.
- `settings.json` is backed up to `~/.claude/backups/claude-ops/settings/` once per run, and only if the merge changes it.
- Settings merge as follows: objects merge recursively, arrays are set-unioned (so hooks are never duplicated), and for scalars this repo's value wins. Keys this repo does not mention are left alone.
- Uninstall only removes what this repo manages: symlinks that still point into this repo, and `settings.json` values that exactly match a fragment. Backups and anything you added yourself stay.
- MCP servers are matched by name only, because `claude mcp` cannot diff a stored server. Uninstalling `mcps/github` removes a user-scope server named `github` even if you defined it yourself, and installing it replaces one.

## Configuration

| Variable | Effect |
| --- | --- |
| `CLAUDE_CONFIG_DIR` | Claude Code config directory to manage instead of `~/.claude`. MCP servers are read from and written to `$CLAUDE_CONFIG_DIR/.claude.json` in that case. |
| `NO_COLOR` | Set to any value to turn colors off. Colors are also off whenever stdout is not a terminal. |

To try the CLI without touching your real setup, point it at a scratch directory:

```bash
export CLAUDE_CONFIG_DIR=$(mktemp -d)
claude-ops install && claude-ops status
```

## Included items

Every item has a summary and longer description in [`manifest.json`](manifest.json), shown by `claude-ops status <target>` and in the picker.

- **Rules**: `git.md` (commit, branch and push conventions), `github.md` (PR and GitHub Actions conventions)
- **Hooks**: `block-direct-push.sh`, `pr-reminder.sh`, `secrets-guard.sh`
- **Settings**: `attribution.json`, `model.json`, `output.json`
- **MCP servers**: `github.json`, GitHub's hosted server. It reads `GH_TOKEN` at connect time, so export `GH_TOKEN="$(gh auth token)"` in your shell profile before starting `claude`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `error: jq is required` | install `jq` (`brew install jq`) |
| `claude CLI is required for mcps, skipping` | install Claude Code, or skip the `mcps` category |
| Hooks installed but not firing | open `/hooks` once, or restart Claude Code |
| `no targets given and not a terminal` | pass targets when running from a script or pipe |
| `'<name>' is ambiguous` | use the `category/name` form |
| Picker looks broken | use a UTF-8 locale and a terminal about 80 columns wide; text is truncated to fit |

## Contributing

Layout:

```
bin/claude-ops       the CLI
rules/ hooks/ settings/ mcps/   the items
manifest.json        summary + details for each item
```

Adding an item:

1. Add the file to its directory. For a hook, also add its entry to `settings/hooks.json`, referencing `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/<name>`.
2. Add `summary` and `details` for it under `items` in `manifest.json`, keyed `category/filename`.
3. Keep machine-specific values and secrets out. Reference an environment variable instead (for example `Bearer ${GH_TOKEN}`).
4. Run `claude-ops install <category>/<name>` against a scratch `CLAUDE_CONFIG_DIR` and check `claude-ops status`.

Editing an existing rule or hook script applies immediately because it is symlinked. New hooks and changes under `settings/` or `mcps/` need `claude-ops install` again.

### CI

`ci.yml` runs on every PR and push:

- `lint-pr` / `lint-commits`: title and commit format (see [`rules/git.md`](rules/git.md))
- `lint-settings`: validates `settings/*.json` against the [Claude Code settings schema](https://json.schemastore.org/claude-code-settings.json)
- `lint-mcps`: every `mcps/*.json` is valid JSON with a `type` of `stdio`, `sse` or `http`
- `lint-manifest`: every item has a `summary` and `details` in `manifest.json`

Run the checks locally:

```bash
curl -fsSL -o /tmp/schema.json https://json.schemastore.org/claude-code-settings.json
npx ajv-cli@5.0.0 validate --strict=false --validate-formats=false -s /tmp/schema.json -d "settings/*.json"

for f in mcps/*.json; do jq -e '.type | IN("stdio", "sse", "http")' "$f"; done

for f in rules/*.md hooks/* settings/*.json mcps/*.json; do
  [ "$f" = settings/hooks.json ] && continue
  jq -e --arg k "$f" '.items[$k].summary and .items[$k].details' manifest.json >/dev/null || echo "missing: $f"
done
```

### Releases

`cd.yml` runs [`nickdemianchuk/actions`'s `release.yml`](https://github.com/nickdemianchuk/actions#releaseyml) on every push to `main`. It runs semantic-release and authenticates as the [Octo Buddy](https://github.com/apps/octo-buddy) GitHub App through the `OCTO_BUDDY_CLIENT_ID` variable and `OCTO_BUDDY_PRIVATE_KEY` secret (registered in `github-ops`). When a release is published, `release-assets.yml` attaches `claude-ops-<version>.tar.gz`, stamped with a `VERSION` file, and its checksum. `claude-ops --version` reads that file, then the git tag, then `CHANGELOG.md`.
