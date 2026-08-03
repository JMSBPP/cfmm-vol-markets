# OCCUPANCY-RESEARCH — `T_ITM/T` vs. our endogenous maturity `T★`

> **STATUS: SPIKE RESEARCH RECORD.** No doc, Lean, plank, or model file was edited. Feeds the
> two-reviewer gate and the promotion decision in `.planning/occupancy/OCCUPANCY-SPIKE.md`.
> **PRIMARY SOURCE:** `../plank/refs/lp-derivatives/kristensen-perpetual_options_uniswap_v3-2024.pdf`
> ("Perpetual Options with Uniswap V3", Jesper Kristensen, 2024).
> **CITATION CONVENTION:** `p. NN` = the **printed** page number in the book's own running header/footer.
> Every anchor below was located by `pdftotext -layout` and confirmed against the nearest printed
> page marker in the same extraction. Extraction retained in the session scratchpad.
> **INHERITED, NOT RE-DERIVED** (per the spike file): `.planning/implied-vol/IV-RESEARCH.md` §4.1
> already established that the integrated object in Kristensen is the **occupation time**, not `VOL`.
> **OUT OF SCOPE, OBSERVED:** re-identifying `υ`. The υ econometric null result (phases 09–10) is
> terminal. Nothing below reopens it; `υ = T/2` is used only as the framework's *definitional*
> bijection (`VolInstrument.variancePortfolio_upsilon`), never as an identification claim.

---

## 0. EXECUTIVE VERDICTS

| # | Question | Verdict |
|---|---|---|
| 1 | Kristensen's definition of `T_ITM/T` | **§3.3.4, p. 56, UNNUMBERED display.** `T_ITM/T = (1/T)∫₀^T Prob[p_t in range] dt`, integrand `= Erf( ln(r) / (σ√(2t)) )`. The integrand is **not** an indicator and **not** an occupation density — it is the **marginal law of the state**, `ℙ[p_t ∈ [p_a,p_b]]`, under **GBM with real-world drift µ**, subsequently **linearized to driftless** by the stated `T(µ−σ²/2) ≪ 1` assumption. **Not a risk-neutral measure.** By Fubini `T_ITM` is the **expected** occupation time, so this is an `𝔼[∫1]` object, not a pathwise one. |
| 2 | **Is his `T` a maturity?** | **NO. Decisive, and it closes the spike.** His own text on p. 55 reads that a Uniswap V3 position **never expires**; `T` is introduced there as "the total duration time", and on p. 58 as "the duration `T` (in days) that the user holds the position", explicitly **user-controlled**. It is an **exogenous holding/observation horizon**. It is *re-labelled* as a synthetic option expiry only in §3.4.2, p. 65, where he **artificially truncates** the perpetual position ("limited for `T` days … expires in `T` days") to make it comparable to a dated BS option. It is **not** a first-passage or liquidation time either: the integrand is the marginal in-band probability, so re-entry is permitted and the process is never stopped. |
| 3 | Consistency with `tStarJointMult` | **REFUTES the substitution, on four independent grounds** (§3). Bijectivity technically *survives* (`T ↦ T_ITM` is strictly increasing), but every property the decision was actually made on **fails**: the burn rate stops being constant, the `σ²`-budget stops being `∝ T`, the variance channel is **double-counted**, and — decisive — the band weight belongs to the **strip-replication-error** channel, not the maturity channel, because a variance swap accrues over *all* of `[0,T]` regardless of the band. |
| 4 | Is `ℙ_{[i_l,i_u]}` an existing object? | **NEW as an object; NOT new as notation.** It is a different **type** from all four existing probabilities (`ℙ_{Δ_ARB}`, `ℙ_{L_JIT}`, `ℙ_{Δ_ARB^{CJ}}`, `ℙ_{L_INV}` are agent **arrival/action** probabilities per period; this is a **state-law** probability). It is *not* the reserved `ℙ_{ITM}` (doc line 1308) either — that is reserved for the **one-sided terminal** delta reading. **NOTHING NEEDS MINTING:** the band edges are already mapped (`p_a,p_b → p(i_l),p(i_u)`, doc line 1306), the in-band **indicator is already a doc object** (`𝟙_{(i_l,i_u)}`, doc lines 1327, 1337), and `ℙ_{[i_l,i_u]}` is the user's own writing in the binding convention. **One flagged convention question** (a set-valued subscript where every other `ℙ_•` subscript is an event name) — user ruling owed, §4.4. |
| — | **RECOMMENDATION** | **DO NOT PROMOTE.** See §6. |

