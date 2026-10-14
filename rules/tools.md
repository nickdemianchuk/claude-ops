# tool rules

Install every tool with [mise](https://mise.jdx.dev), the preferred method; when mise can't install a tool,
use the tool's own recommended installation method. Not `brew`, `apt`, `npm -g`, `pip`, `cargo install`,
`go install` or `curl | sh`.

## installing
- Check `mise.toml` first — the tool may already be declared; `mise install` fetches what it lists
- Search `mise registry` before anything else; for a tool with no registry entry use a backend:
  `npm:`, `pipx:`, `cargo:`, `go:`, `ubi:owner/repo` or `github:owner/repo`
- Record project tools in the repo's committed `mise.toml`; personal tools go in the global config
  (`mise use -g`)

## versions
- Pin the exact latest version: `mise use --pin <tool>@latest` writes the resolved number (`jq = "1.8.2"`)
- Never write `"latest"` or a fuzzy version (`"20"`) into `mise.toml`
- Don't run bare `mise use <tool>` — it writes `"latest"`, or reuses an older installed version
- A version the user names wins; still pin it exact: `mise use --pin node@22`
- Bump deliberately with `mise upgrade --bump`, never as a side effect of another change

## one-off runs
- `mise exec <tool>@<exact version> -- <cmd>`, not an unpinned `npx` or `pipx run`

## ci
- Install tools in workflows with `jdx/mise-action`, pinned to a release, reading `mise.toml`
- Don't re-declare tool versions in the workflow; `mise.toml` is the single source
