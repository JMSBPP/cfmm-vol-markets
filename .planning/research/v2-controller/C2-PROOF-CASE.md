# C2 PROOF-CASE — σ_xs variance-target → Δi⋆, end-to-end (SPEC-03)

> READ-ONLY design spec (2026-06-28). Pins the **single end-to-end proof case** for
> controller **C2** (cross-section variance target → tick-spacing actuator) across
> all four pipeline stages — **SymPy → Lean → Plank → gamsDiff** — on an
> already-proven inversion, so the implementation milestone can build it without
> further research. Scope: **static, tick-lattice, η = ½** (no dynamic/hook content).
>
> Sources (cited concretely below): `CONTROLLERS.md` (C2 entry),
> `TOOLING-CONTROL-DSL.md` (§4 SymPy→Lean→quantize→Plank→diff pipeline),
> `GAMS-MAP.md` (§4 gamsdiff bridge, conventions, tolerances),
> `STATIC-CONTROL-KERNEL-SPEC.md` (§7 integration target),
> `lean/exp/eta_sigma_xs_target_inversion.md` (the proven inversion),
> and `ON-CHAIN-REALIZATION.md` (the SPEC-02 fixed-point `sqrt` / signed-`mulDiv`
> primitive signatures the Plank stage consumes — authored in parallel by plan
> 10-01; cited by name here regardless of its presence on disk).

## The pipeline at a glance

C2 is the one example that exercises **every layer** of the control pipeline on a
single proven inversion:

1. **SymPy** — algebraic design: `solve(σ_xs,poly = σ_target → Δi)` gives the exact
   closed-form positive root; exact `Rational` arithmetic quantizes deterministically
   to WAD 1e18 / Q64.96 (the GAMS role: algebraic derivation + reference oracle).
2. **Lean** — proof authority: theorem `sigma_xs_poly_target_exists` (`eta.lean:560`)
   machine-proves existence and strict positivity of the root under the feasibility
   preconditions. SymPy's closed form must *equal* this proven statement.
3. **Plank** — fixed-point evaluation: evaluate the root on the EVM with one
   fixed-point `sqrt` (for `disc`) + a few `mulDiv`, under the saturate-never-revert
   obligation (consumes the SPEC-02 `sqrt` from `ON-CHAIN-REALIZATION.md`).
4. **gamsDiff** — differential test: a `gamsDiff`-style fixture
   `{inputs (n, d, σ_target), reference Δi⋆}` from the SymPy exact-rational
   reference; `forge --via-ir` runs the Plank evaluation over the same inputs and
   asserts equality within a **stated tolerance**.

The division of labour mirrors `TOOLING-CONTROL-DSL.md` §3–4: **GAMS = numeric
ground truth, Lean = machine-checked proof, SymPy = algebraic design + reference
oracle, Plank = fixed-point evaluator**, closed by the `gamsDiff`/`forge --via-ir`
fixture at the project's EPS tolerance.

---

## Feasibility preconditions

The controller is defined only where its proof holds. Both preconditions are stated
exactly as proven in `lean/exp/eta_sigma_xs_target_inversion.md` and catalogued in
`CONTROLLERS.md` (C2 entry):

- **`n ≥ 2`** — the polynomial's leading coefficient `c₂ = n(n-1)(2n-1)/6` is then
  strictly positive, so `σ_xs,poly` is an upward parabola in `Δi` with at most two
  real roots and a well-defined positive branch.
- **STRICT `σ_target > d²`** — with `d := i₋ - i_μ`. This is the **Aristotle-narrowed**
  precondition: the original request used the non-strict `d² ≤ σ_target`, but
  Aristotle tightened it to the strict bound because the non-strict bound lets the
  positive root **collapse to `Δi = 0`** (e.g. `d = 0, σ_target = 0`, or any `d < 0`
  with `σ_target = d²`). At equality the discriminant equals `c₁²` exactly and
  `√disc = |c₁|` can leave the numerator `c₁ + |c₁| = 0` in the `d ≤ 0` cases. The
  strict bound is the right separation between feasible and degenerate.