---

## 1. Q1 — EXTRACTION (all EXTRACTED unless marked)

### 1.1 The definition, verbatim in structure

**Location: §3.3.4 "Collected Fees", printed p. 56. The display carries NO equation number.**
Its first *numbered* appearance is inside **(3.14), p. 58**.

```
T_ITM / T  =  ( ∫₀^T Prob[ p_t in range ] dt ) / T
           =  ( ∫₀^T Erf( ln(r) / (σ√(2t)) ) dt ) / T
```

with, in his words, `T_ITM` = "the time the price `p` is within the range, i.e., in-the-money (ITM)"
(p. 56). The range is `[p_a, p_b]` with `p_0 = r p_a = p_b / r` for a **range factor `r > 1`** (p. 56);
he also records `r = √(p_b/p_a)` (p. 55).

> **Doc mapping already exists:** Kristensen's `r` → `λ_tick^{ιΔ_i}` (doc line 1306), and his
> `p_a, p_b` → `p(i_l), p(i_u)` (same line). So the user's rendering `ℙ_{[i_l,i_u]}` is the
> already-mapped form of his `Prob[p_t in range]`. **EXTRACTED + doc-grep confirmed.**

### 1.2 What the integrand IS — the question the spike asked

Derived in **§3.3.2, pp. 52–54**. He solves the GBM SDE `dS_t = µS_t dt + σS_t dW_t` for `W_T`,
takes the Gaussian density of `W_t`, and gets

```
Prob[p_T in range] = N( (ln(p_b/p_0) − T(µ−σ²/2)) / (σ√T) )
                   − N( (ln(p_a/p_0) − T(µ−σ²/2)) / (σ√T) )        (p. 53)
```

then drops the drift and centres the band, reaching `Erf(ln(r)/(σ√(2t)))` via `N(x√2) = (Erf(x)+1)/2`
and oddness of `Erf` (p. 54).

Answers to the spike's three candidates:

| Candidate | Verdict | Basis |
|---|---|---|
| in-range **indicator** | **NO** | The object is a *difference of two normal CDFs* — an expectation of the indicator, not the indicator. (p. 53) |
| **risk-neutral** probability | **NO** | Built from the **objective** GBM law with drift `µ`, then *approximated* to driftless via `T(µ−σ²/2) ≪ 1` (p. 57 assumption list). His only risk-neutral machinery, the risk-free rate `α`, appears solely in the §3.4.2 BS premium (p. 65) and never touches the occupation time. **INFERRED (measure identification), from EXTRACTED text.** |
| **occupation density** | **NO, and this matters** | `∫₀^T ℙ[p_t ∈ range] dt = 𝔼[∫₀^T 𝟙{p_t ∈ range} dt]` by Fubini — the **expected** occupation time. It is *not* a pathwise occupation time and *not* a local time. **INFERRED (Fubini step is mine; Kristensen does not state it).** |

⟹ **Measure: the objective (physical) measure `ℙ` induced by GBM, drift-annihilated.** Time measure:
plain Lebesgue `dt` on `[0,T]`.

### 1.3 The closed form and the leading term (p. 57)

```
T_ITM/T = [ (ln²(r) + σ²T)·Erf(ln(r)/(σ√(2T)))
            + ln(r)·√(2/π)·σ√T·e^{−ln²(r)/(2σ²T)} − ln(r) ] / (σ²T)
        = √(8/π)·ln(r)/(σ√T)  +  [powers of ln(r) of degree ≥ 2]
```

