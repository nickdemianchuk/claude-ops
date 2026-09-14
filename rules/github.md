# github rules

## pull requests
- PR title follows semantic-release Angular convention — same format and casing as commit subject (`type: lowercase subject`)
- semantic-release reads merged PR titles; wrong format breaks versioning (https://semantic-release.gitbook.io/semantic-release/)
- Always create as draft first; user promotes to ready
- Use the GitHub MCP server tools for all GitHub operations (PRs, comments, reviews, issues) — not the `gh` CLI
- Squash and merge strategy
- PR body: 1–2 sentences describing the change. For large PRs, a short bullet list instead. No headers, no sections.
- In PR body, wrap variable/function names, values, types, keywords in single backticks (`` ` ``); use multi-line ``` code blocks for snippets
- When writing any GitHub text (PR/issue/comment), apply correct Markdown formatting
- No session links in PR body

## attribution
- No AI/assistant attribution anywhere — PR titles, descriptions, comments, or reviews
- No generated-by footers or session links in any GitHub content

## github actions

### pinning
- Never use `@latest`, `@main`, or any other floating/mutable ref — always pin to a specific version
- Applies everywhere a workflow pulls in external code: action versions (`actions/checkout@v4`), Docker image tags (`node:20.11.1`, not `node:latest`), `runs-on` runner images, and third-party dependencies installed in a step
- Pin to the latest stable release; bump deliberately (e.g. via Dependabot/Renovate or a manual PR) — never let a workflow silently pick up a new version
- Prefer actions published by GitHub (`actions/*`) or the tool's own org over third-party forks

### permissions & secrets
- Grant workflow `permissions` explicitly and as narrowly as possible — avoid relying on the default broad `GITHUB_TOKEN` scope
- Never echo secrets into logs or pass them to untrusted actions
