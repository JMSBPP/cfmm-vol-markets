# ON-CHAIN-REALIZATION — SPEC-02: the concrete on-chain object for the static control kernel

> Implementation-grade sibling to `STATIC-CONTROL-KERNEL-SPEC.md` §4. Where the
> consolidated spec only *gestures* at "one banded matvec + some primitives," this
> document fixes the **exact layout, exact set-point formulas, exact primitive
> signatures, and exact bounds/rounding** — so a Plank implementer needs no further
> research.
>
> **Scope (inherited, non-negotiable):** static, tick-lattice, η = ½. C7's η-split is
> the documented *generalization path*, not dynamic content. No time index, no
> feedback loop, no V4 `beforeSwap` adaptive policy is specified here — only the
> static, precompiled evaluator. (`STATIC-CONTROL-KERNEL-SPEC.md` §1 scope.)
>
> **Sources (cited concretely throughout):** `LIT-LATTICE-CONTROL.md` (theoretical
> frame), `CONTROLLERS.md` (closed forms + readiness ranking),
> `EVM-CONTROL-PRIMITIVES-MAP.md` (primitive inventory, the G5 gaps, numerical
> pitfalls), `STATIC-CONTROL-KERNEL-SPEC.md` §4 (the integration target).
>
> Produced 2026-06-28. READ-ONLY synthesis of prior research; authors a spec doc, no
> production code.

---

## On-chain realization

The on-chain controller is **one object**: a fixed, shift-invariant linear law
evaluated once per call as a banded matrix–vector product, plus a small set of
per-position closed-form set-point entries that populate that operator. Off-chain
(GAMS/SymPy/Lean) does all synthesis; on-chain (Plank/EVM) only *evaluates* a
precompiled constant-gain operator. "Treat the EVM as an *evaluator of a precompiled
constant-gain linear controller*, not a solver." (`EVM-CONTROL-PRIMITIVES-MAP.md` §4.)

### Banded Toeplitz/circulant matvec layout

**The on-chain object.** A shift-invariant static control law over the tick lattice is
the fixed banded operator

```
u = -K x ,   K[i,j] = kappa(i - j)
```

i.e. `K[i,j] = kappa(i-j)` is a function of the lattice *offset* `(i - j)` only, which
makes `K` **Toeplitz** (constant along diagonals). The state `x` is indexed by the
integer tick lattice `i ∈ [-120, 120]` (241 nodes, `tickVal = ord - 121`, λ = 1.0001),
the same state grid the proven inversions live on (`CONTROLLERS.md` "Framing";
`STATIC-CONTROL-KERNEL-SPEC.md` §1). The output `u` is the per-tick control action
(the actuator increment on `Δi`, see the set-point table below).

**Why Toeplitz, and why bandable.** This is the Bamieh–Paganini–Dahleh frame for
spatially-invariant systems: a control law that commutes with shifts along the tick
index is a fixed Toeplitz gain `K[i,j] = κ(i−j)`, computed off-chain per spatial
wavenumber and applied on-chain as one banded matrix–vector product
(`LIT-LATTICE-CONTROL.md` §A1). The optimal controller is "a convolution kernel over
space whose taps decay exponentially with spatial distance" (`LIT-LATTICE-CONTROL.md`
§A1, "inherent degree of decentralization"). That **exponential spatial tap decay** is
the justification for truncating `K` to a narrow band:

```
banded truncation:  keep K[i,j] only for |i - j| <= b,  band width  n = 2b + 1 <= 3-4
```

So the on-chain operator is a **banded Toeplitz matrix with at most n ≤ 3–4 nonzero
taps per row** — `κ(0)` (self), `κ(±1)` (nearest neighbour), optionally `κ(±2)`. The
O(n⁻²) error of a small on-chain band is quantified by the static-replication
convergence result (`LIT-LATTICE-CONTROL.md` §C3, arXiv:1406.5430).

