# github rules

## pull requests
- PR title follows semantic-release Angular convention — same format and casing as commit subject (`type: lowercase subject`)
- semantic-release reads merged PR titles; wrong format breaks versioning (https://semantic-release.gitbook.io/semantic-release/)
- Always create as draft first; user promotes to ready
- Use `gh` CLI to create PRs
- Squash and merge strategy
- No labels, milestones, or assignees

## github actions
- Pin every action to a full-length commit SHA — never a mutable tag like `@v4` or `@latest`
- Add a trailing `# vX.Y.Z` comment next to the pinned SHA so the version is still visible at a glance (e.g. `uses: actions/checkout@<sha> # v4.2.2`)
- Use the latest stable release of an action when pinning or bumping it
- Bump pinned SHAs deliberately (e.g. via Dependabot/Renovate or a manual PR) — never let a workflow silently pick up a new version
- Prefer actions published by GitHub (`actions/*`) or the tool's own org over third-party forks
- Grant workflow `permissions` explicitly and as narrowly as possible — avoid relying on the default broad `GITHUB_TOKEN` scope
- Never echo secrets into logs or pass them to untrusted actions
