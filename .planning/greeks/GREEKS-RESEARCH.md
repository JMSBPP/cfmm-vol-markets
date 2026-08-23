# GREEKS research record — the `## GREEKS` track of `VOLATILITY_INSTRUMENTS.md`

> STATUS: RESEARCH RECORD (stage 1 of the doc-driven pipeline). Feeds the
> two-reviewer gate, then HEAVY USER APPROVAL of the draft G-blocks
> (`model/vol_markets/VOLATILITY_INSTRUMENTS_GREEKS_ADDENDUM.md`), then an
> Aristotle bundle. Nothing here edits the master doc.
> Master-doc section: `../plank/notes/VOLATILITY_INSTRUMENTS.md` `## GREEKS`
> (line 1141 at time of writing; the doc gained J0–J9 and the
> ℙ_{event} probability convention mid-run — this record is written against the
> post-J9 state).
> Binding notation rules applied throughout: doc symbols always win; probabilities
> are ℙ_{event}; curvature is κ_φ (never χ); λ̃ marks incidence operators;
> τ_MEV = channel-(A) monoid, τ_JIT = liquidity tax (J9).

## 1. Papers — identification and provenance

| # | Source | Local path | Status |
|---|--------|-----------|--------|
| P1 | Bardoscia & Nodari, *Liquidity Providers Greeks and Impermanent Gain*, arXiv:2302.11942v3 (2023) | `~/learning/cfmm-theory/lp-derivatives/bardoscia-lp_greeks-2023.pdf` | PRIMARY — the LP-Greeks source ("the one I do not remember" candidate; full LP Greek set incl. locked-liquidity vega) |
| P2 | Maymin, *Option Pricing on Automated Market Maker Tokens*, arXiv:2603.29763v1 [q-fin.PR] (2026-02) | `../plank/refs/greeks/maymin-option_pricing_amm_tokens-2026.pdf` | PRIMARY — IDENTIFIED as the user's "Option Pricing in Automated Market Makers related to emission policies" (has the emission extension §5.6 and the emission Greek). An earlier Bittensor-framed version is `~/learning/cfmm-theory/cfmm-options/amm-options-paper.pdf` (different file; the 2026 version is authoritative) |
| P3 | Demeterfi, Derman, Kamal, Zou, *More Than You Ever Wanted To Know About Volatility Swaps*, Goldman Sachs QSRN (1999) | `../plank/refs/DemeterfietalVarianceSwaps.pdf` | PRIMARY — the doc's variance-swap anchor; carries "the classic greeks … just what you need to know about variance swaps" (log-contract Greeks, pp. 11–12) |
| P4 | Clark, *The replicating portfolio of a constant product market with bounded liquidity*, SSRN 3898384 (2021) | `~/learning/cfmm-theory/lp-derivatives/clark-replicating_portfolio_bounded_liquidity-2021.pdf` | supporting — bounded-range (Uniswap-v3-type) Δ/Γ with the tick-boundary kinks |
| P5 | Kristensen, *Perpetual Options on Uniswap v3* (book, 2024, licensed copy) | `~/learning/cfmm-theory/lp-derivatives/kristensen-perpetual_options_uniswap_v3-2024.pdf` | supporting — Panoptic-side δ(p), Γ(p) in (k, r) strike/range-factor form; streamia |
| P6 | Fateh Singh, Gaskin, Wu, *Modeling LVR in AMMs via Continuous-Installment Options*, arXiv:2508.02971v1 | `~/learning/cfmm-theory/lp-derivatives/fateh_singh_et_al-lvr_via_continuous_installment_options.pdf` | supporting — funding-fee-equals-theta (LVR) decomposition; CI-option boundary conditions |
| P7 | Bichuch & Feinstein, *The Price of Liquidity: Implied Volatility of AMM Fees* (2025) | `~/learning/cfmm-theory/lp-derivatives/bichuch_feinstein-implied_volatility_amm_fees-2025.pdf` | supporting — implied fee = LVR rate; fee-implied volatility (the fee-side inverse problem) |
| P8 | Natenberg, *Option Volatility and Pricing* (textbook) | `~/learning/cfmm-theory/lp-derivatives/natenberg-option_pricing_volatility-textbook.pdf` | background ONLY — the local PDF is a scanned DjVu with NO text layer (`pdftotext` returns nothing); chapter-level citation only, no page-verified formulas. Every classical-Greek display below is therefore anchored to P3 (Demeterfi) or P1 instead. Reviewers: do not expect Natenberg page anchors. |
| P9 | Lababidi, *Greek.fi Options Protocol* (2025-06-26) | `~/learning/cfmm-theory/lp-derivatives/lababidi-greekfi_american_options_protocol-2025.pdf` | inspected — despite the name, the paper contains NO Greek formulas (it is an on-chain American-options protocol design: OT/RT dual token, factory, default swaps). Recorded so nobody re-hunts it as a Greeks source; relevance = EVM options infrastructure only. |
| P10 | Bunni v2 whitepaper (LDFs) | `../plank/refs/bunni-v2.pdf` | future-milestone anchor only (§8) |

Not found locally / not needed: nothing named in the task is missing. The
"one I do not remember" is best matched by P1 (the only paper whose subject IS
the Greeks of an LP position); P2 was separately recalled by the emission link
and confirmed.

## 2. Per-paper extraction (exact formulas + anchors)

Notation inside §2 is EACH PAPER'S OWN; the translation to doc notation is §3
and the collision table is §7. Sign/object typing (per-paper, load-bearing):
P1, P4, P5, P6 price the LP (short-optionality) side directly, so their Greeks
carry the LP signs (Γ < 0, short-vol); P3 prices the LONG log-contract
portfolio (signs flip on the LP side); P2's Greeks — including Λ and E — are
typed to the LONG CALL C on the AMM token, a DIFFERENT object from the LP
position π (LP-side statements from P2 require an explicit composition, §3).

### 2.1 P1 Bardoscia–Nodari (arXiv:2302.11942v3)

Unlocked (redeemable-at-will) full-range CPMM LP, §3.1 pp. 6–8. Position price
(§3, p. 6): `P_t = V0(√(S_t/S_0) + φ t)` with `V0` initial capital, `φ` the
expected fee APY.

- Delta (§3.1.1, p. 6): `Δ_LP = ∂P_t/∂S_t = V0 / (2√(S_0 S_t))` > 0
- Delta 1% (§3.1.2, p. 7): `Δ_LP^{1%} = (V0/2)√(S_t/S_0)·10⁻²`
- Gamma (§3.1.3, pp. 7–8): `Γ_LP = −V0 / (4√S_0 · S_t^{3/2})` < 0, → −∞ as S_t → 0
- Gamma 1% (§3.1.4, p. 8): `Γ_LP^{1%} = −(V0/4)√(S_t/S_0)·10⁻⁴`
- Vega (§3.1.5, p. 8): `ν_LP = ∂P_t/∂σ = 0`
- Theta (§3.1.6, p. 8): `Θ_LP = ∂P_t/∂t = φ·V0` — theta is PURE FEE INCOME
- Rho (§3.1.7, p. 8): `ρ_LP = 0`

