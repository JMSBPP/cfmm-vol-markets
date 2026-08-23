# IV-RESEARCH — Kristensen implied volatility → the vol-instruments framework

> STATUS: RESEARCH RECORD. No doc, Lean, or plank file was edited. Feeds the user-approval gate.
> PRIMARY SOURCE: `../plank/refs/lp-derivatives/kristensen-perpetual_options_uniswap_v3-2024.pdf`
> ("Perpetual Options with Uniswap V3", Jesper Kristensen, 2024).
> CITATION CONVENTION BELOW: `p. NN` = the **printed** page number in the book's own footer.
> The PDF page index is `printed + 7` throughout Chapter 3 (verified on 8 anchors).
> Extraction: `pdftotext` (plain and `-layout`), both retained in the session scratchpad.

---

## 0. EXECUTIVE VERDICTS (details below)

| # | Question | Verdict |
|---|---|---|
| 1 | Kristensen's σ_IV | `IV = 2φ·√(VOL/AMT_tick)`, eq (3.16), **p. 69**. It is **σ, not σ²** — the user's note has it as `σ²_IV = 2φ√(·)`; the correct reading is `σ²_IV = 4φ²·(VOL/AMT_tick)`. Dimension: **per √time** (a daily vol; ×√365 to annualize). **His object is ATM by construction (`k = p₀`) ⟹ it is the doc's ALREADY-EXISTING `σ_IV^{ATM}`, not a new symbol.** |
| 2 | Is the `2·√(·)` a `χ=1/2 / ε_{X/M}=0` CES specialization? | **REFUTED as stated.** `2 = √(√(8/π)·√(2π)) = √16` — BOTH constants are Gaussian (Erf Taylor + standard-normal density at 0). The CES curve does not enter Kristensen's derivation at all. **BUT** two genuine hidden specializations exist, and one of them is a `1/2`: the `√` exponent is `1/(ε_{hold,σ} + ε_{lend,σ})` with both σ-elasticities `= 1`, and the `φ²` is really `φ·(t_s/20001)`, i.e. Uniswap's fee-tier↔tick-spacing pairing. General form derived in §2.3. |
| 3 | `VOL/AMT` → the doc's `u`-argument | **NOT the same object — they are two members of ONE CES family separated by ε.** `u`-argument = `ε=0` (geometric) member; `VOL/AMT` = `ε=1` (linear/value) member. Ordered by AM–GM, **equal iff the flow is leg-balanced**. Proposed lemma chain L1–L6, §3. |
| 4 | `L_{(ξ,ι)}` and the time integral | Cleanly separable. Static part: `AMT_tick(i_K) = 2·L̄·ℓ(ξ,ι;i_K)·Δs(i_K)`. **HEADLINE: Kristensen's constant-`AMT_tick` assumption (Remark 3.8, p. 58) holds EXACTLY iff `ξ = λ^{−ηΔ_i/2}`, which at `η=1` is precisely the doc's `ξ★ = λ^{−Δ_i/2}` — the log-contract / variance-swap ladder.** Accumulated part: `TITM` = occupation time; maps to `ν_t = w_t/D_t` and its support `{t : ν_t > 0}` (M6b). |
| 5 | `priceOfRisk` vs interest rates | The protocol's `p_risk = oracle/(1−h)` is a **haircut-inflated collateral price**, not a price of risk and not a yield — it carries no time dimension and no rate. Kristensen's "lending" is **writing a covered call / cash-secured put, NOT fixed-income lending** (false friend). His `α` (risk-free rate) appears only in the exact BS premium (p. 65) and is **dropped** in the ATM approximation that produces (3.16). ⟹ **an exogenous interest rate is a NEW PARAMETER.** Flagged in the collision table; proposed symbol `r_fix`. |

---

## 1. EXTRACTION (Q1)

### 1.1 The chain, with anchors

**(a) Occupation time (`TIT M`), §3.3.4, p. 56–57.**

```
TITM/T = (1/T)·∫_0^T Prob[p_t in range] dt = (1/T)·∫_0^T Erf( ln(r) / (σ√(2t)) ) dt
```

Closed form on p. 57, then the leading term (p. 57):

```
TITM/T = √(8/π) · ln(r) / (σ√T) + [powers of ln(r) of degree ≥ 2]
```

Stated assumptions (p. 57, verbatim list): `T·(µ − σ²/2) ≪ 1`; `p_0 = √(p_a p_b)` (geometric-mean
start); and `Erf(z) = (2/√π)z + O(z³)`.

**(b) Fee decomposition, eq (3.14), p. 58.**

```
fees collected in T days per unit of asset amount deployed
  = (TITM/T) · T · ( φ · VOL/AMT_tick )
     \____ user ____/   \___ pool controlled ___/
```

**(c) Remark 3.8, p. 58** — verbatim content: `AMT_tick` **varies across ticks**; for narrow
ranges it is *expected to stabilize* and (3.14) then holds *approximately*. This is an explicitly
flagged approximation, not an identity. (Load-bearing for Q4.)

**(d) Tick count, p. 58–59.**

```
N = (t_u − t_l)/t_s = 20001·ln(r)/t_s ,   and since Uniswap pairs (φ,t_s) ∈ {(0.05%,10),(0.3%,60),(1%,200)}
                                          we have t_s/20001 ≈ φ  ⟹  N = ln(r)/φ
```

VERIFIED numerically: `10/20001 = 5.00e-4`, `60/20001 = 3.00e-3`, `200/20001 = 1.00e-2` — exact to
4 significant figures. Also `2/ln(1.0001) = 20000.9999…`, so `20001` **is** `2/ln λ`.

**(e) Effective LP return per tick, p. 59; single-tick form eq (3.15), p. 64.**

```
LP return per tick = AMT_pos · (VOL/AMT_tick) · √(8/π) · (√T/σ) · φ²        (3.15)
```

**(f) Lending leg, §3.4.2, p. 65–66.** Exact Black–Scholes premium (p. 65) —

