# clean code rules

Principles from *Clean Code: A Handbook of Agile Software Craftsmanship* (Robert C. Martin).

Apply these when writing or changing code. They are defaults, not absolutes — when the surrounding code
consistently does something else, match the surrounding code and mention the divergence instead of
rewriting unrelated files.

## names
- Names reveal intent — `elapsedDays`, not `d`; `activeUsers`, not `list1`
- No type or scope encodings: no Hungarian notation, no `m_` prefixes, no `IShape` interface prefix
- No disinformation: don't call something `...List` unless it is a list; don't name a map `accountGroup`
- Distinguish names meaningfully — `ProductInfo`/`ProductData`/`Product` side by side is noise
- Pronounceable and searchable: `generationTimestamp`, not `genymdhms`; a named constant, not a bare `7`
- Single-letter names only for short local loop/lambda scopes (`i`, `e`)
- One word per concept — pick `fetch`, `get`, or `retrieve` and use it consistently across the codebase
- Classes are nouns (`Invoice`, `HttpRequestParser`), methods are verbs (`save`, `deletePage`, `isPosted`)
- No comment needed to explain a name; if one is, rename instead

## functions
- Small. A function does one thing at one level of abstraction; extract until each does
- Prefer ≤20 lines and a single level of nesting; deeper nesting means an extraction is missing
- Argument count: 0 is best, 1–2 fine, 3 needs justification, 4+ means the args belong in an object
- No boolean flag arguments — a flag means the function does two things; split it into two functions
- No output arguments; return a value instead
- Command/query separation: a function either does something or answers something, never both
- Prefer exceptions to error codes — error codes force the caller into `if` nesting and leak into every layer
- No side effects the name doesn't advertise (`checkPassword` must not initialize a session)
- Extract `try`/`catch` bodies into their own functions so error handling stays separate from logic
- Structured flow: avoid `goto`; a `break`/`continue`/early `return` is fine in a small function

## comments
- A comment is a failure to express intent in code — try renaming or extracting first
- Keep: legal headers, intent/"why" notes, warnings of consequence, clarification of an unchangeable API, `TODO` with context
- Delete: redundant restatements of the code, changelog and authorship comments, closing-brace markers, banners, mandated-but-empty docblocks
- Never leave commented-out code — delete it; git remembers
- A comment that can go stale must sit next to the thing it describes
- Comments must be accurate; an inaccurate comment is worse than none

## formatting
- Follow the project's formatter/linter — never hand-format against it, and never reformat unrelated lines in a change
- Blank lines separate concepts; tightly related lines stay adjacent
- Declare variables close to their use; instance variables at the top of the class
- Callers sit above callees, so the file reads top-down
- Keep lines short enough to read without horizontal scrolling
- Formatting is a team rule, not a personal one — consistency beats preference

## data and objects
- Objects hide data and expose behavior; data structures expose data and have no behavior — don't build hybrids with both
- Tell, don't ask: move the logic to the data rather than pulling data out to act on it
- Law of Demeter: talk to your direct collaborators, not to their internals — no `a.getB().getC().doIt()`
- Adding a type is cheap with polymorphism and expensive with switch statements; adding a function is the reverse — pick the shape by which axis changes
- Don't add a getter/setter pair for every field by reflex

## error handling
- Use exceptions, not returned error codes or sentinel values
- Never return `null` — return an empty collection, an option type, or throw
- Never pass `null` into a function; forbid it at the boundary rather than checking for it everywhere
- Throw exceptions with context: what operation failed and with what inputs
- Define exception classes around the caller's needs, not the thrower's; wrap third-party exceptions at the boundary
- Never swallow an exception — no empty `catch`, no bare `catch` that only logs and continues as if nothing happened
- Error handling is one thing: a function that handles errors shouldn't also do the work

## boundaries
- Don't pass a third-party type around your codebase — wrap it and expose the interface you need
- Wrap third-party APIs so you can adapt to their changes in one place and fake them in tests
- Write learning tests against a new library to pin the behavior you rely on
- Define the interface you wish you had for code that doesn't exist yet, and adapt later

## tests
- Tests are first-class code — held to the same naming, structure, and cleanliness standards as production code
- One assertion concept per test; a test name says what it asserts
- F.I.R.S.T: Fast, Independent (no ordering or shared-state coupling), Repeatable (no network/clock/random dependence), Self-validating (pass/fail, not output to read), Timely (written with the code, not after)
- Build-Operate-Check structure, with setup extracted to helpers so the assertion is readable
- Test boundary conditions and the failure paths, not just the happy path
- A dirty test suite gets abandoned; refactor tests as the code moves rather than letting them rot

## classes
- Small, measured by responsibilities rather than lines
- Single Responsibility Principle: one reason to change per class; many small classes beat a few large ones
- High cohesion — when a subset of methods touches only a subset of fields, that subset is a class waiting to be extracted
- Depend on abstractions, not concretions, so behavior can be substituted in tests and at runtime
- Keep it private by default; loosen visibility only for a real caller, never "for testing" without trying an extraction first

## design and smells
- Leave the code cleaner than you found it (Boy Scout Rule) — small, safe improvements as you pass through, kept out of unrelated diffs
- DRY: extract duplication, but only real duplication — two things that happen to look alike aren't one thing
- Don't add speculative generality, config, or abstraction for a requirement that doesn't exist yet
- Delete dead code, unused parameters, unreachable branches, and stale feature flags rather than leaving them
- Be consistent: if you do something a certain way, do all similar things the same way
- No magic numbers or strings — name the constant at the right level of abstraction
- Prefer explicitness over cleverness; the code is read far more often than it is written
- Refactor in separate commits from behavior changes so a diff is either a rename or a change, never both
