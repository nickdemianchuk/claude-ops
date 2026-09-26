# twelve-factor rules

Principles from *The Twelve-Factor App* (Adam Wiggins) — https://12factor.net/

Apply these when building or changing a deployable service. They describe the app's contract with its
execution environment, not its internal design. When an existing service already violates a factor,
follow the surrounding conventions and flag the gap rather than rewriting infrastructure unasked.

## I. codebase — one codebase in revision control, many deploys
- One repo per app, one app per repo — one-to-one, always tracked in version control
- Multiple codebases means it's a distributed system, not an app; each component is its own app
- Never share code by having two apps read the same source tree — extract a library and consume it through the dependency manager
- Every running instance is a deploy (production, staging, each developer's machine); deploys differ by commit and config, never by codebase

## II. dependencies — declare and isolate explicitly
- Declare every dependency, completely and exactly, in a manifest (`package.json`, `pyproject.toml`, `go.mod`, `Gemfile`)
- Commit the lockfile; never let a deploy resolve versions on its own
- Use an isolation tool at execution time so nothing implicit leaks in from the host — declaration alone is not enough, and neither is isolation alone
- Never rely on system-wide/site packages being present
- Never shell out to a system tool that isn't declared (`curl`, `jq`, `convert`, `ffmpeg`) — vendor it or call a library
- The same declaration applies to development and production, with no "dev-only, installed by hand" step
- A new contributor gets running with only the language runtime and package manager, via one deterministic build command

## III. config — store config in the environment
- Config is everything that varies between deploys: backing-service handles, credentials, per-deploy hostnames
- Strict separation of config from code — never hardcode a credential, URL, hostname, or per-deploy value as a constant
- Litmus test: the repo could be open-sourced right now without leaking a single credential. If not, config is still in the code
- Store config in environment variables — language- and OS-agnostic, and hard to commit by accident
- Internal config that does not vary between deploys (routes, DI wiring, framework settings) belongs in the code, not the environment
- Env vars are granular and orthogonal, managed per deploy — never grouped into named "environments" that multiply into `staging`, `qa`, `joes-staging`
- Read env vars once at startup, validate them there, and fail loudly on a missing or malformed required value

## IV. backing services — treat them as attached resources
- A backing service is anything consumed over the network: database, cache, queue, SMTP, object store, third-party API
- Make no distinction in code between a local service and a third-party one — both are resources reached via a locator and credentials from config
- Swapping a local Postgres for a managed one must require a config change only, never a code change
- Each distinct service is a distinct resource with its own handle — two shards are two resources
- Resources attach and detach at will; hold no assumption that a given service instance is permanent

## V. build, release, run — keep the stages strictly separate
- Three stages, in order: **build** (code → executable bundle, dependencies vendored, assets compiled), **release** (build + this deploy's config), **run** (launch processes against a release)
- Never change code at runtime — there is no path back to the build stage; patching a running container is not a deploy
- Every release gets a unique, immutable ID (timestamp or incrementing number); releases are an append-only ledger
- A release is never mutated — any change, code or config, produces a new release
- Rolling back means running a previous release, not reverting-and-rebuilding under pressure
- Keep the run stage as simple as possible: it executes unattended at 3am on a reboot. Put the complexity in build, where a human is watching
- Do no migrations, dependency installs, or asset compilation at process start

## VI. processes — execute as stateless, share-nothing processes
- Processes are stateless and share nothing; anything that must persist goes to a stateful backing service
- Memory and local disk are a single-transaction scratch cache at most — never assume anything written there survives to the next request, job, or restart
- No sticky sessions, ever — session state goes in a store with expiry (Redis, Memcached)
- Compile and package assets in the build stage, not on the filesystem at runtime
- No in-process state that breaks when a second replica starts: no local scheduler locks, no in-memory counters or rate limiters, no local upload directory

## VII. port binding — export services via port binding
- The app is self-contained: it includes its own server as a declared dependency and binds a port itself
- Never depend on a webserver being injected around it at runtime (no app-as-Apache-module, no dropping a WAR into a container)
- Take the port from config (`PORT`), and bind to all interfaces so a routing layer can reach it
- A public hostname is the routing layer's job, not the app's
- The same pattern holds for non-HTTP protocols; one app can be another app's backing service, addressed by a URL in config

## VIII. concurrency — scale out via the process model
- Assign each kind of work its own process type — web, worker, scheduler — and scale each independently
- Scale out by running more processes, not only by growing one process
- In-process threads and async concurrency are fine, but never the only axis: the app must span processes and machines
- Never daemonize and never write PID files — run in the foreground and let the platform's process manager handle restarts, shutdown, and output
- Declare the process formation explicitly (`Procfile`, compose services, deployment manifests) rather than encoding it in a start script

## IX. disposability — fast startup, graceful shutdown
- Processes are disposable: startable and stoppable at a moment's notice
- Minimize startup time — target seconds from launch to serving. Slow boot blocks scaling and deploys
- Handle `SIGTERM`: stop accepting new work, let in-flight work finish within the grace period, then exit
- For a worker, graceful shutdown means returning the current job to the queue (nack, release the lock) so nothing is lost
- Make jobs idempotent and reentrant — assume every job may run twice and every process may be killed mid-flight
- Be robust against sudden death, not just clean shutdown; keep HTTP requests short, and have long-poll clients reconnect

## X. dev/prod parity — keep the gaps small
- Close the time gap: deploy continuously, in hours not weeks
- Close the personnel gap: whoever writes the code deploys it and watches it in production
- Close the tools gap: dev, staging, and production run the same type *and version* of every backing service
- Never substitute a lighter backing service locally (SQLite for Postgres, in-memory cache for Redis) — the small incompatibilities surface in production
- Run real services locally via containers or a declarative environment; the setup cost is lower than the divergence cost
- Adapters are for portability between services, not a license to run a different one in each environment
- Pin the runtime version identically across deploys

## XI. logs — treat logs as event streams
- Write the event stream unbuffered to `stdout` (and `stderr`); never open, write, rotate, or manage a logfile
- Never route or ship logs from inside the app — collection, collation, and archival belong to the execution environment
- One event per line; use structured lines (JSON) when something downstream will query them
- Never log a secret, credential, token, or unredacted personal data
- Include what makes an event correlatable (request/trace id, level) and let the platform add timestamps and source it already knows
- Local development reads the same stream in the terminal — no separate logging mode

## XII. admin processes — run one-off tasks as one-off processes
- Migrations, backfills, and consoles run as one-off processes against the same release — same codebase, same config, same environment as the long-running processes
- Ship admin and maintenance code in the app's repo alongside the application code, so it can never drift out of sync
- Use the same dependency isolation as every other process type — the same vendored interpreter and the same entrypoint wrapper
- Never run an admin task from a developer's machine against production data, and never against a different release than the one deployed
- Make one-off scripts idempotent and re-runnable; log what they changed
