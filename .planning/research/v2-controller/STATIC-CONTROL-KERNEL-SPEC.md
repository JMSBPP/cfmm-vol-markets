# Static Control Kernel — Design Basis

**Milestone:** EVM-controller v2.0 (research / design-spec, NOT implementation).
**Status:** CONTENT-COMPLETE — SPEC-01/02/03 are now concrete. The consolidated design
basis (SPEC-01) integrates research/theory/catalog/tooling; §4 folds in the concrete
on-chain realization ([`ON-CHAIN-REALIZATION.md`](./ON-CHAIN-REALIZATION.md), SPEC-02)
and §7 folds in the C2 end-to-end proof case
([`C2-PROOF-CASE.md`](./C2-PROOF-CASE.md), SPEC-03). The **single remaining gate is the
mandatory two-step review (SPEC-04: Reality Checker + Solidity Smart Contract
Engineer)**, which is **DEFERRED by user choice (2026-06-28)** and owed before any
execution commit.
**Branch:** `feat/evm-controller` (worktree `../cfmm-wt/evm-controller`); ships via PR→`develop`.

This document integrates the seven research artifacts in this directory into a
single design basis for an on-chain (EVM/Plank) controller that operates
**statically on the tick lattice**. It is the GAMS/Lean analog deliverable: the
resources, theory, controller list, and tooling needed to *design* the controller —
deliberately stopping short of implementation.

Sources: `MAPPING-SYNTHESIS.md`, `PROJECT-MAP.md`, `LEAN-MAP.md`, `GAMS-MAP.md`,
`EVM-CONTROL-PRIMITIVES-MAP.md`, `CONTROLLERS.md`, `LIT-CFMM.md`,
`LIT-LATTICE-CONTROL.md`, `TOOLING-CONTROL-DSL.md`.

---

## 1. Scope and layering

In KERNEL.md terms the system layers as: static kernels (`P_X(Δi;i)=λ^{iΔi}`,
`ℓ(ξ,ι;i)`, CES payoffs, vol term structure `σ`) → adaptive fee policy `φ(·;t)` →
the top goal `inf_Θ C_φ^π = d(π, Υ^φ)`.

**In scope (this milestone): the first box only.** Fixed pool liquidity `L̄`, a
representative agent, η = ½. The "controller" is static **algebraic inversion over
the tick lattice** `i ∈ [−120,120]` (state grid k1..k241, λ=1.0001): choose a
structural parameter so a kernel-level target is hit. The iteration index is
**spatial (the tick / binomial lattice), not time.**

**Out of scope (deferred):** the time-indexed adaptive fee policy `φ(·;t)`, any
feedback loop, the V4 `beforeSwap` hook, the stochastic order-flow process as a
*driver*, and general η≠½ (kept as a documented generalization path).

## 2. Theoretical frame (recommended)

**Control of spatially-invariant systems over the tick lattice, diagonalized by the
lattice DFT (Bamieh–Paganini–Dahleh), realized financially as Carr–Madan /
Breeden–Litzenberger static spanning over the grid** (see `LIT-LATTICE-CONTROL.md`).

Why it fits every constraint:
- The iteration index is genuinely **spatial** — the controller is by construction
  a function over the tick coordinate.
- **DFT decoupling pushes all synthesis off-chain**: per-wavenumber constant gains /
  uncoupled Riccati (arXiv:1111.1498 poset-Riccati; arXiv:2509.09269 closed-form
  spatially-invariant feedback).
- The **on-chain step collapses to one fixed banded Toeplitz/circulant
  matrix-vector product** — no solver, no `pow`/`log`, matching the EVM.
- The already-proven Lean static inversions slot in as **the per-position set-point
  entries** of that operator.
- Static replication theory (AEC *Replicating Market Makers* Fenchel duality,
  Carr–Madan spanning, arXiv:2403.14231 piecewise-linear grid bases) gives the
  payoff↔curve map that defines the operator's targets.

## 3. The controllers (from `CONTROLLERS.md`)

Ten candidates, each a static target→actuator map over the lattice (η=½):

| ID | Target | Actuator | Source | Status |
|----|--------|----------|--------|--------|
| C1 | π→0 (zero-slippage) | Δi⋆=log(L̄/(L̄−Δᴵ))/(logλ·i) | `eta_pi_trader_zero_slippage` | PROVEN, EVM-ready (log-free ratio) |
| C2 | σ_xs → σ_target | Δi⋆ (quadratic root) | `sigma_xs_poly_target_exists` | PROVEN (`_poly`); needs fixed-point sqrt; full-σ_xs lift = G3 |
| C3 | min trader payoff (large trade) | Δi=Δi_min | band-min | PROVEN, cheapest (clamp), EVM-ready |
| C4 | variance-swap endpoint | Δi=Δi_max | band-max | PROVEN large-trade + sub-golden; G4 hump |
| C5 | small-signal gain | π/Δᴵ²→P²(P−1)² | `pi_trader_half_small_trade` | PROVEN, EVM-ready |
| C6 | argmin payoff | 3-point parabolic | GAMS-validated ≡ NLP argmin | EVM-portable |
| C7 | generic-η on ½-kernel | P_η(i)=P½(i₋)P½(i₊) | `eta_split_kernel_identity` | PROVEN, generalization path |
| C8 | (η,Δi) identifiability | dual-knob constraint | `eta_Δi_independent…` | PROVEN (structural) |
| C9 | realized variance | lattice rollback → closed form | `sigma_xs_realized` | PROVEN, EVM-ready |
| C10 | stochastic swap-flow ref | BinomialProxy + SwapAmtGen | — | STUB (gap G1) |