```
Put:  k·e^{−αT}·N(−d₂) − p₀·N(−d₁)      Call: p₀·N(d₁) − k·e^{−αT}·N(d₂)
```

— with **α the risk-free rate**. ATM (`k = p₀`) with `µ ≪ σ²/2` and `σ√T/2 ≪ 1` (p. 66):

```
premium ≈ k·[N(σ√T/2) − N(−σ√T/2)] ≈ k·(1/√(2π))·2·(σ√T/2) = k·σ·√(T/2π)
```

**α does not survive this approximation.** Every downstream statement (the hold-vs-lend condition
and (3.16)) is therefore **rate-free**.

**(g) Hold vs lend, §3.4.3, p. 67.**

```
(VOL/AMT_tick)·√(8/π)·(√T/σ)·φ²   vs   σ·√(T/2π)
  \_______ hold position _______/       \_ lend option _/

hold ≻ lend  ⟺  VOL/AMT_tick > (σ/(2φ))²
```

**(h) THE DEFINITION, eq (3.16), p. 69.**

```
VOL/AMT_tick = (IV/(2φ))²    ⟹    IV = 2φ·√( VOL/AMT_tick )        (3.16)
```

Its justification (p. 69, verbatim intent): assume the option market has priced in the expected LP
return (efficient-market footnote), so option premium and LP expected return **converge**; `IV` is
the σ at which they are equal.

### 1.2 What VOL and AMT_tick ARE, in his own terms

| Symbol | Kristensen's words | Units | Scope | Stock/flow |
|---|---|---|---|---|
| `VOL` | "the daily trading volume within the liquidity range" (p. 64) | **value/day** (USD/day) | **pool-wide** daily volume; he then *assumes* it all executes at the single tick — stated outright on p. 69: "We assume that trading activity of the total daily volume $70.5 million is done within the single tick" | **FLOW (rate)** |
| `AMT_tick` | "the total amount of assets locked in each tick" (p. 64) | **value** (USD) | **per TICK**, not per position; varies across ticks (Remark 3.8) | **STOCK** |
| `AMT_pos` | "the amount of liquidity deployed in the position" (p. 64) | value | **per POSITION** | STOCK |

⟹ `VOL/AMT_tick` has units **day⁻¹**. It is a **turnover rate**, not a dimensionless ratio.
⟹ `IV = 2φ√(VOL/AMT_tick)` has units **day^(−1/2)** — a volatility **per √time**, which is why
Example 3.10 (p. 69) multiplies by `√365` to annualize. `σ_IV` is **not** dimensionless.

### 1.3 Numerical replication (all recomputed, none taken on trust)

| Claim | Book | Recomputed | Note |
|---|---|---|---|
| Ex 3.9 `VOL/AMT` | 55.77 | **55.7697** | ✓ |
| Ex 3.9 `(σ/2φ)²` | 76.1 | **76.10** at φ=0.003; **7610.3** at φ=0.0003 | ⚠ **The text on p. 67 states `ϕ = 0.0003`. That is a TYPO.** The pool is labelled "ETH-DAI-0.3%" and both printed numerics require `φ = 0.003`. |
| Ex 3.9 LP return | 1.53%/√day, 29.2%/yr | **1.530%**, **29.2%** | ✓ — but only with `φ = 0.003`. Confirms (3.15) independently. |
| Ex 3.10 annual IV | 41% | **41.04%** | ✓ |
| Ex 3.11 daily IV / 1-week band | 2.15%, ±227 | **2.148%**, **±227.34** | ✓ |
| `√(8/π)·√(2π)` | (implicit) | **exactly 4.0** | the source of the `2`; see §2 |

---

## 2. THE `2` AND THE `√` (Q2) — DERIVED, NOT ASSERTED

### 2.1 Where the `2` comes from

Set (3.15) equal to the ATM premium per unit notional and solve for σ:

```
√(8/π)·(√T/σ)·φ²·R  =  σ·√(T/2π)          [R := VOL/AMT_tick]
⟹ σ² = φ²·R · √(8/π)·√(2π) = φ²·R·√(8/π · 2π) = φ²·R·√16 = 4φ²R
⟹ σ_IV^{ATM} = 2φ√R
```

The `4` is `√(8/π · 2π) = √16`. Its two factors are **both Gaussian and both from Black–Scholes/GBM**:

- `√(8/π)` ← the Erf Taylor expansion `Erf(z) ≈ 2z/√π` used on the occupation time (p. 57).
- `1/√(2π)` ← the standard normal **density at zero**, `N(x) − N(−x) ≈ 2x·ϕ(0) = 2x/√(2π)` (p. 66).

`8/π · 2π = 16` is a numerical coincidence of two Gaussian constants. **Neither `χ_{X/M}` nor
`ε_{X/M}` nor the trading curve appears anywhere in the derivation.** The user's hypothesis, taken
literally ("the 2 is the χ = 1/2 / ε = 0 specialization of `φ_{χ,ε}`"), is **REFUTED**.

### 2.2 Where the `√` comes from — and this one IS a `1/2`

The exponent is a quotient of **σ-elasticities**, not a curve parameter. Under the 2026-08-03
binding rule these are ε-named with new subscripts (freeness checked in §6):

```
ε_{hold,σ} := −∂ln(hold leg)/∂ln σ ,      ε_{lend,σ} := ∂ln(lend leg)/∂ln σ
hold ∝ σ^{−ε_{hold,σ}}·K ,  lend ∝ σ^{+ε_{lend,σ}}
⟹  σ^{ε_{hold,σ}+ε_{lend,σ}} ∝ K   ⟹   σ_IV^{ATM} = (C·K)^{1/(ε_{hold,σ}+ε_{lend,σ})}
```

