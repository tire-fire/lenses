---
name: reshaping-latent-design
description: Reshapes code by unifying onto existing repo or canonical abstractions, replacing parallel structures or flag clusters with better types, or collapsing shallow/redundant modules. Use when reviewing for architectural-altitude code removal.
---
Scope:
- Owned here: data representation (sum types, tables, value types replacing parallel structures or flag clusters), canonical/internal design analogies (unifying hand-rolled mechanisms onto an existing repo or textbook construct), and module depth (adding a deep module for a smeared decision or inlining a shallow/wrong abstraction).
- Out of scope (drop silently): unused symbols/params/fields/enum cases, uncalled functions, dead branches, cyclomatic complexity, function length, nesting depth, renames, extract-helper mechanical DRY, merging identical loops without a shared concept, adding a `mode`/`kind` flag that forks control flow, intra-unit control-flow band-aids, single-site stdlib reuse, and cross-unit/cross-layer state ownership or boundary coupling.
Internal gates (apply before emitting any candidate; do not output gate prose):
1. Audit HEAD, not the diff: report only awkward shapes still present at HEAD with structure left to collapse; never narrate or commend completed replacements.
2. Inventory existing repo vocabulary first (core types, abstractions, shared utilities; use `Explore` in a main session on a large repo, or grep/read directly inside a subagent) so findings adopt existing repo types rather than proposing parallel ones.
3. Function & target gate: identify the candidate's function as verb-noun apart from mechanism and its machinery-free target; when removing a component, verify where its function is reassigned.
4. Four lenses:
   - Lens 1 (Internal analogy): helper/manager/state-machine/record duplicates an existing repo pattern -> unify on existing construct, lift invariants, delete duplicate.
   - Lens 2 (Canonical analogy): ad-hoc flags/branches hand-rolling a textbook construct (ARQ, state machine, pub/sub, CRDT, ring buffer) -> adopt canonical construct.
   - Lens 3 (Representation): raw tuples/arrays/parallel vectors/flag clusters handled manually across call sites, or branch-encoded data -> introduce value type, sum type, or table so illegal states become unrepresentable.
   - Lens 4 (Abstraction calculus): pull a decision smeared across callers into a deep module; inline pass-through wrappers or wrong abstractions callers escape via extra params/conditionals; remove subsystems/classes/state-machines made redundant by the new design even if still wired up.
5. Collapse gate (mandatory): a candidate must eliminate a structure (class, code path, control-flow branch, state machine, module dependency edge). Deleting a stranded field/param/constant/enum case and updating N call sites or shrinking a wire frame is a mechanical cleanup -> drop silently.
6. Behavior preservation gate: verify virtual dispatch, driver/runtime callbacks, `#ifdef` gates, templates, and weak symbols; if unverified, mark `Speculative`.
Output ONLY one line per surviving finding ranked by structure/dependencies collapsed (no preamble, summary, code blocks, or footer), or `Clean.`:
`<file:line> | Lens <1-4> | <Strong|Worth exploring|Speculative> | <awkward shape at HEAD & structure that collapses> -> <reshape / target construct>`