**Proven-and-EVM-ready: C1, C3, C5, C7, C9** (C2 once a fixed-point sqrt is wired;
C4/C6 with regime caveats).

## 4. EVM realization (from `EVM-CONTROL-PRIMITIVES-MAP.md`)

> **Authoritative detail: [`ON-CHAIN-REALIZATION.md`](./ON-CHAIN-REALIZATION.md) (SPEC-02).**
> That sibling doc fixes the exact matvec layout, the exact per-position set-point
> formulas, the exact G5 primitive signatures, and the exact int24 bounds / rounding
> modes per controller. This section carries the headline facts and cross-references
> it; the implementation milestone builds from SPEC-02, not from this survey.

**The on-chain object — one banded matvec.** The controller is a single fixed,
shift-invariant linear law evaluated once per call as a banded matrix–vector product:

```
u = -K x ,   K[i,j] = kappa(i - j)        # Toeplitz: gain depends on lattice offset only
```

over the integer tick lattice `i ∈ [−120,120]` (241 nodes, λ=1.0001). Exponential
spatial tap decay (Bamieh–Paganini–Dahleh; `LIT-LATTICE-CONTROL.md` §A1) justifies
**banding to `n = 2b+1 ≤ 3–4` taps per row**; on a wrapped grid `K` is **circulant**,
diagonalized by the lattice DFT so all synthesis is pushed off-chain. Cost is `n²`
`mulDiv` + `n²` signed adds (~9 `mulDiv` for `n=3`) — no `pow`/`log`, no solve. The EVM
is an **evaluator of a precompiled constant-gain operator**: `A,B,K` are compile-time
constants precomputed off-chain in GAMS/SymPy, never solved on-chain.

**Per-position set-points (the proven inversions are the operator entries).** The
EVM-ready controllers contribute the closed-form set-point that each lattice node is
driven to. Proven-and-EVM-ready set: **C1, C3, C5, C7, C9**; **C2** once the G5
fixed-point `sqrt` is wired (see §3 and the SPEC-02 set-point table for the exact
formulas, e.g. C1 `P_½ = L̄/(L̄−Δᴵ)` via one `mulDiv`, C2 quadratic root, C3 band-floor
clamp, C9 closed-form aggregator). The Plank coordinate bridge `Δi⋆_Plank = 2·Δi⋆_Lean`
(C1) must be applied before the int24 admissibility check.

**Three G5 primitives to build** (do not exist in Plank today; signatures in SPEC-02):

- **`sqrt(x)`** — fixed-point square root for C2's `disc`; built on the `tick_math` MSB
  machinery, round toward zero.
- **`signedMulDiv(a,b,denom)`** — signed fixed-point mul/div over magnitudes via the
  512-bit `mulDiv`, sign by XOR of operand signs. The **#1 correctness hazard** (states
  and gains are signed; unsigned `mulDiv` silently wraps two's-complement).
- **`clamp(x,lo,hi)` / `satAdd(x,y)`** — signed clamp and signed-saturating add (only
  unsigned `min/max` + revert-on-overflow casts exist today).

**Hard rule — saturate, never revert.** A reverting `beforeSwap` hook DoSes the swap,
so every set-point and every matvec accumulation must **saturate, never revert**:
clamp before any value can overflow (`*%` wraps, `*` reverts; `CESLongPayoff.plk:42`
documents a real `~2^192` trap), guard any controller-derived denominator against 0
before `mulDiv`, and keep **one consistent WAD scale with a divide-by-WAD per multiply**
(a dropped `/WAD` is a silent 1e18-per-multiply scale blow-up).

**int24 bounds + rounding.** Every emitted tick/spacing lands in int24
(`MIN_TICK=−887272`, `MAX_TICK=887272`, `src/lib/TickUtils.plk`); admissible spacing
band `Δi ∈ [1,200]` (GAMS abort guard), fixtures `Δi=1`. Round **toward zero** for `</`
and `mulDiv`; keep intermediate scale high (Q96/Q128) and downcast once.