Kristensen has `ε_{hold,σ} = 1` (occupation time `∝ 1/σ`, from the Erf linearization) and
`ε_{lend,σ} = 1` (ATM BS premium `∝ σ`). Hence exponent `1/(1+1) = 1/2`. **The `1/2` is real and
structural — but it is the `1/2` of a σ-elasticity split, not of a CES share.** It ceases to be
`1/2` the moment either leg's σ-elasticity changes (a non-Gaussian occupation law, or a
non-ATM/non-linearized premium).

### 2.3 The genuine hidden specialization — and the general-(χ,ε) statement

Undo the step `t_s/20001 = φ` (p. 59). The per-tick return before that substitution is

```
per-tick return = √(8/π)·(√T/σ)·φ·(t_s/20001)·R
```

so in general `(σ_IV^{ATM})² = 4·φ·(t_s/20001)·R` — the **square on φ is an artifact of Uniswap's
fee-tier↔tick-spacing schedule**, nothing more. In OUR grid `p_{(η,Δ_i)}(i) = λ^{(i/2)Δ_i η}`
the per-tick log-price step is `(ηΔ_i lnλ)/2`, so the framework-native form is

```
σ_IV^{ATM} = 2 · √( φ · (η Δ_i lnλ)/2 ) · √( R )
```

REDUCTION CHECK (numerical): at `η = 1`, `λ = 1.0001`, `Δ_i = t_s`, `(ηΔ_i lnλ)/2 = t_s·4.99975e-5`
and `t_s/20001 = t_s·4.99975e-5` — agreement to 9 significant figures. ✓ Kristensen's `2φ√R` is the
`η = 1`, `Δ_i = 20001·φ` member.

**This is the answer to "is it a special case?": YES, but the specialized axes are `(η, Δ_i)`
versus `φ`, not `(χ_{X/M}, ε_{X/M})`.** In `Θ_p = {η, Δ_i}` and `Θ_φ` the two are independent, so
our framework has a strictly more general IV than Kristensen's, with `√φ` not `φ`.

### 2.4 Where the CES curve genuinely CAN enter

Not through the constants — through `R`. See §3: `R` is itself a member of a CES-indexed family,
and the doc's `u`-argument is a different member of that same family. That is the correct location
for `(χ_{X/M}, ε_{X/M})` in this story.

---

## 3. `VOL/AMT` → the utilization `u` (Q3) — PROPOSED LEMMA CHAIN

### 3.0 Setup and the objects being compared

Doc side (Theorem 1, Fee Envelope, doc line 466; Lean `VolInstrument.sigmoidR`):

```
u = sigmoidR α_R γ_R β_R (x),        x = φ_{1/2,0}(i_K; ΔQ, 0; t) / φ_{1/2,0}(i_K; 0, L; t)
```

With `φ_{1/2,0}(a,b) = √(ab)` and the definition at doc line 315, `L = 0` kills the `ΔQ^L` terms in
the numerator and `ΔQ = 0` kills the exogenous terms in the denominator:

```
x = √( ΔQ_M · ΔQ_X ) / √( ΔQ_M^L(i_K) · ΔQ_X^L(i_K) )
```

Kristensen side: `R = VOL/AMT_tick`, both legs aggregated **in value**.

### 3.1 L1 — TICK VALUE-BALANCE (exact, provable, NOT an assumption)

From `VolInstrument.deltaQM/deltaQX` with `s(i) := priceEta η Δ_i i`:

```
ΔQ_M^L(i_K) = L(i_K)·Δs/(s_- s_+),      ΔQ_X^L(i_K) = L(i_K)·Δs,      Δs := s_+ − s_-
```

Therefore, with `P̄(i_K) := s(i_K)·s(i_K+Δ_i)`,

```
P̄(i_K) · ΔQ_M^L(i_K) = ΔQ_X^L(i_K)          (EXACT, all L, all η, Δ_i)
```

