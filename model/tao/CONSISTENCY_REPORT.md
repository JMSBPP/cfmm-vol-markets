# DTAO model — machine-checked consistency report

This report records what was formalized in Lean 4 (Mathlib) to check the internal
consistency of your investment-market model and its relation to the DTAO
whitepaper, together with the errors found and the corrections adopted **in your
notation**.

All statements below are proved in the `RequestProject/` Lean files and build
without `sorry`; the headline theorems were checked to depend only on the
standard axioms (`propext`, `Classical.choice`, `Quot.sound`).

## Notation dictionary

| your model        | meaning                          | whitepaper |
|-------------------|----------------------------------|------------|
| `X^{(α_i)}`       | Alpha reserve of subnet `i`      | `α_i`      |
| `Y^{(τ)}`         | TAO reserve                      | `τ_i`      |
| `P_{α_i}`         | spot price `Y/X`                 | `p_i`      |
| `L`               | liquidity scale `√(X·Y)`         | `L_i`      |
| `w^{(d)} = β`     | constant-product weight `= 1/2`  | —          |
| `s_i`             | flow-based emission share        | (eqn 16)   |
| `γ̄^{(τ)}`        | tao weight                       | `γ`        |
| `S^{(τ)}`         | root-staked TAO                  | `τ₀`       |
| `S^{(α_i)}(0)`    | initial Alpha outstanding        | `α_i⁰(0)`  |
| `ΔM̄^{(α_i)}`     | per-block Alpha emission cap     | `Δᾱ_i`     |
| `β̄`              | validator share                  | `0.41`     |
| `λ_i`            | root proportion                   | `r_i`      |

## What is consistent (proved)

### AMM core — `RequestProject/AMM.lean`
* `reserve_X`, `reserve_Y` — reserve reconstruction `X = L/√P`, `Y = L·√P` from
  `L = √(X·Y)`, `P = Y/X`.
* `price_preserving` — the price-preserving injection
  `dL^{(α_i)} = dL^{(τ_i)}/P_{α_i}` (i.e. injecting at the current ratio) leaves
  the spot price unchanged. This is the substantive content behind your
  price-impact identity `P + dP ≡ (Y+dY)/(X+dX)`.
* `invariant_grows` — such an injection strictly grows the invariant `K = X·Y`,
  confirming your remark that the price-preserving inject "grows the invariant `K`".

### Injection / emission split — `RequestProject/Injection.lean`
* `sum_tau_inject` — eqn (8): the TAO injections sum to the block budget,
  `Σ_i Δτ_i = Δτ̄`.
* `alpha_inject_le` — eqn (9): the capped Alpha inject satisfies `Δα_i ≤ Δᾱ_i`.
* `min_max_rewrite` — eqn (39): `min(Δτ̄/S, Δᾱ) = Δτ̄/max(S, Δτ̄/Δᾱ)`.
* `share_sum_one` — your flow-based shares `s_i = z_i^p/Σ_j z_j^p` form a
  probability vector, `Σ_i s_i = 1`. (This is the correct normalization; it is
  identical in shape to the deprecated price-weighted form, so the FLOW-based
  correction you flagged does not change the normalization identity.)

### Halving schedule — `RequestProject/Halving.lean`
* `total_supply` — eqn (70): the halving geometric series sums to `S* = 2N`
  (so `N = 10.5e6 ⟹ S* = 21e6`, your `M_max^{(τ)}`).
* `accumulated_supply` — eqn (72): `S↓ = 2N(1 − (1/2)^k)`.
* `k_formula` — eqns (74),(77): `k = −log₂(1 − S↓/S*)` is consistent with the
  geometric accumulation.

### Root-dividend accounting — `RequestProject/Rewards.lean`
* `accounting_step` — the corrected eqn (83) invariant `α_c' = τ'ρ' − δ'`
  (see correction C3 below).

### GBM price expectation — `RequestProject/GBM.lean`
* `gaussian_mgf` — eqn (32): the Gaussian moment integral
  `∫ e^{cx}(2πa)^{-1/2}e^{-(x-d)²/2a} dx = e^{cd + ac²/2}`.
* `expected_price` — eqn (34): `E[P(t)] = P(0)·e^{(μ+σ²/2)t}`.

### Returns / tao-weight heuristic — `RequestProject/APY.lean`
* `root_le_avg` — eqns (65)–(67): if the tao weight obeys `γ·N ≤ 1` then the
  passive root APY is at most the average subnet APY.
* `root_closed` — eqn (67): the root return has antiderivative
  `γ·0.41·log(D)`, so it grows **logarithmically** in `t`.
* `subnet_closed` — eqn (68): the subnet return has antiderivative with a
  leading `(Δᾱ/α⁰)·t` term, so it grows **linearly** in `t`.

