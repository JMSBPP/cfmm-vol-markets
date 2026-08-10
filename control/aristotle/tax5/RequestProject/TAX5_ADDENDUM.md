# DRAFT — The price-shock input (M33–M35)

**The change.** The plant's exogenous input is no longer the quantity pair. `DOC` Definition 32
carries `u_ex = [ΔQ_X, ΔQ_M, σ²(i(t))]ᵀ`. The author rules that the driver is a **relative price
shock** `Δp/p`, and that `ΔQ` is a **response** — the quantity required to move the pool price to
the edge of the fee band, determined by the curve's price impact.

**This is not new coordinates for the MEV side.** `DOC` Definition 21 already compares a
volatility-driven price move against a fee band:

\[
\mathbb{P}_{\Delta_{\text{ARB}}}\bigl(\phi, \sigma, \Delta t\bigr) \; = \; \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
\]

— MMR Thm 1, *the long-run fraction of blocks in which an arb trade occurs*. `σ` is the shock
scale, `φ√(2/Δt)` the band. The change aligns the plant's input with what Definition 21 does.

**Three claims. All algebraic.** `H1`, `H2` and `ScaleHomogeneous` remain **typed hypotheses,
never proved**. **A refutation is a successful outcome** — all four prior bundles returned
refutations that redirected this project. **Do not narrow a claim to make it provable.**

---

## Standing bans — carried forward, unchanged

1. Never identify Capponi's curvature `κ` with the `ε_{X/M}` substitution axis — CES embedding
   **machine-refuted** (`canon_Fcap_not_CES`); only endpoints embed.
2. `η` is the **GRID-SIDE TILT** (`DOC:184`), not the trading-curve share; `κ_φ` depends on
   `ε_{X/M}` alone (`DOC` Proposition 7, `χ` cancels).
3. `π^{\varphi}` (portfolio value, `DOC:821`) ≠ `π^{\phi}` (fee revenue).
4. **The `dphidnu` slot is BARE.** `MevTaxProgram.hasDerivAt_phiTot` fixes it; the monoid Jacobian
   is carried separately in `pathGate`. `SRC` Proposition 13 was corrected accordingly. `SRC`
   Convention 9's **composed** `∂φ/∂ν` governs `Theorem 30` and `Theorem 32` only. **Both readings
   are live on one page — check which slot every claim uses.**
5. Cite prior results by **declaration name AND file**.

---

## **M33. [CLAIM] Under a shock driver, `ν` closes in observables**

**Theorem 45 (Shock-driven utilization) [M33].** Prove or refute: with the price shock as driver,

\[
\Delta Q \; = \; \bar L \cdot g\bigl(\Delta p/p,\; \phi,\; \kappa_{\varphi}\bigr)
\qquad\Longrightarrow\qquad
\nu \; = \; g\bigl(\Delta p/p,\; \phi,\; \kappa_{\varphi}\bigr)
\]

for the **arbitrage** component, with `κ_φ` the curvature of `DOC` Definition 14 (and `ε_{p/X}`,
its price-impact elasticity, declared there an **observable**). Hence `∂ν/∂φ` is a closed form and
**`ε` ceases to be an empirical primitive for the arb half.**

**State `g` explicitly** or show it cannot be written in these arguments.

**Consistency with bundle 3, mandatory.** `MevTaxChannels.Theorem39_arb_side_does_not_close`
proved `∂ΔQ^{ARB}/∂φ` does **not** close in `(σ, φ, Δt, ε_{p/X})`, the obstruction being
**dimensional** — a quantity against scale-free candidates. The factorization above is claimed to
**confirm** that result, not contradict it: `L̄` is the missing primitive, appearing explicitly.
Prove the two are consistent, or exhibit the conflict.

**Falsification targets.** Does `g` require a mispricing *distribution* rather than a realized
shock? Does it require an arb-capital constraint or a competition parameter? Does the benign
component admit any such factorization — it should **not**, since noise traders have no profit
function (`DOC` `[M8]`: *NO DEMAND ELASTICITY*), and a claim that it does is a red flag.

