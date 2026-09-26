---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs}"
  - "**/*.{py,rb,php}"
  - "**/*.{go,rs,java,kt,kts,swift,scala,cs}"
  - "**/*.{c,h,cc,cpp,hpp}"
  - "**/*.{sh,bash}"
---

# comment rules

A comment is a failure to express intent in the code. Before writing one, try a better name or an
extracted function; reach for a comment only when the code genuinely can't carry the meaning.

## write

- **Why, not what** — the reasoning, the constraint, the thing that isn't obvious from reading it
- Warnings of consequence ("this runs before auth is set up", "O(n²), fine under 100 rows")
- Clarification of an API you can't change, where the correct call looks wrong
- `TODO` only with enough context to act on it later — what, and why it isn't done now
- Legal or licence headers where required

## don't write

- Restatements of the code (`// increment i`, `// constructor`)
- Changelog, authorship, or date comments — git has those
- Closing-brace markers, section banners, divider lines
- Docblocks added to satisfy a linter with nothing to say in them
- Commented-out code — delete it; git remembers

## keep them true

- An inaccurate comment is worse than none; update or delete it when the code moves
- Put a comment next to the thing it describes, so it's visible when that thing changes
- Match the comment density and style of the surrounding file rather than the density here