**Circulant variant (periodic/wrapped grid).** On a periodic/wrapped tick grid the
operator becomes **circulant** rather than plain Toeplitz: row `i` wraps modulo the
grid size. Circulants are **diagonalized by the lattice DFT**, so the whole-lattice
synthesis decouples into independent per-wavenumber algebraic problems solved
off-chain, and the DFT synthesis is **pushed off-chain** entirely
(`LIT-LATTICE-CONTROL.md` §A2 "multi-agent case coupled through circulant matrices",
and "Recommended theoretical frame": "DFT decoupling pushes all synthesis off-chain …
the on-chain step collapses to one fixed banded Toeplitz/circulant matrix-vector
product"). On-chain there is no DFT and no solve — only the resulting banded `K`.

**EVM cost (explicit).** An `n × n` constant-gain update costs `n^2` `mulDiv` + `n^2`
signed adds per evaluation (`EVM-CONTROL-PRIMITIVES-MAP.md` §4: "An `n×n` update is
`n²` `mulDiv` + `n²` signed adds per step"). For `n = 3` that is **~9 `mulDiv`**
(each `mulDiv` ≈ a few hundred gas of EVM mul/mulmod/div → low thousands of gas,
"trivially affordable inside `beforeSwap`", `EVM-CONTROL-PRIMITIVES-MAP.md` §4).
Because the band is `n ≤ 3–4`, real cost is a handful of `mulDiv`s with no `pow`/`log`
and no solve.

**Constants are precompiled, never solved on-chain.** `A, B, K` are **compile-time
constants precomputed off-chain** in GAMS/SymPy (per-wavenumber gains or assembled
Carr–Madan/spline weights), then truncated by spatial decay; the EVM never solves for
them. "Matrices `A,B,K` should be compile-time constants (precomputed off-chain in
GAMS/sympy), not solved on-chain" (`EVM-CONTROL-PRIMITIVES-MAP.md` §4). The state
vector is stored as `n` `sstore` slots (signed in u256); gains live as constants in
code, so no dynamic arrays and no memory-layout risk (`EVM-CONTROL-PRIMITIVES-MAP.md`
§4 "Representation").

### Per-position set-point entries

The proven Lean static inversions are **the per-position (per-wavenumber) set-point
entries** of the operator above — "Our already-proven static inversions slot in as the
per-position set-point entries of that operator" (`LIT-LATTICE-CONTROL.md`
"Recommended theoretical frame"; `STATIC-CONTROL-KERNEL-SPEC.md` §2). Each EVM-ready
controller contributes one closed-form set-point that defines what target the operator
drives the corresponding lattice node to. Only the **proven-and-EVM-ready** set is
specified here: **C1, C3, C5, C7, C9** are directly EVM-ready, **C2** is EVM-ready once
the G5 fixed-point `sqrt` is wired (`STATIC-CONTROL-KERNEL-SPEC.md` §3,
`CONTROLLERS.md` ranking table).

| Controller | Set-point formula (the operator entry) | Primitives used | Source theorem |
|---|---|---|---|
| **C1** Zero-Slippage Spacing | Rational price target `P_half = L̄/(L̄-Δᴵ)` reached via **one `mulDiv`**, then price→tick via `getTickAtSqrtRatio` (binary search). Log-free closed form: `Δi⋆ = log(L̄/(L̄-Δᴵ)) / (logλ · i)` with `P_½(Δi⋆) = L̄/(L̄-Δᴵ)` — ship `Δi⋆` **precomputed off-chain** if `log` is to be avoided entirely. | `mulDiv` (target ratio) + `getTickAtSqrtRatio` (price→tick) | `pi_trader_half_zero_at_deltaI_star` + `P_half_at_deltaI_star` (`eta.lean:501,518`); GAMS `eta_pi_trader_zero_slippage.gms` |
| **C2** σ_xs Variance-Target | Quadratic root: `Δi⋆(n,d,σ_target) = (d·n(n−1) + √disc) / (n(n−1)(2n−1)/3)`, `disc = c₁² − 4c₂(d²−σ_target)`, `c₂ = n(n−1)(2n−1)/6`, `c₁ = −d·n(n−1)`, `d := i₋ − i_μ`. **Full formula derivation/quantization deferred to plan 10-02**; here the on-chain budget is recorded: needs **1 `sqrt` + a few `mulDiv`**. | fixed-point `sqrt` (disc) + `mulDiv` | `sigma_xs_poly_target_exists` (`eta.lean:560`) |
| **C3** Band-Min (large trade) | `Δi = Δi_min` — **pure clamp to the band floor**, no payoff evaluation. `π_½(Δi_min) ≤ π_½(Δi)` ∀ admissible `Δi`. | `clamp` only (no `mulDiv`, no payoff eval) | `pi_trader_half_band_min_at_left` (`eta.lean:477`) |
| **C5** Small-Signal Gain | `lim_{Δᴵ→0⁺} π_½/Δᴵ² = P²(P−1)²`, with `P = λ^{i·Δi}`. `P = getSqrtRatioAtTick(i·Δi)` then **two squarings / `mulDiv`**. | `getSqrtRatioAtTick` + 2 squarings via `mulDiv` | `pi_trader_half_small_trade_quadratic` (`eta.lean:428`) |
| **C7** η-Split Kernel | `P_η(i) = P_½(i₋)·P_½(i₊)`, with the node split `i₋ = ⌊η·i⌋`, `i₊ = i − i₋`. **Two `getSqrtRatioAtTick` + one `mulDiv`** (floor via `@evm_sdiv`). The documented generalization path off the η=½ pin; valid for any `η ∈ (0,1)` provided `i₋, i₊` stay int24. | 2× `getSqrtRatioAtTick` + `mulDiv` (+ `@evm_sdiv` floor) | `eta_split_kernel_identity` (`eta.lean:67`) |
| **C9** Realized-Variance Aggregator | Closed form (no per-node loop): `σ_xs = #·σ_realized − (#−1)d² − 2dΔi·#(#−1)`, using `Σ_{k<n}(d+kΔi)² = nd² + dΔi·n(n−1) + Δi²·n(n−1)(2n−1)/6`. A handful of `mulDiv` on integer tick counts. | `mulDiv` on integer tick counts (closed form) | `sigma_xs_eq_sharp_mul_sigma_realized` + `sum_sq_arith` (`eta.lean:286,241`) |

