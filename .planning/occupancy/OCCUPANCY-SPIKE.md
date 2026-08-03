# Research spike — `T_ITM/T` and the endogenous maturity

**Status:** SPIKE, not a phase requirement. **No CTX id.**
**Demoted 2026-08-03** — both reviewers independently reached the same verdict on the first draft,
which had registered this as CTX-OCCUPANCY with a `- [ ]` in the roadmap.

## Why demoted

The whole track rests on one user sentence. There is no research, no source reading, and the stated
next action is *"find his definition, its hypotheses, and whether his `T` is a maturity at all given
perpetual options have none"* — i.e. **we do not yet know the object exists in a connectable form.**
Registered as a requirement it would have occupied an undischargeable checkbox: the requirement text
was "connected to this project's endogenously-controlled maturity `T`", which no outcome can falsify,
and the body's verb was "determine what can be leveraged" — a research verb, not a deliverable.

A spike is the honest shape. It gets promoted to a real requirement **only if it finds a connectable
object**, and at that point it gets a definition of done.

## The user's note, verbatim

> ## OTHER KRSITENSEN CONNECTIONS
>
> Our maturity T which is endogenously controlled by the specified target vega and controlled by
> liquiditations needs to be connected to the T_{ITM} /T = \int_{t_O}^{T} \mathbb{P}_{[i_l, i_u]} dt / T
> as defined on Krsitensen and see what can ew leverage from there

## Why it is a different object from the implied-volatility work

Same source PDF, different quantity. σ_IV is a *level* read off a volume/liquidity ratio; `T_ITM/T`
is an *occupancy fraction* — the time-average of the in-range probability. The IV research already
established that the integrated object in Kristensen is the **occupation time**, not VOL, so this
spike inherits that finding rather than duplicating it.

## Questions the spike must answer

1. Kristensen's definition of `T_ITM/T`, with its hypotheses and page anchor.
2. **Is his `T` a maturity at all?** Perpetual options have none. If it is a horizon parameter rather
   than a maturity, the connection to our endogenous `T` may not exist — and that is a valid,
   reportable outcome.
3. Whether the object is consistent with the DECIDED `tStarJointMult` law (linear burn preserves
   `υ = t/2`; the quadratic variant was REJECTED as pro-holder under clustering), or refutes it.
4. Whether `ℙ_{[i_l,i_u]}` in the binding `ℙ_{event}` convention is the same probability the
   JIT/ARB blocks already use, or a new one.

## Out of scope — explicitly

Re-identifying `υ`. The υ econometric null result (phases 09–10) is **terminal**: "this market cannot
identify υ" is never reopened. This spike is about `T`.

## Promotion criterion

Promote to a CTX requirement only if (1) and (2) return a connectable object. Deliverable at that
point: a doc block stating `T_ITM/T` in the `ℙ_{event}` convention, plus either a proved consistency
lemma against `tStarJointMult` or a recorded refutation, landed axiom-clean.
