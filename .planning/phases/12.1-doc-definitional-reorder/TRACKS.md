# Phase 12.1 (INSERTED) — definitional re-ordering of the document opening

**Requirement:** CTX-DEFORDER (sole).
**Status:** BLOCKED. Nothing may be started.
**Why a decimal insertion, not a phase:** it has a fixed, small spec, zero proof content, and an
indefinite user gate. Registered as a decimal per the roadmap's own convention ("Decimal phases:
urgent insertions") so it can sit unstarted **without holding any phase open**. The first draft
bundled it with three other tracks, which would have left that phase permanently at 3/4.

## The user's three comments, verbatim

1. *"TODO: If already formalized (Make this a DEFINITION using the academic writing convention) This
   is the core definition"* — on the volatility payoff `π^σ`.
2. *"todo: What happened to this. \alphas are taken as notation use c_1 and c_2"* — on the
   replication display.
3. *"This is an assigment not an identity THat is why the left arrow BUT is the consequence of making
   \phi assigned the \theta. Thus the formal definition on \theta comes first. Then the assigment of
   stremia and then a nmaed assignment for the time integerated stremia. NOte taht all these are
   deifcinoiion, and conventions but need re oirdering"*

## The required order, read off comment 3

  (i) formal DEFINITION of `θ` → (ii) ASSIGNMENT of streamia → (iii) NAMED ASSIGNMENT of the
  time-integrated streamia.

The `=` → `←` edit on `p_{π^{call|put}}` is already in the working tree and is **correct** under this
reading: it is item (iii), an assignment, and writing it as an identity was the error.

## ALL THREE COMMENTS ARE BLOCKED — including comment 2

The first draft of this registration certified comment 2 as "a mechanical rename that could ship
alone". **That was wrong, on two counts:**

- **`c_1` and `c_2` are already taken.** They are the E4 branch coefficients in the same document
  (Lean `cOne`/`cTwo` in `EtaCurvature.lean`), 13 sites, and `c_1`'s sign is load-bearing in four
  displays. Executing the rename as literally stated creates a fresh collision — violating the
  freeness-check rule that the same registration file lists as a binding invariant. This is the
  ξ-collision mistake repeating: a proposed symbol that is not free.
- **Comment 2 opens with a question, not an instruction.** *"What happened to this"* is an unanswered
  question about the block. The first draft's paraphrase silently converted question + instruction
  into instruction-only, then certified the result shippable.

**Required before any edit:** answer "what happened to this", and propose a *free* symbol pair to the
user. Do not assume `c₁,c₂`.

## Second precondition, beyond user approval

**The θ exponent-sign FLAG is live and unresolved** (`FLAG (author decision pending): exponent sign
above`, restated as blocking in three later blocks — it "blocks any frozen θ_decay constant"). Step
(i) of the required order is *the formal definition of θ*. **θ cannot be promoted to a definition
while its display carries an unresolved sign.** So this phase has two preconditions, not one:

1. **HEAVY USER APPROVAL** — it restructures the block every later section depends on.
2. **The θ exponent-sign FLAG resolved.**

## Ordering constraint

Renumbering definitions and renaming the replication weights invalidates cross-references in any
block drafted against the current numbering — which is exactly what Phase 14's V0–V9 are.
**12.1 runs strictly BEFORE any V-block lands, or strictly AFTER all of them; never interleaved.**

## Scope note

Comment 1 is **conditional**: *"If already formalized"*. That precondition is verifiable and
load-bearing — check first. The first draft dropped the conditional and added "numbered", which the
user did not write; both corrected here.