**`#` decoupling caveat (gap G3).** C2 is proven for `sigma_xs_poly` with the tick
count `#` = `n` held **FREE** (decoupled from the `sharp` floor). It is therefore
valid only on a Δi-interval where the tick count `#` is **constant**. Lifting the
existence result to the full `sigma_xs` (where `# = ⌊(i₊ − i₋)/Δi⌋` is floor-coupled
to `Δi`) is an open gap (G3 in `CONTROLLERS.md` / `STATIC-CONTROL-KERNEL-SPEC.md` §6).
For protocol-level set-point control over a fixed tick grid, the `_poly` form is the
right object.

---

## Stage 1 — SymPy derivation + exact-rational quantization

**The polynomial.** With `#` = `n` free, the cross-section variance reduces to a
quadratic in `Δi` (verbatim from `lean/exp/eta_sigma_xs_target_inversion.md`):

```
σ_xs,poly(n, d, Δi) = d² − Δi·d·n(n−1) + Δi²·n(n−1)(2n−1)/6
```

i.e. `c₂·Δi² + c₁·Δi + c₀` with the coefficients

```
c₂ = n(n−1)(2n−1)/6        (leading; > 0 iff n ≥ 2)
c₁ = −d·n(n−1)
c₀ = d²
d  := i₋ − i_μ
```

**The closed-form root (positive branch).** Solving `σ_xs,poly = σ_target` for `Δi`
gives the exact positive root (verbatim from `CONTROLLERS.md` C2 and
`eta_sigma_xs_target_inversion.md`):

```
Δi⋆(n, d, σ_target) = (d·n(n−1) + √disc) / (n(n−1)(2n−1)/3)

disc = c₁² − 4·c₂·(d² − σ_target)
```

with `c₂ = n(n−1)(2n−1)/6` and `c₁ = −d·n(n−1)`. The denominator
`n(n−1)(2n−1)/3 = 2·c₂` is the `2·c₂` of the standard quadratic formula
`Δi⋆ = (−c₁ + √disc)/(2·c₂)`. Under the strict precondition `σ_target > d²` the
`−4·c₂·(d² − σ_target)` term is strictly positive, so `disc` **strictly** exceeds
`c₁²`, giving `√disc > |c₁| ≥ c₁` and hence a **strictly positive** root.

**The SymPy recipe** (cite `TOOLING-CONTROL-DSL.md` §4, the concrete 5-step workflow):

1. **Derive.** In a `uv run` SymPy script, declare `n, d, Δi, σ_target` as symbols
   and call

   ```python
   solve(sigma_xs_poly(n, d, Δi) - σ_target, Δi)
   ```

   This reproduces the two roots; select the `+√disc` (positive) branch above.
   `solve` is exactly the set-point inversion SymPy is best at (`TOOLING-CONTROL-DSL.md`
   §2, rank 1).
2. **Cross-check against Lean.** The closed form returned by `solve` must equal the
   proven `sigma_xs_poly_target_exists` statement — SymPy is the **computational
   check**, Lean is the **proof authority** (see Stage 2). GAMS remains the numeric
   ground-truth side where the problem is an actual optimization rather than an
   inversion.
3. **Keep exact rationals.** Carry every coefficient and the root as exact
   `Rational` (SymPy `Rational`/`nsimplify`) — no float collapse. This is what makes
   the downstream quantization **deterministic and auditable**, exactly the
   GDX→fixture→`gamsdiff` pattern this repo already runs at **EPS ≈ 1e-15**.
4. **Quantize deterministically.** From the exact rationals, quantize to the on-chain
   fixed-point scales used by the bridge (`GAMS-MAP.md` §4):
   - **WAD = 1e18** (`unity`) for `σ_target`, `d`, and the dimensionful inputs;
   - **Q64.96** (`2^96 = 79228162514264337593543950336`) for any sqrt-price-domain
     quantity.
   Quantize by exact integer rounding of the rational (`numer·SCALE // denom`,
   round-toward-zero), so the reference is reproducible bit-for-bit.
