# Research spike — `T_ITM/T` and the endogenous maturity

**Status:** **REOPENED 2026-08-03, RESCOPED** — the close-out below answered a narrower question
than the user asked, on a distinction that does not hold. No CTX id yet.
Full record: `OCCUPANCY-RESEARCH.md`; correction in §CORRECTION below.
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

---

## VERDICT (2026-08-03) — DO NOT PROMOTE

**Q2 was decisive and the answer is no: Kristensen's `T` is not a maturity.** He states outright
(p. 55) that a Uniswap V3 position **never expires**; his `T` is "the total duration time", listed
(p. 58) as a **user-controlled input** — the duration the holder chooses to hold. The one
expiry-looking usage (p. 65) is an explicit *construction*: he truncates the perpetual to price it
against a dated Black–Scholes option. It is not a first-passage or liquidation time either — the
integrand is the marginal in-band probability, so re-entry is permitted and the process is never
stopped. **His `T` is an exogenous input; ours is an endogenous output.** They are not the same kind
of object, so there is nothing to connect at the maturity slot.

**His definition** (§3.3.4, printed p. 56, unnumbered; first numbered at (3.14), p. 58):
`T_ITM/T = (1/T)∫₀^T ℙ[p_t ∈ range] dt = (1/T)∫₀^T Erf(ln r/(σ√(2t))) dt`. The integrand is the
**marginal law of the state** under the **objective** measure with real-world drift, drift-annihilated
by his stated `T(µ−σ²/2) ≪ 1` assumption — not risk-neutral, not an indicator, not an occupation
density. By Fubini `T_ITM` is the *expected* occupation time.

**Consistency with `tStarJointMult` — REFUTATION.** Bijectivity technically survives (`T ↦ T_ITM` is
strictly increasing, so `υ = T_ITM/2` stays injective) — stated so as not to overclaim. But every
ground the decision was actually made on fails:

1. `dT_ITM/dT = ℙ_{[i_l,i_u]}(T)` exactly — starts at 1 and decays monotonically to 0. The recorded
   criterion was **"burn rate constant (no cliff)"**. Fails.
2. `T_ITM ∝ √T` asymptotically, so the antecedent that selected the multiplicative form
   (`σ²-budget ∝ T`) is invalidated.
3. Both `ℙ_{[i_l,i_u]}` and `(1−σ²_R/σ²_K)⁺` are σ-decreasing ⟹ it **double-counts the variance
   channel**, landing anti-holder — the opposite pole from the quadratic that was rejected as
   pro-holder.
4. **Decisive:** a variance swap accrues over *all* of `[0,T]` regardless of band, so a band weight is
   the **finite-strip replication error**, not a maturity modifier. **Corroborated in our own
   document** (verified 2026-08-03): the indicator already lives in `Γ` and `Γ^Σ`, never on `T★`.

**The probability** is new as an OBJECT, not as notation — a *state law*, a different type from the
four existing agent arrival/action probabilities. **Nothing needs minting.** One standing trap
recorded: it is **not** `ℙ_{ITM}`, which is reserved on a notation-map line for the delta-as-probability
reading and is one-sided/terminal. One convention question owed to the user: `ℙ_{[i_l,i_u]}` is the
only **set-valued** `ℙ_•` subscript in a convention where every other subscript is an event name —
`ℙ_{p∈(i_l,i_u)}` would match `Γ^Σ`'s existing rendering. Recommended, not applied.

**Two redirects worth keeping:**
- The connection the user wanted **already exists, elsewhere**: the implied-volatility research
  assigned `T_ITM/T` to the **FLAIR** side as the measure of `{t : ν_t > 0}`. Nothing further is owed
  on `T`.
- Kristensen's Erf occupation law is the **`η_L = 0` (constant-σ GBM)** member of the CEV family our
  document already carries — so it **cannot express the vol-clustering scenario the maturity-law
  decision turned on**. It is not merely the wrong tool; it is a strictly less general one.

---

## CORRECTION (2026-08-03, user) — the Q2 framing was WRONG

**The spike's verdict rested on "his `T` is an exogenous input, ours is an endogenous output". That
distinction is false**, and the user caught it.

Our own document (`## VOL ORDER COMPLETION`): *"The perpetual order specifies no `T`; `T★` is the
implied maturity of the equivalent dated variance contract — derived from `ΔQ_v★`, never stored"*,
with `T★ = 2ΔQ_v★/N_σ`. And `ΔQ_v★` is the **target vega — a first-class on-chain order field**
(`create_order(strike, width, skew, targetVega)`, `targetVega : u96`). **So `T★` IS user-controlled**,
indirectly through vega rather than directly. Both horizons are user-set.

The symmetry is closer still: Kristensen **truncates** a never-expiring position at `T` to price it
against a dated Black–Scholes option (p. 65); we derive `T★` as the implied maturity of an equivalent
dated **variance** contract. Both are **equivalence horizons converting a perpetual into a dated
instrument** — the same move, not two kinds of object.

**The real distinction, which is narrower:** his `T` is an *actual holding duration*; ours is an
*implied maturity that is never stored* and corresponds to no period anyone actually holds. So
`∫₀^{T★} ℙ[p_t ∈ range] dt` would integrate occupancy over a horizon that exists only as a pricing
equivalence. **Whether that is meaningful is the open question — the spike did not answer it.**

### What SURVIVES the correction

- **R4, untouched and still decisive against one reading.** A variance swap accrues over all of
  `[0,T]` regardless of band, so a band weight is the **finite-strip replication error**, not a
  maturity modifier — and the band indicator already lives in `Γ`/`Γ^Σ`. This never depended on the
  exogenous/endogenous claim. `T_ITM/T` is **ruled out as a modifier of the maturity law.**
- R1–R3 also stand *as arguments against the modifier reading* specifically.
- The extraction (definition, page anchors, objective-measure integrand), the `ℙ_{ITM}` reuse trap,
  and the CEV-generality observation are all unaffected.

### What is REOPENED — the composition direction

The user's note asked for `T_ITM/T` to be **connected to** our `T★` and for us to *"see what we can
leverage"* — not for it to replace the maturity law. That is a **composition**, and it is well-posed:

> With `T = T★ = 2ΔQ_v★/N_σ`, what is `T_ITM/T★`, and what does it buy?

Open sub-questions:
1. Is integrating an occupancy law over an **implied** maturity meaningful, given `T★` is never held?
   State the interpretation or refute it — this is the question that replaces the old Q2.
2. `T_ITM/T★` is then a function of the **target vega**. Does that give a usable statement — e.g. a
   monotone relation between the vega the user targets and the fraction of the equivalent contract's
   life spent in band?
3. Does it meet the already-identified FLAIR redirect (`T_ITM/T` as the measure of `{t : ν_t > 0}`)
   from the ε-side, i.e. is the composition the *same* object the IV research already placed there?

**Promotion criterion is unchanged**, but the gating question is now (1), not "is his `T` a maturity".