---

## **M34. [CLAIM] A shock driver makes the one-sided domain unreachable**

`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity` refuted `∂ν/∂ΔQ > 0` on a
**one-sided flow**: the operative Rule 5 member is identically zero, so `ν`'s numerator vanishes.
`MevTaxReturns.Corollary40c_one_sided_flow_leaves_no_root` then gives **no root at any tax**. The
flow-domain ruling **PR-REGION** (`DOC:423`) has been OPEN throughout and blocks four results.

**Theorem 46 (Shock-driven flow is two-legged) [M34].** Prove or refute: a trade induced by a
price shock is a **swap** — one leg in, one leg out, both nonzero — so the one-sided configuration
is **not reachable** from a shock driver. It arises from a one-sided *deposit*, which is not a
swap and is not in the plant's input.

If this holds, `Theorem 38(a)` recovers on the reachable domain and **PR-REGION is decided by the
input ruling rather than left open**.

**Be precise about signs.** Under a signed reading the legs have opposite signs and their product
is negative; under an unsigned reading both are positive. `DOC` Rule 5's geometric-mean member
requires a nonnegative product. **State which reading makes `ν` well-defined on shock-induced
flow**, and whether that is a further ruling rather than a consequence.

---

## **M35. [CLAIM] The two channels share a driver — is the fork real?**

`MevTaxChannels.Theorem38_two_routes_close_a_loop` established that route (i) (hazard) and route
(ii) (flow) are **independent paths**, that running both closes `φ → ΔQ → ν → φ`, and that the
total is `naive/(1 − loop)`. `MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` then
showed the loop-consistent FOC **removes `ε` entirely**, giving a different control law:

\[
\text{single channel:}\;\; \tau^{\star} = 1 + \frac{\phi}{(1-\phi_M)(\partial\phi_X/\partial\nu)\nu\epsilon}
\qquad
\text{loop:}\;\; \tau^{\star} = 1 + \frac{1-\phi_X}{(\partial\phi_X/\partial\nu)\,i}
\]

**Which model is operative is currently an unresolved fork**, and it decides whether `ε` is in the
problem at all, whether `Theorem 43`'s threshold elasticity is a real design number, and whether
`Theorem44_O2_closes` settles open item **O2** (the summary states `ε` does not appear under the
loop, so it cannot settle it there).

**Theorem 47 (Shared driver) [M35].** Prove or refute: under a price-shock input, routes (i) and
(ii) are driven by the **same primitive** — the shock creates the arbitrage opportunity (hence the
hazard, via `ℙ_{Δ_ARB}`) **and** determines the flow (hence `ν`). If so, they are **not
independent**, `Theorem 38`'s loop is a reformulation rather than a fork, and the two control laws
above are two readings of one object.

**Determine which of the two survives**, or show both are artifacts of treating a shared driver as
two inputs.

**This is the most valuable claim in the bundle.** A resolution here unblocks `Theorem 42`,
`Theorem 43` and `Theorem 44` — including the O2 closure, which has been load-bearing since
Phase 5.

**Falsification target.** Benign flow is *not* shock-driven — it has no profit function. So even
if the arb channels merge, a residual independent path may survive through benign flow. **If so,
say whether the loop correction applies to that residual alone**, and what its gain is.

---

## What a complete return looks like

- `Theorem 45` with `g` explicit, or a demonstration it cannot be written — **plus** the
  mandatory consistency proof against `Theorem39_arb_side_does_not_close`.
- `Theorem 46`, with the sign reading stated and any further ruling named.
- `Theorem 47`, with the surviving control law identified, or both shown to be artifacts.
- Every declaration `#print axioms`-clean or its dependency stated. **No new `sorry`.**
  A stated `OPEN` with a reason is preferred to a narrowed theorem.