### 1.4 HYPOTHESES — the verbatim list (p. 57), plus the two he does not list

**His stated list (p. 57, "Assumptions"):**
1. `T·(µ − σ²/2) ≪ 1`
2. The starting price is the **geometric mean** of the boundary prices: `p_0 = √(p_a p_b)`
3. Erf Taylor: `Erf(z) = (2/√π)z + O(z³)` — i.e. **small `z`, i.e. LARGE `T`**

**Two further hypotheses he does not list but the derivation requires — INFERRED:**
4. **`σ` is a deterministic constant.** The `Erf` closed form is GBM-specific. Our own price law is
   **CEV**: `σ(i(t)) = δ p^{β−1} = δ p^{−η_L}` (doc line 1303, Maymin Prop 4 eq (20)). Constant `σ`
   is the `η_L = 0` member. *(E8(6), `η_L = η`, is OPEN and is not assumed here.)*
5. **`T` is deterministic and exogenous** — it is the upper limit of a Lebesgue integral, not a
   stopping time.

> Hypothesis 2 is the one hypothesis of his that **our framework satisfies exactly**, not
> approximately: IV-RESEARCH §3.1 (L1) proves the tick inventory is value-balanced at the geometric
> mean of the tick's two edges. Hypotheses 3, 4 and 5 all fail or are unavailable in our setting.

### 1.5 Where it is used (p. 58) — and the user-control sentence

```
fees collected in T days per unit of asset amount deployed
   = (T_ITM/T) · T · ( ϕ · VOL/AMT_tick )                            (3.14)
      \___ User controlled ___/  \___ Pool controlled ___/
```

with the verbatim gloss (p. 58): `T_ITM` "is part of the LP position and **controlled by the user**,
as is the time `T` for which the position is held." **Remark 3.8 (p. 58)** flags that `AMT_tick`
varies across ticks and (3.14) therefore holds only *approximately* — already analysed in
IV-RESEARCH §4.3, not re-opened here.

---

## 2. Q2 — **HIS `T` IS NOT A MATURITY**

This is the decisive question and it returns a negative. Three anchors, all EXTRACTED:

**(a) p. 55, "Next Step", verbatim in substance:** the previous section gives the probability at a
*specific future time* `T`; **however, a Uniswap V3 position never expires**, and fees are earned
each time the price is in range; the natural question is therefore *how long* the price is inside the
range compared to **"the total duration time `T`"**.

⟹ `T` is introduced *in explicit contrast to* expiry. It is the **duration of observation**.

**(b) p. 58:** "the duration `T` (in days) that the user holds the position", and `T` is listed as
**user-controlled**. ⟹ `T` is an **exogenous choice variable of the LP**, a holding horizon.

**(c) p. 65, §3.4.2 — the only place `T` looks like an expiry, and it is a construction:**
"Deploying a single tick LP position **limited for `T` days** is akin to a cash-secured put (or
covered call) with strike `k` that **expires in `T` days**."

⟹ He **imposes** an artificial `T`-day truncation on a perpetual instrument so that it can be priced
against a dated Black–Scholes option. The expiry is a property of the *comparison contract*, not of
the LP position. **This is the paper's whole method: it prices a perpetual by truncating it.**

**(d) It is not a first-passage or liquidation time either — INFERRED, from the integrand.** If `T`
were an exit time the integrand would have to be a survival probability
`ℙ[sup_{s≤t} |ln(p_s/p_0)| < ln r]`. It is not: it is the **marginal** `ℙ[p_t ∈ range]`, which
permits arbitrarily many exits and re-entries before `t`. Kristensen never stops the process. **His
`T_ITM` therefore has no absorbing/liquidation semantics whatsoever.**