**Scope pin.** η = ½ only — **C7 is the documented η-split generalization path** (valid
for any `η ∈ (0,1)` provided `i₋,i₊` stay int24), not dynamic content. Liquidity-kernel
weights are the raw ramp `ξ^i` (Σ≠1) under ι=1 — do not assume normalization.

## 5. Toolchain (from `TOOLING-CONTROL-DSL.md`)

| Stage | Tool | Role |
|-------|------|------|
| Numeric ground truth | **GAMS** | optimization reference values |
| Proof | **Lean** | machine-checked static inversions |
| Control design (algebraic) | **SymPy** (BSD-3, already via MCP) | closed-form inversion (`solve`), exact-rational WAD/Q64.96 quantization, reference oracle |
| Control synthesis (matrix) | **Julia `Symbolics.jl`+`ControlSystems.jl`** (MIT) | DFT per-wavenumber gains / discrete Riccati; `build_function` C oracle |
| On-chain evaluation | **Plank** | fixed-point matvec + set-points |
| Closing the loop | `gamsDiff`-style fixture diff under `forge --via-ir` | EVM ↔ reference equality |

No tool emits fixed-point Solidity; export **verified constants/gains** that quantize
cleanly. Drake (`FittedValueIteration`) and Maxima (`solve_rec`) are bench
specialists for the deferred dynamic layer.

## 6. Open gaps

- **G1** stochastic swap-flow ground truth (no GAMS reference; Plank stubs only).
- **G2** general-η impact / CES payoff (needs fixed-point `pow` or linearization).
- **G3** lift σ_xs inversion from `_poly` (n free) to a Δi-interval where `#` is constant.
- **G4** band-max interior hump (0.618 sliver).
- **G5** fixed-point realization: signed `mulDiv`, `sqrt`, clamp.
- **G6** liquidity-kernel ξ/ι (normalization + actuator semantics).

## 7. Proposed proof case for a first static controller

> **Authoritative detail: [`C2-PROOF-CASE.md`](./C2-PROOF-CASE.md) (SPEC-03).**
> That sibling doc pins the full four-stage pipeline, the verbatim polynomial / root,
> the feasibility preconditions, and the stated diff tolerances. This section names the
> case and cross-references it.

**C2 (σ_xs variance-target → Δi⋆)** is the single end-to-end proof case — it exercises
**every layer** of the control pipeline on one already-proven inversion, across **four
stages**:

1. **SymPy** — algebraic design: `solve(σ_xs,poly − σ_target, Δi)` gives the exact
   closed-form positive root; exact `Rational` arithmetic quantizes deterministically
   to WAD 1e18 / Q64.96 and emits the `c₁,c₂` constant table (`cse`/`ccode`).
2. **Lean** — proof authority: theorem `sigma_xs_poly_target_exists` (`eta.lean:560`)
   machine-proves existence and strict positivity of the `Δi⋆` root; the SymPy closed
   form must *equal* this proven statement.
3. **Plank** — fixed-point evaluation: one G5 fixed-point `sqrt` (for `disc`) + a few
   `mulDiv` (incl. the signed `mulDiv` for `c₁ = −d·n(n−1)`), under the
   saturate-never-revert obligation; consumes the SPEC-02 `sqrt`/signed-`mulDiv`
   signatures from `ON-CHAIN-REALIZATION.md`. Apply `Δi⋆_Plank = 2·Δi⋆_Lean`.
4. **gamsDiff** — differential test: a fixture `{inputs (n, d, σ_target), reference
   Δi⋆}` from the SymPy exact-rational reference; `forge --via-ir` runs the Plank
   evaluation over the same inputs and asserts `assertApproxEqRel` within a stated
   tolerance (reference EPS ≈ 1e-15; a wider fixed-point band for round-toward-zero
   accumulation).

**Feasibility preconditions** (the controller is defined only where its proof holds):
**`n ≥ 2`** (leading coefficient `c₂ = n(n−1)(2n−1)/6 > 0`) and the **strict
`σ_target > d²`** bound with `d := i₋ − i_μ` (the Aristotle-narrowed precondition — the
non-strict `d² ≤ σ_target` lets the positive root collapse to `Δi = 0`). C2 is proven
on `sigma_xs_poly` with `#` free, so valid on a Δi-interval where the tick count is
constant (lifting to the full `σ_xs` is gap G3, §6).

C1/C3/C5/C9 are cheaper fallbacks if a fixed-point `sqrt` proves heavy. C2 (the proof
case) and C1/C3/C5/C7/C9 (EVM-ready, §3/§4) are referenced consistently across the
catalog, realization, and proof-case sections.

---
*Draft assembled from the v2-controller research set; §4 and §7 now integrate the
concrete SPEC-02 (`ON-CHAIN-REALIZATION.md`) and SPEC-03 (`C2-PROOF-CASE.md`) detail
docs. Remaining gate: the deferred SPEC-04 two-step review.*
