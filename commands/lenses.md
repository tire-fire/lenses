---
description: Runs seven concurrent review subagents against a branch diff, ledgers all findings before editing, and runs bounded follow-up passes.
argument-hint: "[base-ref | range] [--followup] (default: upstream base of the current branch)"
---
Run the seven review lenses against `$ARGUMENTS` as seven concurrent fresh-context subagents. On `--followup` / `followup` or Round 2+ after applying ledger fixes, run the §5 follow-up pass unless fixes reshaped cross-package architecture or data structures.
## 1. Range & Repo Profile
- Range resolution: if `$ARGUMENTS` contains `..`, use verbatim; if a single ref, use as `<base-ref>`; if empty, resolve `<base-ref>` from remote `upstream` (else `origin`) via `gh pr view --json baseRefName` (else `git remote show <remote>` `HEAD branch`). For stacked branches, use the shared base of the stack. Always cut at merge-base: `BASE=$(git merge-base <base-ref> HEAD)` and use `$BASE..HEAD`. If `<base-ref>` is ahead of `$BASE`, report commit count and files gained.
- Commit-tree integrity gate: compare `git diff --stat $BASE..HEAD` against `git log --format= --name-only $BASE..HEAD | sort -u`, and verify each commit's `git diff <commit>^ <commit> --stat` contains only its own work. If the range reverts or deletes base additions, stop and run a real `git rebase` first.
- Repo profile (resolve once, never guess commands, do not print narration before spawning subagents):
  1. Stack: languages/frameworks in diff.
  2. Check commands: exact test, lint, type-check, and build commands (plus required DB/env setup) from `CLAUDE.md`, CI/deploy scripts, or package manifests.
  3. Roots: production directories vs. test directories.
  4. Docs: `CONTEXT.md`, `ARCHITECTURE.md`, `THREAT_MODEL.md`, or design/security sections in `CLAUDE.md` (state if absent).
  5. Per-repo lens block: `## Review lenses` in `CLAUDE.md` (Lens 3 hazards, Lens 4 vocabulary paths, Lens 6 lint exemptions, Lens 7 trust boundaries); quote verbatim into matching lens briefs or state absent.
## 2. Launch 7 Subagents in ONE Message
Spawn 7 `Agent` calls (`subagent_type: general-purpose`) in one message. Never run skills inline. Set `model` on each call (unless user/repo overrides):
- High-tier (`opus` / `pro`): Lens 3 (`checking-correctness`), any fixer agent, and Lens 7 (`auditing-security`) when auth, sessions, credentials, permissions, or trust boundaries are touched.
- Mid-tier (`sonnet` / `flash`): Lenses 1, 2, 4, 5, 6, and Lens 7 when no auth/trust boundary is touched.
Common preamble for all 7 subagents (omit commit messages so reviewers audit the code rather than grading intent):
`Repo: <repo path> (<stack>). Branch: <branch>. Range: git diff <RANGE>. Production roots: <prod roots>; test roots: <test roots>.`
`Rules: (1) Read CLAUDE.md first< and <doctrine file> | ; no separate architecture/glossary doc exists>. (2) Diagnose and report only; do NOT edit files. (3) Verify every claim in source, trace call chains across unchanged code, and cite file:line; state if unconfirmed. (4) Do NOT run full/DB/browser test suites; run only fast targeted single-test or type/compile checks when needed to prove a CONFIRMED defect; write scratch files only in /tmp. (5) Output ONLY actionable findings, one line per finding using your lens schema, or the single word Clean. No preamble, title, summary, range restatement, praise of completed work, code blocks copied from the repo, KEEP lists, or deferred/out-of-scope lists (silently drop out-of-scope items). On Round 2+ rechecks, output ONLY prior findings that remain broken or regressed (never list VERIFIED FIXED items). Do not ask follow-up questions.`
Per-lens instructions:
1. `removing-bandaids`: invoke `lenses:removing-bandaids` on `<RANGE>`.
2. `trimming-bloat`: invoke `lenses:trimming-bloat` on `<RANGE>`.
   - Pass 1 (per-file scope): trace production consumers to check what breaks in the shipping product if this file's changes are dropped entirely. Output one line per file whose only consumers are tests or that changes no observable behavior (rename/reformat sweeps): `<file> | scope | <real consumers> | <misleading impression if kept>`.
   - Pass 2 (leanness): run `lenses:trimming-bloat` across `<RANGE>`, grepping production roots to confirm any dead/unused/dup claim and verifying `shrink:` preserves exact behavior across callers.
