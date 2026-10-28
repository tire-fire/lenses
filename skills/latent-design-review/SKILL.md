---
name: latent-design-review
description: Use when evaluating a branch or set of changes for architectural-altitude code removal — reshaping hand-rolled code that reinvents an existing or canonical design, collapsing code with a better data structure or type, or adding/removing an abstraction. Use when a review should surface the design the code is secretly trying to be, NOT linter-tier cleanups (unused symbols, dead branches, cyclomatic complexity, renames, extract-helper DRY).
---

# Latent Design Review

Surface the design the code is *secretly trying to be*, and reshape it toward
that. Most awkward code is an unrecognized instance of something already known —
an abstraction the codebase already has, a canonical construct done worse, or a
shape that the wrong data structure forced into branches and flags. Name the
latent design and the accidental code collapses, with behavior preserved.

**This is advisory + apply-on-approval:** diagnose and present ranked findings,
let the human pick, then carry the chosen ones to edits and verification.

## Why this audit beats the agent that wrote the code

The code under review was likely written by an agent that was context-bounded and
optimizing local correctness — so it reinvented what existed, hand-rolled known
constructs, and added rather than reshaped (this is measured, not folklore; see
`references/why-agents-add.md`). The one move that agent structurally could not
make is the one you make here: hold the whole design in view and recognize the
latent pattern. That is the entire value, so **operate at that altitude or not at
all.**

## The bar (read this before hunting)

A finding must change the *shape* of the design — what abstractions exist, what
the data looks like, what depends on what. If a linter, type checker, or
dead-code scanner could have found it, it is out of scope here.

