---
name: ripoff-bandaids
description: Use when the user wants to simplify a codebase, remove accidental complexity, untangle band-aids layered on band-aids, replace sleeps/polling/watchdogs/retry-loops with direct solutions, delete unnecessary abstractions, consolidate functions or protocols that each handle a slice of one concept (e.g. several getters for parts of one record, or two paths that both deliver the same id), parameterize near-duplicate functions that differ only by a value, strip production code that exists only to facilitate tests, or do the job with less code. For subtractive, architecture-level simplification — not surface metrics like line count or cyclomatic complexity. Uses the repo's own domain vocabulary (CONTEXT.md or equivalent) when it has one.
---

# Rip Off Band-Aids

Find accidental complexity and propose removing it — so the code does what it's actually trying to do, directly, with less. Reducing code is the *consequence* of elegance, not the goal. This is advisory: you diagnose and propose, the human decides.

## Scope boundary (when run alongside the other review lenses)

This skill owns **intra-unit / local control-flow and mechanism simplification**: sleeps/polling/watchdogs/retry-loops, dead state transitions, defensive guards masking a local root cause, shallow pass-through wrappers, and near-duplicate functions within a module.
- Defer **data representation & canonical/internal design analogies** (replacing flag clusters or parallel structures with a sum type, table, or value type; unifying a hand-rolled mechanism onto an existing repo abstraction) to `latent-design-review`.
- Defer **cross-unit/cross-layer structural boundaries and single source of truth** (where state lives across layers, who owns a fact, layer direction, truth propagation, coupling across module boundaries) to `architecture-doctrine`.

## Your own bias is the thing to fight

You default to *adding*. Faced with a problem you reach for one more guard, one more sleep, one more wrapper, one more flag — because additive ideas are faster to retrieve, not because they're better. This is a measured cognitive default in both people and LLMs, and it gets *worse* under load. A band-aid on a band-aid is what that bias produces over time.

So the discipline is subtractive by force: **before you propose adding anything, ask what the code is actually trying to do, and what can be removed to do it directly.** "Simple" is objective (see below). "Easy" — familiar, close at hand, fast to reach for — is not, and is exactly where band-aids come from. Optimize for simple, not easy.

## What "simpler" means (the only tests you need)

- **Complexity = dependencies + obscurity** (Ousterhout). For anything you'd add *or* keep, ask: (a) does it create a dependency — two parts that now must be understood together? (b) does it hide information that should be obvious? A sleep, a watchdog, a defensive guard typically *fails both* — it couples to timing/state it shouldn't, and it obscures the real control flow.
  - **Reuse caveat — don't let this metric reward reinvention.** Reusing a construct the repo, stdlib, or an already-imported dependency already provides *adds a dependency edge but usually yields the simpler system*. A self-contained reimplementation of an existing construct is not "fewer dependencies," it is a duplicated concept: two things that must now evolve together, in two idioms, one of which the reader didn't know existed. A hand-rolled state machine sitting next to the framework's, a bespoke retry loop next to the shared one, a private date-formatter next to the stdlib's — each *looks* leaner because it imports nothing, and each is more system complexity, not less. Ask which makes the whole simpler, not which has fewer imports.
- **Complecting** (Hickey). Complexity is things braided together that could be pulled apart. The canonical one for this skill: **state complects value and time** — which is precisely what polling, sleeps, and retry-loops are. Look for things interleaved that could be separated. Interleaving is observable; "cleanliness" is taste — chase the former.
- **Depth is a test, not a goal.** A module earns its interface by hiding a lot behind a little. Reject the inverse: a shallow wrapper/adapter/guard whose interface is about as complex as its implementation hides no hard decision and adds a dependency. That shallow layer *is* the band-aid.

## Process

### 1. Understand intent (its own gate — do not skip)

Before hunting anything, state in plain language what the system, or the section you're looking at, is *trying to achieve* — the goal, separate from how it currently achieves it. Read `CONTEXT.md` if present and use its domain vocabulary.

This gate exists because the strongest lever against band-aid reasoning is separating *understand* from *act*. You cannot tell accidental complexity from load-bearing complexity until you know what the code is for. Do not proceed to hunting until you can say, directly, what the right outcome is.

If the change replaces or rewrites a component, read what it replaced (deleted lines, git history), not just the added code. Reinvention of an existing construct never shows in the new code alone — the new code looks self-consistent and clean; it only shows against the mechanism that was there before.

### 2. Hunt accidental complexity