i.e. **the tick inventory is value-balanced exactly at the geometric-mean price of the tick's two
edges.** Since `s` is the sqrt-price grid, `P̄ = s_- s_+` is precisely Kristensen's
`k = √(p_a p_b)` (his §3.5, p. 70). The `χ_{X/M} = 1/2` reading is thus *earned at the tick*, not
imposed. **Hypotheses:** `η Δ_i > 0`, `Δ_i ≥ 0`, `L ≥ 0` (the doc's own guard, line 269).

### 3.2 L2 — the `u`-argument FACTORIZES into per-leg turnovers

Define `R_M := ΔQ_M/ΔQ_M^L(i_K)`, `R_X := ΔQ_X/ΔQ_X^L(i_K)`. Multiplicativity of `√(·)` gives

```
x = √( R_M · R_X )   =   GM(R_M, R_X)
```

### 3.3 L3 — Kristensen's `R` is the ARITHMETIC member

Aggregating both legs in value at `P̄` and using L1 (`P̄ΔQ_M^L = ΔQ_X^L`, so the two value weights
are equal):

```
R = VOL/AMT_tick = (P̄ΔQ_M + ΔQ_X)/(P̄ΔQ_M^L + ΔQ_X^L) = (R_M + R_X)/2 = AM(R_M, R_X)
```

### 3.4 L4 — THE BRIDGE (AM–GM), and it is an INEQUALITY, not an identity

```
x = GM(R_M,R_X)  ≤  AM(R_M,R_X) = VOL/AMT_tick ,     equality ⟺ R_M = R_X
```

`R_M = R_X` says the exogenous flow is **leg-balanced at the tick price** — a swap that is executed
at `P̄` and does not tilt the tick's inventory ratio. **HONEST VERDICT: the doc's `u`-argument and
Kristensen's `VOL/AMT` are NOT the same object; they coincide exactly on leg-balanced flow and the
doc's object is otherwise strictly smaller.**

### 3.5 L5 — the two are ONE CES family, separated only by `ε_{X/M}`

Define the general ratio `x_{χ,ε} := φ_{χ,ε}(ΔQ_M, ΔQ_X) / φ_{χ,ε}(ΔQ_M^L, ΔQ_X^L)` (after price
normalization of the X leg). Then:

- `ε_{X/M} = 0, χ_{X/M} = 1/2` ⟹ `x` = the doc's `u`-argument (geometric turnover).
- `ε_{X/M} = 1` ⟹ `φ_{χ,1}(Q_X,Q_M) = χQ_X + (1−χ)Q_M` is an **arithmetic value aggregate**; with
  `χ/(1−χ) = P̄` it is exactly `VOL` over `AMT_tick`. ⟹ **Kristensen's ratio is the LINEAR
  (`ε=1`, zero-curvature `κ_φ = 0`, perfect-substitutes) member.**
- Under L1 the denominator legs are equal, so `x_{1/2,ε} = M_ε(R_M,R_X)` (the power mean) and is
  **increasing in `ε_{X/M}`** — recovering L4 as the `ε: 0 → 1` special case.

VERIFIED numerically (`R_M=0.7, R_X=3.1`): `ε = −2,−1,0,0.5,1,2 ↦ 0.9656, 1.1421, 1.4731, 1.6865,
1.9000, 2.2472`; monotone, `ε=0` = GM = 1.4731, `ε=1` = AM = 1.9. ✓

### 3.6 L6 — price normalization is a `χ` shift (so the ratio is well-posed)

`φ_{χ,ε}(pQ_X, Q_M) = (χp^ε + (1−χ))^{1/ε} · φ_{χ',ε}(Q_X,Q_M)` with `χ' = χp^ε/(χp^ε + (1−χ))`.
The scalar prefactor is common to numerator and denominator, so

```
x_{χ,ε}(price-normalized) = x_{χ',ε}(raw)
```

⟹ **applying the tick price to the X leg is exactly a reparametrization along the SHARE axis**, and
the ratio is invariant. VERIFIED numerically on 4 random `(χ, ε, p)` draws, agreement to 1e-15. ✓

### 3.7 WHAT WOULD MAKE L1–L6 FALSE — flag list

1. **SIGN OF THE FLOW LEGS (BLOCKER-grade).** The doc never states whether `ΔQ = (ΔQ_M, ΔQ_X)` is
   signed. A swap has one leg in and one out. If signed, `φ_{1/2,0}(ΔQ_M,ΔQ_X) = √(ΔQ_MΔQ_X)` is
   **not real**, and the `u`-argument (and Theorem 1's `u ∈ [0,α_R]`) is ill-posed on exactly the
   flow it is meant to measure. If magnitudes, then a one-directional swap has both legs positive
   and the lemmas hold. **This must be pinned before any Aristotle bundle.** Note the Lean docstring
   for `sigmoidR` already hedges: "`x` remains abstract because the document does not specify
   behavior when its flow-region denominator vanishes."
2. **ONE-SIDED FLOW.** If either leg is zero (a pure single-asset deposit), `x = 0` while
   `VOL/AMT_tick > 0`. The geometric member **collapses** where the arithmetic member does not.
   L4's inequality still holds (0 ≤ AM) but the identification is vacuous there.
3. **TIME AGGREGATION.** `VOL` is per **day**; the `u`-argument's `ΔQ` is a per-**step** flow.
   `β_R` is calibrated in whatever time unit `ΔQ` carries. The two ratios are commensurable only
   after a stated time base. Not currently stated anywhere in the doc.
4. **`AMT_tick` VS THE LADDER.** Kristensen's `AMT_tick` is constant across ticks by Remark 3.8;
   ours is `ℓ(ξ,ι;i_K)`-weighted. See §4 — they agree only at one `ξ`.
5. **THE `L=0` DEGENERACY.** `φ(i_K; 0, L; t)` with `L = 0` is `0`, so `x` is undefined on an empty
   tick. Guard `L(i_K) > 0` required.
6. **η, Δ_i SIGNS.** L1 needs the doc's own `ηΔ_i > 0 ∧ Δ_i ≥ 0` guard (line 269), otherwise `Δs`
   flips sign and the "value" is negative.

---

## 4. `L_{(ξ,ι)}` AND THE TIME INTEGRAL (Q4)

### 4.1 The user's conjecture is TWO conjectures — separate them

The user wrote `φ_{χ,ε}(∫_{t_0}^t)(some metric of trading volume)/AMT_tick`, i.e. a curve
evaluation of a **time-integrated volume** over a **ladder-weighted** denominator. In Kristensen:

- there is **no trading-curve evaluation at all** — his numerator is a plain scalar volume;
- `VOL` is a **rate**, already per-day, treated as constant — **it is not the integrated object**;
- the genuinely integrated object is `TITM = ∫_0^T ℙ[p_t ∈ range] dt` (p. 56), the **occupation
  time**, which multiplies the fee term in (3.14).

So: **static ladder ↔ `AMT_tick`; accumulated flow ↔ `TITM` and the per-step turnover, not `VOL`.**

### 4.2 STATIC PART — `AMT_tick(i_K)` in our objects

Using L1, the tick's inventory **value** is `P̄ΔQ_M^L + ΔQ_X^L = 2ΔQ_X^L`, hence

```
AMT_tick(i_K) = 2·L̄·ℓ(ξ,ι;i_K)·Δs(i_K),        Δs(i_K) = s(i_K)·(g − 1),  g := λ^{ηΔ_i/2}
```

The user is right that `AMT` maps to `L(i_K) = L̄·ℓ(ξ,ι;i_K)` — but only through the **linear** map
`ΔQ^L`, and the grid contributes a second, `i_K`-dependent factor `Δs(i_K) ∝ g^{i_K}`.

### 4.3 THE HEADLINE — Kristensen's Remark 3.8 pins `ξ` to `ξ★`

`AMT_tick(i_K) ∝ ξ^{i_K} · g^{i_K} · (g−1) = (ξg)^{i_K}(g−1)`. Constant in `i_K` **iff** `ξg = 1`:

```
AMT_tick(·) constant   ⟺   ξ = λ^{−ηΔ_i/2}     and at η = 1:   ξ = λ^{−Δ_i/2} = ξ★
```

`ξ★ = λ^{−Δ_i/2}` is **exactly** the doc's log-contract / variance-swap replicating weight
(doc line 232; `GeomProfile`, `logContractLiquidity_geometric`, `VolInstrument.strikeWeight_bridge`).

> **Kristensen's constant-`AMT_tick` approximation is not an approximation in our framework — it is
> the exact statement that the ladder is the variance-swap ladder.** Equivalently: the log-contract
> ladder is precisely the ladder with uniform notional per tick, which is the geometry under which
> (3.14)–(3.16) are exact rather than "approximately hold for narrow ranges".

This is the strongest single result of this research pass. It is currently **ASSERTED-with-derivation**
(algebra above is elementary and reproducible); it is an obvious Aristotle target.

CAVEAT to pin before formalizing: the index origin of `ξ^{i_K}` (measured from `i_min` per
`GeomProfile.geomWeight`, vs from the strike). `η` also enters, so at `η ≠ 1` the AMT-flattening
`ξ` and the log-contract `ξ★` **separate** — the coincidence is an `η = 1` statement. That is
itself a testable consequence, and it is a new η-lever finding.

### 4.4 ACCUMULATED PART — `TITM`, `ν_t`, and `streamingPremium`

Kristensen's holding return over `T`, with the occupation term written out:

```
hold(T) = φ · (TITM/T) · T · R = φ · Σ_t 1[i(t) ∈ K] · ν_t ,      ν_t := w_t/D_t
```

because `w_t` is "per-step traded amount" and `D_t` is "the SAME capital denominator" (doc lines
682–683). ⟹ **`ν_t` IS Kristensen's `VOL/AMT_tick`, per block instead of per day; `W = Σ_t ν_t` is
the T-day accumulation; and `TITM/T` is the measure of `{t : ν_t > 0}`** — the very set M6b's
equality condition is stated on. Nothing new needs to be defined.

Consequently, at constant fee `φ`, `λ_FLAIR = φ·W` is **exactly** Kristensen's holding return, with
the in-range gating already carried by `w_t = 0` off-range. The dynamic-fee generalization is the
doc's own `λ_FLAIR = φ̄W + uΣ_jα_jW_j`.

On the LEND side, `Panoptic.streamingPremium` `Σ_N = Σ_{j<N}θ_jΔt` is the doc's accumulator for the
option's time decay. The doc's **streamia** assignment `φ ⟸ θ` says the fee *is* the theta; taking
that assignment as an **aggregate equality** rather than a per-step identification is **exactly
Kristensen's IV condition**. That is the conceptual payoff of this whole exercise.

### 4.5 The doc-native IV definition that falls out

```
σ_IV^{ATM}(T) := √(2π/T) · λ_FLAIR(T)                       [reduced / observable form]
```

Dimension check: `λ_FLAIR` is dimensionless (income per capital over `[t_0,t]`); `√(2π/T)` is
`T^{−1/2}` ⟹ `σ_IV^{ATM}` is per √time ✓ (matches §1.2). Consistency check: substituting Kristensen's
structural `λ_FLAIR = √(8/π)(√T/σ)φ²R` and setting `σ = σ_IV^{ATM}` reproduces `(σ_IV^{ATM})² = 4φ²R` ✓.

Two readings, both worth stating:
- **STRUCTURAL:** `W` is modelled `∝ 1/σ` (occupation time) ⟹ closed form `σ_IV^{ATM} = 2√(φ·(ηΔ_ilnλ)/2·R)`,
  and `σ_IV^{ATM}` is a **fixed point** because `W` depends on the σ being solved for.
- **REDUCED:** `W` is measured from chain data ⟹ `σ_IV^{ATM} = √(2π/T)·λ_FLAIR(T)` is a **model-free
  implied vol read directly off the FLAIR accumulator**. This is new relative to Kristensen and is,
  in my view, the most useful deliverable of the track: it makes `σ_IV^{ATM}` a functional of `Θ_φ`.

---

## 5. `priceOfRisk` VS INTEREST RATES (Q5)

### 5.1 What the protocol actually computes

Read: `../plank/src/lib/exposure/VegaIssuanceLib.plk`,
`../plank/src/lib/exposure/PanopticVegaLensLib.plk`,
`../plank/src/types/exposure/VegaExposure.plk`,
`../plank/src/modules/exposure/VegaAccountMod.plk`.

```
haircut_risk_price(oracleX96, hX96) = oracleX96 · 2^96 / (2^96 − hX96)        // p_risk = oracle/(1−h)
issue_shares(deposit, p_risk)       = deposit · 2^96 / p_risk
dqv_funded(ΔQ_v★, Q_M, p_risk)      = min(ΔQ_v★, Q_M·2^96/p_risk)
implied_maturity(dqv, N_σ)          = 2·dqv/N_σ                               // seconds
```

`p_risk` is documented in `PanopticVegaLensLib.plk` as "Q64.96 LINEAR (collateral per L unit)", is
set by an **unauthenticated exogenous setter** (`SELECTOR_SET_RISK_PRICE`, deliberately so in v1),
and is stored in `VegaExposure.VegaNominal.priceVolX96` with the comment "carries the exogenous
`p_risk` in v1".

**FINDING:** `p_risk` is a **haircut-inflated collateral valuation** — a margin price. It has:
no time dimension, no accrual, no rate, no comparison to any alternative return. It is **not** a
"price of risk" in the market-price-of-risk / Sharpe sense, and it is **not** a yield. Calling it
the entry point for opportunity cost is a **name-driven inference, not a code-driven one**.

What it *does* give the framework is the **only exogenous, oracle-fed price in the vega stack** —
so it is the natural **socket** into which an exogenous rate would be wired, even though it is not
itself that rate.

(Related: `model/vol_markets/risk.md` sketches `RiskDiscount{price, factor = haircut/price}` and
`collateralAmt·(price/haircut)` — algebraically inconsistent with the shipped
`oracle/(1−h)`. Recorded, not acted on: `risk.md` is a design sketch, the plank code is the truth.)

### 5.2 Kristensen's LP-vs-lending, precisely, and the FALSE FRIEND

**"Lending a Uniswap V3 LP position" (§3.4.2, p. 65) means WRITING AN OPTION** — "Deploying a
single tick LP position limited for T days is akin to a cash-secured put (or covered call) with
strike k that expires in T days. Consequently, a fair price for lending the LP position is the
premium from the sold put (or call)". It does **not** mean depositing into a money market.

⟹ Kristensen's comparison is **risky-vs-risky** (fee income vs option premium). The risk-free rate
`α` enters only the exact BS premium (p. 65) and is **annihilated** by the ATM approximation
(p. 66). **There is no fixed-income opportunity-cost condition anywhere in Kristensen.** The user's
reading of the section is a reasonable guess from its title and is **not supported by the text**.

### 5.3 The condition he DOES imply, in our notation

```
HOLD ≻ WRITE   ⟺   λ_FLAIR(T)  >  σ_R·√(T/2π)
```

and structurally, with the §2.3 grid form,

```
HOLD ≻ WRITE   ⟺   ν̄  >  σ_R² / ( 4·φ·(ηΔ_i lnλ)/2 )        [ν̄ := W/T, the mean turnover rate]
```

which at `η=1, Δ_i = 20001φ` collapses to `R > (σ/2φ)²` ✓ (p. 67).

### 5.4 The exogenous rate IS a new parameter — and what it buys

To add the third leg the doc must gain an object it does not have. Grep evidence: `risk-free`,
`risk free`, `interest rate`, `discount`, `yield`, `Sharpe`, `opportunity cost` return **zero
matches** in `VOLATILITY_INSTRUMENTS.md` outside the user's own line-1484 note. `numeraire` occurs
only inside the Capponi canonical-curve block (`p_B = 1`), which is a price normalization, not a
rate. **CONFIRMED: an exogenous interest rate is a NEW PARAMETER. It must be introduced explicitly,
never silently.**

Proposed three-way comparison (per unit notional, horizon `T`):

```
λ_FLAIR(T)          [LP: hold]        ~ √T
σ_IV^{ATM}·√(T/2π)  [write the option]~ √T
exp(r_fix·T) − 1    [fixed income]    ~ T
```

**NEW RESULT (derivable, elementary):** the fixed-income leg is `O(T)` while both crypto legs are
`O(√T)`, so there is always a crossing horizon

```
r_fix·T = σ·√(T/2π)   ⟹   T_c = σ² / (2π r_fix²)
```

⟹ **the exogenous rate binds only when `σ ≤ r_fix·√(2πT)`.** At `r_fix = 5%/yr` and `T = 1yr` that
threshold is `σ ≤ 12.5%/yr` — i.e. at crypto volatilities the fixed-income leg is essentially
**never** the binding alternative. Honest consequence: **adding `r_fix` is conceptually necessary
but quantitatively inert in the current regime**, and the addendum says so rather than dressing it
up as a live lever.

The plank socket: `r_fix` would have to enter through `p_risk` acquiring a carry term (e.g. a
funding-adjusted `p_risk(t)`), or through a separate accrual on `Q_M`. Neither exists. Out of scope
for this session (plank source is `ul2inqpl`'s), recorded as a cross-track note.

---

## 6. NOTATION COLLISION TABLE (freeness checked by grep against `VOLATILITY_INSTRUMENTS.md`)

> **BINDING (user, 2026-08-03), applied throughout:** `ε` is reserved for ELASTICITIES, always
> subscripted; `σ` is reserved for VOLATILITIES and VARIANCES and is never an elasticity. The
> elasticity of substitution is `\bar\epsilon_{X/M} = 1/(1−\epsilon_{X/M})` (doc line 323) — `σ_ES`
> is dead and appears nowhere in these deliverables (verified by grep). Any new elasticity takes an
> `ε` with a NEW subscript; any new volatility takes a `σ` with a subscript.

| Kristensen | Ours | New? | Freeness check | Decision |
|---|---|---|---|---|
| `IV` | **`σ_IV^{ATM}`** | **NO — already in the doc.** Lines 1384, 1406, 1413, 1440 (Greeks block G2/G3): `σ_IV(K)/σ_IV^{ATM} = f(K/p; η_L)`, the DIAGNOSTIC control-matrix row. | `\sigma_{IV}` 4 hits, `\sigma_{IV}^{ATM}` 4 hits | **REUSE `σ_IV^{ATM}`. Mint NOTHING.** Kristensen's derivation is ATM by construction (`k = p₀`, p. 66), so his object is the `^{ATM}` one exactly. **SYNTHESIS (§6.2): this closes the doc's DIAGNOSTIC row — the Greeks block has the SHAPE and no LEVEL; Kristensen supplies the LEVEL.** |
| — | `σ²_I(0)` (doc line 160, declared, never defined) | pre-existing | 1 hit | **DO NOT TOUCH.** It may or may not be the same object as `σ_IV^{ATM}`. Raising it, not resolving it — see OPEN §8.4. |
| `σ`-elasticities of the two legs | `ε_{hold,σ}`, `ε_{lend,σ}` | **YES — NEW (elasticity family)** | only `\epsilon_{X/M}` exists (39 hits); `\text{hold}` / `\text{lend}` subscripts: **0 hits** — FREE | **MINT, FLAGGED.** Required by the 2026-08-03 rule: these are elasticities, so they must be `ε` with a new subscript, and they may not be called `a`, `b`, or any `σ`-name. |
| `σ` (realized) | `σ_R` | no | in use | as-is |
| `VOL` | `w_t` (per-step traded amount), `W = Σ_t w_t/D_t` | no | in use (FLAIR) | **map, do not mint**. `VOL ↦ w_t/Δt`. |
| `AMT_tick` | `2·L̄·ℓ(ξ,ι;i_K)·Δs(i_K)`; aggregate `D_t` | no | in use | **map, do not mint** |
| `VOL/AMT_tick` | `ν_t = w_t/D_t` (M6b) | no | `ν` explicitly reserved by the doc, line 909 | **REUSE `ν`.** Tick-local reading `ν_t(i_K)` is an argument, not a new symbol. |
| `TITM/T` | `(1/T)∫_0^T ℙ_{i(t)∈K} dt` | no | `ℙ_{event}` is the doc convention | **write it out; mint nothing.** `Υ` rejected (confusable with `υ` = vega, 38 uses). |
| `AMT_pos` | `ΔQ_v★` / `Σ_{i_K}L(i_K)` | no | in use | map |
| `k = √(p_a p_b)` | `P̄(i_K) = p_{(η,Δ_i)}(i_K)·p_{(η,Δ_i)}(i_K+Δ_i)` | no | derived object | map |
| `r` (range factor) | `λ^{nΔ_i η/2}` | no | — | **never write bare `r`**; `r` collides with the rate below |
| `φ` (his fee) | `φ` | no | in use | same |
| `α` (his RISK-FREE RATE) | — | **COLLISION** | `α_j`, `α_R` = fee amplitudes, `Θ_φ = {γ,φ̄,β,α}` | **Kristensen's `α` MUST be remapped.** |
| — | `r_fix` (exogenous fixed-income rate) | **YES — NEW** | `\rho` free (0 hits) but reserved by Lean `phiCES ρ` = the doc's `ε_{X/M}`; `\varrho` taken (66, valuation premia); `\vartheta` taken (21, JIT); `\varpi` taken (16); `α` taken; bare `i` taken (tick index) | **MINT `r_{\text{fix}}`** — roman, subscripted, no Greek collision, subscript mandatory because bare `r` is Kristensen's range factor. **FLAGGED AS NEW. Requires user approval.** |
| — | `T_c` (rate-crossing horizon) | **YES — NEW, derived** | `T`, `T★`, `T★_joint` in use; `T_c` free | **MINT `T_c`, low risk** (it is a derived quantity, not a parameter). **FLAGGED.** |

### 6.1 A LEAN-SIDE NAMING TRAP (must be in any Aristotle prompt)

`PhiCES.lean` line 24: `phiCES (ρ ε x y) = (ε·x^ρ + (1−ε)·y^ρ)^(1/ρ)`.
⟹ **Lean `ε` is the SHARE (doc `χ_{X/M}`) and Lean `ρ` is the SUBSTITUTION EXPONENT (doc
`ε_{X/M}`).** The two letters are *swapped* relative to the doc. Any bundle that writes
`phiCES ε_{X/M} χ_{X/M} …` will be silently wrong. (The doc's line-407 mapping note covers
`EtaTilde`, not `PhiCES`.)

### 6.2 SYNTHESIS — Kristensen supplies the LEVEL the Greeks block is missing

The doc already carries an implied-volatility object, in the Greeks blocks:

```
σ_IV(K)/σ_IV^{ATM} = f(K/p; η_L)        — independent of δ and L̄        (doc line 1384)
```

and the control matrix declares that row **DIAGNOSTIC** precisely because it is an *observable*, a
depth-invariant identification readout for `η_L`, and not a design target (doc line 1413). Note
what it is: a **SHAPE**, normalized by an ATM level that the document never pins.

Kristensen (3.16) is exactly that missing **LEVEL**, and it is ATM by construction (`k = p₀`):

```
σ_IV^{ATM} = 2·√( φ · (ηΔ_i lnλ)/2 · ν̄ )       [§2.3, framework-general form]
σ_IV(K)    = σ_IV^{ATM} · f(K/p; η_L)          [doc line 1384, unchanged]
```

⟹ **the two together determine the whole smile from pool observables** — level from turnover and
the fee/grid pair, shape from `η_L`. This is the single most valuable structural consequence of
the track and it requires no new symbol whatsoever. It does NOT resolve E8(6) (`η_L = η`) and no
display above assumes it: the level uses the grid `η`, the shape uses the CEV `η_L`, and they stay
distinct.

---

## 7. ASSERTED vs PROVEN vs NEEDS-ARISTOTLE

### PROVEN (already in the tree, cited, unchanged by this pass)
- `VolInstrument.sigmoidR_mem`, `multiFee_bounds`, `multiFee_monotone` — Theorem 1 envelope.
- `VolInstrument.deltaQM_token0`, `deltaQM_nonneg`, `deltaQX_nonneg` — the leg forms L1 rests on.
- `GeomProfile.geomWeight_sum/_pos/_tendsto_uniform`, `logContractLiquidity_geometric`,
  `VolInstrument.strikeWeight_bridge` — the `ξ★` ladder §4.3 rests on.
- `PhiCES.phiCES_homogeneous/_pos/_mono`, `phiCES_zero_half_eq_geom`, `phiCES_one` — L5/L6 rest on.
- `FlairOptimization.flairMulti_affine`, `W_j_lt_W` — the `λ_FLAIR = φ̄W + uΣα_jW_j` form of §4.4.
- `Panoptic.streamingPremium`, `streamingPremium_succ` — the lend-side accumulator.

### VERIFIED BY RECOMPUTATION (this pass, arithmetic — not machine-checked proof)
- `√(8/π)·√(2π) = 4` exactly.
- Kristensen Examples 3.9 / 3.10 / 3.11 all reproduce (3.9 only with `φ = 0.003`; **the printed
  `ϕ = 0.0003` is a typo**).
- `t_s/20001 ≡ (ηΔ_i lnλ)/2` at `η=1, λ=1.0001` to 9 s.f.; `2/ln(1.0001) = 20000.9999…`.
- L5 power-mean monotonicity and L6 price-rescale invariance, on random draws.

### ASSERTED (derived here, elementary, NOT machine-checked)
- §2.1 the `4 = √16` decomposition and its Gaussian provenance.
- §2.2 the `1/(a+b)` homogeneity reading of the `√`.
- §2.3 the general grid form `σ_IV^{ATM} = 2√(φ·(ηΔ_ilnλ)/2·R)`.
- §3.1–3.6 lemmas L1–L6.
- §4.3 `AMT_tick` constant ⟺ `ξ = λ^{−ηΔ_i/2}`, `= ξ★` at `η=1`.
- §4.5 `σ_IV^{ATM}(T) = √(2π/T)·λ_FLAIR(T)` and its fixed-point reading.
- §5.4 `T_c = σ²/(2πr_fix²)` and the `σ ≤ r_fix√(2πT)` binding threshold.

### NEEDS AN ARISTOTLE BUNDLE (proposed, ordered by value)
| ID | Statement | Risk |
|---|---|---|
| **IV1** | L1: `P̄(i_K)·ΔQ_M^L(i_K) = ΔQ_X^L(i_K)` exactly, under the doc's `ηΔ_i>0 ∧ Δ_i≥0 ∧ L≥0` guard. | low |
| **IV2** | L2 + L4: `x = √(R_MR_X) ≤ (R_M+R_X)/2`, equality iff `R_M = R_X`. | low; needs the sign decision (§3.7.1) |
| **IV3** | L5: `x_{1/2,ε} = M_ε(R_M,R_X)` monotone in `ε`; `ε=0` ↦ doc `u`-arg, `ε=1` ↦ `VOL/AMT`. | medium (`Real.rpow` domain, the `ε→0` limit is `phiCES_tendsto_phiEps`) |
| **IV4** | L6: price-rescale ⟺ `χ`-shift; ratio invariance. | low |
| **IV5** | §4.3: `i ↦ ℓ(ξ,ι;i)·Δs(i)` constant ⟺ `ξ·λ^{ηΔ_i/2} = 1`; and at `η=1` that `ξ = ξ★`. | low–medium |
| **IV6** | §2.2: if `hold ∝ σ^{−a}K`, `lend ∝ σ^{b}`, then the equalizing σ is `(CK)^{1/(a+b)}`; specialize `a=b=1`. | low |
| **IV7** | §5.4: `∃! T_c > 0` with `r_fix T = σ√(T/2π)`, `T_c = σ²/(2πr_fix²)`; sign of the difference either side. | low |
| **IV8** | §4.5: `σ_IV^{ATM}(T) = √(2π/T)λ_FLAIR(T)`; and existence/uniqueness of the fixed point when `W ∝ 1/σ`. | medium — needs a σ-dependence axiom for `W`, which the doc does NOT currently have. **Do not bundle until the user rules on it.** |
| **IV9** | §6.2: the composition `σ_IV(K) = σ_IV^{ATM}·f(K/p;η_L)` is well-posed with `σ_IV^{ATM} > 0` under `φ>0, ηΔ_i>0, ν̄>0`; the level is `η_L`-free and the shape is `(φ,ν̄)`-free (orthogonality of level and shape). | medium — the shape `f` is not currently a Lean object; may need to be axiomatized, in which case **state it as a hypothesis, do not fabricate `f`.** |

**DO NOT BUNDLE:** anything that requires Kristensen's occupation-time law `TITM/T = √(8/π)ln r/(σ√T)`
as a *hypothesis about our grid*. That law is GBM-specific, uses two stated small-parameter
assumptions (p. 57), and importing it would be exactly the kind of unearned transfer the `ptrade`
negative-fee pole and the T24 refutation were caused by.

---

## 8. OPEN QUESTIONS (severity-ordered)

1. **[BLOCKER] Are the `ΔQ` legs signed or magnitudes?** Everything in §3 turns on it, and
   Theorem 1's `u` is ill-posed on signed legs. Needs a one-line user ruling.
2. **[MAJOR] Does `W` depend on `σ` in our framework?** Kristensen's does (occupation time). The
   doc's `W = Σw_t/D_t` is data. Without a ruling, `σ_IV^{ATM}` is either a closed form or a fixed point
   and the two are not the same object. IV8 is blocked on this.
3. **[MAJOR] Time base for the `u`-argument.** `VOL` is per-day; `ΔQ` is per-step. `β_R` is
   calibrated in the unmatched unit. What is the intended time base of `ΔQ`?
4. **[MAJOR] The doc appears to carry TWO symbols for implied volatility.** `σ²_I(0)` (line 160,
   variance-swap block, declared but never defined) and `σ_IV` / `σ_IV^{ATM}` (lines 1384–1440,
   Greeks block, defined and used). If they are the same concept, one must go — and the Greeks-block
   `σ_IV` is the one with a definition and a control-matrix row, so `σ²_I(0)` is the likelier
   casualty. **This is a pre-existing doc condition surfaced by this pass, not created by it; I am
   raising it, not resolving it.** These deliverables use `σ_IV^{ATM}` exclusively and touch
   `σ²_I(0)` nowhere.
5. **[MINOR, found en route] Suspected typo in the `λ_FLAIR` denominator (doc line 632):**
   `p·Q_M^L(ΣL) + Q_M^L(ΣL)` — both terms are `Q_M^L`. Pool value should presumably pair the
   `p`-scaled X leg with the M leg. The proved discretization uses an abstract `D_t`, so nothing
   downstream is affected; the continuous display looks wrong.
6. **[MINOR] `η ≠ 1` splits the two `ξ`s** (§4.3). Is the AMT-flattening ladder or the log-contract
   ladder the primitive when `η ≠ 1`? A real design question the framework now has to answer.
7. **[MINOR] `risk.md` vs shipped plank.** `risk.md`'s `price/haircut` disagrees with
   `oracle/(1−h)`. Cross-track note only.
8. **[MINOR] Kristensen typo to record:** `ϕ = 0.0003` on p. 67 must be `0.003`.
