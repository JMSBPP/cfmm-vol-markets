# LEAN-MAP — Formalization inventory for the CFMM adaptive-feedback controller

Read-only survey produced 2026-06-28. Maps what is actually FORMALIZED and PROVED
in the Lean4 layer vs stated/stubbed, and relates it to the math spec and to
controller design.

## 1. Scope of the Lean project (what exists)

There is exactly **one** Lean source file in the entire repo:

- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/exp/eta.lean` (732 lines)
- Project config: `lean/lakefile.toml`, `lean/lean-toolchain`
  - Lean `leanprover/lean4:v4.30.0`; Mathlib pinned `v4.30.0`.
  - Also requires `Philogy/LeanEVM` (`evm`), but **`eta.lean` does NOT import it**
    (`import Mathlib` only, line 22). The EVM/fixed-point model is unused
    scaffolding; nothing in eta.lean touches `UInt256` / Q64.96 / WAD.
- No other `*.lean` anywhere (`/home/.../cfmm-replicationPlank/lean/` holds only
  `exp/eta.md`, no Lean). Everything below is in the single `CFMM.Eta` namespace.

### Verification status (important caveat)
- **No actual `sorry`/`admit`/`axiom` in the code.** The only grep hit is a
  *stale docstring comment* at `eta.lean:602` ("Substantive; left as `sorry` for
  Aristotle.") describing `pi_trader_half_band_max_small_trade` — but that theorem
  (line 701) now carries a **complete proof** via `residual_antitone`. The comment
  is out of date; the theorem is proved.
- No local `.olean` build artifacts exist for `eta` (build dir empty), so I did
  **not** independently recompile. An `lean/.aristotle-out.tar.gz` is present and
  `model/exp/eta.md` marks `eta_split_kernel_identity` as "Proven" on Aristotle.
  Treat status as "**proof text complete, no sorry; not re-verified locally in this
  survey**." UNKNOWN: whether the full file compiles clean under the pinned
  toolchain right now.

## 2. Definitions (all over ℝ — `Real`, not fixed-point)

| Def | Line | Meaning |
|---|---|---|
| `IsInt24 i` | 32 | tick range predicate `[-8388608, 8388607]` (Uniswap v3 / Plank Int24) |
| `P_half lam Δi i` | 38 | ½-pricing kernel `P(i)=λ^{i·Δi}` (= spec `pricingKernel.md` exactly) |
| `tickSplit_minus η i` | 42 | `i₋(η)=⌊η·i⌋` |
| `tickSplit_plus η i` | 48 | `i₊(η)=i − i₋(η)` |
| `sigmaVTS δ lam eta i Δi` | 108 | vol term structure `σ=δ·λ^{η·i·Δi}` (KERNEL.md `σ=δ·P^η`) |
| `L_eta eta X Y` | 112 | CES trading function `Lη=X^η·Y^{1−η}` |
| `P_half_post lam Δi i L̄ ΔI` | 183 | post-swap sqrt price `L̄P/(L̄+ΔI·P)` (Plank `getNextSqrtPriceFromAmount0RoundingUp`) |
| `Delta_O_half …` | 190 | output `ΔO=L̄·(P−P')` (Plank `getAmount1DeltaUnsigned`) |
| `pi_trader_half …` | 195 | trader payoff `π=(P·ΔI−ΔO)²` (η=½ squared-slippage / variance-swap) |
| `sharp i₋ i₊ Δi` | 208 | tick count `#=⌊(i₊−i₋)/Δi⌋.toNat` |
| `sigma_xs i₋ i₊ iμ Δi` | 219 | cross-section vol closed form (quadratic in Δi) |
| `sigma_realized …` | 231 | averaged discrete variance `(1/#)Σ(i₋+kΔi−iμ)²` |
| `sigma_xs_poly n d Δi` | 542 | σ_xs as polynomial with `#=n` a FREE parameter (decoupled from floor) |
| `deltaI_star lam i L̄ ΔI` | 496 | zero-slippage spacing `Δi⋆=log(L̄/(L̄−ΔI))/(log λ · i)` |

## 3. Lemmas & theorems — all PROVED (no sorry)

| Name | Line | Statement (plain) | Status |
|---|---|---|---|
| `tickSplit_sum` | 52 | `i₋(η)+i₊(η)=i` | PROVED (ring) |
| `eta_split_kernel_identity` | 67 | **η-decomposition**: on Int24, `P½(i₋(η))·P½(i₊(η))=P½(i)` for any η∈(0,1) — the η-kernel closes under the ½ sqrt-price algebra | PROVED (rpow_add) |
| `sigmaVTS_invariant_under_eta_Δi_rescaling` | 120 | σ depends on (η,Δi) only through the product η·Δi: rescaling (η,Δi)↦(cη,Δi/c) leaves σ fixed | PROVED (grind) |
| `eta_Δi_independent_in_sigma_and_L_eta` | 138 | but in the JOINT observable (σ, Lη) the two separate: on the σ-invariant manifold `Lη` still varies with η when X≠Y, c≠1 | PROVED |
| `sum_sq_arith` | 241 | closed form for `Σ_{k<n}(d+kΔi)²` | PROVED (induction) |
| `sigma_xs_eq_sharp_mul_sigma_realized` | 286 | exact relation `σ_xs = #·σ_realized − (#−1)d² − 2dΔi·#(#−1)` (naive `σ_xs=#·σ_realized` shown FALSE unless d=i₋−iμ=0) | PROVED |
| `P_half_pos` | 308 | `λ>0 ⇒ P>0` (positivity/boundedness) | PROVED |
| `one_lt_P_half` | 314 | `λ>1, i>0, Δi>0 ⇒ P>1` | PROVED |
| `P_half_strictMono` | 324 | **monotonicity**: `λ>1, i>0 ⇒ P` strictly increasing in Δi | PROVED |
| `slippage_residual` | 335 | closed form `P·ΔI−ΔO = ΔI·P·(L̄+P(ΔI−L̄))/(L̄+ΔI·P)` | PROVED |
| `pi_trader_half_strictly_increasing_in_Δi` | 366 | **CONTROL KNOB**: in regime `i>0, λ>1, L̄≤ΔI`, π is strictly increasing in Δi | PROVED |
| `pi_trader_half_small_trade_quadratic` | 428 | **small-signal gain**: as ΔI→0⁺, `π/ΔI² → P²(P−1)²` | PROVED (limit) |
| `pi_trader_half_band_min_at_left` | 477 | large-trade band minimizer = left endpoint Δi_min | PROVED |
| `P_half_at_deltaI_star` | 501 | at Δi⋆ the kernel equals `L̄/(L̄−ΔI)` (kernel↔spacing inversion) | PROVED |
| `pi_trader_half_zero_at_deltaI_star` | 518 | **setpoint exists, closed form**: small-trade (ΔI<L̄) π=0 at Δi⋆; global min since π≥0 | PROVED |
| `sigma_xs_poly_target_exists` | 560 | **σ-target inversion**: for #=n≥2 and σ_target>d², ∃ Δi>0 with `σ_xs_poly=σ_target` (positive quadratic root) | PROVED |
| `pi_trader_half_band_max_large_trade` | 609 | large-trade band maximizer = right endpoint Δi_max | PROVED |
| `residual_antitone` | 635 | residual is antitone in Δi under golden bound `ΔI²+ΔI·L̄≤L̄²` | PROVED |
| `pi_trader_half_band_max_small_trade` | 701 | small-trade π is U-shaped ⇒ band-max at an endpoint (needs golden bound; bare ΔI<L̄ shown insufficient w/ counterexample) | PROVED (despite stale "sorry" comment at 602) |

## 4. Relation to the math spec layer (`model/spec/*.md`)

- `primitives.md`: constants WAD=1e18, uintMax=2^256−1, ε=1e12, i_max=2^24−1,
  i_min=2^23−1. **In Lean only `IsInt24` reflects this** (signed range
  [−2^23, 2^23−1]); WAD/ε/uintMax/fixed-point are **not formalized at all**.
- `pricingKernel.md`: `P_X(Δi;i)=λ^{iΔi}`, λ=1.0001. **Matched exactly** by
  `P_half` (eta.lean:38). λ=1.0001 is a spec constant; Lean proves facts for
  generic `λ>0` / `λ>1` rather than pinning the value.
- `liquidityKernel.md`: per-tick weight `ℓ(ξ,ι;i)=ξ^i/((1−ξ^ι)/(1−ξ))`, unit-sum
  over ι-window; parameters ξ (decay base, regimes (0,1) and (1,uintMax]) and ι
  (support length, [1, maxTick]). **NONE of this is in Lean.** The unit-sum
  geometric-series identity is argued on paper only. `ξ`, `ι` do not appear in
  eta.lean (it uses `L̄`, pool liquidity, as a scalar). Spec already flags the
  shipped ι=1 collapses normalization — unformalized.
- `model/exp/eta.md` (the driving note): poses the η-decomposition (→ proved as
  `eta_split_kernel_identity`), the trader payoff `π=(P·ΔI−ΔO)²`, and the
  σ↔π connection (→ the monotonicity + inversion theorems). It also sketches a
  **stochastic order-flow / time dynamics** model (Poisson Nₜ, LogNormal jump
  sizes, deterministic proxy `Δy(t)=19+1.0001^{η t⁴}`) — **NONE of the temporal
  dynamics is formalized in Lean**.

## 5. Parameters and proved facts about their ranges/relationships

| Param | Where | Proved facts |
|---|---|---|
| `λ` (lam) | kernel base, spec 1.0001 | `λ>0 ⇒ P>0`; `λ>1 ∧ i>0 ∧ Δi>0 ⇒ P>1` |
| `Δi` (tick spacing) | the **control input** | P strictly monotone↑ in Δi (i>0,λ>1); π strictly monotone↑ in Δi (regime L̄≤ΔI); Δi⋆ closed form drives slippage→0; σ_xs invertible for a Δi hitting any σ_target>d² |
| `η` (elasticity) | ∈(0,1) | tick→price map is **η-free** (`P_half` has no η — η enters at reserve/impact level); η-kernel decomposes onto ½-kernel; in σ alone (η,Δi) collapse to product η·Δi (not separately identifiable); separable only in joint (σ,Lη) |
| `i` (tick) | exponent | constrained by `IsInt24` [−8388608, 8388607]; η-split must keep i₋,i₊ in Int24 (explicit hyps) |
| `L̄` (L_bar) | pool liquidity | `L̄>0` throughout; appears in Δi⋆ and golden bound |
| `ΔI` (trade size) | input shock | regimes `L̄≤ΔI` (large) vs `ΔI<L̄` (small) give opposite π geometry; golden bound `ΔI²+ΔI·L̄≤L̄²` (≈ ΔI ≤ 0.618 L̄) is the *tight* condition for residual monotonicity |
| `#` (sharp) | tick count | `#≥2 ⇒ σ_xs quadratic coeff > 0` (convex in Δi); `#≥1` needed to invert the average |

## 6. Controller relevance — what is and is NOT formally established

PROVED and directly usable by a controller design:
- **Plant gain / monotonicity (sign of dπ/dΔi):** `P_half_strictMono`,
  `pi_trader_half_strictly_increasing_in_Δi` — the actuator (tick spacing Δi)
  moves the controlled output (trader payoff π) monotonically in the large-trade
  regime. Gives a guaranteed control direction.
- **Boundedness / positivity:** `P_half_pos`, `one_lt_P_half` — output stays
  positive / >1; no sign flips of the kernel.
- **Setpoint existence + closed-form inverse (feedforward law):**
  `deltaI_star` + `P_half_at_deltaI_star` + `pi_trader_half_zero_at_deltaI_star`
  give an explicit Δi that zeroes slippage (small-trade); `sigma_xs_poly_target_exists`
  gives an explicit Δi hitting a target cross-section variance. These are
  **invertibility / reference-tracking** results.
- **Small-signal gain (linearization):** `pi_trader_half_small_trade_quadratic`
  — π/ΔI² → P²(P−1)², a usable local gain for a linearized loop.
- **Convexity / extremum location on an admissible band:** band-min and band-max
  theorems + `residual_antitone` + σ_xs convexity (`#≥2`) — tells the controller
  where optima sit (endpoints) and under what regime (golden bound).
- **Identifiability caveat:** (η,Δi) are **not independently identifiable from σ
  alone** (collapse to η·Δi); separable only if Lη (reserves) is also observed.
  Critical for state estimation in any feedback loop.

OPEN / NOT formalized (gaps a controller designer must own):
- **Discrete-time closed-loop dynamics:** no temporal recursion, no state-update
  map, no trajectory. Everything is static/comparative-statics. UNKNOWN in Lean.
- **Stability / Lyapunov / contraction / fixed-point of a feedback iteration:**
  NOT proved. `deltaI_star` is an algebraic setpoint, NOT a contraction map; no
  convergence theorem exists. This is the single biggest gap for "adaptive
  feedback controller."
- **Fixed-point numeric bounds (WAD / Q64.96 / UInt256):** NOTHING. All math is
  over exact ℝ. No overflow, rounding, or fixed-point error lemmas; LeanEVM is
  imported by the project but NOT by eta.lean. Tick-grid arithmetic only as the
  `IsInt24` predicate + `sharp` floor (which under-counts by ≤1 tick on misaligned
  spacing — noted, not bounded).
- **General-η impact/payoff:** only η=½ is instantiated (P_half, pi_trader_half).
  General-η price impact and CES payoff (in eta.md) are not formalized beyond the
  existence of the η-decomposition.
- **Liquidity-kernel (ξ, ι) properties:** unit-sum normalization etc. — paper
  only, not in Lean.
- **Stochastic order flow** (Poisson/LogNormal, the `Δy(t)` proxy): not in Lean.

## 7. One-line takeaway
The Lean layer is a **static comparative-statics / inversion toolkit for the η=½
sqrt-price CFMM**: it rigorously establishes plant sign (monotonicity),
positivity/boundedness, closed-form set-point inverses (zero-slippage Δi⋆ and
variance-target Δi), small-signal gain, and band-optima — everything needed to
justify Δi as a control actuator. It does **not** yet contain any dynamical,
stability/contraction, or fixed-point-arithmetic results, which the on-chain
adaptive feedback controller will have to add.
