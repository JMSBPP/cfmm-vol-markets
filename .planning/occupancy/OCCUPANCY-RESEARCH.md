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

---
---

# ROUND 2 (2026-08-03)

> **Round 1's §2 verdict was OVERTURNED by the user.** Round 2 records the correction, then answers
> the rescoped question (Task 1) and the new `ℙ_{ITM}` definition task (Task 2). **Round 1 above is
> NOT rewritten**: the extraction (§1), the R4 replication-error argument (§3.3), the `ℙ_{ITM}` reuse
> trap (§4.2), the type taxonomy (§4.1) and the CEV-generality point all stand unchanged, and none of
> them depended on the overturned claim. **No doc, Lean, plank, or model file was edited in round 2
> either.**

## R2.0 — CORRECTION ACCEPTED: the exogenous/endogenous distinction was FALSE

Round 1 §2 closed on "his `T` is a free input, ours is an output". **That is wrong**, and our own
document says so. EXTRACTED from `../plank/notes/VOLATILITY_INSTRUMENTS.md`:

- **line 526** (`## VOL ORDER COMPLETION — ENDOGENOUS MATURITY`, heading at line 504): "The perpetual
  order specifies no `T`; `T★` is the implied maturity of the equivalent dated variance contract —
  derived from `ΔQ_v★`, never stored."
- **line 518**: the vol order packs the target vega as its fourth field —
  `create_order(strike, width, skew, targetVega)`, `targetVega : u96` at bits 152..247 of the packed
  `VolOrder` word, in raw liquidity units, `targetVega = ΔQ_v★` exactly.

⟹ `ΔQ_v★` is a **first-class user-supplied order field**, and `T★ = 2ΔQ_v★/N_σ` is therefore
**user-controlled, indirectly through vega**. Both horizons are user-set. **The symmetry is real:**
Kristensen truncates a never-expiring LP position at `T` to price it against a dated Black–Scholes
option (p. 65); we derive `T★` as the implied maturity of an equivalent dated **variance** contract
(doc line 526). **Both are equivalence horizons that convert a perpetual into a dated instrument.**

**The surviving distinction is narrower, and it is now the live question:** his `T` is an *actual
holding duration* ("the duration `T` in days that the user holds the position", p. 58); ours is an
*implied maturity that is never stored* and corresponds to no period anyone holds. Addressed in
R2.1.1.

**What round 1 still gets right, restated so it is not lost:** the refutation of the **MODIFIER**
reading (§3.3 R1–R5) never depended on the false distinction. Multiplying `T★` *by* an occupancy
fraction remains refuted. Round 2 is about **composition** — evaluating an occupancy functional *at*
`T★` — which is a different operation and is what the user's note actually asked for.

---

## R2.1 — TASK 1: THE COMPOSITION DIRECTION

### R2.1.1 Is `∫₀^{T★} ℙ dt` meaningful when `T★` is never held?

**The "never held" objection does not bite — and the reason is symmetric.** *(INFERRED.)*

`T_ITM = ∫₀^T ℙ_{[i_l,i_u]} dt` is **already** not a realized-path quantity on Kristensen's side
either: by §1.2 it is `𝔼[∫₀^T 𝟙{p_t ∈ range} dt]`, an expectation under a model law. **Nobody observes
`T_ITM` even when they do hold for `T`.** So "our `T★` is never held" cannot disqualify an object
that was never a held-path quantity to begin with. Both sides are model quantities; the only question
is whether the *upper limit* is well-defined.

**LEGITIMATE INTERPRETATION (the one that works).** `T★` is *defined* (doc line 526) as the maturity
of the **equivalent dated variance contract**. That counterfactual contract is a well-posed object —
it is the dated instrument whose vega equals `ΔQ_v★`. Therefore

> `∫₀^{T★} ℙ_{[i_l,i_u]} dt / T★` = **the fraction of the equivalent dated contract's life that the
> price would spend inside the replicating band.**

It is a **design diagnostic of the order**, computed at mint from `(ΔQ_v★, N_σ, strike, width)`, and
it is unobservable by construction — exactly like Kristensen's. That is a legitimate object.

**WHERE IT IS ILL-POSED — the real gate.** `T★` is not static: `T★_joint(t) = T★·f_fund·f_budget`
contracts with funding and realized variance (doc line 591). Two readings, and only one is well-posed:

| Reading | Upper limit | Status |
|---|---|---|
| **INCEPTION** | `T★` evaluated once at mint, held **fixed** as the integration limit | **WELL-POSED.** Matches the doc's own "at inception `υ = T★/2`" (line 1305). This is the reading to use. |
| **RUNNING** | limit `T★_joint(t)` moving with `t` | **ILL-POSED as written** — the upper limit depends on the integration variable. Requires a stated stopping rule, e.g. the first `t` with `t = T★_joint(t)`, whose existence/uniqueness would itself need proof, plus measurability of `t ↦ T★_joint(t)`. **CONJECTURAL. Do not write it until the stopping rule is a user decision.** |

> **ANSWER 1: legitimate under the INCEPTION reading; ill-posed under the RUNNING reading without a
> stopping rule.** This replaces round 1's Q2 as the gating question, and it returns **positive with
> a named condition** rather than negative.

### R2.1.2 `T_ITM/T★` as a function of the target vega — there IS a usable statement

*(INFERRED; each ingredient named.)* Compose two facts:

1. **PROVED, in the tree:** `EndogenousMaturity.tStar_strictMono_dQvStar` (line 96) — at fixed
   `N_σ > 0`, `T★ = 2ΔQ_v★/N_σ` is **strictly increasing** in `ΔQ_v★`.
2. **PROVABLE (round 1 §3.3 R1):** `T ↦ (1/T)∫₀^T ℙ dt` is **antitone** whenever the integrand `ℙ` is
   antitone in `t` — which Kristensen's is (`Erf(ln r/(σ√(2t)))` decreases in `t`), and which is the
   *only* property needed. **This is the mean-of-a-decreasing-function lemma; it does NOT require
   Kristensen's `Erf` form, only monotonicity of the integrand.**

Composing:

> **The in-band fraction of the equivalent dated contract's life is strictly DECREASING in the target
> vega.** The more vega a user targets, the longer the equivalent dated contract, and the smaller the
> share of that life the price spends in the replicating band.

And the un-normalized companion:

> **The in-band *time* `∫₀^{T★} ℙ dt` is strictly INCREASING but CONCAVE in the target vega** —
> diminishing returns in band coverage from targeting more vega. (Concavity because the integrand is
> decreasing; asymptotically `∝ √ΔQ_v★` under Kristensen's law, but the concavity itself needs only
> monotonicity.)

**This is non-vacuous and it is a genuine vega↔band-coverage tradeoff statement.** It is the first
thing in this whole spike that is both new and provable without importing a price law — because the
integrand stays **abstract and hypothesis-carrying**, exactly the discipline IV-RESEARCH §7
("DO NOT BUNDLE Kristensen's occupation law as a hypothesis about our grid") demands.

**HONEST LIMIT:** the statement is about `T★` (inception), not `T★_joint`. Under the funding/budget
factors `T★_joint ≤ T★`, so the occupancy *fraction* would be **larger** for the contracted maturity —
the monotonicity in `ΔQ_v★` survives only if `f_fund·f_budget` is held fixed. **State that hypothesis
explicitly or the claim is false.**

### R2.1.3 Is this the same object IV-RESEARCH put on the FLAIR side? **PARTIALLY — and yes, it is worth knowing**

IV-RESEARCH §4.4 placed `T_ITM/T` as **"the measure of `{t : ν_t > 0}`"**, gating fee accrual in
`λ_FLAIR` (`ν_t = w_t/D_t`, M6b; off-range `w_t = 0`).

| | IV-RESEARCH (FLAIR side) | This composition (vega side) |
|---|---|---|
| **integrand** | band occupancy | band occupancy — **IDENTICAL** |
| **horizon** | the FLAIR accumulation window | `T★` (inception) |
| **consumer** | `λ_FLAIR` fee accrual | vega-design diagnostic |
| **direction** | "how much fee did the band earn" | "how well does the targeted vega cover the band" |

> **VERDICT: same integrand, different upper limit, different consumer — a PARTIAL duplicate,
> approached from the other end.** The engineering consequence is concrete and worth acting on:
> **build ONE occupancy lemma over an abstract integrand, and instantiate the upper limit twice.**
> Building two independent formalizations of `∫ℙdt` would be the duplicate this question was asked to
> catch.