**Plank coordinate bridge (C1).** The Lean-domain spacing maps to the Plank/on-chain
domain by `Δi⋆_Plank = 2·Δi⋆_Lean` (`CONTROLLERS.md` C1; reproduced in the int24 table
below). This factor-of-2 is load-bearing wherever a precomputed `Δi⋆` from Lean is
shipped on-chain — it must be applied before the int24 admissibility check.

**Why no per-node loop (C9) and no payoff eval (C3).** These are the cheapest entries:
C3 is "trivial — pick/clamp to the band floor. No payoff eval." and C9 is a "Lattice
recursion collapsed to closed form (no binomial rollback needed)"
(`CONTROLLERS.md` C3, C9). The set-point operator therefore never iterates the lattice
on-chain.

---

### Required fixed-point primitives to build (gap G5)

These three helpers do **not exist anywhere in Plank today** and must be written; they
are exactly gap **G5** ("the signed-fixed-point `mulDiv` and saturating clamp that
C2/C4/C6 need are not yet written in Plank", `CONTROLLERS.md` G5;
`EVM-CONTROL-PRIMITIVES-MAP.md` §3 "What's MISSING for linear algebra"). The substrate
is `u256` only; signed values are two's-complement *in* a `u256`, and signed ops are
explicit EVM builtins (`EVM-CONTROL-PRIMITIVES-MAP.md` §3 "Language substrate").

**Signatures only (this is design, not implementation):**

1. **Fixed-point `sqrt`** — needed by C2 (the `disc` root).
   ```
   sqrt(x: u256) -> u256
   ```
   - **Scale convention:** operate over ONE stated fixed-point scale — WAD (1e18) for
     controller params, or a Q-fixed scale (Q64.96 / Q128.128) where it touches
     sqrt-price. State the scale at the call site and keep it consistent (see the WAD
     discipline in the saturate-never-revert rule below).
   - **Built on existing MSB machinery:** reuse the `tick_math` / `mostSignificantBit`
     (`bit_math.plk:5`) used by the v3 log/sqrt path — "needs a fixed-point `sqrt`,
     which `tick_math` MSB machinery supports" (`CONTROLLERS.md` C2;
     `EVM-CONTROL-PRIMITIVES-MAP.md` §3, "MSB (used by log/sqrt)").
   - **Rounding:** round **toward zero** (consistent with `</` and `mulDiv`).

2. **Signed `mulDiv`** — the single biggest gap for `K·x` gain math with signed states.
   ```
   signedMulDiv(a: u256, b: u256, denom: u256) -> u256
   ```
   - Operate on **magnitudes** via the existing 512-bit `mulDiv` (`full_math.plk:6`),
     recover the sign by **XOR of the operand sign bits** (tested with `@evm_slt`), and
     re-apply the sign via two's-complement negate (`-x`).
   - This is the **#1 correctness hazard**: "states/gains are signed; `mulDiv` is
     unsigned. Every product `K_ij · x_j` needs explicit sign handling … Forgetting
     this silently corrupts via two's-complement wrap. This is the #1 correctness
     hazard." (`EVM-CONTROL-PRIMITIVES-MAP.md` §4; §3 "No signed fixed-point mul/div
     helper (must hand-roll …). This is the single biggest gap.")

