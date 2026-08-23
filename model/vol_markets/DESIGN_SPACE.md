# EVM-aware design space for `d(·,·)` and `∂_(M,v)`

This note answers the two design questions and records one correction to the
informal "admissibility" claim. Every mathematical assertion referenced here is
machine-checked in `RequestProject/Main.lean` (builds with **no `sorry`**).

## 0. Fixed-point conventions in play

| Name    | Scale factor `S` | Typical EVM slot | Origin              |
|---------|------------------|------------------|---------------------|
| X96 / Q64.96 | `2^96`      | `uint160`        | Uniswap v3 `sqrtPriceX96` |
| WAD     | `1e18`           | `uint256`        | 18-decimal tokens   |
| RAY     | `1e27`           | `uint256`        | rate/precision accumulators |

A real value `x` is stored as the integer `round(x · S)`; multiplication of two
`S`-scaled numbers produces an `S^2`-scaled product that must be rescaled by
`/ S` (mulDiv), and division `a / b` of `S`-scaled operands is `mulDiv(a, S, b)`.

## 1. Correction to the stated "admissibility" identity

The note asserts

> `d ∈ [0,1]  ⟹  ∀N, Σ Qᵥⁱ·d(p_risk, p(i)) = Σ Qᵥⁱ`.

**This implication is false.** With `Qᵥⁱ > 0`, `d ∈ [0,1]` only yields the
*inequality* and a sharp equality condition:

- `0 ≤ Σ Qᵥⁱ·dᵢ`                                  — `discounted_nonneg`
- `Σ Qᵥⁱ·dᵢ ≤ Σ Qᵥⁱ`  (`= Qᵥ^Σ`, the accounting identity) — `discounted_le_total`
- `Σ Qᵥⁱ·dᵢ = Σ Qᵥⁱ  ↔  ∀i, Qᵥⁱ·dᵢ = Qᵥⁱ`         — `discounted_eq_total_iff`
- with `Qᵥⁱ > 0`: equality `↔ ∀i, dᵢ = 1`           — `discounted_eq_total_iff_pos`
- explicit counterexample (`N=1, Qᵥ≡1, d≡0 ⟹ 0 ≠ 1`) — `discounted_claim_counterexample`

So the accounting identity is recovered **only** in the degenerate case
`d ≡ 1`. For any genuine distance the discounted total `Qᵥ^Σ_disc := Σ Qᵥⁱ·dᵢ`
is a *contraction* of `totalShares`, living in `[0, Σ Qᵥⁱ]`. This bracket is the
invariant the fixed-point encoding must preserve.

## 2. Design space for `d` — which number representation fits

Constraints that drive the choice:

1. **Codomain is `[0,1]`.** Only fractional resolution matters; no integer range
   is needed beyond the single endpoint value `1`.
2. **`d` multiplies `Qᵥⁱ`** and the products accumulate into `Qᵥ^Σ_disc`, which
   must stay inside `[0, Σ Qᵥⁱ]` (Section 1). A representation that can encode
   values `> 1` breaks this invariant unless separately clamped.
3. **`p(i(σ_x96))` and `p_risk` are X96 (`Q64.96`)** inputs to `d`, so `d`'s
   *domain* is already `2^96`-scaled.

**Recommended representation: unsigned `Q0.96` (a.k.a. `X96` weight), i.e. store
`d̂ = round(d · 2^96)` with the invariant `0 ≤ d̂ ≤ 2^96`.**

Rationale / design space ranking:

- **`Q0.96` / X96 (preferred).** Base-consistent with the X96 price inputs, so
  `d` is a pure power-of-two rescale of quantities already in the system — no
  base conversion between `2^96` and `1e27`/`1e18`. The product `Qᵥⁱ · d̂`
  is a `mulDiv(Qᵥ, d̂, 2^96)`, where `/2^96` is an exact **right shift `>> 96`**
  (no rounding division, cheapest gas). `d̂ = 2^96` is the exact `1`. Fits a
  `uint128`/`uint160` slot with room; `d̂ ≤ 2^96 < 2^97`.
  Termwise `Qᵥⁱ·d̂ ≤ Qᵥⁱ·2^96` mirrors the proved `mul_le_of_le_one_right`
  bound, so the `[0, Σ Qᵥⁱ]` invariant survives the encoding.