---

## R2.2 — TASK 2: `ℙ_{ITM}` DEFINED THE PANOPTIC WAY

> **Source of record:** `../plank/lib/panoptic-v2-core/contracts/…`. Every claim below carries a
> file:line anchor. Nothing is paraphrased from general knowledge of how Panoptic works.

### R2.2.1 HEADLINE — Panoptic has NO boolean ITM predicate; it has THREE distinct notions

*(EXTRACTED.)* A grep for `ITM|inTheMoney` across `contracts/` returns comments and a **quantitative**
`itmAmounts` accumulator — **no `isITM` function anywhere.** Three separate notions are used:

**(1) MONEYNESS ITM — one-sided, threshold at the STRIKE.**
`RiskEngine.sol:1594` — "if position is short, check whether the position is **out-the-money**";
`RiskEngine.sol:1596` — "if position is **ITM or ATM**, then the collateral requirement depends on
price"; `RiskEngine.sol:1598–1600` — "get the ratio of **strike to price for calls** (or **price to
strike for puts**). Both of these ratios **decrease as the position becomes deeper ITM**"; implemented
at `RiskEngine.sol:1604–1622`:

```solidity
uint160 ratio = tokenType == 1
    ? Math.getSqrtRatioAtTick(bound(2*(atTick - strike), …))   // puts  -> price/strike
    : Math.getSqrtRatioAtTick(bound(2*(strike - atTick), …));  // calls -> strike/price
```

⟹ **the moneyness predicate is `ratio < 1`**, i.e. *(INFERRED from the verbatim comment + the sign of
the tick difference)*:

```
tokenType = 0 (CALL): ITM  ⟺  atTick > strike
tokenType = 1 (PUT):  ITM  ⟺  atTick < strike
ATM (atTick = strike) is grouped WITH ITM          (RiskEngine.sol:1596, verbatim)
```

> **CORRECTION TO THE TASK BRIEF:** the brief said ITM-ness "depends on the leg's encoded fields
> `isLong`, `tokenType`, `asset`, `strike`, `width`". **It does not.** The predicate depends on
> **`tokenType` and `strike` only** (plus `width`/`tickSpacing` for the *transition band*, notion 2).
> `isLong` selects which collateral branch runs (`RiskEngine.sol:1592`) and flips the payoff sign — it
> does **not** move the moneyness threshold. `asset` only rescales liquidity
> (`PanopticMath.sol:392–397`) and never enters the predicate. **Verified by reading, not assumed.**

**(2) CHUNK MEMBERSHIP ("in-range") — two-sided, HALF-OPEN `[tickLower, tickUpper)`.**
`RiskEngine.sol:445`: `if ((currentTick < _strike + rangeUp) && (currentTick >= _strike - rangeDown)) hasLegsInRange = true;`
`RiskEngine.sol:1640`: `if ((atTick < tickUpper) && (atTick >= tickLower))` — the in-range collateral
interpolation branch.
`Math.sol:372–378` (`getAmountsForLiquidity`), the canonical three-way split:
`currentTick < tickLower` ⟹ all token0; `currentTick >= tickUpper` ⟹ all token1; else ⟹ a mix.

**Band geometry** — `PanopticMath.sol:406–432`, `getTicks` / `getRangesFromStrike`, **verbatim dev
comment**: "Given `r = (width * tickSpacing) / 2`, `tickLower = strike − floor(r)` and
`tickUpper = strike + ceil(r)`."

```
rangeDown = (width*tickSpacing)/2                        (floor)
rangeUp   = unsafeDivRoundingUp(width*tickSpacing, 2)    (ceil)
tickLower = strike − rangeDown ,  tickUpper = strike + rangeUp
```

⟹ **the band is ASYMMETRIC about the strike whenever `width·tickSpacing` is odd.** The strike is the
*floor*-midpoint, not the midpoint. `PanopticMath.sol:458–463` inverts this
(`width = (tickUpper−tickLower)/tickSpacing`, `strike = tickLower + rangeDown`), and this project's
plank encoder matches it exactly: `PanopticTokenId.plk:66` — `strike = lo + (span </ 2)`,
`width = span </ ts`. **Round-trip consistency holds and is provable** (R2.2.4, L3).

