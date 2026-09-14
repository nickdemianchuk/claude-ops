# git rules

## commits
Follow Angular commit convention per semantic-release and Conventional Commits:
- https://semantic-release.gitbook.io/semantic-release/
- https://www.conventionalcommits.org/

Format: `type: subject`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `perf`

Subject rules:
- Lowercase first letter (e.g. `feat: add login page` not `feat: Add login page`)
- Imperative mood (e.g. `add` not `added`)
- ≤50 chars
- No trailing period
- No body, no footer — single subject line only
- Never add `Co-Authored-By` lines

Version impact:
- `fix:` → patch bump
- `feat:` → minor bump
- `BREAKING CHANGE:` in footer → major bump (confirm with user before using)

## branches
- Conventional naming: `feat/slug`, `fix/slug`, `chore/slug` — kebab-case slug
- Base branch: `main`
- Delete branch after PR merges

## push
- Push freely to any non-`main` branch — no confirmation needed
- Never push directly to `main` — always open a PR instead
- `main` is the only protected branch

## force push
- Get explicit user confirmation before force pushing
- Warn about consequences first