### Bonding curve — `RequestProject/Model.lean`
* `phi_homogeneous` — your CES/Cobb–Douglas bonding curve
  `φ(η; X, Y) = X^η·Y^{1-η}` is homogeneous of degree one, the property that
  makes it a well-defined constant-value-share invariant.

## Errors found and corrections (in your notation)

### C1 — `λ_i` numerator is missing a factor `S^{(τ)}` (root proportion)
You wrote
```
λ_i      = γ̄^{(τ)} / (γ̄^{(τ)} S^{(τ)} + S^{(α_i)})
1 − λ_i  = S^{(α_i)} / (γ̄^{(τ)} S^{(τ)} + S^{(α_i)})
```
These **do not sum to 1** unless `S^{(τ)} = 1`:
`lambda_literal_inconsistent` proves
`λ_i + (1−λ_i) = 1  ↔  S^{(τ)} = 1`.

**Correction.** The numerator of `λ_i` must carry `S^{(τ)}`, matching the
whitepaper root proportion `r_i = γτ₀/(γτ₀+α_i⁰)`:
```
λ_i = γ̄^{(τ)} S^{(τ)} / (γ̄^{(τ)} S^{(τ)} + S^{(α_i)})
```
`lambda_corrected_sum` proves this version satisfies `λ_i + (1−λ_i) = 1`.

### C2 — `r_F^{(i)}` carries the same missing `S^{(τ)}` factor
Your risk-free rate
```
r_F^{(i)} = (1/S^{(τ)}) · Σ_t  γ̄^{(τ)} β̄ ΔM̄^{(α_i)} / D_i(t)
```
with `D_i(t) = γ̄^{(τ)} S^{(τ)} + S^{(α_i)}(0) + t ΔM̄^{(α_i)}` is the whitepaper
`APYᵣ` contribution **divided by an extra `S^{(τ)}`** — the same dropped factor
as in C1. `rF_literal_ne_corrected` exhibits parameter values where the literal
and corrected numerators disagree.

**Correction.** Restore `S^{(τ)}` in the numerator (equivalently drop the
`1/S^{(τ)}` prefactor); `rF_corrected_reduces` proves the corrected form collapses
to the clean whitepaper expression
```
r_F^{(i)} = Σ_t  γ̄^{(τ)} β̄ ΔM̄^{(α_i)} / D_i(t)     (eqn (59))
```

### C3 — rewards-accounting closing term (whitepaper §5.3, eqn (83))
The whitepaper's eqn (83) writes the final term as `(δ + ρ·Δα)`. With the stated
updates (`δ' = δ + ρ·Δτ`, eqn (80)) this is a **typo**: the correct closing term
is `(δ + ρ·Δτ)`. `accounting_step_literal_false` shows the literal `(δ + ρ·Δα)`
version fails in general; `accounting_step` proves the corrected invariant
`α_c' = τ'ρ' − δ'`.

## Consistent without change (no correction)

* The α-return `r^{(α_i)}` (your second displayed rate) is **term-by-term equal**
  to the whitepaper subnet APY (eqn (57)); no factor is missing. Its closed form
  (linear growth) is verified by `APY.subnet_closed`.
* The CEV/√-weight `β = w^{(d)} = 1/2` is the mechanical constant-product weight;
  the AMM identities above are exactly the `β = 1/2` (constant-product) case, so
  this is consistent with the stated `dP = μ dt + δ P^β dW` exponent.

## On the tautological "splitting" equations

Several lines in your spec are written as identities of the form
`dL = w·dL + (1−w)·dL` (and `dM̄ = w·dL + (1−w)·dL`). As you noted, the content
there is **routing**, not an equation: the protocol parameter `w` *splits* one
flow into two streams that are then sent to different destinations. Read literally
they are trivially true (`w·x + (1−w)·x = x`) and carry no constraint; the
substantive identities are the routing targets, which are captured by the
injection/emission and `λ_i`-split lemmas above. They are therefore left as
bookkeeping and not formalized as standalone theorems.

## File map

| file | content |
|------|---------|
| `RequestProject/AMM.lean`       | constant-product identities, price-preserving inject, invariant growth |
| `RequestProject/Injection.lean` | emission conservation, Alpha cap, min/max rewrite, share normalization |
| `RequestProject/Halving.lean`   | geometric-series supply `2N`, accumulated supply, log index formula |
| `RequestProject/Rewards.lean`   | corrected rewards-per-tao accounting (C3) |
| `RequestProject/GBM.lean`       | Gaussian moment integral, lognormal price expectation |
| `RequestProject/APY.lean`       | tao-weight heuristic `γ ≤ 1/N`, root/subnet closed forms |
| `RequestProject/Model.lean`     | bonding-curve homogeneity, `λ_i` and `r_F` corrections (C1, C2) |
