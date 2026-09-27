---
name: fixing-comments
description: Use when cleaning up, reviewing, or fixing code comments — when comments narrate changes ("changed this to...", "now we..."), restate what the code obviously does, are multi-sentence/verbose, or when code feels over-commented. Also apply while writing new code to avoid producing such comments.
---

# Fixing Comments

## Overview

A comment exists to tell a future reader something the code itself cannot: a hidden constraint, a non-obvious reason, an invariant, a warning. Everything else is noise that rots the moment the code changes.

**Core principle:** A good comment answers "why is this here?" — not "what does this line do?" and never "what did I just change?"

Most comment cleanup is not binary delete-or-keep. There are **three** moves, and the verbose ones usually get compressed, not deleted.

## The Three-Way Decision

For every comment, pick one:

| Move | When | Example |
|------|------|---------|
| **DELETE** | Narrates a change, restates the code, or states the obvious | `# Changed to a loop to avoid recursion` · `# Check if premium` · `# Return the result` |
| **COMPRESS** | The WHY is real but buried in 2-4 sentences of explanation | 4 lines on how rounding math works → one line: the constraint that forces it |
| **KEEP** | One line, states a non-obvious WHY the code can't show | `# Stripe floors to cents; a half-cent mismatch fails their charge validation` |

The user's most common complaint is the missed **COMPRESS** move: a paragraph explaining transitive math or restating an algorithm should become a single line naming the *reason* — or be deleted if the reason is self-evident from the code.

## What to DELETE on sight

- **Change narration** — talking to the reviewer, not the reader: `# Changed this to...`, `# Now we use map`, `# Refactored to...`, `# Updated to handle X`. This belongs in the commit message.
- **Restating the code** — `# loop over users` above `for user in users`, `# increment counter`, `# import os`.
- **Step labels** — `# Step 1: fetch`, `# First, validate` when the code is already linear and readable.
- **Obvious intent** — `# Apply 20% discount` above `price * 0.8` under an `if tier == "premium"` branch. The code already says it.

## How to COMPRESS

Strip everything the reader can see for themselves; keep only the fact they can't derive.

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

## The "why is this here?" test

Ask of each surviving comment: **does this state something the reader could NOT learn from the code itself?**

- Yes → keep it, one line.
- No → delete it.

If you're explaining *what* the code does, the comment is wrong by default — improve a name or delete the comment instead. Comments earn their place only by explaining *why*.

## Workflow when invoked as cleanup

1. Read the file; classify each comment as DELETE / COMPRESS / KEEP.
2. Apply edits in place. Don't add comments that weren't requested.
3. Watch for the adjacent fix: a comment that exists only because a name is bad — rename the thing instead of annotating it (mention it, don't silently rename if scope was comment-only).
4. Report counts briefly: e.g. "deleted 6, compressed 2, kept 3" — don't narrate each one.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Over-deleting — stripping a real WHY because it "looked obvious" to you | If it encodes a constraint, workaround, or invariant the code can't show, KEEP one line of it |
| Treating it as delete-or-keep only | Verbose WHY comments get COMPRESSED, not deleted |
| Compressing into terse jargon the next reader can't parse | One plain-English line beats a cryptic fragment; readable > short |
| Leaving change-narration because it "has context" | It's commit-message content. Delete it. |
| Adding new explanatory comments during a cleanup pass | Cleanup removes noise; don't add unless the WHY is genuinely missing and non-obvious |

## Red Flags — the comment is probably noise

- Starts with "Changed", "Updated", "Now", "Refactored", "Fixed", "Added"
- Is a sentence-by-sentence echo of the lines below it
- Explains a language feature or basic math
- Takes more than one line to say something the code already says
