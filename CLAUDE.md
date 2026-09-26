# claude-ops

This repo *is* my Claude Code configuration. Everything under it is installed into the user config dir
(`~/.claude/`, or `$CLAUDE_CONFIG_DIR`) as symlinks by `install.sh`, so a change here changes how every
session on this machine behaves. Treat edits as config changes, not just docs.

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

An instruction in `rules/` is a request Claude can misjudge. A hook or a `permissions.deny` rule is
enforcement. Anything that must hold every time belongs in the latter two, with the rule as documentation.

## Conventions

- Keep each unconditional rules file short — they cost context in every session, in every project.
  Long reference material belongs in a skill.
- One topic per file; name files after the topic (`git.md`, not `misc.md`).
- Hooks read the tool-call JSON on stdin and emit a `hookSpecificOutput` object. Every hook needs a case
  in `tests/`; the existing tests show the shape.
- Secrets never go in `mcps/*.json` or `settings/*.json` — reference an env var (`${GH_TOKEN}`), which
  Claude Code expands at connect time.

## Checks

```bash
./tests/block-direct-push.test.sh     # push guard matrix
./tests/secrets-guard.test.sh         # secret path/command matrix
./tests/install-roundtrip.test.sh     # install -> re-install -> uninstall, against a temp CLAUDE_CONFIG_DIR
shellcheck install.sh uninstall.sh hooks/*.sh tests/*.sh
```

`install.sh`/`uninstall.sh` write to `$CLAUDE_CONFIG_DIR`, so always point that at a temp dir when
testing them by hand — never run an untested change against the real `~/.claude`.

## After changing things

Editing an existing `rules/*.md`, `skills/*/` file, or `hooks/*.sh` applies immediately — they're
symlinked. Adding a *new* rule, skill, or hook, or changing anything in `settings/`, needs
`./install.sh` again to link or merge it. Hook and settings changes need `/hooks` reopened or a restart.