> ### VERDICT Q2
> **Kristensen's `T` is an exogenous, user-chosen holding horizon over an explicitly never-expiring
> position — a truncation parameter, not a maturity.** Our `T★` is an **endogenous** protocol
> quantity (`T★ = 2ΔQ_v★/N_σ`, then burned by the funding factor and the variance budget), whose
> degenerate case *is* a genuine stopping time (`Q_M → 0`; doc line 577). **These are objects of
> different kind, with opposite dependency direction (his is a free input, ours is an output), and
> the honest reading is that the connection the note asks for does not exist at the level of `T`.**

---

## 3. Q3 — CONSISTENCY WITH THE DECIDED `tStarJointMult`

### 3.1 What the decided law actually is (EXTRACTED from our own tree)

`lean/vol_markets/EndogenousMaturity.lean`:

```
tStar dQvStar Nσ                = 2 * dQvStar / Nσ                                        (line 21)
tStarFunded QM prisk dQvStar Nσ = tStar (min dQvStar (Flow.deltaShares QM prisk)) Nσ      (line 118)
tStarJointMult … sig2K sig2R    = tStarFunded … * max 0 (1 - sig2R / sig2K)               (line 218)
```

Proved: `_nonneg`, `_antitone` (↓ `σ²_R`), `_zero` (`= T★(t)` at `σ²_R = 0`), `_exhausted` (`= 0` at
`σ²_R = σ²_K`); plus the two-sided bijection `dQvStarOfMaturity_tStar` / `tStar_dQvStarOfMaturity`
(lines 28, 35) and `variancePortfolio_upsilon_at_tStar` (line 49).

The doc's **recorded rationale** for choosing the multiplicative law (line 599, verbatim):
> "`υ = T/2 ⟹ σ²-budget ∝ T` (bijection preserved); `T★_joint = T★·f_fund·f_budget` (monotonicities
> chain); **burn rate constant (no cliff)**. Alternates formalized, rejected: `T★_sub`
> (off-domain floor placement only), **`T★_quad`** (`(1−r²) ≥ (1−r)`: **pro-holder under vol
> clustering**)."

The candidate under test is the occupancy-weighted maturity
`T_occ := (T_ITM/T)·T★_joint`, equivalently `T ↦ T_ITM(T)`.

### 3.2 What SURVIVES — stated first, so the refutation is not overstated

**INFERRED (elementary, not machine-checked).** For `r > 1`, `σ > 0`, the integrand
`Erf(ln r/(σ√(2t))) ∈ (0,1]` for all `t > 0`, so `T ↦ T_ITM(T) = ∫₀^T ℙ dt` is continuous and
**strictly increasing**, hence **injective**. So `υ = T_ITM/2` is still a bijection onto its image.

> **The occupancy weight does NOT, by itself, destroy the `υ = T/2` bijection.** Any claim that it
> does would be wrong, and this record says so.

### 3.3 What BREAKS — four grounds, independent

**(R1) The burn rate stops being constant — and this was the stated decision criterion.**
By the fundamental theorem of calculus, `dT_ITM/dT = ℙ_{[i_l,i_u]}(T)` **exactly**. By Remark 3.7
(p. 54) this equals `1` at `T → 0` and `→ 0` as `T → ∞`, and it is **monotonically decreasing** in
`T` (the `Erf` argument `ln r/(σ√(2T))` decreases). ⟹ `T_ITM` is **strictly concave** in `T`, with a
**front-loaded, monotonically decaying burn rate**. The recorded decision criterion is *"burn rate
constant (no cliff)"*. **It fails.** *(INFERRED; numerically confirmed at `σ=1, r=1.05`:
`T_ITM/T = 0.571, 0.223, 0.0755, 0.0383, 0.0193, 0.00970, 0.00486` at `T = 0.01…256`, strictly
decreasing; `T_ITM/√T → 0.0777` vs. the p. 57 leading constant `√(8/π)ln(r)/σ = 0.07786` ✓.)*