3. **Clamp / saturating add** — needed by C3 (band-floor clamp) and every accumulator.
   ```
   clamp(x: u256, lo: u256, hi: u256) -> u256        // signed bounds
   satAdd(x: u256, y: u256) -> u256                   // signed-saturating add
   ```
   - Only **unsigned** `min/max` (`std/math.plk:1,9`) + **revert-on-overflow** casts
     (`safe_cast.plk`) exist today — there is "No saturation/clamp primitive (only
     revert-on-overflow casts + `min/max` on unsigned). A `clamp(x,lo,hi)` and
     signed-saturating add must be written." (`EVM-CONTROL-PRIMITIVES-MAP.md` §3.)
   - `satAdd` returns the saturated bound on overflow/underflow instead of reverting
     (see the saturate-never-revert rule).

> All three are cited against `EVM-CONTROL-PRIMITIVES-MAP.md` §3 (MISSING primitives)
> and §4 (numerical pitfalls). They are the on-chain prerequisites for C2 and for any
> signed `K·x` accumulation in the banded matvec.

### Saturate-never-revert rule

**HARD RULE: the controller must saturate, never revert.** A reverting `beforeSwap`
hook **DoSes the swap** — "a hook that reverts DoSes the swap → every controller must
**saturate, never revert**" (`CONTROLLERS.md` Framing; `EVM-CONTROL-PRIMITIVES-MAP.md`
§4: "For a controller you generally want **saturation, not revert** (a hook that
reverts blocks the swap → DoS)"). This is non-negotiable for every set-point and every
matvec accumulation.

Concrete consequences (all from `EVM-CONTROL-PRIMITIVES-MAP.md` §4 numerical pitfalls):

- **Clamp BEFORE any value can overflow** — do not rely on checked `*`. `*%` wraps
  silently; `*` reverts. "So clamp before it can overflow rather than relying on
  checked `*`." Use `satAdd`/`clamp` (the G5 primitives) on every accumulator step.
- **Guard any controller-derived denominator against 0 BEFORE `mulDiv`.** `mulDiv`
  reverts on `denom==0` (`full_math.plk:6`). "Any gain/normalizer that can reach 0
  must be guarded *before* the call, else the swap reverts." (Relevant to C1's
  `L̄−Δᴵ` denominator and C2's leading coefficient.)
- **One consistent WAD scale; divide-by-WAD per multiply.** "pick ONE scale (WAD
  recommended …). Each `A·x` term is `mulDiv(a_ij, x_j, WAD)` to keep scale; a missing
  `/WAD` blows the scale up by 1e18 per multiply." A dropped `/WAD` is a silent
  1e18-per-multiply scale blow-up.
