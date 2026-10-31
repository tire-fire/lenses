---
name: evaluating-architecture
description: Evaluates cross-unit structural design across six axes: state ownership, single authority, layer direction, truth propagation, minimum scope, and boundary coupling. Use when designing or reviewing cross-layer components and state boundaries.
---
Authority: Read and cite `CONTEXT.md`, `ARCHITECTURE.md`, or `CLAUDE.md` if present; otherwise cite axis number (1-6) below.
Axes ("no" = finding):
1. Ownership: Is state stored where decisions about it are made? Move state to decision owner or make owner authoritative and callers read-only.
2. Single authority: Is there one authoritative source for each fact rather than multiple reconstructions (graph walks, handshakes, re-derivation)? Name the authority; make all callers read it.
3. Layer direction: Do dependencies point strictly downward across layers (no transport/storage/driver holding business/UI/domain rules)? Push higher-layer concepts up or pass opaquely.
4. Truth propagation: Does the fact owner publish changes directly rather than forcing consumers to recompute or periodically re-sync?
5. Minimum scope: Does each component store only neighbor-local state unless the requirement spans the system? (Axis 5 = what a unit stores; Axis 6 = what crosses a boundary.)
6. Boundary coupling: What single change forces edits on both sides of a boundary? If it is a design decision (wire format, timeout, state encoding, buffer layout, URL scheme), move it into one owner. Flag shared mutable globals/buffers, duplicate payload decoders, `a.getB().getC().doX()` chains, unstable surfaces, and state-mutating queries (`hasNewData()` clearing a flag, lazy-init getters coupling callers to call order).
Yields & out of scope (drop silently):
- Axes 2, 4, 5 yield when a fact is authoritative and trivial to derive locally with zero coordination.
- Axis 6 yields when coupled to a stable stdlib, driver, or internal interface.
- Drop reinvention, data representation/type selection, compensating retry/polling loops, local guards, shallow wrappers, and line-level cuts.
Output ONLY one line per finding (no preamble, summary, code blocks, or deferred list), or `Clean.`:
`<file:line> | <Axis 1-6 or doc citation> | <misplaced state or boundary coupling> -> <single owner, direction, or propagated fact>`
Example: `bot/cogs/tickets.py:84, web/tickets/views.py:142 | Axis 2 | both cog and view reconstruct claim eligibility from 3 status flags -> move to Ticket.can_claim(actor) on domain model`
