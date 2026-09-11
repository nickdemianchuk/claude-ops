# github rules

## pull requests
- PR title follows semantic-release Angular convention — same format and casing as commit subject (`type: lowercase subject`)
- semantic-release reads merged PR titles; wrong format breaks versioning (https://semantic-release.gitbook.io/semantic-release/)
- Always create as draft first; user promotes to ready
- Use `gh` CLI to create PRs
- Squash and merge strategy
- No labels, milestones, or assignees

## github actions
- Always pin to a specific version — never `@latest`, `@main`, or any other floating/mutable ref
- Applies to everything a workflow pulls in: action versions (`uses: actions/checkout@v4`), `runs-on` runner images, third-party dependencies installed in a step, and Docker image tags (`node:20.11.1`, not `node:latest`)
- Use the latest stable release when pinning or bumping a version
- Bump pinned versions deliberately (e.g. via Dependabot/Renovate or a manual PR) — never let a workflow silently pick up a new version
- Prefer actions published by GitHub (`actions/*`) or the tool's own org over third-party forks
- Grant workflow `permissions` explicitly and as narrowly as possible — avoid relying on the default broad `GITHUB_TOKEN` scope
- Never echo secrets into logs or pass them to untrusted actions