Locked-until-T LP (GBM risk-neutral pricing, §3.2 pp. 8–9): fair price
`P_t = V0[ √(S_t/S_0) · exp(−τ(r_f/2 + σ²/8)) + φT e^{−r_f τ} ]`, τ = T−t,
via `E_Q[√S_T] = √S_t · exp(r_f τ/2 − σ²τ/8)` (their (⋆), Appendix A).
Locked Greeks, §3.3 pp. 10–13:

- Delta (3.3.1): `Δ_LP = V0/(2√(S_0 S_t)) · exp(−τ(r_f/2 + σ²/8))`
- Gamma (3.3.3): `Γ_LP = −V0/(4√S_0 S_t^{3/2}) · exp(−τ(r_f/2 + σ²/8))`
- Vega (3.3.5, p. 12): `ν_LP = −V0 (στ/4) √(S_t/S_0) · exp(−τ(r_f/2 + σ²/8)) < 0`
  — locking CREATES the short-vol vega; in σ²-units `∂P_t/∂σ² = −(τ/8)·(asset leg)`
- Theta (3.3.6, p. 12): `Θ_LP = V0[ √(S_t/S_0)(r_f/2 + σ²/8) e^{−τ(r_f/2+σ²/8)} + r_f φT e^{−r_f τ} ]`
- Rho (3.3.7, p. 13): `ρ_LP = −V0[ (τ/2)√(S_t/S_0) e^{−τ(r_f/2+σ²/8)} + τ φT e^{−r_f τ} ]`

Impermanent Gain (§4, from p. 14; Greeks pp. 18–24) is their hedge product;
not extracted further (out of scope: we hedge with our own ladder).

### 2.2 P2 Maymin 2026 (arXiv:2603.29763v1)

Constant-weighted-product invariant `x^w y^{1−w} = K` (his K = invariant level),
diffusive net flow `dF = μ_F dt + σ_F dW` (Definition 1, eq (7)).

Orientation, VERBATIM from the paper (§3.2, p. 6): `w ∈ (0,1)` is "the weight of
token X (the numeraire)"; the marginal price is `P = ((1−w)/w)·(x/y)` (eq (5)),
i.e. the PRICED token is `y` and its weight is `1−w`; the flow enters the
numeraire leg, `dx = dF` (eq (8)).

- Theorem 1 (eqs (11)–(13), pp. 8–9): the token price follows CEV,
  `dP = μ(P)dt + δ P^w dW`, CEV exponent `β = w` (the NUMERAIRE WEIGHT),
  `δ = (1/(1−w)) ((1−w)/w)^{1−w} K^{−1} σ_F` (eq (12)); drift eq (13).
  Black–Scholes is the deep-pool limit (Remark 3, eq (29)).
  ORIENTATION CHECK AT FORMULA LEVEL (eq (12) is asymmetric in w, so it decides
  the mapping without appealing to the symmetric w = 1/2 case): from (4)+(5),
  `P = ((1−w)/w) K^{−1/(1−w)} x^{1/(1−w)}` ⟹ `∂P/∂x = (1/(1−w))·P/x`, and
  `x = P^{1−w}(w/(1−w))^{1−w}K`, so `(∂P/∂x)σ_F = (1/(1−w))((1−w)/w)^{1−w}K^{−1}σ_F·P^w`
  — eq (12) EXACTLY. The `w ↔ 1−w` swap would give `(1/w)(w/(1−w))^{w}K^{−1}σ_F·P^{1−w}`,
  which differs from (12) for every `w ≠ 1/2`. The `1/(1−w)` prefactor is the
  reciprocal of the ASSET weight ⟹ asset share = `1−w`.
- Proposition 4 (eq (20), p. 10): instantaneous return volatility
  `σ_ret(P) = δ P^{β−1}`; for β = 1/2, `σ_ret = δ/√P` — the leverage effect.
- Proposition 5 (pp. 10–11): the ATM-normalized implied-vol skew depends ONLY
  on β = w — not on δ, not on pool depth k. (Proof via degree-one homogeneity
  + `a/c = (K_str/P)^{2(1−β)} e^{−2r(1−β)T}`.)
- Theorem 7 (eqs (22)–(27), p. 12): closed-form CEV call,
  `C = P[1 − χ²(a; b+2, c)] − K_str e^{−rT} χ²(c; b, a)` with
  `κ = 2r/(δ²(1−β)(e^{2r(1−β)T}−1))`, `c = κP^{2(1−β)}e^{2r(1−β)T}`,
  `a = κK_str^{2(1−β)}`, `b = 1/(1−β)`; put by parity (eq (28)).
- Proposition 8 (eq (30), p. 13): `C_CEV = C_BS(σ_eff) + Λ_C`, `σ_eff = δP^{w−1}`,
  liquidity correction `Λ_C = O(δ²) = O(k⁻²)` ATM, signed by moneyness.
- Definition 2, AMM Greeks (eqs (31)–(34), p. 14):
  - `Δ_CEV = ∂C/∂P = [1 − χ²(a;b+2,c)] + P ∂_P[1−χ²(a;b+2,c)] − K_str e^{−rT} ∂_P χ²(c;b,a)` (31)
  - `Γ_CEV = ∂²C/∂P²` (32)
  - liquidity Greek `Λ = ∂C/∂k = (∂C/∂δ)(∂δ/∂k)`; CPMM: `δ = 2σ_F/√k`,
    `∂δ/∂k = −σ_F k^{−3/2}`, so `Λ < 0` — deeper pools compress volatility (33)
  - emission Greek `E = ∂C/∂e = (∂C/∂v̄²)(∂v̄²/∂k̇)(∂k̇/∂e) < 0` (34)
- Hedging friction: slippage per rebalance `≈ P²(ΔP)²/2k` (eq (35));
  replication premium `R ≤ (δ²P^{2β}/2k)·E_Q[∫₀^T Γ²_CEV P² dt]` (eq (37)),
  scaling k⁻² vs the k⁻¹ pricing correction (Remark 4).
- Emission extension §5.6 (eqs (38)–(41), pp. 15–16): emissions grow the
  invariant `dk/dt = y e_TAO + x e_α` (38), `k(t) ≈ k₀ + k̇t` (39),
  `δ(t) = 2σ_F/√(k₀+k̇t)` (40); Proposition 10: the call formula stands with
  `δ²T → v̄² = (4σ_F²/k̇)·ln(1 + k̇T/k₀)` (41). Emissions act as an effective
  dividend yield (Remark 5). THIS is the "emission policies" link the user
  remembered.

### 2.3 P3 Demeterfi et al. (GS QSRN 1999) — the log-contract Greeks