**(3) SWAP-ITM — the operational SFPM notion, one-sided, threshold at a CHUNK EDGE.**
`SemiFungiblePositionManagerV4.sol:862–863`, **verbatim**:
```solidity
// if tokenType is 1, and we transacted some currency0: then this leg is ITM
// if tokenType is 0, and we transacted some currency1: then this leg is ITM
```
and `:883–885` — a swap fires iff `LeftRightSigned.unwrap(itmAmounts) != 0`. The diagram at `:681–696`
labels the in-chunk case "in-the-money: mix of tokens 0 and 1 within the chunk".

Composing that comment with `Math.sol:372–378` *(INFERRED — the composition is mine)*:

```
tokenType = 0 (CALL): swap-ITM  ⟺  amount1 ≠ 0  ⟺  atTick ≥ tickLower
tokenType = 1 (PUT):  swap-ITM  ⟺  amount0 ≠ 0  ⟺  atTick <  tickUpper
```

### R2.2.2 How the three relate — exactly

*(INFERRED; elementary, and provable — see L1/L2 in R2.2.4.)* With `rangeDown, rangeUp ≥ 0`:

```
CALL (tokenType 0):  ITM_moneyness = [strike, ∞)        ⊂  ITM_swap = [tickLower, ∞)
PUT  (tokenType 1):  ITM_moneyness = (−∞, strike]       ⊂  ITM_swap = (−∞, tickUpper)
```

> **`ITM_swap = ITM_moneyness ∪ (the OTM half of the chunk)`, in both cases.** Swap-ITM is a strict
> *relaxation* of moneyness-ITM: it fires as soon as **any** token mixing exists, i.e. from the near
> chunk edge, whereas moneyness flips at the strike in the chunk's interior. **They are not
> interchangeable and the codebase never treats them as such.**

### R2.2.3 THE ONE-SIDED vs TWO-SIDED PROBLEM, head on

Four objects, and the reconciliation:

| Object | Sidedness | Time semantics | Threshold |
|---|---|---|---|
| **doc's reserved `ℙ_{ITM}`** (line 1308) | one-sided | **terminal** (`ℙ[p_T > K]`, "ATM delta = 50%") | strike |
| **Panoptic moneyness ITM** | one-sided | **spot / instantaneous**, evaluable at any `t` | strike |
| **Panoptic swap-ITM** | one-sided | instantaneous, only at mint/burn | chunk edge |
| **Kristensen band occupancy** | **two-sided** | instantaneous, then **integrated** | both edges |

**THE RECONCILIATION — and it is exact, not a fudge.** Kristensen's own derivation (**p. 53**,
EXTRACTED in round 1 §1.2) is *literally a difference of two one-sided normal CDFs*:

```
ℙ[p_T ∈ [p_a,p_b]] = N( ln(p_b/p_0)/(σ√T) ) − N( ln(p_a/p_0)/(σ√T) )
```

⟹ **the two-sided object is the difference of two one-sided objects evaluated at the two chunk
edges.** In our band notation *(INFERRED, but a pure indicator identity — see L4)*:

```
ℙ_{[i_l,i_u]}(t)  =  ℙ_{i(t) ≥ i_l}(t)  −  ℙ_{i(t) ≥ i_u}(t)
```

> **No new primitive is required.** One-sided is the primitive; two-sided is a difference. Kristensen's
> band occupancy and Panoptic's moneyness ITM are **the same primitive applied at different
> thresholds** — the chunk edges vs. the strike.

**VERDICT on whether `ℙ_{ITM}` can carry the Panoptic definition:**

> **YES, but ONLY as a `t`-indexed FAMILY, and that requires AMENDING the reservation's wording.**
> The reservation (line 1308) says *terminal*. Panoptic's is *instantaneous*. They are compatible in
> the strongest possible sense — **the reserved terminal reading is exactly the `t = T` member of the
> instantaneous family** — but the current wording does not say that, and a reader is entitled to
> take "terminal" literally. Two further conditions:
> - the `tokenType` and `strike` arguments must be **explicit**, not hidden — the same symbol denotes
>   two different half-lines depending on `tokenType`;
> - the **ATM convention** must be stated (`RiskEngine.sol:1596` groups ATM **with** ITM, and on a
>   discrete tick lattice ATM has strictly positive probability — see the boundary artifact A4).
>
> **AMENDING THE RESERVATION IS A USER DECISION. FLAGGED, NOT ASSUMED, NOT APPLIED.**
> Round 1 §4.2's warning stands unchanged for the *two-sided* object: `ℙ_{ITM}` must **never** be
> reused for Kristensen's band occupancy. That one is a *difference* of two `ℙ_{ITM}`-type terms and
> must be written out as such.

