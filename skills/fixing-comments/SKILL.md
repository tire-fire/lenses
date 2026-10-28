---
name: fixing-comments
description: Use when cleaning up, reviewing, or fixing code comments — when comments narrate changes ("changed this to...", "now we...", "instead of..."), list callers or scenarios, restate what the code or its names already say, make unverified mechanism or parity claims, are multi-sentence/verbose, or when code feels over-commented. Also apply while writing new code to avoid producing such comments.
---

# Fixing Comments

## Overview

Silence is golden. The default is no comment. A comment exists only to tell a future reader something the code and its names cannot: a hidden constraint, an invariant enforced elsewhere, a hardware/runtime/library quirk, or a workaround's reason. Everything else is noise that rots the moment the code changes.

**Core principle:** Judge every comment for necessity first, then length. A good comment answers "why must this be this way?" — never "what does this line do?", never "who calls this?", and never "what did this branch change?"

## The Three-Way Decision

For every comment, pick one:

| Move | When | Example |
|------|------|---------|
| **DELETE** | Narrates a change, lists callers/scenarios, restates the code or a name, or pads a comment to feel "complete" | `# Changed to a loop to avoid recursion` · `# Called by sync() after boot` · `# Return the result` |
| **COMPRESS** | A real hidden constraint is buried in multi-sentence explanation | 4 lines on how rounding math works → one line naming the external constraint that forces it |
| **KEEP** | One line (two at most), states a verified non-obvious fact the code cannot show | `# Stripe floors to cents; a half-cent mismatch fails their charge validation` |

A KEEP needs the one non-obvious fact the comment carries; if you cannot name it, it is DELETE.

## What to DELETE on sight

- **Change narration** — talking to the reviewer of the diff instead of a reader meeting the code for the first time: what it replaced, what used to happen, `"now"`, `"no longer"`, `"instead of"`, `"changed this to"`, `"refactored to"`, or the review/bug that led to it. The change's story belongs in the commit message.
- **Caller lists, call order, and scenario lists** — enumerating who calls a function, in what sequence, or which cases a branch handles. Callers change without touching the callee, and the code already shows the branches.
- **Restating the code or its names** — `# loop over users` above `for user in users`, `# increment counter`, or a docstring that repeats the function and parameter names in prose.
- **Step labels** — `# Step 1: fetch`, `# First, validate` when the code is already linear and readable.
- **Obvious intent** — `# Apply 20% discount` above `price * 0.8` under an `if tier == "premium"` branch.
- **Completeness padding** — a true sentence appended to a real WHY comment just to make the explanation feel complete.

## How to COMPRESS

What survives gets compressed hard: **one line by default, two at most.** "It is all true" is never a reason for a longer comment. Prefer deleting a clause to rewording it. Where a diff only changed a word of the base branch's comment without changing the fact, restore the base wording.

```python
# BEFORE — four sentences narrating the math
# We multiply price by 0.8 to get the discounted price. This works because
# multiplying by 0.8 is the same as subtracting 20%. Addition and subtraction
# are transitive so the order does not matter. This is necessary to apply the discount.
discount = price * 0.8

# AFTER — delete it. `price * 0.8` under a premium branch is self-evident.
discount = price * 0.8
```

```python
# BEFORE — buries a real constraint in an explanation of the mechanism
# Here we floor the value to two decimal places. We multiply by 100, floor it,
# then divide by 100. We do this because floating point can produce values like
# 19.999999 and we need clean cents for the payment processor to accept it.
amount = math.floor(amount * 100) / 100

# AFTER — keep only the constraint the reader can't see
# Payment processor rejects sub-cent precision; floor to clean cents.
amount = math.floor(amount * 100) / 100
```

## Fact-check every surviving comment

A false comment is worse than none. Before keeping or compressing any comment that asserts a mechanism:

1. **Mechanism claims** — ordering, lifetime, who calls what, what fires when, what a guard admits or prevents, or what is guaranteed: trace the source and verify it holds. Check especially for a statement of the same fact elsewhere in the codebase that the comment contradicts, and **always fact-check untouched docstrings or comments immediately attached to a function, struct, method, or template whose body changed in the diff** (editing an implementation frequently invalidates the untouched doc comment right above it).
2. **Parity claims** — a comment saying new code reproduces old code ("X's own defaults", "the same timings", "reproduces what Y did") is verified only when you have read how *each* implementation consumes the value, not just that the numbers match. Equal constants are not equal behavior. Reading the declaration on one side and the use on the other, then inferring equivalence across the gap, is OVERCLAIMING.
3. **Disinforming identifiers (names that lie)** — a function, method, field, or variable whose name contradicts its actual behavior, polarity, unit, type, or scope (especially an untouched name whose body was generalized or repurposed in the diff, or a name encoding the wrong unit or container type) is a FALSE comment in identifier clothing. Report it alongside FALSE comments with `file:line` evidence.

## Workflow when invoked as cleanup or review

1. Check whether a lint rule or style hook requires a comment form (e.g., public Doxygen or docstrings) — never delete a required block, but compress it to one line where one line will do.
2. **Ignore pure whitespace or column-alignment changes (`git diff -w`) on pre-existing comments whose underlying code did not change** (for example, `gofmt` or a formatter re-aligning neighboring struct field or `const` comments when a new field is added). Do not create unrelated diff churn on untouched code's comments.
3. Judge each added/modified comment — plus any untouched docstring or comment attached to a modified function, struct, method, or template — for necessity first (DELETE vs survive), then compress survivors to 1–2 lines, then fact-check every mechanism and parity claim on what remains.
4. Watch for the adjacent fix: a comment that exists only because a name is bad, or an identifier whose name contradicts what its code actually does after a change — rename the thing instead of annotating it (mention it under FALSE if scope is comment-only).
5. Report FALSE and OVERCLAIMING comments first with `file:line` evidence, then DELETE / COMPRESS / KEEP counts (DELETE first), and flag any file where comment lines added outnumber code lines added.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Keeping a multi-line comment because every sentence is true | Truth is a floor, not a justification; keep only the non-obvious constraint, in one line |
| Leaving change narration (`"now"`, `"no longer"`, `"instead of"`) because it "has context" | It is commit-message content. Delete it. |
| Leaving caller lists or call-order summaries | They rot silently the next time a caller changes. Delete them. |
| Accepting a parity claim because the constant matches | Trace how both the old and new implementations *consume* the value |
| Over-deleting a genuine hidden constraint because it looked short | If it encodes a quirk, workaround, or external invariant the code cannot show, KEEP one line of it |
| Deleting or rewriting a pre-existing comment that only appeared in the diff due to formatter alignment (`git diff -w`) | Ignore whitespace-only hunks on untouched code's comments to avoid unrelated churn |
| Skipping an untouched docstring right above a function whose body changed | Fact-check it; changing a function's behavior frequently makes its existing doc comment false |
| Adding new explanatory comments during a cleanup pass | Cleanup removes noise; never add unless a hidden hazard is genuinely non-obvious |

## Red Flags — the comment is noise

- Uses diff-relative words: "Changed", "Updated", "Now", "No longer", "Instead of", "Previously", "Refactored", "Fixed"
- Lists callers ("Called from...", "Used by...") or narrates the branches below it
- Is a sentence-by-sentence echo of the code or signature
- Explains a language feature or basic math
- Takes more than two lines