Use the Agent tool with `subagent_type=Explore` to walk the code, holding the intent from step 1 in mind. You're looking for the gap between what the code is trying to do and the machinery it uses to do it. The band-aid catalog — the usual suspects:

- **Sleeps / polling / retry-loops / watchdogs working around timing** → almost always a complected value+time that wants a direct, event-driven, or awaited solution. The code is waiting for a condition; make it wait *on the condition*, not on the clock.
- **Async-interrupt / signal workarounds** routed around the real control flow instead of through it.
- **Defensive guards masking a root cause** — a null check, try/except, or clamp that silences a symptom whose cause lives elsewhere. Trace to the cause; the guard often deletes itself.
- **Shallow pass-through wrappers / adapters** that forward calls and hide no design decision.
- **Reinvented existing machinery (failure to reuse)** — the diff hand-rolls a loop / parser / state machine / dedup / retry / date-format that stdlib, an in-use dependency, or an existing repo primitive already provides. The reinvention hides in the *added* lines and looks clean there; the sharpest tell is what the code *replaces* — if the thing being rewritten used the canonical construct, the rewrite that drops it is the band-aid. So on a rewrite/replacement, read the deleted code, not just the new. At single-site altitude (a stdlib fn, one obvious util a few files over) it's a rip right here. When the reinvention is a whole design reshaped worse — a framework or abstraction the repo already has — that is architectural altitude: route it to the `latent-design-review` skill rather than flattening it into this pass. Keep this entry thin; the moment it grows past "did you check for an existing X," it has become that other skill wearing this hat.
- **Complected state + time** — flags, status fields, and caches that exist to remember "where we are" in a process that could be expressed directly.
- **Flowchart-step decomposition** (Parnas) — modules split by processing step rather than by a hidden design decision likely to change, so one change ripples across all of them.
- **The wrong abstraction** (Sandi Metz) — an abstraction that no longer fits its callers, each bolting on parameters/conditionals to escape it. Duplication is cheaper than the wrong abstraction; inlining it back is often the simplification.
- **Over-specified interfaces** — an interface that forces callers to know an ordering, a sequence, or a detail they don't need.
- **Scattered cohesion** (a concept fragmented across units) — several functions, methods, or protocols that each deliver a *slice* of one thing: `get_user_name`/`get_user_email`/`get_user_role` each fetching one field of the same record; two protocols that each independently resolve and hand back the same `user_id`. The slices are facets of a single concept, so callers must know every piece and reassemble the whole, and the concept itself lives nowhere. This is the *inverse* of the wrong abstraction — not one abstraction stretched over too many cases, but one concept shattered into too many. The direct form is one function or type that returns the whole, or one source of truth for a value that's currently delivered in several places. **The trap:** syntactic or shape similarity is only a prompt to look closer — never, by itself, a reason to merge. Merge only when the units share a real *reason to change* (one concept, one owner). Two functions with the same `(number) -> string` shape and nothing else in common stay apart; merging them manufactures the wrong abstraction you'd otherwise be ripping off. The test is **cohesion** — do these change together, for the same reason? — not how alike they look.
- **Test-induced design damage** — production code that exists only to serve the tests: a hook, observer, callback, getter, `reset()`, `if TESTING:` branch, or constructor seam whose only caller is the test suite. It couples production to the test harness (a dependency that rides on every real call) and obscures the real design behind a back channel. The direct form is to exercise the *real* interface — call the public operation, assert on its observable result — and delete the seam. **The discriminator that decides keep-vs-remove:** does the seam name a dependency the production design genuinely has — a clock, a network client, a source of randomness it can't otherwise control — or only a window the test couldn't otherwise see through? Injected real dependencies are a load-bearing boundary the test merely *uses*; keep them. Hooks and peek-getters that exist only to reach internals the public surface already exposes (or should) are damage; remove them and route the test through the front door.
- **The same wrapper at every site, plus a guard test that it is there**: a decorator, try/except, or helper call repeated on each of N methods so that one concern (translating an error, adding a header, checking a permission) applies everywhere, with a test that scans for the methods and asserts each carries it. The guard can only check what it scans for: a private helper, a method reached indirectly, or a new call site the pattern does not match slips past both the wrapper and the guard, and the suite stays green. The direct form is one chokepoint every call already passes through (a single request method, a middleware, a base call), so coverage is a property of the structure, and the guard shrinks to "only the chokepoint touches the resource". **Verify the guard by trying to slip past it**: add a call that bypasses the wrapper the way a future contributor would (through a private helper, say) and confirm the guard fails. If it stays green, the guard is a band-aid on a band-aid.
- **Near-duplicate functions differing only by a value** — two or more functions with the same body that differ in a single literal or value (a tax rate, a URL, a threshold). This is duplication, not fragmentation: the same operation, copied. The direct form lifts the differing value into a parameter (or a data table) and deletes the copies — frequently a one-argument, one-line addition to one function lets you delete the entire body of another. When that ratio holds — add a little, delete a lot, no behavior lost — the juice is worth the squeeze; do it. **The guard — parameterize a value, never fork a behavior:** this is a win only when the functions differ by a *value*. If their bodies differ in control flow or algorithm, adding a `mode`/`kind`/boolean flag to unite them is the flag-argument trap — it braids two behaviors into one function, forces every caller to know the flag, and is the wrong abstraction in a DRY costume (CSV-vs-JSON export is two algorithms, not one with a parameter — leave them apart). The cohesion test settles it: one operation differing by data → merge; two operations sharing only a shape → leave.

