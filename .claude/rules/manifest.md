---
paths:
  - "manifest.json"
  - "rules/*.md"
  - "skills/**"
  - "hooks/*"
  - "settings/*.json"
  - "mcps/*.json"
---

# manifest.json upkeep

`manifest.json` holds the human description of every installable item. `lint-manifest` fails CI when an item
has no entry, and `claude-ops status` and the picker fall back to a thin line derived from the file itself.

## when it needs changing

- **Adding an item** — a rule, skill, hook, settings fragment or mcp — add its `items` entry in the same change
- **Removing one** — delete the entry; nothing else references it
- **Renaming one** — rename the key. The key is a path, so a stale key is silently ignored rather than flagged
- **Changing what one does** — update `details`. A hook whose matcher or behaviour changed reads as working
  the old way until you do, and nothing catches that
- **Adding a category** — add a `categories` entry, and extend the `lint-manifest` glob in
  `.github/workflows/ci.yml` so the new category's items are checked too

## keys

The key is the item's repo-relative path, except a skill, which is keyed by its directory:

| Item | Key |
| --- | --- |
| `rules/comments.md` | `rules/comments.md` |
| `skills/twelve-factor/SKILL.md` | `skills/twelve-factor` |
| `hooks/secrets-guard.sh` | `hooks/secrets-guard.sh` |
| `settings/model.json` | `settings/model.json` |
| `mcps/github.json` | `mcps/github.json` |

`settings/hooks.json` has no entry on purpose: each hook owns its slice of it, so the hook's entry covers it.

## what to write

- `summary` — one line, shown beside the item name. `status` truncates it to the terminal width minus 43
  columns, the picker to width minus 34, so it clips around 37 characters on an 80-column terminal. The
  existing summaries run 29–48 characters; match that rather than padding to the limit.
- `details` — a short paragraph covering what it does and anything surprising: a rule that loads only for
  certain files, a hook needing a `/hooks` reopen, a setting that also blocks something you'd want.

Both are prose for a person choosing whether to install the item, not a restatement of the filename.

Check the same way CI does:

```bash
for f in rules/*.md skills/*/ hooks/* settings/*.json mcps/*.json; do
  [ "$f" = settings/hooks.json ] && continue
  jq -e --arg k "${f%/}" '.items[$k].summary and .items[$k].details' manifest.json >/dev/null \
    || echo "missing: ${f%/}"
done
```