**(R2) The antecedent of the decision fails: `σ²`-budget is no longer `∝ T`.**
Asymptotically `T_ITM ∝ √T` (verified above and matching the p. 57 leading term). The rationale's
chain was `υ = T/2 ⟹ σ²-budget ∝ T ⟹` a *multiplicative* budget factor is the right shape. Under
occupancy weighting the budget would be `∝ √T`, so the multiplicative form loses the argument that
justified it. **The refutation is of the DERIVATION, not merely of the value.**

**(R3) The variance channel is double-counted.**
`ℙ_{[i_l,i_u]}(t) = Erf(ln r/(σ√(2t)))` is **strictly decreasing in `σ`**. The decided budget factor
`(1 − σ²_R/σ²_K)⁺` is **also** strictly decreasing in realized variance (`tStarJointMult_antitone`).
Composing them contracts `T★` **twice** for the same volatility, through two factors with no stated
economic separation. Direction: both **anti-holder** — i.e. the composite lands on the *opposite
pole* from the rejected `T★_quad`, which was rejected for being *pro-holder*. **There is therefore
no sense in which occupancy weighting corrects the decided law; it overshoots it.** *(INFERRED.)*

**(R4) — DECISIVE — the band weight is a REPLICATION-ERROR object, not a maturity object.**
`υ = T/2` is the vega of the **Demeterfi log-contract variance portfolio**. Under the doc's own
Demeterfi notation-map entry (**line 1305**), his variance vega `V = (T−t)/T` maps to `υ`, whose
argument is the **maturity parameter** `t`, not calendar time (`υ = T★/2` at inception). A variance swap pays realized variance `∫₀^T σ² dt` over the
**whole** interval, **irrespective of where the price sits relative to any band**. Multiplying `T` by
a band-occupancy fraction asserts that the variance leg stops accruing outside `[i_l,i_u]` — which is
**false for the variance swap** and **true only for the finite-strip replication**, where the
out-of-band excursion is precisely the **truncation error**.

> ⟹ In our framework `T_ITM/T` measures **how much of the horizon the finite strip actually
> replicates**, not **how long the contract lives**. Putting it on `T★` conflates the replication
> error with the maturity. **This is the substantive reason the connection the note asks for is the
> wrong connection, quite apart from Q2's reason that his `T` is not a maturity at all.**

**Corroboration from our own doc:** the in-band indicator is already a first-class object on the
**Greek** side, not the maturity side —
`Γ(i_K) = −½ L̄ ℓ(ξ,ι;i_K) p^{−3/2} 𝟙_{(i_l,i_u)}` (doc line 1327) and
`Γ^Σ(p) = −½ L̄ p^{−3/2} Σ_{i_K} ℓ(ξ,ι;i_K) 𝟙_{p∈(i_l,i_u)(i_K)}` (doc line 1337).
`ℙ_{[i_l,i_u]} = 𝔼[𝟙_{(i_l,i_u)}]` is exactly the expectation of the object already sitting in `Γ^Σ`.

**(R5, supporting) The hypothesis set is unavailable to us anyway.** Kristensen's occupation law
requires **constant deterministic `σ`** (§1.4 item 4). The decided law's *rejection reason* for the
quadratic cites **vol clustering**. A constant-`σ` law **cannot express the scenario that drove the
decision**, so it cannot arbitrate it either. Importing it as a hypothesis about our grid is exactly
the unearned transfer that IV-RESEARCH §7 flags as DO-NOT-BUNDLE, and that the `ptrade` negative-fee
pole and the T24 refutation were both caused by.

> ### VERDICT Q3
> **REFUTATION (first-class outcome).** Bijectivity survives; **the decision survives nothing else**.
> An occupancy-weighted `T` breaks the constant burn rate (R1), invalidates the derivation that
> selected the multiplicative form (R2), double-counts the variance channel (R3), and — decisively —
> mis-assigns a **strip-truncation** quantity to the **maturity** slot (R4), on hypotheses our CEV
> price law does not grant (R5). **`tStarJointMult` should NOT be occupancy-weighted.**

