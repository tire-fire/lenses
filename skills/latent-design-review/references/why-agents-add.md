# Why agents add, and the prior art for taking it back out

Background for `latent-design-review`. Read when you want the evidence behind the
method, or to cite it when justifying a finding.

## The failure mode this skill targets

LLM coding agents produce code that *works* but doesn't *cohere*: it reinvents
what already exists, hand-rolls awkward versions of known constructs, and reaches
for one more flag/guard/wrapper instead of a better shape. Four converging
results explain why, and why an after-the-fact audit beats the generating agent.

- **Additive bias is real, and LLMs share it.** Humans systematically search for
  additive changes and overlook subtractive ones, even when subtraction is better
  and cheaper (Adams, Converse, Hales & Klotz, *People systematically overlook
  subtractive changes*, Nature 2021, https://www.nature.com/articles/s41586-021-03380-y).
  LLMs replicate the same bias (*More is More: Addition Bias in Large Language
  Models*, arXiv 2409.02569, https://arxiv.org/pdf/2409.02569). The model reaches
  for "add a thing" because additive moves are faster to retrieve, not better.

- **Bounded context → reuse failure.** AI-authored PRs reuse significantly less
  existing code than human ones; the model can't see what already exists, so it
  reinvents it (*More Code, Less Reuse*, arXiv 2601.21276,
  https://arxiv.org/pdf/2601.21276). It optimizes for a working solution, not one
  that integrates with existing infrastructure.

- **Local correctness over global coherence → sprawl and superseded code.** An
  empirical study of agentic refactoring found agents do low-level work
  competently (rename variable/parameter, change type) but almost never target
  duplication (1.1% of refactorings vs 13.7% for humans) or reuse (4.6% vs 12.9%),
  and fail to reduce design/implementation smells (median delta 0.00). They
  "underperform at high-level architectural work requiring system understanding"
  (*Agentic Refactoring: An Empirical Study of AI Coding Agents*, arXiv
  2511.04824, https://arxiv.org/html/2511.04824v1). **This is the linchpin:** the
  exact move the generating agent cannot make is the one this skill makes — hold
  the whole design in view and recognize that the new code is an awkward instance
  of something already known.

- **It compounds at scale.** Duplicated code blocks rose roughly eightfold in
  2024; copy/paste exceeded moved (refactored) code for the first time on record;
  cloned blocks carry 15–50% more defects (GitClear, *AI Copilot Code Quality
  2025*, https://www.gitclear.com/ai_assistant_code_quality_2025_research). The
  surface plausibility of AI code masks the debt (Sonar,
  https://www.sonarsource.com/blog/the-inevitable-rise-of-poor-code-quality-in-ai-accelerated-codebases/).

The throughline: the generating agent was structurally unable to do the wide
search and the global-coherence check. The audit's whole value is doing exactly
that — which is why it must operate at architectural altitude, not at the
static-analysis tier a linter already covers.

## Prior art: the spine of the method

No single named process is exactly this skill, but it sits at the intersection of
three mature disciplines. The method borrows their structure rather than
inventing one.

- **TRIZ — Trimming + Ideal Final Result** (Altshuller; inventive engineering).
  *Trimming* is a formal procedure: build a function map, then remove a component
  and **reassign its useful function to the components that remain** — total
  removal with function preserved, not deletion of function. The *Ideal Final
  Result* is an implementation-free description of the solved state: "the function
  is delivered, the machinery does not exist." TRIZ's core premise is also
  solve-by-analogy: treat a novel problem as an instance of an abstract,
  already-solved one.
  Trimming: https://www.oreilly.com/library/view/triz-for-dummies/9781119107477/21_9781119107477-ch14.xhtml
  IFR: https://innovation.world/invention/ideal-final-result/

- **Value Engineering — Function Analysis** (Lawrence Miles, GE, 1947). Separate
  *function* from *implementation*: name what each part does as a verb-noun pair,
  then find the least-cost way to deliver that same function without sacrificing
  it. "What does this code *do*, and what is the least machinery that delivers
  that?" is the behavior-preserving-removal gate stated as a formal method.
  https://www.dfma.com/resources/value-engineering.asp

- **Refactoring to Patterns (Kerievsky) + DDD's "refactoring toward deeper
  insight" (Evans)** — the software-native analogy move. Kerievsky: your
  hand-rolled code is an awkward instance of a known pattern; reshape toward the
  pattern. Evans: the latent model is trying to surface; refactor until it does.
  This is "surface the design the code is secretly trying to be," in our field's
  own vocabulary.

- **Database normalization** (Codd) — the one formal, named procedure behind the
  representation lens: restructure the data to remove redundancy, and the
  redundant logic dissolves with it.

## The design principles the lenses rest on

- **Complexity = dependencies + obscurity** (Ousterhout, *A Philosophy of
  Software Design*). A module earns its interface by hiding a lot behind a little
  (a *deep* module). A *shallow* module — interface about as complex as its
  implementation — hides no decision and only adds a dependency. Add depth; remove
  shallowness.
- **Simple vs easy / complecting** (Hickey, *Simple Made Easy*). Complexity is
  things braided together that could be pulled apart. "Easy" (familiar, close at
  hand) is where band-aids come from; "simple" (un-braided) is the target.
- **Data dominates** (Brooks: "show me your tables and I won't usually need your
  flowcharts"; Pike's Rule 5: "if you've chosen the right data structures, the
  algorithms will be self-evident"; Torvalds: good programmers worry about data
  structures and their relationships). The representation lens is this principle
  applied: the right data shape makes the logic dumb and deletes the branches.
- **The wrong abstraction** (Sandi Metz). An abstraction that no longer fits its
  callers — each bolting on parameters and conditionals to escape it — costs more
  than the duplication it replaced. Inlining it back is often the simplification.