5. **Emit the constant table.** Use `cse` (common-subexpression elimination) +
   `ccode` to emit the `n`-dependent integer constants `c₁, c₂` and the denominator
   `n(n−1)(2n−1)/3` as an auditable constant/kernel table for the Plank evaluator
   (the `n`-dependent coefficients are integer constants — computable on-chain or
   shipped).

SymPy is the **design / computational-check** engine; it does **not** replace the
Lean proof — it produces the exact constants Lean's theorem certifies as a feasible,
positive root.

---

## Stage 2 — Lean existence / positivity

**Proven theorem:** `sigma_xs_poly_target_exists` at **`eta.lean:560`**
(`lean/exp/eta_sigma_xs_target_inversion.md`; `CONTROLLERS.md` C2). It guarantees,
under the feasibility preconditions above:

```
For n ≥ 2,  d² < σ_target :
    ∃ Δi > 0 :  σ_xs,poly(n, d, Δi) = σ_target
```

i.e. **existence and strict positivity** of the `Δi⋆` root. The proof takes the
positive branch via the quadratic formula and discharges the equation by
`linear_combination`; the strict `σ_target > d²` bound is what forces
`√disc > |c₁|`, hence `Δi⋆ > 0` rather than `Δi⋆ = 0`.

**SymPy must equal Lean.** The Stage-1 closed form (the `+√disc` branch) must equal
this proven statement — Lean is the proof authority, SymPy the computational check.
Anywhere they disagree is a SymPy/derivation bug, never a license to weaken the
theorem.

**Numeric ground-truth side.** The GAMS σ identity recorded in
`eta_sigma_xs_realized_connection.md` (the cross-section identity
`σ_xs = #·σ_realized − (#−1)d² − 2d·Δi·#(#−1)`, proven as
`sigma_xs_eq_sharp_mul_sigma_realized`, see C9 in `CONTROLLERS.md`) is the numeric
ground-truth side that the realized variance C2 drives — it ties the abstract
`σ_xs,poly` back to the lattice-realized variance.

**Plank ↔ Lean tick convention.** As with C1 (`CONTROLLERS.md`,
`pi_trader_half_zero_at_deltaI_star`), the Plank coordinate carries a factor-of-two
tick convention: where it applies, **`Δi⋆_Plank = 2·Δi⋆_Lean`**. The Plank evaluator
(Stage 3) and the gamsDiff fixture (Stage 4) must apply this convention consistently
so the EVM result and the Lean/SymPy reference are compared in the same coordinate.

---

## Stage 3 — Plank fixed-point evaluation

The on-chain evaluation computes `Δi⋆` directly from the closed form. Per
`CONTROLLERS.md` (C2 "EVM cost & primitives"), the cost is **one fixed-point `sqrt`
(`disc`) + a few `mulDiv`**:

- **Primitives consumed (SPEC-02).** The evaluation **consumes the SPEC-02
  fixed-point `sqrt`** for `√disc`, plus a few `mulDiv` (512-bit) and the
  **signed** fixed-point `mulDiv` for the `c₁ = −d·n(n−1)` term (`d` may be
  negative). These primitive signatures are specified in **`ON-CHAIN-REALIZATION.md`**
  (SPEC-02, authored in parallel by plan 10-01) — reference that doc for the exact
  `sqrt` / signed-`mulDiv` signatures. The fixed-point `sqrt` is realizable from the
  `tick_math` MSB machinery (`CONTROLLERS.md` C2 status; gap G5 in
  `STATIC-CONTROL-KERNEL-SPEC.md` §6).
- **Constants.** The `n`-dependent coefficients `c₁`, `c₂`, and the denominator
  `n(n−1)(2n−1)/3` are **integer constants** — either computed on-chain from `n`
  (cheap integer arithmetic) or shipped from the Stage-1 `cse`+`ccode` table.
