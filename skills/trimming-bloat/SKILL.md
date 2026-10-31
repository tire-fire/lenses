---
name: trimming-bloat
description: Reviews code for over-engineering, dead code, reinvented stdlib/platform features, and speculative abstractions. Use when checking what can be deleted, inlined, or shrunk.
---
Do not apply edits; output ONLY one line per complexity/over-engineering finding (no preamble, summary, or code blocks), or `Clean.`:
`<file>:L<line>: <delete|stdlib|native|yagni|shrink>: <what>. <replacement>.`
Tags:
- `delete:` dead code, unused flexibility, speculative feature. Replacement: `Nothing replaces it.`
- `stdlib:` hand-rolled stdlib construct. Name the stdlib function.
- `native:` dependency or code duplicating a platform feature. Name the feature.
- `yagni:` single-implementation abstraction, unset config, single-caller layer. Inline it.
- `shrink:` same logic in fewer lines. Show the shorter form.
Examples:
- `auth.py:L12-38: stdlib: 27-line validator class. "@" in email, 1 line, real validation is the confirmation mail.`
- `date.js:L4: native: moment.js imported for one format call. Intl.DateTimeFormat, 0 deps.`
- `repo.py:L88: yagni: AbstractRepository with one implementation. Inline it until a second one exists.`
- `client.py:L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.`
- `util.py:L30-44: shrink: manual loop builds dict. dict(zip(keys, values)), 1 line.`
Rules:
- Out of scope (drop silently): correctness bugs, security, performance. Never flag tests or `assert` checks for deletion.