- **Real precedent for the overflow trap:** `CESLongPayoff.plk:42` already documents a
  real `*%` overflow at **~2^192** — "the same trap applies to accumulators"
  (`EVM-CONTROL-PRIMITIVES-MAP.md` §4; `CONTROLLERS.md` C5 "Watch `*%` overflow above
  ~2^192"). Clamp to a safe magnitude before any product can reach 2^192.

### int24 bounds + rounding mode per inversion

Every inversion that emits a tick / spacing must land in int24 and round
deterministically. The int24 contract comes from the v3 `TickMath` port
(`src/lib/TickUtils.plk`): `Tick = u256` (two's-complement int24), with
**`MIN_TICK = -887272`** and **`MAX_TICK = 887272`** (`EVM-CONTROL-PRIMITIVES-MAP.md`
§3). Admissible spacing band: `Δi ∈ [1,200]` (GAMS abort guard); fixtures use `Δi = 1`
(`CONTROLLERS.md` C1/C3 regimes, Framing). Rounding: round **toward zero** for `</` and
`mulDiv`; keep intermediate scale high (Q96/Q128) and **downcast once**, mirroring
`tick_math`'s Q128.128→Q96 final shift (`EVM-CONTROL-PRIMITIVES-MAP.md` §4
"Truncation/precision").

| Controller | int24 admissibility | Admissible Δi band | Rounding mode | Plank coordinate bridge |
|---|---|---|---|---|
| **C1** Zero-Slippage | result tick ∈ [`MIN_TICK = -887272`, `MAX_TICK = 887272`] | `Δi ∈ [1,200]` (GAMS aborts otherwise); fixtures `Δi=1` | round-toward-zero on `mulDiv` (ratio) and on `getTickAtSqrtRatio` price→tick; keep ratio at Q96, downcast once | **`Δi⋆_Plank = 2·Δi⋆_Lean`** — apply before the int24 check |
| **C2** σ_xs Target | `Δi⋆` ∈ band; root must be ≥ 0 (strict `σ_target > d²`) | `Δi ∈ [1,200]`; valid on a Δi-interval where `#` is constant (G3) | round-toward-zero on `sqrt`(disc) and on the dividing `mulDiv`; high intermediate scale, downcast once | n/a (operates on σ/Δi directly) |
| **C3** Band-Min | `Δi_min` ∈ [`MIN_TICK`, `MAX_TICK`] | clamp to band floor `Δi_min`, `Δi ∈ [1,200]` | clamp (no division → no rounding bias) | n/a |
| **C5** Small-Signal Gain | tick `i·Δi` ∈ [`MIN_TICK`, `MAX_TICK`] for `getSqrtRatioAtTick` | `Δi ∈ [1,200]` | round-toward-zero on the squaring `mulDiv`; guard `*%` < 2^192 | n/a |
| **C7** η-Split | **requires `IsInt24 i₋` AND `IsInt24 i₊`** (explicit hyps); both ∈ [`MIN_TICK`, `MAX_TICK`] | `Δi ∈ [1,200]`; `i₋ = ⌊η·i⌋`, `i₊ = i − i₋` | round-toward-zero `⌊η·i⌋` floor via `@evm_sdiv`; one `mulDiv` round-toward-zero | n/a (η-split, generalization path) |
| **C9** Realized-Var | integer tick counts `#`, spacing `Δi`, all int24-bounded | `Δi ∈ [1,200]`, `# ≥ 1` | round-toward-zero on the closed-form `mulDiv`s; integer arithmetic | n/a (read-only aggregator) |

Notes on rounding discipline (shared): integer `</` and `mulDiv` round toward zero, and
"repeated feedback steps accumulate bias" — so keep the intermediate scale high
(Q96/Q128) and downcast once at the end, mirroring `tick_math`'s Q128.128→Q96 final
shift (`EVM-CONTROL-PRIMITIVES-MAP.md` §4). Snapping a tick to `tickSpacing` follows the
existing `ReferenceMarket`/`TickUtils` pattern (`@evm_sdiv … *% tickSpacing`,
`EVM-CONTROL-PRIMITIVES-MAP.md` §1, §3) and must respect the same round-toward-zero
convention.

---

## Traceability

- **Banded matvec layout** ← `LIT-LATTICE-CONTROL.md` §A1/§A2 + "Recommended
  theoretical frame"; cost ← `EVM-CONTROL-PRIMITIVES-MAP.md` §4.
- **Set-point entries (C1/C2/C3/C5/C7/C9)** ← `CONTROLLERS.md` closed forms + readiness
  ranking; integration role ← `STATIC-CONTROL-KERNEL-SPEC.md` §2, §3.
- **G5 primitive signatures (sqrt, signed mulDiv, clamp/saturating add)** ←
  `EVM-CONTROL-PRIMITIVES-MAP.md` §3; gap label ← `CONTROLLERS.md` G5,
  `STATIC-CONTROL-KERNEL-SPEC.md` §4/§6.
- **Saturate-never-revert rule** ← `CONTROLLERS.md` Framing +
  `EVM-CONTROL-PRIMITIVES-MAP.md` §4 (incl. `CESLongPayoff.plk:42` ~2^192 precedent).
- **int24 bounds + rounding** ← `EVM-CONTROL-PRIMITIVES-MAP.md` §1/§3/§4 (`TickUtils.plk`,
  `MIN_TICK=-887272`/`MAX_TICK=887272`); Plank bridge ← `CONTROLLERS.md` C1.

*This document is SPEC-02. It deliberately stops at design: signatures, formulas,
bounds — no Plank/Solidity implementation. The implementation milestone builds from
here; the consolidated spec (`STATIC-CONTROL-KERNEL-SPEC.md` §4) references it.*