**NOTHING IS MINTED.** Freeness greps run against `plank/notes/VOLATILITY_INSTRUMENTS.md`:
`\mathbb{P}_{\text{ITM}}` — **1 hit** (line 1308, the reservation itself: exists, reuse candidate);
`T_{\text{ITM}}` — **0 hits** (write it out, per round 1 §4.3);
`occupanc` — **0 hits**; `chunk` — **0 hits** (the doc says *band* `[i_l,i_u]`; **do not import
Panoptic's word "chunk" into the doc** — use the doc's band notation). *(Per the brief's warning that
`c₁`/`c₂` and `ξ_{X/M}` were both proposed and both collided: **round 2 proposes no symbol at all**,
so there is nothing to collide.)*

### R2.2.4 INTEGRATION ARTIFACTS — what is needed, what exists, what is missing

For `∫₀^{T★} ℙ_{ITM}(t) dt` to be well-defined:

| # | Artifact | Status | Evidence |
|---|---|---|---|
| **A1** | **The predicate as a measurable function of a tick process** `i(t)` | ❌ **MISSING — the biggest gap.** The doc uses `i(t)` informally (9 hits) and `σ(i(t))`; the **Lean tree contains no probability space and no price process at all.** The nearest carrier is `Panoptic.crrStep` / `latticeTheta` (a CRR binomial lattice, `Panoptic.lean:90,105`) — a *discrete* candidate, not a continuous-time process. | `Panoptic.lean` 15 decls: `volOptionPayoff`, `replicationPrice`, `streamingPremium`, `q`, `crrStep`, `latticeTheta`, `thetaAtm`, … — **nothing about ITM, nothing measure-theoretic** |
| **A2** | **Measurability + integrability on `[0,T★]`** | ⚠️ **CHEAP ONCE A1 LANDS.** `ℙ_{ITM}(t) ∈ [0,1]` is bounded, so on a bounded interval integrability follows from measurability alone; measurability follows free from monotonicity or continuity of `t ↦ ℙ_{ITM}(t)`. Under a GBM/CEV law it is continuous. **Must be a stated hypothesis, not assumed.** | — |
| **A3** | **The measure** | ❌ **MISSING, and it CANNOT come from Panoptic.** `RiskEngine` never takes a probability — it evaluates a **deterministic predicate on an observed tick**. **Panoptic supplies the EVENT; our framework must supply the LAW.** Kristensen's law is the **objective** measure (round 1 §1.2). The doc has no price-law measure convention (its `ℙ_{Δ_ARB}`, `ℙ_{L_JIT}` etc. inherit laws from their own source models). **USER DECISION OWED: objective vs risk-neutral.** | `RiskEngine.sol:1604–1622` — pure tick arithmetic, no distribution |
| **A4** | **Boundary / continuity at the tick edges** | ⚠️ **EVIDENCE EXISTS, DECISION MISSING.** Panoptic's comparisons are **half-open and asymmetric**: in-range `[tl, tu)` (`RiskEngine.sol:445,1640`; `Math.sol:372–378`); band asymmetric about the strike when `w·ts` is odd (`PanopticMath.sol:419` dev comment); ATM grouped **with** ITM (`RiskEngine.sol:1596`). On a **continuous** state law the boundary is null and none of this matters; on the **discrete tick lattice it is NOT null** and ATM carries positive mass. **Inherit the code's own convention (ATM ∈ ITM) — but that is a decision to record, not an inference to make silently.** | as cited |
| **A5** | **WHICH tick** | ❌ **MISSING — and worse than a single choice.** `RiskEngine.sol:1037–1062`: the solvency check runs against **1 tick in normal mode (`spotTick`) and 4 under high deviation or `safeMode` (`spotTick, medianTick, latestTick, currentTick`)**, taking the worst case. The `atTick` argument is therefore **not a single deterministic function of time**, and `spotTick` is an **EMA**, not spot (`OraclePack.sol:29,164–169,390–395`). ⟹ `ℙ_{ITM}` at the pool tick and at the oracle tick are **different objects with different laws**. **USER DECISION OWED.** | `RiskEngine.sol:1030–1064`; `OraclePack.sol:29,202–222` |
| **A6** | **A continuous-time on-chain evaluation** | ❌ **DOES NOT EXIST AND CANNOT.** Panoptic evaluates ITM only at **mint, burn, and collateral checks** (`SFPMv4.sol:883`, `RiskEngine.sol:1640`). There is **no accumulator** anywhere. ⟹ `∫₀^{T★}ℙ_{ITM}dt` is a **purely OFF-CHAIN / model object** and can never be a contract invariant. It belongs in the doc's OFF-CHAIN row (line 1470), not in any on-chain obligation. | as cited |

