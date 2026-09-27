# lenses

A Claude Code plugin that reviews a branch with six independent reviewers instead of
one, then makes the orchestrator write every finding down before it fixes anything.

Each lens is a fresh-context subagent that sees the diff and nothing else: not your
reasoning, not the other lenses, and in one case not even the commit messages. They
run concurrently, they report, and the orchestrator ledgers every finding with a
disposition before the first edit. Two lenses reaching the same conclusion from
different directions is the strongest signal the process produces, and the ledger is
what stops single-lens findings from evaporating.

## The six lenses

| # | Lens | Question it asks | Skill |
|---|------|------------------|-------|
| 1 | ripoff-bandaids | What accidental complexity can be removed so the code does its job directly? | bundled |
| 2 | scope | For each file in the diff: what breaks in the shipping product if this file's changes are dropped? Then, what is bloat? | ponytail-review (bundled, MIT, by Dietrich Gebert) |
| 3 | correctness | Where does this break, and can each new code path actually fire in the shipping build? | none |
| 4 | latent-design-review | What design is this code secretly trying to be, and what structure disappears if it becomes that? | bundled |
| 5 | architecture-doctrine | Is each fact stored where its decision is made, and what single change would force both sides of a boundary to move? | bundled |
| 6 | fixing-comments | Is every comment that asserts a mechanism true? Then delete, compress or keep. | bundled |

Lens 2 is briefed without the commit messages on purpose. Knowing the intent makes a
reviewer grade execution against it, which is exactly the anchor that lens exists to
escape.

## Install

```
claude plugin marketplace add tire-fire/lenses
claude plugin install lenses@lenses
```

Then, in any repo:

```
/lenses                  # review the current branch against its upstream base
/lenses main             # review against a base ref (merge-based automatically)
/lenses abc123..HEAD     # review an explicit range
```

## What the command does

1. **Resolves the range at the merge base**, never at the base tip, so a base that
   moved since the fork does not show up as reverse changes the branch never made.
   Stacked branches are reviewed as a stack.
2. **Resolves a repo profile** from the tree: the stack, the check commands (from
   `CLAUDE.md`, the deploy or CI script, or the package manifest), which directories
   ship and which only test, whether an architecture document exists, and the
   per-repo lens block described below. Every lens is briefed from the same profile.
3. **Launches all six lenses in one message**, each as a `general-purpose` subagent
   with the skill it needs and a brief written for that lens.
4. **Ledgers every finding** into `docs/lens-ledger-<branch>.md` with a disposition
   of `FIXED`, `DEFERRED-<ticket>`, `ASKED` or `REJECTED-<citation>`, before the first
   edit.
5. **Synthesizes**: convergent findings first, single-lens findings verified before
   acting, rejections written down with a citation, and an audit of the orchestrator's
   own fix diff hunk by hunk, because the lenses only ever saw the pre-fix code.

## Making it sharp for your repo

The command works on any codebase as-is. What makes it sharp is a short
`## Review lenses` section in your repo's `CLAUDE.md`, which the orchestrator quotes
verbatim into the matching lens briefs. It holds the three things that cannot be
derived from the tree:

- **Failure classes this codebase has actually shipped**, for lens 3. A hazard list
  earned from real bugs beats anything derived from the stack. Without it, lens 3
  applies four checks that hold anywhere: authorization on every new entry point,
  atomicity and ordering, trust-boundary inputs, and every invariant a new comment
  claims, plus the "can this path fire in production" trace.
- **Where the design vocabulary lives**, for lens 4: the directories holding the
  core types and shared utilities that everything else builds on.
- **Comment forms a lint rule requires**, for lens 6, so it never recommends
  deleting one.

An example from the ESP32 firmware this was written for:

```markdown
## Review lenses

### Lens 3 hazards
Lifetimes and use-after-free of captured `this` in callbacks; ordering hazards
between state lifecycle, callbacks, and the coordinator's `sync()`; single-slot
observers being clobbered (grep *every* registrant, test fixtures included);
behavior differences where polled code was converted to event-driven or vice
versa; bounds and clamping on anything off the wire. A mechanism gated behind a
flag or an init call that nothing under `src/` invokes is dead in production.

### Lens 4 vocabulary
`lib/core/include/state/`, `lib/core/include/device/`, `lib/core/include/wireless/`

### Lens 6 exemptions
`///` Doxygen blocks on public method declarations are required by the style hook.
```

And one for a Django portal with a Discord bot:

```markdown
## Review lenses

### Lens 3 hazards
Every new or changed view carries `@require_permission` or an explicit
`has_permission()` check, and JSON endpoints return a 403 `JsonResponse` rather
than a redirect. Get-then-save on rows the bot and the web process both touch.
Migrations matching the model change. Task-queue rows created with a valid type,
a payload matching the documented schema, and `status="pending"`. Blocking calls
(sync ORM, requests, sleep) inside the bot's event loop. Naive datetimes. A view
with no route in a `urls.py` or a cog nothing registers in `main.py` is dead in
production.

### Lens 4 vocabulary
`web/core/` (models, permissions, utils), the per-app `models.py` and `views/`,
`bot/discord_queue.py`, `bot/cogs/`

### Lens 6 exemptions
Ruff's `ERA` rule already rejects commented-out code; do not spend findings on it.
```

## Using the skills on their own

The five bundled skills are ordinary Claude Code skills and work outside the
command: `lenses:ripoff-bandaids`, `lenses:ponytail-review`,
`lenses:latent-design-review`, `lenses:architecture-doctrine`,
`lenses:fixing-comments`. Each is advisory: it diagnoses and proposes, and the
human decides.

## License

MIT. `skills/ponytail-review/` is from
[ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert, also MIT;
its license is reproduced alongside it.