---

## 4. Q4 — THE PROBABILITY `ℙ_{[i_l,i_u]}`

### 4.1 What already exists in the doc (grep-verified against `VOLATILITY_INSTRUMENTS.md`)

| Existing symbol | What it is | Doc line(s) | Type |
|---|---|---|---|
| `ℙ_{Δ_ARB}` | arbitrage-trade probability (MMR `P_trade`; Lean `MevOptimization.ptrade`) | 683, 699, … | **action-in-a-period** |
| `ℙ_{L_JIT}` | JIT-arrival probability (CJZ `π`; Lean `πJ`) | 683, 1201 | **arrival-in-a-period** |
| `ℙ_{Δ_ARB^{CJ}}` | Capponi–Jia arb-occurrence probability | 921, 997, … | **event-in-a-period** |
| `ℙ_{L_INV}` | investor-arrival probability | 922, 1028, … | **arrival-in-a-period** |
| `ℙ_{Y_{n,c} ≤ x}` | Maymin's noncentral-χ² CEV transition CDF | 1303 | **state law** |
| `ℙ_{ITM}` | RESERVED for "any probability reading of delta"; **declared, never used** | 1308 only | **terminal, one-sided** |
| `𝟙_{(i_l,i_u)}` | the in-band **indicator**, already used in `Γ` and `Γ^Σ` | 1327, 1337 | indicator |

### 4.2 Is Kristensen's object one of these?

- **Not `ℙ_{Δ_ARB}` / `ℙ_{L_JIT}` / `ℙ_{Δ_ARB^{CJ}}` / `ℙ_{L_INV}`.** All four are probabilities that
  **an agent acts or arrives** within a period. Kristensen's is the **marginal law of the price
  state** at a fixed calendar time. **Different type. Not the same object.**
- **Not `ℙ_{ITM}`** (doc line 1308) — though this is the near miss and must be recorded as such.
  `ℙ_{ITM}` is reserved for the **one-sided, terminal** delta reading (`ℙ[p_T > K]`, "ATM delta =
  50%"). Kristensen's is **two-sided band membership** (`ℙ[p_t ∈ [p(i_l), p(i_u)]]`) at an **interior**
  time `t`, then integrated. Reusing `ℙ_{ITM}` would silently merge a one-sided terminal object with
  a two-sided instantaneous one. **Do not reuse it.**
- **Same type as `ℙ_{Y_{n,c} ≤ x}` — and this is the one useful leverage point.** *(INFERRED.)* Under
  our CEV law `σ(i(t)) = δ p^{−η_L}` the correct band probability is a **difference of two
  `ℙ_{Y_{n,c} ≤ x}` evaluations**, not an `Erf`. Kristensen's `Erf` is the **`η_L = 0` (constant-`σ`,
  GBM) member** of the family our doc already carries. *(E8(6) `η_L = η` is OPEN and is not assumed.)*

### 4.3 Does anything need minting? **NO.**

Freeness/existence checks run against `plank/notes/VOLATILITY_INSTRUMENTS.md`:

| Needed piece | Status |
|---|---|
| band edges `p_a, p_b` | **already mapped** → `p(i_l), p(i_u)`, line 1306 |
| Kristensen's range factor `r` | **already mapped** → `λ_tick^{ιΔ_i}`, line 1306 |
| in-band indicator | **already a doc object** `𝟙_{(i_l,i_u)}`, lines 1327/1337 |
| the probability itself | writable as `ℙ_{[i_l,i_u]}` — **the user's own rendering**, already in the binding `ℙ_{event}` convention |
| `T_ITM` as a symbol | **0 hits** outside the user's note (line 1495). If ever needed it should be **written out** as `∫ ℙ_{[i_l,i_u]} dt`, per the same decision IV-RESEARCH §6 took for `T_ITM/T` (`Υ` was rejected there as confusable with `υ`). |

**No symbol is minted by this record.**

