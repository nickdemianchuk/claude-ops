# claude-ops

Personal Claude Code configuration. This repo is the source of truth; `bin/claude-ops` installs it into the
user config dir (`~/.claude/`, or `$CLAUDE_CONFIG_DIR`), symlinking files so the installed state follows the
repo. A change here changes how every session on the machine behaves, so treat edits as config changes rather
than docs.

## Where things go

Pick by how the content should load, not by subject:

| Adding | Goes in | Loads |
| --- | --- | --- |
| A convention that applies in every session | `rules/<topic>.md`, no frontmatter | always |
| A convention only relevant to certain files | `rules/<topic>.md` with `paths:` frontmatter | when Claude reads a matching file |
| Reference material or a `/command` workflow | `skills/<name>/SKILL.md` | description always, body on demand |
| Something that must happen every time | `hooks/<name>.sh` + an entry in `settings/hooks.json` | on its lifecycle event |
| A hard block Claude cannot reason around | `permissions.deny` in `settings/permissions.json` | enforced by the client |
| A config value | a new `settings/<topic>.json` fragment | merged into `settings.json` |
| An MCP server | `mcps/<name>.json` | registered user-scope on install |

Rule loading is mechanical, never contextual: a rule with no `paths` loads at launch, and one with `paths`
loads when Claude reads a matching file. A skill is the contextual one — Claude matches the task against its
`description`. So a convention that must hold for every edit belongs in a rule, not a skill: a skill that
fails to fire does so invisibly.

An instruction in `rules/` is still only a request Claude can misjudge. A hook or a `permissions.deny` rule
is enforcement. Anything that must hold every time belongs in the latter two, with the rule as documentation.

## Conventions

- Keep each unconditional rules file short — they cost context in every session, in every project.
  Long reference material belongs in a skill.
- One topic per file; name files after the topic (`git.md`, not `misc.md`).
- Every new item needs a `summary` and `details` in `manifest.json`, or `lint-manifest` fails. A skill's key
  is its directory (`skills/twelve-factor`), and its `name` frontmatter must match that directory.
- Adding a category means touching `CATEGORIES`, `canon_category`, `list_items`, `item_state`,
  `item_summary`, `install_item`, `uninstall_item` and `item_detail` in `bin/claude-ops`.
- Hooks read the tool-call JSON on stdin and emit a `hookSpecificOutput` object. Every hook needs a case
  in `tests/`; the existing tests show the shape.
- Secrets never go in `mcps/*.json` or `settings/*.json` — reference an env var (`${GH_TOKEN}`), which
  Claude Code expands at connect time.
- Write shell that works on BSD userland too, not just GNU: no `\n` inside a `sed` bracket expression, no
  GNU-only flags. CI runs Linux, so a GNU-ism passes there and fails on macOS.

## Checks

```bash
for t in tests/*.test.sh; do bash "$t"; done   # hooks, plus the install/uninstall round-trip
shellcheck bin/claude-ops hooks/*.sh tests/*.sh
```

`bin/claude-ops` writes to `$CLAUDE_CONFIG_DIR`, so always point that at a temp dir when testing it by hand —
never run an untested change against the real `~/.claude`. The round-trip test already does this.

## After changing things

Editing an existing `rules/*.md`, `skills/*/` file, or `hooks/*.sh` applies immediately — they're symlinked.
Adding a *new* rule, skill, or hook, or changing anything in `settings/`, needs `claude-ops install` again to
link or merge it. Hook and settings changes need `/hooks` reopened or a restart.
