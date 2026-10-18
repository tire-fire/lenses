---
description: Run six independent review lenses as fresh-context subagents against a branch diff, then ledger every finding before fixing
argument-hint: "[base-ref | range] (default: upstream base of the current branch)"
---

Run the six review lenses against `$ARGUMENTS` (or the default range below) as six
independent subagents, each with a fresh context.

## 1. Resolve the range and the repo profile first, and say what they are

### The range

- `$ARGUMENTS` contains `..` → use it verbatim as the range.
- `$ARGUMENTS` is a single ref → treat it as the base ref and merge-base it, below.
- Empty → resolve the base ref from the remote the branch will be merged into: the
  remote named `upstream` if one exists, otherwise `origin` (`git remote -v`). Use
  the base branch of the open PR for this branch if there is one
  (`gh pr view --json baseRefName`), otherwise that remote's default branch
  (`git remote show <remote>` → "HEAD branch").
- If the branch is **stacked** on another unmerged branch, review the whole stack
  against the shared base. A reviewer sees the stack; so should the lenses.

**Cut the range at the merge base, never at the base tip.** Resolve
`BASE=$(git merge-base <base-ref> HEAD)` and use `$BASE..HEAD`. A two-dot range
against a base that has moved since the fork renders everything the base gained as
a change the branch made *in reverse* — files it never deleted, licenses it never
changed, config it never touched — and the lenses report those as branch findings.
Two-dot `git log` is unaffected; it is `git diff` that inverts. If the base ref is
ahead of the merge base, say by how much and name the files it gained: those are
the merge conflicts this branch will hit, which is worth knowing before review, not
after.

### The repo profile

Every lens needs the same five facts about this repo. Resolve them once, here, from
the repo itself, and substitute them into the preamble below. Never guess a command;
if you cannot find one, say so in the preamble rather than inventing it.

1. **Stack** — languages and frameworks in the diff, one line.
2. **Check commands** — the test, lint, type-check and build commands, in the exact
   form the repo runs them. Sources in order: `CLAUDE.md`, a deploy or CI script
   (`deploy.sh`, `Makefile`, `.github/workflows/*`, `justfile`), the package
   manifest (`package.json` scripts, `pyproject.toml`, `Cargo.toml`,
   `platformio.ini`, …). Note any setup a command needs first (a test database, an
   environment file).
3. **Production roots vs test roots** — the directories that ship, and the
   directories that only test them. The lenses grep the former to confirm "unused"
   and refuse to call anything under the latter bloat.
4. **Doctrine and glossary** — whether the repo has a `CONTEXT.md`,
   `ARCHITECTURE.md` or a design document `CLAUDE.md` points at. If not, say so, so
   lens 5 uses its axes as the doctrine instead of hunting for a file.
5. **The per-repo lens block** — a `## Review lenses` section in `CLAUDE.md`, if
   present. It holds what cannot be derived from the tree: the failure classes this
   codebase has actually shipped (for lens 3), where its design vocabulary lives
   (for lens 4), and any comment or docstring form a lint rule requires (for lens
   6). Quote each part verbatim into the matching lens brief. When the section is
   absent, each lens falls back to the stack-neutral brief below; say that too.

Print the resolved range, the commits in it, and the profile before launching
anything.

## 2. Launch all six in ONE message

Six `Agent` calls with `subagent_type: general-purpose`, all in a single message so
they run concurrently. Do **not** invoke the skills inline in your own context —
the whole point is that each lens reads the diff without your reasoning attached to
it. Do not run any of them yourself while they work.

Give every agent this common preamble, substituting the resolved range and profile:

> Repo: <repo path> (<stack>). Branch: <branch>.
> Range: `git diff <RANGE>`. Commits in range: <list>.
> Production code lives under <production roots>; tests under <test roots>.
>
> Rules:
> - Read `CLAUDE.md` at the repo root first for the project's conventions and
>   vocabulary<, and `<doctrine file>` for its architectural principles | ; it has
>   no separate architecture or glossary document>.
> - Do NOT apply any edits. Diagnose and report only.
> - Verify every claim against the actual source before asserting it, and cite
>   `file:line`. Read the surrounding unchanged code the change builds on — never
>   reason from the diff alone. Trace call chains rather than inferring them from
>   names. Say plainly when you could not confirm something.
> - You may run: <check commands, with any setup they need>. Scratch files go in
>   /tmp, never the repo.
> - Do not ask a follow-up question — your final message is the report.

Then the per-lens body:

**1. ripoff-bandaids** — invoke the `lenses:ripoff-bandaids` skill first. Rank
findings by complexity removed; give intent, the band-aid and its catalog pattern,
the direct alternative, verification, and strength. Apply the load-bearing /
Chesterton's-fence check to every removal candidate. End with one top
recommendation.

**2. scope** — invoke the `lenses:ponytail-review` skill first, then apply it with
scope as the primary question rather than leanness.

> **Brief this one WITHOUT the commit messages.** Give it the range and the file
> list only. Naming the intent makes a reviewer grade execution against it, which
> is exactly the anchor this lens exists to escape.

Its first pass is per-file, over every file in the diff: **what breaks in the
shipping product if this file's changes are dropped entirely?** Answer it by
tracing consumers, not by reading the code's stated purpose. A file whose only
consumers are its own tests fails this — production code whose sole justification
is that it is tested is a model built to be asserted on, not a behavior anyone
depends on. So does a file that changes no observable behavior (a rename sweep, a
reformat) and rode along because lint fired on touch.

Report each such file as its own finding: the file, who its real consumers are,
and what a reader would wrongly conclude from its presence in this change. Do not
soften these into "worth exploring" — either something breaks or nothing does.

Then the ordinary leanness pass. One line per finding. Confirm anything called
dead/unused/duplicated with a grep across the production roots and cite it.
Tests are not bloat — never flag a check for deletion. End with
`net: -<N> lines possible.` or `Lean already. Ship.`

**3. correctness** — no skill; do a rigorous correctness review.

If the per-repo lens block names this codebase's failure classes, brief them
verbatim as the primary focus: they are the bugs this repo has actually shipped,
and a hazard list earned that way beats anything derived from the stack.

Whether or not it does, also apply the four checks that hold in any codebase:

- **Authorization on every new or changed entry point** — a route, a handler, a
  command, an RPC, a message consumer. Find the mechanism this repo uses and confirm
  the new entry point carries it, and that a failure yields the same response shape
  its siblings give (not a redirect where siblings return 403, not a stack trace
  where siblings return an error frame).
- **Atomicity and ordering** — read-then-write on state another process, thread,
  task or callback also touches; a lock, transaction or single-writer rule the
  siblings honor that the new code skips; callbacks or timers that can fire after
  the object they capture is gone or reset.
- **Anything crossing a trust boundary** — request bodies, wire frames, files,
  environment — reaching storage, a template, a shell or an index unvalidated or
  unbounded.
- **Every invariant a new comment, docstring or test name claims.** Trace it. A
  claim about ordering, lifetime, or "always/never" is a hypothesis until the code
  proves it.

> **Ask explicitly: can each new code path actually fire in the shipping build?**
> A mechanism gated behind a flag, an init call, a registration or a route that
> nothing in the production roots invokes is dead in production no matter how green
> the tests are, because the test fixture enables it. Trace from the production
> entry point (`main`, the app factory, the URL table, the cog or plugin registry,
> the firmware `setup()`), not from the test. If a code path replaced working code,
> prove the replacement is reachable in the configuration that ships.

Report each finding as: one-sentence defect, concrete failure scenario
(inputs/state → wrong behavior), `file:line`, and CONFIRMED (traced or executed)
vs PLAUSIBLE. Most severe first. Writing a scratch program or test to prove a
suspected bug is encouraged. If nothing real, say so rather than padding.