### 4.4 ONE FLAGGED CONVENTION QUESTION — user ruling owed, not decided here

Every existing `ℙ_•` subscript is an **event name** (`Δ_ARB`, `L_JIT`, `L_INV`, `ITM`) or a **typed
inequality** (`Y_{n,c} ≤ x`). The user's `ℙ_{[i_l,i_u]}` uses a **set** as the subscript, which is a
third style. Two consistent options, both requiring the user's word:

- **(i)** keep `ℙ_{[i_l,i_u]}` and extend the convention to admit set-valued subscripts (reads as
  "probability of being in the set"); or
- **(ii)** name the event, e.g. `ℙ_{p ∈ (i_l,i_u)}`, matching the `𝟙_{p∈(i_l,i_u)(i_K)}` form already
  used in `Γ^Σ` at doc line 1337.

**RECOMMENDATION (not a decision): (ii)**, because it is byte-consistent with the indicator already
in the doc and keeps `ℙ_•` subscripts uniformly predicate-shaped. **FLAGGED. Not applied.**

---

## 5. EXTRACTED vs INFERRED — the separation, in one place

### EXTRACTED FROM KRISTENSEN (verbatim or structurally verbatim, with anchors)
- `T_ITM/T = (1/T)∫₀^T Prob[p_t in range] dt`, integrand `Erf(ln r/(σ√(2t)))` — §3.3.4, **p. 56**, **unnumbered**.
- `Prob[p_T in range]` as a difference of two normal CDFs of the GBM law with drift `µ` — **p. 53**.
- The `Erf` reduction via `N(x√2) = (Erf(x)+1)/2` and oddness — **p. 54**.
- Remark 3.7: `Prob → 0` as `r → 1`; `Prob → 1` as `T → 0` — **p. 54**.
- Closed form + leading term `√(8/π)ln(r)/(σ√T)` — **p. 57**.
- The three stated assumptions — **p. 57**.
- (3.14) and the "User controlled / Pool controlled" split; `T` = "the duration `T` (in days) that the user holds the position" — **p. 58**.
- Remark 3.8 (`AMT_tick` varies; (3.14) approximate) — **p. 58**.
- "a Uniswap V3 position never expires"; `T` = "the total duration time" — **p. 55**.
- "limited for `T` days … expires in `T` days"; `α` = risk-free rate, in the BS premium only — **p. 65**.

### EXTRACTED FROM OUR OWN TREE
- `tStar` / `tStarFunded` / `tStarJointMult` definitions and their proved lemmas — `lean/vol_markets/EndogenousMaturity.lean` lines 21, 118, 218, 238–262; bijection at lines 28/35; `variancePortfolio_upsilon_at_tStar` line 49.
- The decided-law display and its rationale — `../plank/notes/VOLATILITY_INSTRUMENTS.md` lines 587–599.
- Notation-map entries (band edges, `r`, `ℙ_{ITM}`, Maymin CEV/χ², Demeterfi `V → υ`) — doc lines 1303–1308.
- `Γ`, `Γ^Σ` and the in-band indicator — doc lines 1327, 1337.
- The occupation-time (not `VOL`) finding — inherited from `.planning/implied-vol/IV-RESEARCH.md` §4.1/§4.4.

### INFERRED BY ME (elementary, NOT machine-checked, NOT in the source)
- Fubini: `T_ITM` is the **expected** occupation time, not a pathwise one (§1.2).
- The measure is the **objective** one, drift-annihilated — not risk-neutral (§1.2).
- Unstated hypotheses 4 (constant deterministic `σ`) and 5 (`T` deterministic/exogenous) (§1.4).
- `dT_ITM/dT = ℙ_{[i_l,i_u]}(T)`, hence strict concavity and a monotonically decaying burn rate (R1).
- `T_ITM ∝ √T` asymptotically; **numerically confirmed**, and it is a **large-`T`** asymptotic — the `Erf` linearization is invalid at small `T`, where `ℙ → 1` and `T_ITM ≈ T` (R1).
- Strict monotonicity ⟹ bijectivity survives (§3.2).
- The `σ`-double-count and its anti-holder direction (R3).
- The replication-error-vs-maturity assignment, and `ℙ_{[i_l,i_u]} = 𝔼[𝟙_{(i_l,i_u)}]` linking to `Γ^Σ` (R4).
- Kristensen's `Erf` law is the `η_L = 0` member of our CEV `ℙ_{Y_{n,c} ≤ x}` family (§4.2).
- The type-distinction argument separating state-law from arrival/action probabilities (§4.2).