> **NET: A1, A3, A5 are hard blockers requiring a user decision or a new tree artifact; A4 needs a
> recorded convention; A2 is cheap once A1 lands; A6 is a permanent scoping fact, not a gap to close.**
> **The predicate algebra (R2.2.1–R2.2.2) needs NONE of them** and is buildable today — which is what
> makes the narrow promotion in R2.4 possible.

### R2.2.5 PROPOSED LEAN SURFACE — names and statement shapes only, no proofs

House style: guarded hypotheses explicit, `PosSpec.lam` for the tick base, real powers guarded, no
`autoImplicit`. Namespace `Panoptic` (checked: no name collision with its existing 15 decls). **Tick
arithmetic over `ℤ` so the half-open/rounding semantics are faithful; the occupancy layer over `ℝ`.**

```lean
namespace Panoptic

/-! ### Band geometry (PanopticMath.sol:406–432) -/
def rangeDown (w ts : ℤ) : ℤ := (w * ts) / 2            -- floor
def rangeUp   (w ts : ℤ) : ℤ := (w * ts + 1) / 2        -- ceil, for 0 ≤ w*ts
def tickLower (strike w ts : ℤ) : ℤ := strike - rangeDown w ts
def tickUpper (strike w ts : ℤ) : ℤ := strike + rangeUp   w ts

/-! ### The three predicates -/
/-- MONEYNESS ITM (RiskEngine.sol:1596–1622). ATM is grouped WITH ITM. -/
def isITM     (tokenType : Fin 2) (strike i : ℤ) : Prop :=
  if tokenType = 0 then strike ≤ i else i ≤ strike
/-- Band membership, half-open (RiskEngine.sol:445,1640; Math.sol:372–378). -/
def inBand    (strike w ts i : ℤ) : Prop :=
  tickLower strike w ts ≤ i ∧ i < tickUpper strike w ts
/-- SWAP-ITM (SFPMv4.sol:862–863). -/
def isITMswap (tokenType : Fin 2) (strike w ts i : ℤ) : Prop :=
  if tokenType = 0 then tickLower strike w ts ≤ i else i < tickUpper strike w ts

/-! ### Occupancy layer — the integrand stays ABSTRACT (no price law imported) -/
noncomputable def occupiedTime (P : ℝ → ℝ) (T : ℝ) : ℝ := ∫ t in (0:ℝ)..T, P t
noncomputable def occupancy    (P : ℝ → ℝ) (T : ℝ) : ℝ := occupiedTime P T / T
```