- **WAD (`1e18`) — acceptable, not ideal.** Human-friendly ("0.75e18 = 75%")
  and native for 18-decimal share tokens, but `/1e18` is a true `mulDiv`
  (rounding division, more gas) and needs a base change from the `2^96` price
  side. Enforce `d̂ ≤ 1e18`.
- **RAY (`1e27`) — use only to match the state accumulator.** Since the state
  update `(Qᵥ^Σ)_next` is declared RAY, storing `d` in RAY avoids a rescale at
  the accumulation step; the cost is base-changing away from the X96 price side
  and carrying 27 decimals of a quantity that never exceeds 1. Enforce
  `d̂ ≤ 1e27`.
- **Rejected:** signed types (distance is nonnegative — waste a bit and admit
  invalid negatives); floating point (not available/deterministic on the EVM);
  any format whose representable max exceeds the intended `1` without an
  explicit clamp (violates invariant 2).

**Rule of thumb:** pick the base that removes the most conversions on the hot
path. Because both `d`'s inputs are X96, `Q0.96`/X96 makes the discount a shift
and keeps the whole `d`-pipeline in one power-of-two base; convert to RAY once,
only at the final state write.

## 3. Design space for `∂_(M,v)` (the flow `ΔQᵥ^Σ`)

The operator produces the exogenous increment `ΔQᵥ^Σ = ∂_(M,v) Q_M^Σ` used in
the RAY state update `(Qᵥ^Σ)_next = Qᵥ^Σ + ΔQᵥ^Σ`, constrained to the admissible
region `ΔQᵥ^Σ ≤ Q_M^Σ / p_risk`.

Representation and bounds:

- **Carry `Δ` in RAY (`1e27`),** matching the state accumulator so the add
  `Qᵥ^Σ + Δ` needs no rescale and does not drift precision across ticks.
- **`p_risk` is `Q64.96`,** so the map "money → shares", `Δ = Q_M^Σ / p_risk`,
  crosses bases. Compute it as a single fused `mulDiv` so the intermediate
  `Q_M^Σ · 2^96` (or `· 1e27`) is never truncated before the divide.
- **Division-free admissibility check (EVM form).** For `p_risk > 0`,
  `Δ ≤ Q_M^Σ / p_risk  ⟺  Δ · p_risk ≤ Q_M^Σ`  — proved as `admissible_iff_mul`.
  Prefer the cross-multiplied test on-chain: it replaces a rounding division in
  the guard with one multiplication, removing an off-by-rounding boundary bug
  class.
- **Bounded, one-sided, monotone.** The admissible flow is confined to
  `0 ≤ Δ ≤ Q_M^Σ / p_risk`, hence the post-update state stays in
  `[Qᵥ^Σ, Qᵥ^Σ + Q_M^Σ / p_risk]` — proved as `admissible_state_bounds`. So
  `∂_(M,v)` only needs to represent a **nonnegative, upper-bounded** quantity:
  an unsigned RAY value suffices; no signed slot is required for a pure inflow.
  (If `∂_(M,v)` is ever meant to be bidirectional M↔v, promote to a signed RAY
  `int256` and add the symmetric lower guard.)
- **Rounding direction.** Because the guard is an upper bound, round `Δ` (and
  the `mulDiv` for `Q_M^Σ / p_risk`) **down** so the computed flow can never
  exceed the true admissible ceiling — conservative for the `totalDeposits`
  backing `totalShares`.

### Summary

| Object | Recommended base | Slot | Key EVM property proved |
|--------|------------------|------|--------------------------|
| `d`    | `Q0.96` / X96 (`2^96`), clamp `≤ 2^96` | `uint128`/`uint160` | discount = shift `>>96`; keeps `Σ Qᵥⁱ·dᵢ ∈ [0, Σ Qᵥⁱ]` |
| `∂_(M,v)` / `Δ` | RAY (`1e27`), unsigned, round down | `uint256` | guard `Δ·p_risk ≤ Q_M^Σ` (no division); state ∈ `[Qᵥ^Σ, Qᵥ^Σ + Q_M^Σ/p_risk]` |
