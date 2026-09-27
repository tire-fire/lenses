---
name: architecture-doctrine
description: Use when designing or reviewing a STRUCTURAL decision — where a piece of state should live, who owns a fact, whether a component may depend on another, whether truth should be propagated or rediscovered, whether knowledge should be local or global, or what would force two units to change together. Fires at design time before building a component that spans layers or holds state, and at review time on a branch that moves state, adds a cross-layer dependency, or introduces a compensating system (retry/reconcile/backstop), or couples two units through a shared global, a shared format, or a side-effecting query. Owns the six structural axes (ownership, authority, layer separation, truth propagation, minimum scope, coupling quality); defers module depth, simplicity, root cause, and reinvention to ripoff-bandaids, latent-design-review, and ponytail-review.
---

# Architecture Doctrine

Check a design against the six structural axes: **where state lives, who owns a
fact, how layers are separated, how truth flows, how far knowledge spreads, and
what forces two units to change together.**
These are the questions the complexity skills structurally do not ask — ponytail
asks "is it simple," this asks "is it in the right place." Advisory: name the
violation and propose the doctrine-aligned shape; the human decides.

## The authority

If the repo keeps its architectural principles and layer stack in a file
(`CONTEXT.md`, `ARCHITECTURE.md`, a design doc named in `CLAUDE.md`), read it
first and **cite** it rather than restating it — one authority, not copies. The six
axes below are the *method*; the repo's own document is the doctrine. When no such
file exists, the axes are the doctrine, and a finding cites the axis by number.

## The six axes this skill owns

For each, ask the diagnostic question. A "no" is a finding.

1. **Ownership follows responsibility.** *Is this state stored where the decision
   about it is made?* State parked away from its decision point drifts and needs
   syncing. Move it to the owner, or make the owner authoritative and let others
   read.
2. **Authority over consensus.** *Is there one authoritative source for this fact,
   or is it reconstructed in several places?* Multiple reconstructions (graph
   walks, mutual-agreement handshakes, per-component re-derivation) are the tell.
   Name the authority; make everyone read it.
3. **Layer separation.** *Does this dependency cross a layer boundary the wrong
   way?* A lower layer knowing a higher layer's concept (a transport holding a
   business rule, a storage model holding a UI state, a driver holding a game
   role) is the violation. Push the concept up, or pass it opaquely.
4. **Propagate truth, don't rediscover it.** *One component already knows this —
   is it telling the others, or are they each recomputing it?* Recomputation that
   drifts, or a periodic flood to re-sync a view, means the truth isn't being
   propagated from its source.
5. **Minimum scope of knowledge.** *Does this component hold more of the world than
   it needs?* A global view where a neighbor-local one suffices is the tell. Shrink
   the blast radius: local first, global only when the requirement genuinely spans
   the whole system. This is what a component *stores*; how far a call *reaches* is
   axis 6.
6. **Coupling quality.** *What single change would force edits on both sides of this
   boundary?* Two units are coupled when changing one forces changing the other.
   Name that change: if it is a real design decision — a wire format, a timeout, a
   state encoding, a buffer layout, a URL scheme — the decision has no owner and
   both sides encode it. Tells: a shared mutable global or static buffer standing in
   for a call; two modules independently decoding the same frame or payload; a
   chain reaching through intermediaries (`a.getB().getC().doX()` — talk to your
   parameters, your fields, and what you made, not to their friends); a surface
   unstable enough that callers churn with it. And **a query that changes the
   answer** — `hasNewData()` that clears the flag, a getter that lazily initializes
   — which couples every caller to a call *order* that nothing declares. Move the
   shared decision into one unit and hand out the result.

Axes 1, 2, 4, and 5 ask where a *fact* lives. Axes 3 and 6 ask what a *boundary*
costs — 3 in the direction it points, 6 in what crosses it.

Axes 2, 4, and 5 are usually the same smell seen from three sides: a component
rebuilding a global picture (5) by consensus (2) because no one propagated the
truth from its owner (4). A periodic broadcast in which every node re-announces
everything it knows so that every other node can rebuild the same table fails all
three at once; one owner publishing the one fact that changed fixes all three.

## Not this skill's job — delegate

- Reinvented / hand-rolled constructs, wrong data structure, an abstraction the
  repo already has → **latent-design-review**.
- A system compensating for another system, retries/reconciliation as a band-aid
  → **ripoff-bandaids**.
- Is it simple, is it minimal, the "simplest system" question →
  **ponytail-review**.
- **Module depth** — a shallow wrapper or pass-through adapter, an interface that
  costs as much to learn as the implementation it hides, one decision smeared
  across callers that wants a deep module → **ripoff-bandaids** /
  **latent-design-review**, which own depth. Axis 6 is adjacent but different: it
  asks what forces two units to change *together*, not how much one unit hides.

If a finding is really one of those, route it there instead of forcing it through
these six axes.

## Process

**At design time (the higher-value moment).** Before building a component that
holds state or spans layers, ask first — *what is the simplest system that
satisfies the requirements?* — then walk the six axes on the proposed shape.
Fixing "this state lives in the wrong layer" costs a sentence now and a rewrite
later.

**At review time.** Focus on changes that move state, add a cross-layer
dependency, or introduce a compensating system. For each finding: name the axis,
show the current shape, propose the doctrine-aligned one, and confirm it's not
already better handled by one of the delegated skills.

## When an axis yields

2, 4, and 5 can pull against "fewest moving parts": propagating a truth adds a
message, requiring an authority adds a dependency. Yield when a value is
authoritative and cheap to derive locally with zero coordination — "I am the head
of this chain because my upstream port has no peer" is a local read that needs no
propagation channel. Do not manufacture a shared authority or a propagation path
for something every node can compute correctly on its own.

6 yields to stability. Coupling to a surface that does not move — a stdlib type, a
driver API, a settled internal interface — is acceptable and not a finding, however
heavy the dependency looks. The tell is a dependency mediated by no interface at
all. Naming this tension in a finding is better than pretending the axis is
absolute.