Portfolio with price-independent variance exposure (p. 11):
`Π(S,σ,t,T) = (2/T)[(S−S*)/S* − ln(S/S*)] + ((T−t)/T)σ²`; log-contract leg
`L(S,σ,t,T) = −(2/T)ln(S/S*) + ((T−t)/T)σ²` (EQ 8, p. 11).

- variance vega (EQ 9, p. 11): `V = (T−t)/T` — equals 1 at t = 0, decays
  linearly to 0. (The doc's Π, master-doc FAQ display, drops the 2/T
  normalization; then υ = ΔΠ/Δσ² = t/2 — PROVEN `variancePortfolio_upsilon`.)
- theta (EQ 10, p. 12): `θ = −σ²/T` — constant time decay.
- delta (p. 12, unnumbered display between EQ 10 and EQ 11): `Δ = −(2/T)(1/S)`
  shares — a constant DOLLAR delta of $(2/T).
- gamma (EQ 11, p. 12): `Γ = (2/T)(1/S²)` — constant dollar gamma `ΓS² = 2/T`.
- the balance identity (EQ 12, p. 12): `θ + ½ Γ S² σ² = 0` — "the essence of
  Black–Scholes": theta and gamma are NOT independent.
- replication weighting (pp. 9–10, Fig. 1): strike density `∝ 1/K²` (options
  weighted inversely proportional to squared strike) gives price-independent
  variance exposure — the doc's `varswapWeight` ratio `1.0001^{−Δ_i}` /
  liquidity ratio `ξ* = 1.0001^{−Δ_i/2}` (PROVEN, `GeomProfile`).

### 2.4 P4 Clark 2021 (SSRN 3898384) — bounded-range corrections

Range [p_a, p_b], virtual liquidity L. Value (eq (10), p. 4):
`V = p·R_α⁺` for p ≤ p_a; `V = 2L√p − L√p_a − pL/√p_b` in-range;
`V = R_β⁺` for p ≥ p_b (with `R_α⁺ = L/√p_a − L/√p_b`, `R_β⁺ = L√p_b − L√p_a`,
eqs (7)–(8), p. 3).

- Delta (UNNUMBERED display, §"Greeks", p. 5): `Δ_CPM = ∂V/∂p = R_α⁺`
  (p ≤ p_a); `L/√p − L/√p_b` (in-range); `0` (p ≥ p_b).
- Gamma (eq (12), p. 5): `Γ_CPM = ∂²V/∂p² = 0` outside;
  `−½ L p^{−3/2}` in-range.
  (Anchor note: eq (13) in Clark is the Green–Jarrow spanning formula of §5,
  NOT a Greek — do not cite it for gamma.)
- The tick-boundary corrections are the DISCONTINUITIES of Γ at p_a, p_b
  (Δ is continuous, kinked; Γ jumps between 0 and −½Lp^{−3/2}).

### 2.5 P5 Kristensen 2024 (Panoptic book) — strike/range-factor form

Range written as `[k/r, kr]` (strike k, range factor r).

- Delta (eq (3.21), pp. 76–77): `δ(p) = 1` (p ≤ p_a);
  `√(p_a/p)·(√p_b − √p)/(√p_b − √p_a)` in-range; `0` (p ≥ p_b);
  in (k, r) form (eq (3.22), p. 78): `δ(p) = (√(r·k/p) − 1)/(r − 1)` in-range.
  ATM narrow-range limit δ → ½ (Remark 3.18) — "ATM options have 50% delta";
  under the new ℙ convention any probability READING of delta is written
  ℙ_{ITM}, never δ.
- Strike-from-delta inversion (eq (3.23), p. 78): `k_δ = p(δ(r−1)+1)²/r`.
- Gamma (eq (3.24), p. 81): `Γ(p) = −½ · 1/(r−1) · √(rk)/√(p³)` in-range,
  0 outside. Boundary limits RECOMPUTED from (3.24) (the book's pdftotext
  rendering of these two limits is mangled), work shown:
  at p → (k/r)⁺: `−Γ = ½·(r−1)^{−1}·r^{1/2}k^{1/2}·(r/k)^{3/2}
                      = ½·(r−1)^{−1}·r^{1/2+3/2}k^{1/2−3/2} = r²/(2k(r−1))`;
  at p → (kr)⁻:  `−Γ = ½·(r−1)^{−1}·r^{1/2}k^{1/2}·(kr)^{−3/2}
                      = ½·(r−1)^{−1}·r^{−1}k^{−1} = 1/(2kr(r−1))`.
  Both exponent balances are exact — no residual `r^{3/2}` or `√(r−1)` factor
  survives; these are the values to copy into any prompt.
- Streamia (§4.1.2 + §4.1.4, pp. 85–88): the buyer pays the seller the fee
  stream the borrowed liquidity would have earned — theta is REALIZED as a fee
  flow, not a model quantity. Lean: `Panoptic.streamingPremium`;
  the ATM closed form `Θ_ATM(τ) = kσ/√(8πτ)` is the target of
  `Panoptic.theta_atm_closed_form` (source: the Panoptic paper,
  arXiv:2204.14232 — cited by the master doc; not part of this local set).
  τ-remap note: the `τ` inside this display is quoted VERBATIM from the master
  doc's FLAG (line ~42) where it means remaining time; under this section's
  remap (T → t★, remaining time → t★ − t, τ reserved for τ_MEV) it reads
  `Θ_ATM(t★ − t)` — the verbatim quote is kept ONLY because the FLAG owns it.

### 2.6 P6 Fateh Singh et al. (arXiv:2508.02971v1)

- Position value (eq (3), p. 3): `V(S) = k(√S − √a) + kS(√b − √S)/√(Sb)`,
  S ∈ [a,b].
- Delta / gamma (eq (4), p. 3): `X(S) := V′(S)`, `Γ(S) := V″(S) = X′(S) ≤ 0`.
- LVR (eqs (5)–(6), p. 4): `dLVR_t = ½σ²S_t²Γ(S_t)dt` — LVR is linear in
  gamma, quadratic in price and vol.
- CI-option layer (§2.3, eqs (7)–(8), p. 4): perpetual American
  continuous-installment put `P_q(S;K)` with funding rate q solves
  `½σ²S²∂²_S P_q + rS∂_S P_q − rP_q = q` on (S_ℓ, S_u), with value-matching and
  delta-matching `P_q(S_ℓ)=K−S_ℓ, ∂_S P_q(S_ℓ)=−1, P_q(S_u)=0, ∂_S P_q(S_u)=0`.
  The funding fee q exactly offsets theta (their Fig. caption (c), §4); the
  q → ∞ funding-equals-LVR limit is stated in the ABSTRACT/§1 PROSE and
  formalized in their Lemmas 1 and 3 — NOT in eqs (7)–(8), which are only the
  ODE + boundary conditions. Bridge: funding/installment rate ↔ streamia.

