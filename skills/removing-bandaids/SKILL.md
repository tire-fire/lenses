---
name: removing-bandaids
description: Removes intra-unit accidental complexity (timing loops, defensive guards masking local bugs, shallow wrappers, test-only seams, repeated wrappers, scattered slices, and near-duplicate functions). Use when simplifying control flow or reviewing a branch for local band-aids.
---
Scope:
- Owned here: intra-unit control flow and local mechanisms.
- Out of scope (drop silently): data representation (sum types, tables, value types), whole-design analogies, and cross-unit/cross-layer state ownership or boundary coupling.
Internal gates & catalog (apply before emitting any candidate; do not output gate prose):
1. Intent gate: identify what the target code achieves apart from its mechanism (using `CONTEXT.md` vocabulary if present). On rewrites/replacements, inspect deleted lines (`git diff` / `git log`) to catch dropped canonical constructs.
2. Hunt accidental complexity (use `Explore` in a main session on a large repo, or grep/read directly inside a subagent):
   - `timing`: sleeps, polling, retry loops, watchdogs -> await/signal the condition directly.
   - `signal-workaround`: async-interrupt / signal workarounds -> route through primary control flow.
   - `defensive-guard`: guard masking a local root cause -> trace null/invalid value to its source, fix the cause, delete the guard.
   - `shallow-wrapper`: pass-through wrapper/adapter whose interface costs as much as its body and hides no decision -> inline.
   - `reinvention`: single-site hand-rolled loop, parser, dedup, retry, or formatter -> replace with existing stdlib, dependency, or repo primitive.
   - `complected-state`: status flags or caches tracking progress in a flow expressible directly -> remove state.
   - `wrong-abstraction`: abstraction callers escape via extra flags/params or that imposes call-order coupling -> inline.
   - `scattered-cohesion`: functions/protocols each fetching or resolving a slice of one concept (`get_user_name`/`get_user_email` on one record, or two paths resolving the same ID) -> merge into one function/type returning the whole (only on shared reason to change, never on type-signature similarity alone).
   - `test-damage`: production hooks, peek-getters, `reset()` methods, or `if TESTING:` branches used only by tests -> delete and test through public interface (keep injected boundaries for external clock/network/randomness).
   - `repeated-wrapper`: decorators, `try/except`, or helpers repeated across N methods and policed by AST/regex scan tests -> collapse into one structural chokepoint and test the chokepoint.
   - `near-duplicate`: functions differing only by a literal/value -> lift value into a parameter or table and delete copies (never add a `mode`/boolean flag that forks control flow).
3. Load-bearing gate: verify what breaks if removed; if removal pushes complexity into N callers, drop silently. If unverified, mark `Speculative`.
Output ONLY one line per surviving finding ranked by dependencies + obscurity removed (no preamble, summary, code blocks, or footer), or `Clean.`:
`<file:line> | <catalog-tag> | <Strong|Worth exploring|Speculative> | <band-aid mechanism & what collapses> -> <direct replacement>`
