# DRAFT — The transactional channel (M36–M40)

**The change, ruled by the author.** The model gains a second exogenous shock: a **private
valuation shock `V`**, independent of the price shock, carried by benign (non-toxic,
transactional) traders. Their payoff object is denoted **`π^{transactional}`**. Everything stays
in **shock space**: no volume function is parametrized; participation is a shock crossing a
protocol-set band, exactly as `ℙ_{Δ_ARB}` already is.

**The measure connection, ruled by the author.** The transactional probability measure carries a
**`1 − ℙ_{Δ_ARB}` structure**: benign execution lives on the complement of the arb event. The
per-block event algebra, under `V ⊥ (Δp/p)`:

\[
\mathbb{P}_{\text{arb}} = \mathbb{P}_{\Delta_{\text{ARB}}},
\qquad
\mathbb{P}_{\text{trans}} = \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\cdot h(\phi),
\qquad
\mathbb{P}_{\text{idle}} = \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\cdot\bigl(1-h(\phi)\bigr)
\]

with `h(φ) ≡ ℙ(|V| > band(φ))` the **valuation-shock participation probability**. Under an
exponential tail with rate `α`, `h(φ) = e^{−αφ}` — the literature's Form A hazard
(`arXiv:2606.21769` §2.4, `arXiv:2506.02869` §2) **is** a shock-space participation probability,
and `α` is the tail rate of the valuation distribution. **Elasticity appears nowhere as a
primitive**; `ε(φ) = −αφ` is derived and fee-dependent.

**Why this exists.** `MevTaxShock.Theorem47_shared_driver_leaves_no_root` proved the FOC has no
root at any tax because both channels shared one driver, and
`Theorem47_benign_residual_is_not_an_exogenous_path` proved benign flow entered the loop gain
rather than the exogenous input. The valuation shock is the second, genuinely independent edge.
Published confirmation of the degeneracy: `arXiv:2606.21769` Prop. 4.1 — with `α = 0` the
objective is negative everywhere and increasing, the optimum is the boundary; §6.2 — *"The
aggregate demand response D restores strict concavity … and rules out the degenerate bang-bang
equilibrium that arises when total uninformed volume is treated as fixed."*

**New typed assumptions** — same class as `H1`/`H2`/`ScaleHomogeneous`, assumed by name, never
proved, never estimated:

- **(A-ind)** `V ⊥ (Δp/p)` — the independence. This is the load-bearing one.
- **(A-tail)** `V`'s tail is exponential with rate `α > 0` (so `h(φ) = e^{−αφ}`). The register
  records that **no causal estimate of `α` exists** (`RESEARCH-REGISTER.md` @ `5f7f3d8`, S-21/S-22
  and the two identification-failure papers); any threshold verdict rests on a chosen number.
- **(A-size)** benign trade size `δ > 0` is exogenous — the rate responds to the fee, the size
  does not (the literature's uniform choice; the opposite of `arXiv:2512.19838`, noted).
- **(A-route)** per the adopted monoid entry (A): **the `τ` share of the composed fee is NOT
  routed to LPs** — `NO compensation routed`. LPs accrue leg fees only (`DOC` Rule 6).

**A refutation is a successful outcome.** All five prior bundles returned refutations that
redirected this project. Do not narrow a claim to make it provable; exhibit the witness.

---

## Standing bans — carried forward, unchanged

1. Never identify Capponi's `κ` with the `ε_{X/M}` axis (`canon_Fcap_not_CES`; endpoints only).
2. `η` is the **grid-side tilt** (`DOC:184`); `κ_φ` depends on `ε_{X/M}` alone (`DOC` Prop. 7).
3. `π^{\varphi}` (portfolio value) ≠ `π^{\phi}` (fee revenue); and now ≠ `π^{transactional}`
   (benign traders' payoff — a **trader-side** object, not an LP-side one).
4. **The `dphidnu` slot is BARE** (`MevTaxProgram.hasDerivAt_phiTot`); `SRC` Convention 9's
   composed `∂φ/∂ν` governs `Theorem 30`/`Theorem 32` only. Check which slot every claim uses.
5. Cite prior results by **declaration name AND file**.
6. **Isoelastic demand `Q ∝ φ^{−ε}` is banned as a specification** — it is monotone, cannot
   produce an interior optimum, and appears nowhere in the literature. The hazard `h` is the only
   admissible demand object.

---

## **M36. [CLAIM — THE MEASURE] The complement structure completes Proposition 9**

**Theorem 48 (Transactional measure) [M36].** Under (A-ind), prove:

(a) the three block events above partition, with `ℙ_trans = (1−ℙ_{Δ_ARB})·h(φ)`;

(b) this **completes `DOC` Proposition 9's split**: the per-block expected LP income gains the
    term `MMR` eq. (27) leaves unspecified,

\[
\text{NT\_FEE}(\phi) \; = \; \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}(\phi,\sigma,\Delta t)\bigr)\; h(\phi)\; f_{\text{LP}}(\phi)\;\delta
\]

with `f_LP` the **LP-accrued** fee under (A-route) — the leg share, `τ`'s share excluded;