### 2.7 P7 Bichuch–Feinstein 2025

- Theorem 4.2 (p. 9): the LP value process is a martingale iff the implied fee
  is `F(p_x, p_y) = p_y ℓ(p_x/p_y)` with
  `ℓ(q) = −½(σ_x² − 2ρσ_xσ_y + σ_y²) q² x′(q)` — the instantaneous LVR.
- Corollary 4.3: under that fee the risk-neutral LP is indifferent over all
  stopping times; V ≡ C (pool value).
- Theorem 5.1 (§5, pp. 12–13): a fixed-for-floating fee swap with fixed leg
  π̄ ∈ [0, C̄(P₀ˣ)) is in bijection with an implied volatility σ*_x ≥ 0 via
  `π̄ = E[∫₀^T ℓ(e^{−rt}P_tˣ)dt]` — the fee-implied vol quote.
- Reading for us: the FEE side has an implied-σ² inverse problem; combined with
  the multiFee sigmoid this is the identification channel through which
  (β_j, γ_j) become OBSERVABLE (fee curve ↦ implied σ² ↦ sigmoid parameters).

## 3. Mapping onto our objects (doc notation)

Dictionary used (traceability §0): price kernel `p_{(η,Δ_i)}(i;t)`
(`VolInstrument.priceEta`), weights `L(i_K) = L̄·ℓ(ξ,ι;i_K)`
(`GeomProfile.geomWeight`), realized vol `σ(i(t))`, fee
`φ(σ) = φ̄ + Σ_j α_j Λ(γ_j(σ−β_j))·u` (`VolInstrument.multiFee`), curvature
`κ_φ(η,Δ_i) = 1 − p(i)/p(i+Δ_i)` (E1), maturity `t★`, `υ = t/2` (PROVEN),
hazards `λ_FLAIR, λ_ARB, λ_MEV`, incidence `λ̃_JIT`, taxes `τ, τ_JIT`.

The Greeks are defined house-style as discrete sensitivity quotients of the
position/claim price π (the doc already does exactly this for θ ≡ Δπ/Δt and
υ ≡ Δπ/Δσ²). One new operator symbol is proposed (G0 collision table §7):

    𝒟_x[π] ≜ Δπ / Δx        (sensitivity operator; subscript = the variable)

