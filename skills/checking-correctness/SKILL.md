---
name: checking-correctness
description: Reviews branch diffs for functional, state-machine, concurrency, boundary, guard-coverage, doc-claim, and production-reachability bugs. Use when auditing logic correctness, race conditions, or caller contracts.
---
Scope:
- Owned here: functional logic, state machines, concurrency/ordering, caller/template contracts, partial-failure paths, guard coverage, claimed invariants (in code and in spec/design docs), and production reachability.
- Out of scope (drop silently): adversarial auth, trust-boundary input validation, injection, secret handling, and style/simplification refactors.
Checklist:
1. Atomicity & ordering: read-then-write races across processes/threads/tasks/callbacks; skipped locks, transactions, or single-writer rules honored by siblings; callbacks/timers firing after capture target reset/teardown.
2. Generalization contracts: verify every caller and template matches a generalized helper's assumed DOM, input, or value structure.
3. Boundary & partial-failure paths: nil/empty/zero inputs, half-completed multi-step writes, swallowed errors, wedged rollback/cleanup paths.
4. Guard coverage: when the diff adds a guard (catch, validation, bound, lock) at one site, list every other site that consumes the same input or reads the state the guarded code stores (timers, renderers, list/snapshot builders, other routes), and check each; a guard covers only the code that runs inside it.
5. Claimed invariants: trace every invariant asserted in new comments, docstrings, or test names against source.
6. Doc claims: for each changed or newly reachable symbol, grep the repo's spec and design docs (`openspec/`, `specs/`, `docs/`, `ARCHITECTURE.md`, `CONTEXT.md`, `README.md`; `THREAT_MODEL.md` belongs to Lens 7) for statements about it, whether or not the doc changed, and verify each against source. When doc and code disagree, decide which side is wrong: if the doc states intended behavior, report the code defect at the code's `file:line`; otherwise report the stale statement at the doc's `file:line` with the corrected sentence as the fix.
7. Added mechanisms (Round 2+): when a prior fix added a guard, flag, lock, marker, or retry, check whether simpler state (one flag, one owner, one transaction) eliminates it.
8. Production reachability: trace every new code path from production entry points (`main`, app factory, URL table, cog/plugin registry, firmware `setup()`), not test fixtures; verify replacements for working code fire in the shipping configuration.
Output ONLY one line per finding (most severe first; group low-severity `PLAUSIBLE` lines under `Below the bar:` at the end; no preamble, summary, or code blocks), or `Clean.`:
`<file:line> | <CONFIRMED|PLAUSIBLE> | <high|medium|low> | <defect> | <inputs/state -> wrong behavior> -> <fix>`
Example: `web/scoring/views.py:112 | CONFIRMED | high | unlocked read-then-write on assignment status | two concurrent graders submit -> second overwrites first -> wrap in transaction.atomic() with select_for_update()`