| ID | Statement shape | Hypotheses | Expectation |
|---|---|---|---|
| **L1** | `isITM tt strike i → isITMswap tt strike w ts i` | `0 ≤ w`, `0 < ts` | **PROVABLE** (needs `0 ≤ rangeDown`, `0 ≤ rangeUp`) |
| **L2** | the set difference `isITMswap \ isITM` is exactly the OTM half-band | `0 ≤ w`, `0 < ts` | **PROVABLE** |
| **L3** | `tickUpper − tickLower = w * ts`; and `rangeUp − rangeDown = (w*ts) % 2` (the asymmetry) | `0 ≤ w*ts` | **PROVABLE** — this is the round-trip against `PanopticMath.sol:458–463` **and** `PanopticTokenId.plk:66` |
| **L4** | indicator identity: `𝟙_inBand = 𝟙_{i ≥ tickLower} − 𝟙_{i ≥ tickUpper}` | `tickLower ≤ tickUpper` | **PROVABLE** — the formal content of "two-sided = difference of two one-sided" (Kristensen p. 53) |
| **L5** | `occupancy P T ∈ [0,1]` | `0 < T`, `∀t ∈ [0,T], P t ∈ [0,1]`, `IntervalIntegrable P volume 0 T` | **PROVABLE** |
| **L6** | `T ↦ occupiedTime P T` is **concave** and monotone on `(0,∞)` | `P` antitone, nonneg, locally integrable | **PROVABLE** (standard) |
| **L7** | `T ↦ occupancy P T` is **antitone** on `(0,∞)` | `P` antitone, nonneg, integrable | **PROVABLE** — mean-of-a-decreasing-function; the round-1 R1 fact, restated without any `Erf` |
| **L8** | `dQvStar ↦ occupancy P (EndogenousMaturity.tStar dQvStar Nσ)` is **strictly antitone** | `0 < Nσ`, `0 < dQvStar`, `P` strictly antitone + L7's hypotheses | **PROVABLE** — composes the already-**PROVED** `tStar_strictMono_dQvStar` (`EndogenousMaturity.lean:96`) with L7. **This is R2.1.2, and it is the deliverable of the whole rescoped question.** |
| **L9** | `ℙ_{ITM}(t) = 𝔼[𝟙 (isITM …)]` | a probability space + a tick process | **NOT PROVABLE — A1/A3/A5 missing.** State as a **definition against a supplied measure**, never as a theorem. **Do not fabricate the process.** |
| **L10** | any statement giving `P t` a closed form (e.g. `Erf(…)`) | a price law | **CONJECTURAL. DO NOT BUNDLE.** Round 1 §3.3 R5 and IV-RESEARCH §7 both forbid importing Kristensen's occupation law as a hypothesis about our grid. |
| **L11** | the RUNNING-`T★` reading (`t = T★_joint(t)` fixed point) | a stopping rule | **CONJECTURAL — blocked on R2.1.1's user decision.** |

> **L1–L8 are PROVABLE TODAY with no new axioms and no imported price law. L9–L11 are not, and are
> labelled as such.** The split is deliberate: everything above the line depends only on integer
> arithmetic and monotonicity; everything below needs an artifact the tree does not have.

---

## R2.3 — ROUND 2: EXTRACTED vs INFERRED

**EXTRACTED from Panoptic v2 source** (`../plank/lib/panoptic-v2-core/contracts/`)
- `RiskEngine.sol:1594` "check whether the position is out-the-money"; `:1596` "if position is ITM or ATM"; `:1598–1600` the strike/price-vs-price/strike ratio comment; `:1604–1622` the implementation.
- `RiskEngine.sol:445`, `:1640` the in-range test `(atTick < tickUpper) && (atTick >= tickLower)`.
- `RiskEngine.sol:1030–1064` the `atTicks` vector (1 tick normally, 4 under deviation/safeMode).
- `PanopticMath.sol:406–432` `getTicks` / `getRangesFromStrike` + the floor/ceil dev comment at `:419`; `:458–463` the inverse; `:392–397` `asset` → liquidity only.
- `Math.sol:368–378` `getAmountsForLiquidity`, the three-way split.
- `SFPMv4.sol:678–699` the ITM diagram; `:862–863` the tokenType/cross-token ITM comment; `:883–885` the swap trigger.
- `OraclePack.sol:29,164–169,202–222,390–395` — `spotEMA` is an EMA; `medianTick` exists.
- No `isITM` function exists anywhere in `contracts/` (grep).

**EXTRACTED from our own tree**
- `VOLATILITY_INSTRUMENTS.md:504,518,526` — the `## VOL ORDER COMPLETION` block, `create_order(strike, width, skew, targetVega)`, `targetVega = ΔQ_v★`, "`T★` … derived from `ΔQ_v★`, never stored".
- `EndogenousMaturity.lean:96` `tStar_strictMono_dQvStar` — **PROVED**.
- `Panoptic.lean` — 15 decls, none about ITM (gap confirmed by reading, not assumed).
- `PosSpec.lean:39,46` `lam`, `tickPrice`.
- `PanopticTokenId.plk:9–10,50–68` the bit layout and `strike = lo + (span </ 2)`, `width = span </ ts`.
- Freeness greps (R2.2.3).