**4. latent-design-review** — invoke the `lenses:latent-design-review` skill first.
Follow its process step 1 seriously: inventory the repo's existing design
vocabulary before hunting. If the per-repo lens block names where that vocabulary
lives, start there; otherwise find it — the core models or types, the shared
utilities, the module every other module imports. Audit HEAD, not the diff — a
finding must describe an awkward shape still present with something left to
collapse, never narrate what the branch already did well. Apply the collapse test:
name the structure that disappears, or drop the finding.

**5. architecture-doctrine** — invoke the `lenses:architecture-doctrine` skill
first. If the repo has a doctrine document, read it and cite it, don't restate it;
if it has none, the skill's six axes are the doctrine and findings cite an axis by
number. Walk the six axes. Route findings that belong to ripoff / scope /
latent-design to those lenses instead of forcing them through an axis. Say where an
axis yields rather than pretending it is absolute.

**6. fixing-comments** — invoke the `lenses:fixing-comments` skill first, then
apply it to every comment and docstring added or changed in range. Before
recommending a deletion, check whether a lint rule or style hook requires that
comment form (the per-repo lens block names any such rule; otherwise read the lint
config) — never recommend deleting a required one, but hold it to the same bar
below: one line where one line will do.

> **Silence is golden. Judge every comment for necessity first, then length.** The
> default is no comment. A comment earns its place only by stating something a
> reader cannot get from the code and its names: a hidden constraint, an invariant
> enforced elsewhere, a hardware, runtime or library quirk, a workaround's reason.
> Everything else is DELETE:
> - restating what the code does, or what a name already says;
> - listing callers, call order, or the scenarios a branch handles;
> - narrating the change: what it replaced, what used to happen, "now", "no
>   longer", "instead of", the reasoning, review or bug that led to it. Comments
>   are for a reader meeting this code for the first time, who never saw the old
>   version; the change's story belongs in the commit message;
> - a true sentence appended to make a comment "complete".
>
> What survives gets COMPRESSED hard: one line by default, two at most. A longer
> comment needs a stated reason in your report, and the reason is never "it is all
> true". Prefer deleting a clause to rewording it. Where a comment only changed a
> word of the base branch's text, recommend restoring the base wording.
>
> Report, per file, comment lines added against code lines added, and flag every
> file where comments outnumber code. Apply this to every comment in the range, not
> only those changed since the last round: earlier rounds' additions are the
> usual offenders.

> **Then fact-check every surviving comment that asserts a mechanism.** A false
> comment is worse than none. For each comment claiming something about ordering,
> lifetime, who calls what, what fires when, what a guard admits or prevents, or
> what is guaranteed — trace it in the source and verify it is true. Report FALSE
> and OVERCLAIMING comments FIRST, as their own findings, with the `file:line`
> evidence showing what the code really does. Check especially for a correct
> statement of the same fact elsewhere in the branch that the comment contradicts.

> **Parity claims need both sides' USE, not both sides' value.** A comment saying
> the new code reproduces what the old code did — "X's own defaults", "the same
> timings", "reproduces what Y did" — is verified only when you have read how
> *each* implementation consumes the value, not just that the numbers match. A
> constant that is equal is not behaviour that is equal. Reading the declaration on
> one side and the use on the other, then inferring equivalence across the gap, is
> the specific mistake: report it as OVERCLAIMING and name the two call sites you
> compared. If you cannot find where the old code used the value, say so rather
> than treating the number as the answer.
>
> This is not hypothetical. A button driver migration carried OneButton's
> `_click_ms = 400` across as iot_button's `short_press_time`. Both are 400ms and
> both gate a click. But OneButton resolved the click immediately on release
> whenever no double-click handler was attached (`_nClicks == _maxClicks`,
> `OneButton.cpp:293`) and nothing in the project attached one, so the 400ms was
> never waited; iot_button always waits it. Every click resolved 400ms late and
> faster taps folded into a multi-click nothing handled, which made entering a
> pairing code impossible. Six lenses read that driver. The one that got closest
> cited the declaration and the new use, called the roles identical, and never
> opened the old use.

