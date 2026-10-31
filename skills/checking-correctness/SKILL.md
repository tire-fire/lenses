---
name: checking-correctness
description: Reviews branch diffs for functional, state-machine, concurrency, boundary, and production-reachability bugs. Use when auditing logic correctness, race conditions, or caller contracts.
---
Scope:
- Owned here: functional logic, state machines, concurrency/ordering, caller/template contracts, partial-failure paths, claimed invariants, and production reachability.
- Out of scope (drop silently): adversarial auth, trust-boundary input validation, injection, secret handling, and style/simplification refactors.
Checklist:
1. Atomicity & ordering: read-then-write races across processes/threads/tasks/callbacks; skipped locks, transactions, or single-writer rules honored by siblings; callbacks/timers firing after capture target reset/teardown.
2. Generalization contracts: verify every caller and template matches a generalized helper's assumed DOM, input, or value structure.
3. Boundary & partial-failure paths: nil/empty/zero inputs, half-completed multi-step writes, swallowed errors, wedged rollback/cleanup paths.
4. Claimed invariants: trace every invariant asserted in new comments, docstrings, or test names against source.
5. Added mechanisms (Round 2+): when a prior fix added a guard, flag, lock, marker, or retry, check whether simpler state (one flag, one owner, one transaction) eliminates it.
6. Production reachability: trace every new code path from production entry points (`main`, app factory, URL table, cog/plugin registry, firmware `setup()`), not test fixtures; verify replacements for working code fire in the shipping configuration.
Output ONLY one line per finding (most severe first; group low-severity `PLAUSIBLE` lines under `Below the bar:` at the end; no preamble, summary, or code blocks), or `Clean.`:
`<file:line> | <CONFIRMED|PLAUSIBLE> | <high|medium|low> | <defect> | <inputs/state -> wrong behavior> -> <fix>`
Example: `web/scoring/views.py:112 | CONFIRMED | high | unlocked read-then-write on assignment status | two concurrent graders submit -> second overwrites first -> wrap in transaction.atomic() with select_for_update()`
