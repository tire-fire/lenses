---
name: fixing-comments
description: Fact-checks code comments, docstrings, identifier names, and PR descriptions against source, deleting change narration/restatements and compressing constraints to 1-2 lines. Use when reviewing or cleaning up comments on a branch.
---
Default: no comment. Only keep verified facts the code and identifiers cannot express: hidden constraints, external invariants, hardware/runtime/library quirks, or workaround reasons. If a comment is 1-2 lines stating a verified non-obvious constraint, skip it silently (never emit `KEEP` items, ratio tables, or counts).
Actionable dispositions:
- `FALSE` / `OVERCLAIMING`: comment, docstring, disinforming identifier, or PR description claim contradicted by or broader than the code.
- `DELETE`: diff narration (`now`, `no longer`, `instead of`, `changed to`, `refactored`, `previously`, bug/review history), caller/call-order/scenario lists, code/signature restatements, linear step labels (`# Step 1`), obvious intent, completeness padding, or any comment with no specific non-obvious fact.
- `COMPRESS`: genuine hidden constraint buried in multi-sentence prose -> 1 line (2 max); delete clauses rather than rewording. Restore base-branch wording if the diff only tweaked words without changing the fact.
Fact-checking:
1. Mechanism claims: verify ordering, lifetime, caller, guard, and guarantee claims in source; check for contradicting statements across the codebase; always check untouched docstrings/comments attached to functions, structs, methods, or templates whose body changed in the diff.
2. Parity claims ("X's defaults", "same timings", "reproduces Y"): read how both old and new implementations consume the value, not just whether constants match. Equal constants with different consumption gates are `OVERCLAIMING`; cite both call sites or state that the old use was not found.
3. Disinforming identifiers: any function, method, field, or variable whose name contradicts its post-diff behavior, polarity, unit, type, or scope is `FALSE` (`file:line`); provide the replacement identifier name.
4. PR / change description: trace claims about what the change does, what old code did (verify against base branch), and what tests guarantee; report `FALSE` and `OVERCLAIMING` claims with contradicting `file:line`.
Rules:
- Respect lint-required comment forms (e.g., public Doxygen/docstrings): compress to 1 line where possible, never delete.
- Ignore whitespace/alignment-only diff hunks (`git diff -w`) on untouched code's comments.
- Never add new comments during cleanup unless a hidden hazard is non-obvious.
Output ONLY one line per actionable item (`FALSE`/`OVERCLAIMING` first, then `DELETE`, then `COMPRESS`; no preamble, summary, ratio tables, or `KEEP` list), or `Clean.`:
`<file:line or PR-body> | <FALSE|OVERCLAIMING|DELETE|COMPRESS> | <contradicting file:line evidence + fix, OR reason to delete, OR exact 1-line replacement text>`
Example: `web/core/auth.py:64 | FALSE | docstring claims disabled users keep read access, but has_permission() at L41 returns False when not account_active -> delete claim`