- **Saturate-never-revert obligation** (the hard rule from
  `EVM-CONTROL-PRIMITIVES-MAP.md`, restated in `CONTROLLERS.md` framing and
  `STATIC-CONTROL-KERNEL-SPEC.md` §4): a reverting hook DoSes the swap, so the
  evaluator must **saturate, never revert**. Concretely:
  - **guard `disc ≥ 0` before the `sqrt`** (feasibility precondition violated ⇒ clamp,
    do not revert);
  - **clamp the result into the admissible `int24` Δi band** (the GAMS-side band is
    `Δi ∈ [1, 200]`; the lattice/fixtures use spacing `Δi ∈ {1..60}`, fixtures at
    `Δi = 1`) rather than returning an out-of-range or reverting value.
- **Coordinate.** Apply the `Δi⋆_Plank = 2·Δi⋆_Lean` tick convention (Stage 2) so the
  on-chain output is in the same coordinate as the reference it is diffed against.

---

## Stage 4 — gamsDiff fixture equality

The differential-test contract closes the loop (cite `TOOLING-CONTROL-DSL.md` §4
step 5, and `GAMS-MAP.md` §4 conventions/tolerances):

- **Fixture.** A `gamsDiff`-style fixture `{inputs (n, d, σ_target), reference Δi⋆}`
  produced from the **SymPy exact-rational reference** (Stage 1), serialized as
  JSON/CSV (the same GDX→fixture pattern the repo runs for the pricing / price-impact
  kernels).
- **Runner.** `forge --via-ir` deploys the Plank evaluator harness and runs it over
  the **same inputs**, then compares the on-chain `Δi⋆` to the fixture reference.
- **Tolerance (stated explicitly).** Two tolerances, both justified:
  - **Reference tolerance: EPS ≈ 1e-15 relative** (the repo's diff EPS = `1e3` =
    `1e-15` relative in `assertApproxEqRel`, `GAMS-MAP.md` §4) for the exact-rational
    SymPy reference — this is the tight bound the existing pricing/price-impact diffs
    already meet (`max_rel_error ≈ 2.02e-16`, ~5× headroom).
  - **Fixed-point tolerance: a wider band for the Plank quantized result.** The Plank
    evaluation accumulates **round-toward-zero** error across the `mulDiv` /
    fixed-point `sqrt` chain (one `sqrt` + several `mulDiv`), so its quantized output
    can deviate from the exact rational by more than 1e-15. State and justify a wider
    tolerance (e.g. a small ULP-budget proportional to the number of round-toward-zero
    operations in the `disc → √disc → /(2c₂)` chain) as **round-toward-zero
    accumulation**, not as a correctness failure.
- **Pass condition.** **Equality within the stated tolerance** is the pass condition:
  `assertApproxEqRel(Δi⋆_Plank, Δi⋆_reference, tol)` row-by-row over the fixture
  inputs, with `tol` the fixed-point band above and the reference itself validated at
  EPS ≈ 1e-15 against the exact rational.

---

## Pipeline summary

| Stage | Tool | Artifact | Check |
|-------|------|----------|-------|
| 1 | **SymPy** (BSD-3, via MCP) | exact-rational `Δi⋆` closed form + `c₁,c₂` constant table (`cse`/`ccode`); WAD/Q64.96 quantization | `solve(σ_xs,poly − σ_target, Δi)` reproduces the positive root |
| 2 | **Lean** (`eta.lean:560`) | theorem `sigma_xs_poly_target_exists` | ∃ Δi⋆ > 0 with σ_xs,poly = σ_target, for `n ≥ 2`, strict `σ_target > d²` |
| 3 | **Plank** | fixed-point evaluator: 1 `sqrt` (`disc`) + few `mulDiv` | guard `disc ≥ 0`, clamp to int24 Δi band, **saturate-never-revert**; consumes SPEC-02 `sqrt` (`ON-CHAIN-REALIZATION.md`) |
| 4 | **gamsDiff** (`forge --via-ir`) | fixture `{n, d, σ_target → Δi⋆}` | `assertApproxEqRel` within tolerance (ref EPS ≈ 1e-15; wider fixed-point band for round-toward-zero accumulation) |

---
*SPEC-03 proof case for controller C2. Integration target: `STATIC-CONTROL-KERNEL-SPEC.md` §7.*