- delta = 𝒟_p[π] with p = p_{(η,Δ_i)}(i;t). Per-tick ladder (P4 UNNUMBERED
  §4.2 p. 5 display, P5 eq (3.21)) on our grid: in-band tick i_K contributes
  `𝒟_p[π](i_K) = L(i_K)·(p^{−1/2} − p(i_u)^{−1/2})` — the FIRST term uses the
  CURRENT price p (Clark's `L/√p − L/√p_b`), NOT the tick price p(i_K)
  (sqrt-price convention `PosSpec.tickPrice`); out-of-band 0 / full. The
  AGGREGATE delta of the geometric ladder is the ξ-weighted sum — depends on
  (ξ, ι, η, Δ_i, L̄) and on NOTHING in Θ_φ.
- gamma = Γ ≜ 𝒟_p²[π]. Per tick (P4 eq (12)): `−½ L(i_K) p^{−3/2}` in band.
  With `L(i_K) = L̄ ℓ(ξ,ι;i_K)`, the gamma LADDER is
  `Γ(i_K) = −½ L̄ ℓ(ξ,ι;i_K) p^{−3/2}` (current p) — (ξ,ι) choose WHERE gamma
  sits, L̄ its size, (η,Δ_i) the grid it sits on. At `ξ = ξ* = λ^{−Δ_i/2}` the
  ladder replicates the log contract, but the flat-dollar-gamma statement is
  GRID-EXACT, NOT pointwise: `Γ(p(i_K))·p(i_K)² = const in i_K` (P3 EQ 11;
  PROVEN `varswapWeight_geometric` / `logContractLiquidity_geometric`), while
  INSIDE a band `Γp² = −½L̄ℓ(ξ*,ι;i_K)p^{1/2} ∝ p^{1/2}`, swinging by
  `λ_tick^{Δ_i/2}` per band. Never bundle "Γp² = const" as a pointwise claim —
  it is false.
- theta = the doc's θ (line ~36; exponent-sign FLAG untouched). Structurally
  θ splits into carry and decay:
  `θ = θ_fee − θ_decay`. TWO COMMENSURABLE FORMS of θ_fee, always labelled
  (B1 decision), never interchanged:
      SCHEDULE-LEVEL (per unit of money leg):   `θ_fee^sched = φ(σ_t)·ν_t`
      POSITION-LEVEL (what the LP position earns): `θ_fee^pos = φ(σ_t)·ν_t·ΔQ_M`
  with ν_t = w_t/D_t. The schedule-level form is the M6b-commensurable one —
  M6b's budget `Σ_t φ_t ν_t = B` and `λ_FLAIR = φ̄W + uΣ_j α_j W_j` are stated
  in exactly these units, and λ_FLAIR sums the schedule-level form. The
  position-level form is P1 §3.1.6's `Θ = φ·V0` (his V0 → our ΔQ_M). The §4
  control matrix and §5 target set are POSITION-LEVEL. `θ_decay` = the option
  dt-leg (P3 EQ 10; the doc's θ display); the BS identity θ_decay = ½Γp²σ²
  (P3 EQ 12) makes θ_decay REDUNDANT given (Γ, σ) — not an independent target.
- vega = υ (already bound; σ²-convention). υ = t/2 is PROVEN and pinned by
  t★ (`tStar` layer): vega is controlled by MATURITY, by nothing else. The
  σ-convention vega of the papers is `2σ(i(t))·υ` (chain rule) — never a new
  symbol. P1's locked-LP vega (−στ/4 per unit asset leg) is the SHORT side of
  the same object. t-SEMANTICS: the `t` in υ = t/2 is the MATURITY PARAMETER
  (υ = t★/2 at inception; calendar-time form υ(t) = (t★−t)/2), whereas the `t`
  in P1's locked vega is calendar time entering through `t★ − t`. Same remap
  for P3's `V = (T−t)/T`. Never mix the two readings in one display.
- depth Greek — TYPE SPLIT (P2 eq (33) is a C-Greek, NOT a π-Greek):
  `Λ = ∂C/∂k → 𝒟_{L̄}[C] < 0` on the LONG CALL C (his k = L̄²; CPMM
  x^{1/2}y^{1/2} = K = L̄, k = K², so `Λ = 𝒟_{L̄}[C]/(2L̄)`); deeper pools
  reduce OPTION value by compressing σ. The LP-side row is a COMPOSITION, with
  the OPPOSITE sign: `𝒟_{L̄}[π] = (Δπ/Δσ²)·(Δσ²/ΔL̄) = (<0)·(<0) ≥ 0` — the
  short-vol LP GAINS from depth. Do not import P2's sign onto π.
- emission Greek = 𝒟_{k̇}-type (P2 eq (34)), likewise a C-Greek: `E = ∂C/∂e
  → 𝒟_{ΔQ_M}[C] < 0`, sensitivity of the CALL to the DEPTH-GROWTH rate. Our
  slot: the vault's ΔQ_M schedule (SCHEDULE.md control x = ΔQ_M(t), bang-bang
  PROVEN) IS our emission policy — the analog of P2's k̇. The π-side row
  `𝒟_{ΔQ_M}[π]` is again a composition through the short vega, not an import.
- the CEV weighting parameter w (P2 Theorem 1, Prop 5) — ORIENTATION RESOLVED
  (M1): P2's w is the NUMERAIRE weight (§3.2 eq (4)–(5)), while our η_L is the
  ASSET share (`model/exp/eta.md` line 12: `L_eta η X Y = X^η Y^{1−η}` with
  P = price of X in Y ⟹ η = exponent on the ASSET). Hence
      **w = 1 − η_L,  η_L = 1 − w,  CEV exponent β = w = 1 − η_L**
  decided at formula level against eq (12) (§2.2), NOT by the w = 1/2 example
  where the flip is invisible. Inherited displays:
      `dp = μ(p)dt + δ p^{1−η_L} dW`,  `σ(i(t)) = δ p^{β−1} = δ p^{−η_L}`,
      `σ_IV(K)/σ_IV^ATM = f(K/p; η_L)`,  CPMM `δ = 2σ_Q/L̄` (eq (12) at w = ½).
  LEVERAGE-EFFECT DIRECTION: σ ∝ p^{−η_L} is DECREASING in p for every η_L > 0
  and steepens as the ASSET share η_L rises. The η_L slot is NOT the (ξ,ι)
  slot (those weight strikes across ticks, not reserves) and NOT automatically
  the grid exponent η: the identification η_L = η is exactly the E8(6) OPEN
  claim (E0's "claim (ii)"), so P2's skew-universality transfers to the pricing
  kernel ONLY conditionally on E8(6). Unconditionally it transfers to η_L:
  the ATM-normalized implied-vol skew of the token is controlled by η_L alone
  — a NEW, sharp role for the kernel block, and a testable one (normalized
  skew is depth-invariant).
- fee-implied vol (P7 Theorem 5.1): the inverse map fee-swap-price ↦ σ*.
  Composed with multiFee it identifies (β_j, γ_j) from fee data.
- funding/installment rate (P6): q ↔ streamia (`Panoptic.streamingPremium`)
  ↔ θ_fee. The CI value-matching/delta-matching boundary conditions (P6 eq
  (8)) are the American-exercise analog of our band edges i_l, i_u.

## 4. Control matrix

Parameter blocks (columns) × Greeks/hazards (rows). "●" = direct algebraic
dependence (the block appears in the display); "○" = indirect/equilibrium/
mediated only (subscript or parenthesis names the mediator); "—" = provably
absent (the display does not contain the block). LEVEL: every Greek row is
POSITION-LEVEL (B1) — θ_fee means `θ_fee^pos = φ(σ_t)ν_t ΔQ_M`; the hazard
rows are the schedule-level ledgers those aggregate to. The normalized-IV-skew
row is a **DIAGNOSTIC** (an observable identification readout for η_L), not a
design target: it is excluded from `T` in §5 and from every deficit count.

| target \ block | (ξ,ι) shape | (η,Δ_i)→κ_φ kernel | L̄ scale | (φ̄,α,u) fee level | (β_j,γ_j) fee shape | t★ (ΔQ_v★) | τ, τ_JIT | hazard inputs (σ path, w_t, D_t) |
|---|---|---|---|---|---|---|---|---|
| 𝒟_p[π] (delta ladder) | ● | ● | ● | — | — | — | — | — |
| Γ (gamma ladder) | ● | ● | ● | — | — | — | — | — |
| υ (= t/2) | ○ (flatness: ξ = ξ* makes υ price-independent) | — | — | — | — | ● (the ONLY lever) | — | — |
| θ_fee^pos (carry level) | ○ (via which ticks earn) | ○ | ○ (via ν_t = w_t/D_t) | ● | ● (σ-profile!) | — | ○ (via the tax carve-out) | ● |
| Δθ_fee/Δσ (carry σ-slope) | — | — | ○ (via ν_t) | ● (α_j amplitudes) | ● (γ_j slopes, β_j locations) | — | — | ● |
| θ_decay (dt-leg) | ● (≡ ½Γp²σ², P3 EQ 12 — redundant given Γ) | ● | ● | — | — | — | — | ● |
| fee-vega Δθ_fee/Δσ² | — | — | ○ (via ν_t) | ● | ● | — | — | ● |
| 𝒟_{L̄}[π] (depth Greek, LP-side composition) | ○ | ○ | ● | — | — | — | — | — |
| 𝒟_{ΔQ_M}[π] (emission Greek, LP-side composition) | — | — | ● | — | — | ○ (funded maturity `tStarFunded`) | — | — |
| normalized IV skew (P2 Prop 5) — **DIAGNOSTIC, not a target** | — | ● unconditional in η_L; conditional on E8(6) for the grid η | — (depth-invariant!) | — | — | — | — | — |
| λ_FLAIR | — | — | ○ (D_t) | ● | ● (Λ(γ_j(σ_t−β_j)) weights, W_j) | — | ● | ● |
| λ_ARB | — | ● (κ_φ interior η*, E4) | ○ | ● (via ℙ_{Δ_ARB}) | ○ (only through multiFee level) | — | ● (τ rebate) | ● |
| λ̃_JIT | — | ○ (κ_φ-entry J9, TO PROVE) | ○ | ○ | — (DISCARDED, J9) | — | ● (τ_JIT, THE lever) | ● |

HEADLINE — do (β_j, γ_j) gain a genuine control role? **YES, exactly one, and
it is theta-shaped.** The rows 𝒟, Γ, υ are fee-free: the payoff-shaping
Greeks CANNOT be touched by the sigmoid block, confirming the doc's claim that
(ξ,ι) are the payoff-shaping base. But θ_fee is fee-income, and with
`φ(σ) = φ̄ + Σ_j α_j Λ(γ_j(σ−β_j))·u` the σ-PROFILE of carry is controlled by
(β_j, γ_j) alone **at fixed (φ̄, α, u)**, in both B1 forms:

    SCHEDULE-LEVEL:  Δθ_fee^sched/Δσ = u Σ_j α_j γ_j Λ′(γ_j(σ−β_j)) · ν_t
    POSITION-LEVEL:  Δθ_fee^pos/Δσ   = u Σ_j α_j γ_j Λ′(γ_j(σ−β_j)) · ν_t · ΔQ_M

β_j place the carry response in σ-space, γ_j set its steepness (Λ′ > 0).
Equivalently (β,γ) give the SHORT position a fee-vega (Δθ_fee/Δσ² ≠ 0) that the
flat-fee LP of P1 (Θ = φV0, ν = 0 unlocked) does not have.

CAVEAT — "at fixed (φ̄,α,u)", NOT "corner-pinned" (M4): this is a PARTIAL
comparative static, not one evaluated at the FLAIR optimum. Shaping carry
RE-PRICES λ_FLAIR — the master doc's `λ_FLAIR = φ̄W + uΣ_j α_j W_j` has
`W_j = Σ_t Λ(γ_j(σ_t−β_j))w_t/D_t` DEPENDING on (β_j,γ_j), so every finite
(β,γ) leaves the sup's argument, and the doc's saturating limit β → −∞
(`flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`) is never
attained. Level optimality cannot be imported into this row.

CAVEAT — UNITS (M2): the locked-LP short vega Δπ/Δσ² = −(t★−t)/8·(asset leg)
is VALUE per σ²; Δθ_fee/Δσ² is VALUE per TIME per σ². The correctly-typed claim
is the time-integrated one — `∫_t^{t★} (Δθ_fee/Δσ²) ds` is commensurable with
the locked short vega and is the candidate hedge; the pointwise derivative alone
hedges nothing. Signs verified: short vega < 0 (P1 §3.3.5), fee-vega > 0
(Λ′ > 0, α, u ≥ 0), so the carry leg does offset in sign.

This is consistent with every prior negative result: the joint FLAIR/MEV program
is level-blocked ((β,γ) saturate — corner solution), J9 discards (β,γ) for JIT
(duration-blind); neither program contained a σ-profile-of-carry objective. The
Greeks layer is the first place the sigmoid SHAPE enters a first-order display.

Sharpening of "(β,γ) are free": they are free in every LEVEL program and bind
only in the σ-derivative rows of θ_fee. Any Aristotle bundle should state both:
(i) absence from 𝒟, Γ, υ (easy structural lemmas — the displays don't contain
them), (ii) the Δθ_fee/Δσ display and its (β_j,γ_j)-comparative statics
(Λ′ > 0, so γ_j scales and β_j translates the response).

## 5. Equation count — the underspecification claim, made precise

Independent targets (aggregate level; θ_decay excluded as redundant by P3 EQ 12,
λ_MEV excluded as the ⊕-sum, normalized IV skew excluded as DIAGNOSTIC per §4):

    T = { 𝒟, Γ, υ, θ_fee^pos(level), Δθ_fee/Δσ (slope), 𝒟_{L̄}, 𝒟_{ΔQ_M},
          λ_FLAIR, λ_ARB, λ̃_JIT }            |T| = 10

(§4 has 13 matrix rows; the three non-targets are θ_decay, the separately-listed
fee-vega Δθ_fee/Δσ² — the σ²-convention twin of the Δθ_fee/Δσ row — and the
DIAGNOSTIC IV-skew row.)

Controls, with prior commitments folded in:

    ξ    — pinned to ξ* = λ^{−Δ_i/2} by the variance-claim mandate (PROVEN geometry)   0 free
    ι    — free                                                                        1
    η    — pinned at the interior η* (E4 DECIDED program)                              0 free
    Δ_i  — venue-quantized (tick spacing)                                              0 free
    L̄   — scale                                                                       1
    φ̄,u,α_j — corner-pinned by the FLAIR/MEV level program                            0 free
    β_j,γ_j — n sigmoids                                                               2n
    t★   — free (sets υ)                                                               1
    τ, τ_JIT — decided levers                                                          2
    ΔQ_M schedule — bang-bang, ceiling X                                               1
                                                                       total free = 6 + 2n

Naive count: 6 + 2n ≥ 10 for n ≥ 2 — NOT underspecified in raw numbers. The
deficit is STRUCTURAL (the matrix in §4 is block-triangular):

- The SHAPE block {𝒟, Γ, υ-flatness} (3 targets) is reachable only through
  {ξ, ι, η, Δ_i, L̄}, of which ξ, η, Δ_i are already committed ⟹ 2 free
  controls (ι, L̄) for 3 targets: **deficit 1 at aggregate level.**
- At LADDER resolution it is worse: the per-tick profiles {𝒟(i_K)}, {Γ(i_K)}
  over ι ticks form an (ι−1)-dimensional target (weights on the simplex); the
  geometric family ℓ(ξ,ι;·) with ξ pinned spans a 1-parameter curve:
  **deficit ι − 2.**
- (β_j, γ_j) CANNOT be redeployed to close this: their column is zero on the
  shape rows (§4). They are consumed by the carry-profile rows, where they are
  now essential.
- The hazard rows are fully served (φ̄, α, u, τ, τ_JIT, η*) — no deficit there.

So the user's claim holds in the refined form: *the shape-Greek subsystem is
underspecified by ι − 2 (≥ 1 aggregate), and no fee-side parameter can close
it because the fee block is absent from every shape display.*

**The Bunni-v2 LDF milestone (FUTURE — noted, not executed):** replace the
geometric family by a Liquidity Density Function `ℓ_LDF(θ_LDF; i_K)` (Bunni v2
whitepaper §2.2: `l_r = L·LDF_w(r)`, normalized Σ = 1; geometric distribution
is their base example §2.2.1). Each added LDF parameter beyond (ξ, ι) closes
one unit of the ladder deficit; dim θ_LDF ≥ ι − 2 (aggregate: ≥ 3) restores
exact controllability of {𝒟-ladder, Γ-ladder, υ-flatness}. This is the other
GSD milestone per the master doc; it is out of scope here.

## 6. EVM representation

Per Greek: exactly computable on-chain from pool state / approximable / off-chain.
Fixed-point notes at the QUANTITY level only (no implementation).

| quantity | on-chain status | state inputs (Uniswap v4 / Panoptic) | fixed-point notes |
|---|---|---|---|
| 𝒟_p[π] ladder (P4 §4.2 p.5 UNNUMBERED display, P5 eq 3.21) | EXACT | `slot0.sqrtPriceX96`, position ticks (TickMath), `liquidity`/position L | pure sqrt-price arithmetic: ratios of Q64.96; one division per tick; rounding direction must be fixed per side (short/long) |
| Γ ladder (P4 eq 12) | EXACT | same | needs `p^{3/2}` = sqrtPrice³: Q96³ overflows 256 bits — mulDiv chain (X96 → X192 intermediate); sign is exact |
| υ = t/2 | EXACT (trivial) | `t★` / elapsed accrual time (EndogenousMaturity; `implied_maturity` in seconds precedent) | a single division by 2; the σ²(i(t)) INPUT is the hard part (below) |
| θ_fee (realized carry) | EXACT ex-post | `feeGrowthInside0/1X128` deltas (v4), Panoptic premium accumulators (streamia) | Q128 fee-growth deltas; per-liquidity normalization by uint128 L |
| θ_fee σ-profile / multiFee value (state which B1 form: `φν_t` schedule-level or `φν_tΔQ_M` position-level) | EXACT given σ input | multiFee is affine in logistics: needs exp — `expWad`-class approximation | logistic Λ(γ_j(σ−β_j)) in WAD; bounded error ~1e-18-scale; monotonicity preserved if exp approximant is monotone |
| θ_decay (doc θ display, line ~36) | APPROXIMABLE | needs exp and √(8πt) | expWad + sqrt; the exponent-sign FLAG must be resolved BEFORE freezing any on-chain constant; ATM form kσ/√(8πτ) needs only sqrt + one constant (8π in WAD). τ-REMAP: the τ here is VERBATIM from the master-doc FLAG (remaining time); under this section's remap it reads `Θ_ATM(t★ − t)` — τ is τ_MEV and is NEVER time |
| σ²(i(t)) realized variance | APPROXIMABLE **only with new plumbing** / EXACT via ledger | v4 has no built-in TWAP, and E2/E5 feed the OFF-chain subgraph reader (events→subgraph→GAMS layer), NOT a contract — so on-chain availability presupposes EITHER an oracle hook OR a NEW on-chain accumulator | sum of squared tick increments: i(t) is int24; squares fit easily; Δt weighting in seconds |
| 𝒟_{L̄}[C] (P2 eq 33, a CALL Greek) / 𝒟_{L̄}[π] (LP-side composition) | APPROXIMABLE | L̄ = total nominal (vault state); the ∂C/∂δ factor is CEV-model-bound | the CEV factor is off-chain; on-chain only the elasticity shortcut δ ∝ 1/L̄ ⟹ relative form Δσ/σ = −ΔL̄/L̄ is exact; the π-side sign is the COMPOSITION (≥ 0), not P2's Λ < 0 |
| 𝒟_{ΔQ_M}[C] (P2 eq 34, a CALL Greek) / 𝒟_{ΔQ_M}[π] | OFF-CHAIN (model) / schedule side EXACT | ΔQ_M schedule state (`Flow` ceiling X, bang-bang) | v̄² integral (P2 eq 41) needs ln — `lnWad`-class; the k̇ input is the vault's own schedule, exact |
| CEV option prices / Δ_CEV, Γ_CEV (P2 eqs 22, 31–32) | OFF-CHAIN ONLY | — | non-central χ² CDFs; no sane fixed-point form; quote off-chain, verify on-chain only at the ladder level |
| fee-implied σ* (P7 Thm 5.1) | OFF-CHAIN (auction/quote layer) | fee-swap clearing price π̄ | the bijection is monotone ⟹ a table/iterative inversion off-chain; on-chain stores only the quoted σ* |
| λ ledger (λ_FLAIR, λ_ARB, λ̃_JIT realized) | EXACT ex-post | E1/E3/E4/E5/E6 events + subgraph→GAMS reader | sums of φ(σ_t)w_t/D_t terms; division per event; uint accumulation |

## 7. Collision table (binding proposals; every line is a future notation-map line)

Precedent pattern: MMR γ→φ, Capponi k→κ_φ, CJZ λ→ϑ, CJZ τ₁→c₁, anchor λ
written through Δt ≜ λ⁻¹ ("through its own primitive"). Probabilities: ℙ_{event}
(user, binding, 2026-07-31). All proposals PENDING USER APPROVAL at the gate.

| external symbol (source) | collides with (ours) | proposal | note |
|---|---|---|---|
| Δ (delta, all papers) | Δ the difference operator; Δ_i, ΔQ_v, ΔQ_M, Δt | **𝒟_p[π]** — new operator `𝒟_x ≜ Δ(·)/Δx`, subscript = variable; \mathcal{D} is unused in the doc (checked: mathcal in use = 𝒞, ℰ, 𝒢, ℛ, 𝒰) | uniform family: 𝒟_p, 𝒟_p² (= Γ), 𝒟_{L̄}, 𝒟_{ΔQ_M}; matches the doc's own θ ≡ Δπ/Δt style <!-- notation-map --> |
| δ (Kristensen's delta) | δ_S, δ_R (J1 swap curves) | → 𝒟_p[π] | never import δ <!-- notation-map --> |
| Γ (gamma) | — (Γ FREE: zero uses in doc; only lowercase γ_j is bound) | **keep Γ**, bare capital; rule: bare Γ = gamma ONLY, sigmoid steepness ALWAYS subscripted γ_j | mirror of the Θ_•/θ discipline <!-- notation-map --> |
| Θ (option theta, external) | Θ_φ, Θ_p, Θ_ℓ parameter sets; the doc's θ function | **identify with the doc's θ** (it IS Δπ/Δt, line ~36); rule: parameter sets always subscripted Θ_•, the theta function always lowercase θ; Θ_ATM stays as in the FLAG | no new symbol; exponent-sign FLAG untouched <!-- notation-map --> |
| vega ν (Bardoscia) | ν_t = w_t/D_t (M6b) | **never import**; all vegas through υ (σ²-convention); σ-convention vega written `2σ(i(t))·υ` | υ is bound = t/2 <!-- notation-map --> |
| variance vega V = (T−t)/T (Demeterfi EQ 9, a REMAINING-CALENDAR-TIME ratio) | V, V₀ (CJZ J0/J5) | → υ with the doc's normalization, where the `t` of `υ = t/2` is the MATURITY PARAMETER (υ = t★/2 at inception); calendar-time form `υ(t) = (t★−t)/2` | already PROVEN `variancePortfolio_upsilon`; t-SEMANTICS clause, §3 <!-- notation-map --> |
| ρ (rho, Bardoscia) | — (ρ free in doc) | keep ρ, scope-limited (no exogenous rate in our system; appears only in transcriptions of P1's locked case) | <!-- notation-map --> |
| Λ (Maymin liquidity Greek, eq 33) | Λ(·) the logistic (doc lines 378, 543) | → **𝒟_{L̄}[C]** — a Greek of the LONG CALL C, NOT of π — with the depth bridge `k = L̄²` (CPMM), so Maymin's Λ = 𝒟_{L̄}[C]/(2L̄); the π-row `𝒟_{L̄}[π]` is a separate composed object | never import his sign onto π <!-- notation-map --> |
| E (Maymin emission Greek, eq 34) | E-block labels; 𝔼 expectation | → **𝒟_{ΔQ_M}[C]** (schedule-level, again a C-Greek), our emission policy = the ΔQ_M schedule; π-row composed separately | <!-- notation-map --> |
| β (Maymin CEV exponent = w = NUMERAIRE weight) | β_j sigmoid locations | → **1 − η_L** (η_L = the ASSET share of `L_eta`, model/exp/eta.md line 12), i.e. `w = 1 − η_L`; orientation decided at formula level against eq (12), §2.2. η_L = η is E8(6) OPEN — never conflate | SEVERE collision, never import β <!-- notation-map --> |
| δ (Maymin CEV vol parameter, eq 12) | δ_S, δ_R | eliminate through primitives: `σ(i(t)) = δ p^{β−1} = δ p^{−η_L}` (his Prop 4 σ_ret IS our σ(i(t))), and CPMM `δ = 2σ_Q/L̄` (eq (12) at w = ½, K = L̄) | <!-- notation-map --> |
| σ_F (Maymin flow vol) | σ̄_f (FeeSchedule volStrike) — subscript-f sigma clash | → **σ_Q** (vol of the net Q-flow; flows are Q-objects in this doc) | <!-- notation-map --> |
| K (Maymin invariant level) | K our strike | → **L̄** (CPMM: x^{1/2}y^{1/2} = K ⟹ K = √k = L̄) | <!-- notation-map --> |
| K_str (Maymin strike) | — | → our K (strike) / K_i grid | <!-- notation-map --> |
| k (Maymin pool depth) | k SCHEDULE slope; MevJointProgram taxFraction k | → **L̄²** | <!-- notation-map --> |
| κ (Maymin eq 23, χ² scale) | bare κ FORBIDDEN (E0) | → **c₀** (Latin, c₁-precedent) | <!-- notation-map --> |
| χ²(x; n, λ) CDF (Maymin eq 22) | χ banned near curvature (κ_φ rule); its λ-slot collides with hazards | probability-typed ⟹ ℙ-form: **ℙ_{Y_{n,c} ≤ x}** (noncentral-χ² variable Y; the noncentrality slot is already Latin a/c in his parametrization, bare λ never appears) | <!-- notation-map --> |
| "delta as ITM probability" (Kristensen remark) | — | any probability reading written **ℙ_{ITM}**, never δ | ℙ_{event} discipline <!-- notation-map --> |
| S_t, S (underlying price, P1/P3/P6) | — | → `p_{(η,Δ_i)}(i;t)` | <!-- notation-map --> |
| S* (Demeterfi split) | — | → p* (already in doc) | <!-- notation-map --> |
| T, τ = T−t (P1/P3) | τ = τ_MEV! | maturity → **t★**, remaining time → `t★ − t`; NEVER τ | SEVERE: τ is the MEV tax <!-- notation-map --> |
| V0 (Bardoscia initial capital) | V₀ (CJZ J5) | → **ΔQ_M** (the money leg deposited) | <!-- notation-map --> |
| φ (Bardoscia expected APY) | φ our per-swap fee | eliminate through primitives in TWO labelled forms (B1): SCHEDULE-LEVEL `φ(σ_t)·ν_t` (M6b units, what λ_FLAIR sums) and POSITION-LEVEL `φ(σ_t)·ν_t·ΔQ_M` (his Θ = φ·V0, V0 → ΔQ_M) | the two φ's are different objects (yield vs fee rate); the two forms differ by ΔQ_M and are never interchanged <!-- notation-map --> |
| p_a, p_b, a, b (band edges, P4/P6) | α_j, β_j adjacency risk | → `p(i_l), p(i_u)` (PosSpec.tickPrice at band ticks) | <!-- notation-map --> |
| k, r (Kristensen strike, range factor) | k slope; r unused | strike → K (tick i_K); range factor → **λ_tick^{ι·Δ_i}** (through its own primitive, Δt-precedent) | <!-- notation-map --> |
| L (virtual liquidity, P4) | — | → L(i_K) = L̄ℓ(ξ,ι;i_K) | <!-- notation-map --> |
| R_α, R_β (Clark reserves) | α_j adjacency | → cumulative `ΔQ_X`, `ΔQ_M` (`VolInstrument.cumulativeQX/QM`) | <!-- notation-map --> |
| ℓ(q) (Bichuch LVR rate) | ℓ(ξ,ι;i_K) our weight function | eliminate through primitives: `a_t ≜ ℓ(·)·Δt` (M0/M3 a_t = leading-order LVR × Δt) | <!-- notation-map --> |
| q (Fateh installment rate) | q_R, q_S (CJZ J0) | → **q_CI** (subscripted), bridged to streamia/θ_fee | <!-- notation-map --> |
| x(q), x′(q) (Bichuch reserve fn) | x SCHEDULE control | appears only inside the a_t elimination above; if displayed, write the reserve function as `Q_X(·)` | <!-- notation-map --> |
| σ*_x (Bichuch implied vol) | x-subscript = SCHEDULE control adjacency | → **σ*_φ** (fee-implied volatility; subscript φ = implied by the fee swap) | PENDING — alternative: σ*_imp <!-- notation-map --> |
| ℙ_{Δ_ARB}, ℙ_{L_JIT} | (already renamed doc-side, line 569) | used as-is | user convention, mid-run <!-- notation-map --> |

Biggest decisions for the user at the gate: (1) the 𝒟_x operator family
(one new mathcal symbol covering delta, depth and emission Greeks uniformly);
(2) bare Γ for gamma (free, but one glyph away from γ_j — the subscript rule
must be enforced like the κ/κ_φ rule); (3) Maymin's CEV exponent β = w → 1 − η_L
(orientation RESOLVED against eq (12); η_L = the asset share) with the E8(6)
firewall; (4) maturity T → t★ and the absolute ban on τ for time.

## 8. Open questions (carried to the gate)

1. θ exponent-sign FLAG (master doc line ~42) — still author-pending; blocks
   any on-chain θ_decay constant and the G1 theta display's final form.
2. E8(6): η_L = grid-η identification — P2's skew universality lands on the
   pricing kernel ONLY if this closes; otherwise it stays an η_L statement.
3. The Δθ_fee/Δσ display uses ν_t = w_t/D_t as the flow weight: is the
   carry-profile objective stated per-event (M6b style) or time-integrated
   (λ_FLAIR style)? Affects the Aristotle statement, not the control claim —
   and the M2 hedge claim NEEDS the time-integrated form (units). Every bundled
   θ_fee statement must additionally NAME its B1 form (schedule-level `φν_t` vs
   position-level `φν_tΔQ_M`); a mixed statement is unprovable.
7. BUNDLE SCOPE: the §3 depth/emission/skew block is OFF-BUNDLE — its analytic
   content (CEV pricing, noncentral-χ² tails, implied-vol inversion) is beyond
   Mathlib v4.28. Bundle the ladder/θ-split/carry-static/deficit lemmas only.
4. n (number of sigmoids) vs the number of σ-profile targets: 2n sigmoid
   parameters can match at most 2n moments of the carry profile — if the
   hazard ladder demands more σ-resolution, the deficit reappears on the fee
   side; count before bundling.
5. Bunni-v2 LDF milestone (FUTURE, user-declared): pick the LDF family and
   dim θ_LDF ≥ ι − 2; nothing here executes it.
6. Natenberg is image-only locally — if the gate demands classical-Greek page
   anchors from it, it must be OCR'd or substituted (all classical displays
   here are anchored to P3/P1 instead).