3. `checking-correctness`: invoke `lenses:checking-correctness` on `<RANGE>` (quoting per-repo Lens 3 hazards verbatim if present).
4. `reshaping-latent-design`: invoke `lenses:reshaping-latent-design` on `<RANGE>` (starting vocabulary inventory from per-repo Lens 4 paths if present).
5. `evaluating-architecture`: invoke `lenses:evaluating-architecture` on `<RANGE>`.
6. `fixing-comments`: invoke `lenses:fixing-comments` across `<RANGE>` (including untouched docstrings/comments above modified code and per-repo Lens 6 lint exemptions). Check the PR description (`gh pr view --json body` or draft summary) in Round 1 and the final round before PR creation/update.
7. `auditing-security`: invoke `lenses:auditing-security` on `<RANGE>` (quoting per-repo Lens 7 trust boundaries verbatim if present).
## 3. Ledger Before Editing
Wait for all subagents to finish before editing any file. Write every finding from all reports (including `DELETE`/`COMPRESS` items and `Below the bar:` lines) into `/tmp/lens-ledger-<branch-or-issue>.md` (or the review-notes dir named in `CLAUDE.md`). Schema per row: `ID | Lenses | One-line statement | file:line | Disposition` where `Disposition` is `FIXED | DEFERRED-<ticket> | ASKED | REJECTED-<citation>` (never blank). Update rows as fixes land so `grep -E 'OPEN|ASKED' ledger` tracks completion. When a change invalidates a claim, `grep -rn '<old claim>' <production roots>` across the tree.
## 4. Fix & Verify
- Fix convergent findings first; verify single-lens findings in source before acting; cite `file:line` when recording `REJECTED-<citation>`.
- Prefer simpler state (one owner, one flag, one transaction) over adding guards, locks, markers, or retries.
- On `THREAT_MODEL_DRIFT`, update or bootstrap `THREAT_MODEL.md` / `ARCHITECTURE.md` using the 8-element schema in `lenses:auditing-security`.
- When delegating fixes, spawn a fresh fixer agent per round with the round's ledger rows, requiring a real `git rebase` and the §1 commit-tree check.
- Audit `git diff <base>..HEAD` hunk by hunk for unintended edits, moved blocks, unforced renames, or stray file touches.
- Run targeted lint, type, and test checks after each round, and falsify every added/changed test by reverting its mechanism and confirming failure. Run full and browser suites once before opening/updating the PR.
## 5. Follow-Up Rounds (Round 2+ / `--followup`)
Launch in one message on `<prev-HEAD>..HEAD` (with `$BASE..HEAD` for caller context, prior findings to recheck, and prior `REJECTED-<citation>` items excluded unless invalidated), writing to `/tmp/lens-ledger-<branch-or-issue>-r2.md` (`-r3.md`, ...):
- Run all 7 lenses if fixes reshaped cross-package architecture or added new data structures/files.
- Otherwise run: Lens 1 (`removing-bandaids`), Lens 3 (`checking-correctness`), Lens 6 (`fixing-comments`), and Lens 7 (`auditing-security`, omit on pure comment/CSS/internal-refactor fixes; may combine Lenses 3 and 7 into one agent on small deltas).
Stopping rules:
- Required after any behavior or structure change (only comment/name/wording/test-only edits may skip, stating why).
- Stop when a round finds only comment phrasing or identifier/test names: apply, run checks, and stop.
- Stop when Round 2+ finds only low-severity `PLAUSIBLE` items: list in PR known limits (`file:line`) and ledger as `DEFERRED-<PR>`.
- Stop at 5 rounds max (or repo/user cap): list remaining open items in PR known limits and note cap reached.