(c) **the comparison**: state precisely how the FOC differs between the complement-conditioned
    measure above and the unconditional alternative `ℙ_trans = h(φ)` (benign trades execute in
    arb blocks too). `(1−ℙ_{Δ_ARB})` is **increasing** in `φ` — determine what that second
    channel does to the root and **which reading is consistent with Proposition 9's accounting**
    (the split must not double-count the arb block's flow). Do not pick silently; derive both.

(d) `π^{transactional}` — the benign trader's own expected payoff,
    `(1−ℙ_{Δ_ARB})·E[(|V| − band(φ))⁺ | participation]·δ` or the form you derive — is
    **well-defined in shock space** and strictly decreasing in `φ`.

---

## **M37. [CLAIM — THE CURE] The loop gains an exogenous input**

**Theorem 49 (The second edge) [M37].** Prove: under (A-ind), the transactional channel is a
**genuinely independent edge** — the loop system of
`MevTaxChannels.Theorem38_two_routes_close_a_loop` acquires exogenous input `i ≠ 0` driven by
`(ν₀, α, V)`, and `MevTaxShock.Theorem47_shared_driver_leaves_no_root`'s conclusion **fails in
the extended model**: the FOC `P·(1−loop) = RHS` has `RHS ≠ (1−φ_M)(1−φ_X)` and admits a root.

State exactly which of `Theorem 47`'s hypotheses is relaxed (it should be
`Theorem47_no_exogenous_hazard_input`'s premise, and nothing else), so the two results stand
side by side rather than contradicting.

---

## **M38. [CLAIM — THE INTERIOR OPTIMUM] Existence, uniqueness, the two conditions**

Per-block LP objective, eq.-(27) form:

\[
m(\phi;\sigma^2) \; = \; \text{NT\_FEE}(\phi) \; - \; \frac{\sigma^2\Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}}(\phi,\sigma,\Delta t)
\]

**Theorem 50 (Interior tax) [M38].** Prove or refute, on the carrier `φ ∈ [0,1)` with the monoid
`1−φ = (1−φ_M)(1−φ_X)(1−τ)`:

(a) **Profitability condition**: an interior maximiser exists iff `sup_φ m(φ;σ²) > 0`, and it is
    unique under (A-tail);

(b) the analogue of `φ* > 1/α` on our carrier, stated exactly;

(c) **the top-up law**: with `φ_base = 1−(1−φ_M)(1−φ_X)`,

\[
\tau^{\star} \; = \; \frac{\phi^{\star} - \phi_{\text{base}}}{1 - \phi_{\text{base}}},
\qquad
\tau^{\star} \in (0,1) \;\Longleftrightarrow\; \phi_{\text{base}} < \phi^{\star}
\]

— **the tax is the top-up** from the leg fees to the optimal composed fee, and `τ* = 0` is the
honest answer when the base fee already covers `φ*`;

(d) **pro-cyclicality**: `∂φ*/∂σ > 0` (the arb loss scales with `σ²`, `NT_FEE` does not), hence
    `τ*` is increasing in volatility — the on-chain controller is a volatility feedback;

(e) the **corner taxonomy**: `τ* = 0` (base fee sufficient), interior (both conditions), and the
    shutdown regime where `m < 0` everywhere (no fee is profitable — state what the constrained
    optimum on `[0,1)` is there, and do not present it as an optimum of anything but losses).

---

## **M39. [QUESTION — INCIDENCE] The no-routing FOC**

Every paper in the sweep has the fee-setter keep the revenue. Under (A-route) ours does not:
raising `τ` widens the band (deters arbs — the benefit is **LVR retention**, and it survives)
and shrinks `h` (benign attrition — the cost survives), but the marginal tax revenue on benign
trades goes elsewhere.

**Theorem 51 (Incidence) [M39].** Derive the FOC under (A-route) and under the counterfactual
full-routing (`f_LP = φ`), and determine:

(a) whether the interior root survives no-routing (the trade-off has both sides, so it should —
    but derive it);

(b) the **sign and magnitude of the shift** `τ*_no-route − τ*_route`. **No sign is asserted by
    the author** — this is the question, and it has been wrong before when reasoned rather than
    checked;

(c) whether `∂m/∂τ` under no-routing picks up a **discontinuous** term at `τ = 0` (the first
    unit of tax destroys benign surplus without compensating revenue — or does it?).

---

## **M40. [CLAIM — SECOND ORDER] O2 in the extended model**

`MevTaxShock` recorded O2 as **resolved-empty** — no interior stationary point to classify. The
extended model restores one.

**Theorem 52 (Second order) [M40].** At `Theorem 50`'s interior root: prove strict concavity of
`m` (hence the root is a **maximum of LP PnL** — note the objective here is `m`, not
`Definition 36`'s squared-derivative form, and `Theorem44_objective_reading_does_not_discriminate`
already showed the squared form cannot distinguish), state the single-crossing property
explicitly, and record what (A-tail) contributes versus what survives for a general
log-concave `h`. If uniqueness fails for some admissible `h`, exhibit it.

---

## What a complete return looks like

- `Theorem 48` (a)–(d), with the (c) comparison derived both ways and the accounting-consistent
  reading identified.
- `Theorem 49`, naming the exact relaxed hypothesis.
- `Theorem 50` (a)–(e) — the top-up law and pro-cyclicality are the controller.
- `Theorem 51` with the shift signed **by derivation**.
- `Theorem 52`, with the (A-tail)-vs-log-concave split stated.
- Every declaration `#print axioms`-clean or its dependency stated. **No new `sorry`.** A stated
  `OPEN` with a reason beats a narrowed theorem.