| OUT of scope (a tool's job) | IN scope (this skill) |
|---|---|
| Unused symbol, never-called function, dead branch | A whole mechanism the new design made redundant |
| Cyclomatic complexity, long function, nesting depth | A data structure that makes the branches unnecessary |
| Rename, extract-helper, deduplicate a literal | Hand-rolled code that *is* a known construct, reshaped to it |
| "These two loops are identical, merge them" | "This identity tuple wants to be a value type" |
| Unused parameter, magic number | "This is the wrong abstraction; inline it back" |

When you catch yourself writing a finding from the left column, stop. That is the
baseline an agent produces without this skill. Raise altitude or drop it.

**Boundary with sibling review lenses:** This skill owns **data representation**
(sum types, tables, value types replacing parallel structures or flag clusters) and
**canonical/internal design analogies** (unifying a hand-rolled mechanism onto an
existing repo or textbook abstraction). Defer local control-flow band-aids, timing
loops, and dead state transitions within a unit to `ripoff-bandaids`, and defer
cross-unit/cross-layer state ownership, authority, and boundary coupling to
`architecture-doctrine`.

## Audit HEAD, not the diff

The diff against the merge-base only *focuses attention*. A finding must describe
code in the awkward form **as it exists at HEAD now** — and still have something
left to collapse. On a rewrite branch the diff shows old→new, and the trap is to
narrate it: describing the new (better) code as if you were proposing it. That is
a changelog entry, not a finding. If the branch already replaced the hand-rolled
thing with the right abstraction, that is *completed work* — at most a fence that
holds, never an opportunity. Before writing any finding, confirm the bad shape is
still present at HEAD; if a reshape would change nothing because it is already
done, delete it. Do not praise, commend, or summarize what the branch did well —
the deliverable is remaining opportunities and load-bearing fences, full stop.

## The spine (TRIZ + Value Engineering + Refactoring-to-Patterns)

Every finding runs through three steps, in order:

1. **Function analysis (Value Engineering).** State what the code *does* as a
   verb-noun, separate from how it currently does it. "Delivers a packet
   reliably." "Identifies a peer." "Tracks the current match." You cannot tell
   accidental machinery from load-bearing machinery until function is named apart
   from mechanism.
2. **Ideal Final Result (TRIZ).** Describe the solved state implementation-free:
   the function is delivered with the least possible machinery. This is the target
   the reshape moves toward — not "fewer lines," but "the function, directly."
3. **Reshape by analogy or representation, or trim.** Apply the lenses below.
   *Trimming* (TRIZ) means removing a component by **reassigning its function** to
   what remains — never dropping the function itself.

## The four lenses

### 1. Internal analogy — the codebase already does this
The change reinvents a flow, protocol, or mechanism the repo already embodies in
a better form. **Recognition:** a new helper/manager/state-machine whose job
rhymes with an existing abstraction's job — or the same problem solved a second
way, in a different shape: another data structure for the same kind of record,
another route to the same input (a global here, a parameter there). **Move:** unify on the existing one,
lift its invariants, delete the reinvention. **Requires** that you first know what
exists — see Process step 1.

### 2. Canonical analogy — this is a known construct, done worse
The code hand-rolls a textbook pattern: an ack/retry/backoff loop is *ARQ /
reliable delivery*; flags tracking "where we are" is a *state machine*; a fan-out
of callbacks is *pub/sub*; last-write-wins reconciliation is a *CRDT*; a fixed
buffer with head/tail is a *ring buffer*. **Recognition:** ad-hoc flags and
edge-case branches that a named construct would make disappear. **Move:** name the
construct, adopt its form and invariants; the special cases collapse into the
pattern's guarantees.

### 3. Representation — the right data structure deletes the code
A better type or structure collapses logic while preserving behavior: a sum type
makes illegal states unrepresentable (so the guards that checked for them vanish);
a table replaces a branch ladder; a value type with its own equality/formatting
absorbs hand-rolled comparisons scattered across the codebase; the right container
replaces manual bookkeeping. **Recognition:** the same raw shape (a tuple, a
`std::array`, parallel vectors, a cluster of flags) handled by hand in many
places; "knowledge" encoded in code that belongs in data. **Move:** introduce the
type/structure; the redundant logic dissolves (Brooks: show me your tables).

### 4. Abstraction calculus — add depth, or remove shallowness
Both directions. **Add** a deep module where one hard decision is currently smeared
across many callers (each caller knowing an ordering, a sequence, a detail it
shouldn't). **Remove** a shallow module — a pass-through wrapper/adapter whose
interface costs about as much as its implementation and hides no decision — and the
*wrong* abstraction, one that no longer fits its callers (each escaping it via new
parameters and conditionals); inlining it back is the simplification. Also here:
**design-superseded mechanism** — a whole subsystem, class, code path, or
coordination mechanism the branch's new approach made architecturally redundant
even though it is still wired up and still "called" (so no dead-code tool flags
it). The discriminator is **leverage, not origin**: removing it must collapse a
*dependency* or a chunk of *machinery*. A lone remnant the rewrite stranded — an
unused struct field, parameter, constant, or enum case — is the linter's job, not
a finding, *even though it too is "leftover from the old design."* "Superseded"
earns a finding only when there is a mechanism to remove, not a value. If a
remnant is the visible tip of a mechanism that is **still present**, the finding
is that mechanism — name it and show what collapses, don't report the field. If
the mechanism it served is **already gone**, the inert remnant alone is out of
scope; leave it to the scanner.

**The collapse test — apply to every removal candidate.** Name the *other code*
that ceases to exist, or ceases to depend on something, when you make the change.
Deleting a field/parameter/constant and updating its call sites is **not** a
collapse: every call site still exists, each just one argument lighter, and the
wire is a byte smaller. That is a scanner's win and is out of scope here **no
matter how many signatures it touches, and no matter that it changes the wire
format** — "it ripples across N call sites," "the packet shrinks," and "it aligns
the struct with what the code really does" are not leverage, they are the texture
of a mechanical cleanup. A real lens-4 collapse removes **structure**: a class, a
code path, a branch of control flow, a state machine, an entire dependency edge
between modules. If you cannot name the *structure* that disappears, it is not a
finding — it is a `--fix`-able lint, and you should drop it.

## Process

0. **Scope the change set.** `git merge-base HEAD <upstream>/main`; diff the branch
   against it. (Source-of-truth remote, not stale local main.) The diff focuses
   attention; you may follow threads into unchanged code the branch builds on.
1. **Inventory the existing design vocabulary** *before* hunting. What abstractions,
   patterns, data structures, and value types does the repo already have? Use an
   `Explore` subagent for a large repo. Lenses 1 and 4 are impossible without this
   map — you cannot say "reinvents X" or "superseded Y" without knowing X and Y.
2. **Function-analyze each candidate region.** Verb-noun, function apart from
   mechanism (spine step 1), then its Ideal Final Result (spine step 2).
3. **Run the four lenses** over the candidates.
4. **Load-bearing check on every candidate** (Chesterton's fence). Why does this
   exist; what breaks if reshaped; is the machinery accidental or load-bearing? In
   C++ especially, things that look removable are not: virtual dispatch,
   function-pointer callbacks registered with a driver or runtime, `#ifdef`-gated code,
   templates, weak symbols. If you cannot establish behavior is preserved, that is
   a finding to surface as uncertain, not a change to recommend.
5. **Present, ranked by architectural leverage** (how much design collapses — not
   lines). For each finding:
   - **Function / Ideal Final Result** — what it does, and the machinery-free target
   - **Current form** — the awkward instance, and which lens it is
   - **The reshape** — the analogy named, or the type/structure introduced
   - **What collapses** — the accidental machinery that goes away
   - **Behavior preservation** — the tests/observations that must still pass
   - **Strength** — Strong / Worth exploring / Speculative

   End with a top recommendation, then ask which to pursue. On approval, apply the
   edits and run the project's verification loop to confirm behavior held.

## Worked example (lens 1 + lens 3: adopt the type the codebase already chose)

One module passes peer addresses as raw `std::array<uint8_t, 6>`: equality is
hand-rolled `memcmp(a.data(), b.data(), 6)` in the resend table, the eliminated
set, and the bracket lookup; "is this address in this vector" is a manual linear
scan repeated per call site; the display name has its own bespoke hex formatter.

The decisive move is **step 1 of the process**, not cleverness: inventory the
existing vocabulary *first*. Doing so reveals the codebase already has a `Mac`
value type with equality, ordering, and a shared formatter — and that a sibling
module already migrated to it. So this isn't "invent a type" (lens 3 in the
abstract); it's **lens 1, internal analogy**: this module is the holdout, and the
design it should be is one the repo already embodies.

- **Function:** identify a peer, compare two peers, render a peer for display.
- **Ideal Final Result:** call sites use `==`, `=`, and the shared formatter; no
  module hand-rolls six-byte ops.
- **Reshape:** adopt the existing `Mac` type for the struct fields and the
  `const uint8_t*` boundary conversions; the `memcmp`/`memcpy` pairs become
  `==`/`=`; route the bespoke formatter through the shared one.
- **What collapses:** every hand-rolled comparison and format in the holdout
  module, plus the length-6 bug surface — bringing it in line with the rest.
- **The trap the inventory step avoids:** without step 1 you "discover" a need to
  *introduce* a type that already exists, propose a worse parallel version, and
  duplicate the very thing you meant to unify. Always confirm what exists, and
  preserve its exact behavior (e.g. match the existing formatter's output, don't
  assume yours).
- **Why a baseline misses it:** it is cross-cutting and needs whole-system view;
  no single site looks wrong, and no linter flags "this module skipped the type
  the rest of the codebase adopted."

This is the kind of finding that justifies the review. A note that "`onAck`
duplicates `findPending`, merge them" is not — that is the left column.

## Red flags — you have dropped to the wrong altitude

- Your finding is "unused", "never called", "dead branch", or "unused parameter" →
  a scanner's job. Cut it.
- Your finding is "extract a helper" / "these two loops are identical" → mechanical
  DRY, not a design change. Cut it unless it reveals a missing *type* or *concept*.
- You are merging two things because they look alike → shape similarity is a prompt
  to look closer, never a reason to merge. Merge only on shared *reason to change*
  (one concept, one owner). Same shape, different concept → leave apart.
- You are proposing a `mode`/`kind` flag to unite two functions → if their bodies
  differ in control flow, that braids two behaviors into one. Parameterize a
  *value*, never fork a *behavior*.
- You recommend a removal without naming where its function goes → that is deletion,
  not trimming. Reassign the function first.
- You ranked by lines removed → rank by dependencies and obscurity removed. A change
  that deletes 200 lines but couples two independent modules is not a simplification.
- Your finding describes what the branch already did (the new code, the replacement,
  the adoption) → that is a changelog entry, not a finding. Re-check HEAD: is the
  awkward form still there with something left to collapse? If not, drop it (or note
  it as a fence). Findings are remaining opportunities only; never commend the diff.
- Your finding is "remove this leftover field / parameter / constant / enum case the
  rewrite stranded" → that is the scanner's job, not lens 4. "Design-superseded"
  means a *mechanism* whose removal collapses a dependency, not a dead value. If the
  remnant is the tip of a mechanism still present, name and report the *mechanism*;
  if that mechanism is already gone, the inert value is out of scope.
- You are defending a stranded-value removal with "it changes the wire format" / "it
  ripples across N signatures" / "it aligns the struct with what the code does" →
  none of those is leverage; they are what a mechanical cleanup looks like. Apply the
  collapse test: if no *structure* (class, code path, state machine, dependency edge)
  disappears, it is a `--fix`-able lint. Drop it, however consequential the diff feels.
- You wrote "the mechanism it served is already gone … inert remainder" and then
  recommended removing it anyway → re-read your own sentence. Already-gone mechanism
  ⇒ out of scope. Stop.

## Quick reference

| Lens | Recognition cue | The move |
|---|---|---|
| Internal analogy | New thing rhymes with an existing abstraction | Unify on the existing one, lift its invariants |
| Canonical analogy | Flags + edge cases a named construct would erase | Name the construct (ARQ, state machine, pub/sub…), adopt its form |
| Representation | Same raw shape handled by hand in many places | Introduce the type/structure; logic goes dumb |
| Abstraction calculus | Decision smeared across callers, or shallow/wrong wrapper | Add a deep module, or inline the shallow/wrong one |

**Foundations and citations:** `references/why-agents-add.md`.