Then the DELETE / COMPRESS / KEEP pass with counts, DELETE first. A KEEP needs
the one non-obvious fact the comment carries; if you cannot name it, it is DELETE.

## 3. While they run

Hold all edits until every lens has reported. Do not edit files the agents are
mid-read on. If a lens returns something alarming, verify it yourself with a
targeted grep — but do not start fixing.

## 4. Ledger the findings BEFORE fixing anything

Write every finding from all six reports into `docs/lens-ledger-<branch-or-issue>.md`
(or wherever this repo keeps review notes, if `CLAUDE.md` says) in one pass, before
the first edit. One row per finding: number, which lenses raised it, a one-line
statement, `file:line`, and a disposition that must be exactly one of

    FIXED | DEFERRED-<ticket> | ASKED | REJECTED-<citation>

Nothing may stay blank, and "I'll fold that in" is not a disposition. Then fix from
the ledger and update rows as you go, so `grep -E 'OPEN|ASKED' ledger` answers "did
you get everything" out of a file rather than out of recollection — which also
survives context compaction.

This step exists because skipping it fails the same four ways every time:

- **Working from your own summary of a report instead of the report.** The headline
  gets fixed; the DELETE/COMPRESS lists, the "soft notes" and the "below the bar"
  sections never enter the working set. Those sections are where the false comments
  hide.
- **Fixing only what the diff shows you.** When a change makes a statement
  elsewhere false, the statement is not in the diff. **Grep the tree for the claim,
  not the hunk** — if a commit moves who does something, `grep -rn '<the old
  claim>' <production roots>` before calling the comment pass done.
- **Findings that need a decision get raised once and evaporate.** They go in as
  ASKED and stay there until answered.
- **Single-lens findings get filtered out.** Convergence is a priority ordering,
  not an admission test; a lone finding with a `file:line` is usually right.

## 5. Synthesis

- **Convergence is the strongest signal.** Two or more lenses reaching the same
  conclusion from different directions is near-certainly real. Verify it yourself
  anyway, then fix it first.
- **Verify before acting on any single-lens finding.** They are wrong often enough
  to matter; a confident report is not evidence. Trace it.
- **Audit your own diff before pushing, hunk by hunk.** After the fixes are in,
  read `git diff <base>..HEAD` end to end and ask of every hunk: did I mean this?
  The lenses only ever saw the pre-fix diff, so anything introduced while applying
  their findings is unreviewed — a botched regex, a hand-retyped block landing in
  the wrong place, a replacement that kept half the old sentence. Tests and builds
  passing says the behavior is right; it says nothing about whether the diff is.
  Churn to look for specifically: blocks that moved rather than changed, renames
  that are not forced by the diff-scoped lint, and files touched for no reason.
- **Run the scope question yourself before launching.** Lens 2 is a second pair of
  eyes on it, not the only pair: for each file in the diff, ask what breaks in the
  product if its changes are dropped. Lenses grade how well a change is built and
  systematically miss that it should not exist, because the diff frames the
  question as "is this good" rather than "should this be here."
- Push back in writing when a lens is wrong, and say why with a citation — a
  rejection without one is a skipped finding wearing a verdict. Lenses contradict
  each other often enough that settling it yourself is routine, usually with two
  greps.
- Say which findings you are deferring and why — separate "already decided against,
  here's the reason" from "genuinely new." A deferral needs an owner: a ticket
  number, or an ASKED row that survives into the next turn.
- **Re-run the lenses after a round of fixes, not before a push.** Every report
  predates the fixes applied from it, so a second round reviews code nothing has
  seen. Expect the largest category in round N+1 to be comments written in round N;
  that has held every time so far.
- After fixing: re-run every check command from the profile. **Falsify every test
  you added or changed** by reverting its mechanism and confirming it fails; a test
  that passes with the mechanism gone is worthless. Check the falsification grep
  actually matches the runner's output format before trusting a clean result.