### NOT CLAIMED
- No claim that `T_ITM/T` is useless — see §6.2.
- No claim about `υ` identification. Out of scope, untouched.
- No claim on E8(6) (`η_L = η`).
- No numerical replication of Kristensen's Examples 3.9–3.11 (already done in IV-RESEARCH §1.3; not re-run).

---

## 6. RECOMMENDATION

### 6.1 The criterion, and the call

The spike file's promotion criterion:
> "Promote to a CTX requirement only if **(1) and (2) return a connectable object**."

- **(1) returns an object** — a precisely defined, anchored one (§1).
- **(2) returns a NEGATIVE** — his `T` is an exogenous holding horizon over an explicitly
  never-expiring position, not a maturity (§2).
- **(3) independently refutes** the substitution into `tStarJointMult` on four grounds (§3).

> # ⛔ DO NOT PROMOTE
>
> **One sentence:** Kristensen's `T` is an exogenous holding horizon over a position his own text
> says *never expires*, so it is not the same kind of object as our endogenous `T★`, and the
> occupancy fraction it normalizes is — in our framework — a **finite-strip replication-error**
> quantity that belongs with `Γ^Σ` and `λ_FLAIR`, **not** a maturity modifier; weighting
> `tStarJointMult` by it would break the constant burn rate the law was chosen for and double-count
> the variance channel.

**The spike closes here.** No CTX requirement, no roadmap checkbox, no doc block, no Lean bundle.

### 6.2 What is honestly salvageable — recorded, NOT promoted, NOT registered

Two spin-offs exist. **Neither is part of this spike, neither is a requirement, and both need the
user's discussion before anything is written anywhere.**

1. **The object already has a home, and it is not `T★`.** IV-RESEARCH §4.4 already assigned
   `T_ITM/T` to the **FLAIR** side: it is the measure of `{t : ν_t > 0}`, and at constant fee
   `λ_FLAIR = φ·W` *is* Kristensen's holding return with in-range gating carried by `w_t = 0`
   off-range. **The connection the user is looking for already exists — on the fee leg, made in the
   IV track.** Nothing further is owed on `T`.
2. **`Γ^Σ` band-truncation.** `ℙ_{[i_l,i_u]} = 𝔼[𝟙_{(i_l,i_u)}]` is the expectation of an indicator
   already sitting inside `Γ^Σ` (doc line 1337). A statement about the *expected* replicated gamma of
   a finite strip would be a real, well-typed result. **It is a different question from the one this
   spike was asked**, and under our CEV law it needs `ℙ_{Y_{n,c} ≤ x}`, not `Erf` (§4.2). Raising it,
   not opening it.

### 6.3 Carry-forwards (facts worth not re-learning)

- **Kristensen prices a perpetual by truncating it.** Any future import from this paper inherits an
  artificial horizon. Check for it every time.
- **His occupation law is constant-`σ` GBM** — the `η_L = 0` member of the CEV family we already
  carry. It cannot express vol clustering, which is the exact scenario our maturity-law decision
  turned on.
- **`ℙ_{ITM}` (doc line 1308) is declared but never used**, and is one-sided/terminal. It is a
  standing trap for anyone tempted to reuse it for a two-sided band probability.
- **`ℙ_•` subscript style is not uniform** once set-valued subscripts are admitted — §4.4 is a live,
  unresolved convention question independent of this spike's outcome.