Most of the catalog is spotted at a *single site*: you look at one sleep, one guard, one wrapper and know. **Scattered cohesion and near-duplicate functions are the exceptions** — invisible at any one site, they only surface when you compare units. So hunt them deliberately: scan for clusters of functions or protocols with similar names, similar shapes, the same return value, or near-identical bodies, and for each cluster ask whether they're facets of one concept (merge whole), the same operation differing by a value (parameterize), or only alike in shape (leave apart). Apply the cohesion test before proposing any merge.

### 3. Load-bearing check on every candidate

Before recommending any removal, run the deletion test — Chesterton's fence: *why does this exist, what breaks if it's gone, is it accidental or load-bearing?* If deleting it would make complexity reappear across N callers, it was earning its keep — drop the candidate. The skill removes accidental complexity, never load-bearing complexity it didn't take the time to understand. When you can't tell, that's a finding to surface, not a removal to recommend.

### 4. Present candidates

Present them in the conversation, ranked by **complexity removed** (dependencies and obscurity eliminated — not lines). For each:

- **Intent** — what this code is trying to do
- **The band-aid** — the accidental complexity, and which catalog pattern it is
- **The direct alternative** — what it becomes when done directly
- **Verification** — how you'd confirm behavior is preserved (the tests/observations that must still pass)
- **Strength** — Strong, Worth exploring, Speculative

End with a **Top recommendation**: which to rip off first and why. Use the repo's own domain vocabulary. Then ask: **"Which of these would you like to explore?"**

### 5. Grilling loop

Once the user picks one, design the direct solution with them — what the code is really doing, what survives, what verifies behavior is preserved, what other complexity collapses once the band-aid is gone. If the repo keeps a domain glossary (`CONTEXT.md` or similar) and you name a concept it lacks, add it there; if a term is fuzzy, sharpen it on the spot.

## Red flags — you're reaching for a band-aid

If you catch yourself thinking any of these, stop, restate what the code is trying to do, and solve it directly:

- "I'll add a small sleep / a retry / a longer timeout to make it pass."
- "I'll wrap it so callers don't have to deal with X." (Does the wrapper hide a *hard decision*? If not, it's a shallow band-aid.)
- "I'll add a guard / null check here to stop the error." (Where does the bad value come from?)
- "I'll add a flag / status field to track that case."
- "It's easier to add a branch than to rework this."
- "These two look almost identical / both return the same value — I'll merge them." (Do they share a *reason to change*, or just a shape? Same shape, different concept → leave them apart; merging is the wrong abstraction.)
- "These two are nearly identical — I'll add a `mode` flag to merge them." (Parameterize a *value* they differ by, yes. Add a flag that *forks behavior*, no — that braids two operations into one. Different bodies → leave them apart.)
- "This getter / hook / `reset()` is only used by tests, but I'll keep it so the suite stays green." (Either the test should go through the real interface, or the seam names a real dependency. Decide which — don't keep a test-only back channel by default.)
- "A small self-contained enum / loop / struct is cleaner than pulling in the existing framework / util." (Fewer imports is not fewer moving parts. If the repo — or the code you're replacing — already has this construct, your copy is a second thing to keep in sync, in a second idiom. That's more system complexity, not a simplification.)

Every one of these is the additive default talking. The fix is upstream, in the intent — not one more layer.

## Don't measure success by line count or smell count

Removing lines is the side effect, not the target — and surface metrics (line count, cyclomatic complexity, automated smell counts) reward systematic surface fixes while masking whether the architecture got simpler. Judge a simplification by: **did dependencies and obscurity go down, and is behavior provably preserved?** A change that deletes 200 lines but couples two modules that were independent is not a simplification.