**INFERRED BY ME (round 2; elementary, NOT machine-checked)**
- The moneyness predicate `tokenType=0 ⟹ ITM ⟺ atTick > strike` (and the put mirror) — read off the *sign* of the tick difference plus the verbatim "ratios decrease as the position becomes deeper ITM".
- The swap-ITM tick characterization — composing `SFPMv4.sol:862–863` with `Math.sol:372–378`.
- The strict inclusion `ITM_moneyness ⊂ ITM_swap`, difference = the OTM half-band.
- `ℙ_{[i_l,i_u]} = ℙ_{i≥i_l} − ℙ_{i≥i_u}` as the reconciliation of one-sided and two-sided (Kristensen's p. 53 form is the EXTRACTED witness; the identification with our band notation is mine).
- The "never held ⟹ meaningless" objection does not bite, because `T_ITM` is an expectation on Kristensen's side too.
- INCEPTION well-posed / RUNNING ill-posed.
- The vega monotonicity (R2.1.2) and its `f_fund·f_budget`-fixed caveat.
- The partial-duplicate finding vs the FLAIR object.
- The A1–A6 artifact classification and the L1–L11 provability split.

**NOT CLAIMED IN ROUND 2**
- No claim that Panoptic's ITM is a probability — it is a deterministic predicate; the law is ours to supply.
- No amendment to the line-1308 reservation (flagged as a user decision).
- No symbol minted or proposed.
- Nothing about `υ` identification. Out of scope, untouched.
- No closed form for `P t`.

---

## R2.4 — RECOMMENDATION ON THE RESCOPED QUESTION

The round-1 call (**DO NOT PROMOTE**) was answering "does `T_ITM/T` modify `T★`?" — and that
refutation **stands** (§3.3 R1–R5). The rescoped question is different: **does the composition
`occupancy(P, T★)` yield anything?** It does.

> # ✅ PROMOTE — NARROWLY, AND CONDITIONALLY
>
> **One sentence:** the composition returns a real, non-vacuous, axiom-free result — *the in-band
> fraction of the equivalent dated contract's life is strictly decreasing in the target vega*
> (L8, composing the already-proved `tStar_strictMono_dQvStar` with an abstract-integrand occupancy
> lemma) — together with an exactly-extracted Panoptic predicate algebra (L1–L4) that the tree
> currently lacks entirely.

**PROMOTE (buildable today, no new axioms, no imported price law):**
- The Panoptic predicate algebra **L1–L4** — three predicates, their inclusion order, the band
  round-trip against both `PanopticMath` and `PanopticTokenId.plk`, and the one-sided/two-sided
  indicator identity.
- The abstract occupancy layer **L5–L7** and the vega monotonicity **L8**, with the integrand `P` left
  as a hypothesis-carrying parameter and the `f_fund·f_budget`-fixed caveat stated.

**DO NOT PROMOTE (blocked, each on a named thing):**
- **L9** — blocked on **A1** (no tick process in the tree), **A3** (no measure convention: user
  decision, objective vs risk-neutral), **A5** (which tick: spot/EMA/median/current — user decision).
- **L10** — permanently out, per IV-RESEARCH §7 and round 1 §3.3 R5.
- **L11** — blocked on the RUNNING-`T★` stopping rule (user decision, R2.1.1).
- **Any `T★` modifier.** Round 1 §3.3 R4 stands: a band weight is finite-strip replication error.
  Promotion here is for **evaluating an occupancy functional AT `T★`**, never for **multiplying `T★`
  by one**. These must not be conflated in whatever gets written.

**USER DECISIONS OWED BEFORE ANY DOC BLOCK IS WRITTEN** (four, none assumed here):
1. Amend the line-1308 `ℙ_{ITM}` reservation from *terminal* to a `t`-indexed family? (R2.2.3)
2. The measure convention for a price-law probability — objective or risk-neutral? (A3)
3. Which tick is the predicate's argument — pool spot, `spotEMA`, `medianTick`, or the worst-case
   vector? (A5)
4. The ATM convention on the discrete lattice — inherit `RiskEngine.sol:1596` (ATM ∈ ITM)? (A4)

**ENGINEERING NOTE, actionable now:** build **one** occupancy lemma over an abstract integrand and
instantiate the upper limit twice — once at `T★` (this track) and once at the FLAIR window
(IV-RESEARCH §4.4). They share the integrand and differ only in the limit (R2.1.3).
