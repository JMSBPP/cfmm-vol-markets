# Phase 9: upsilon-econometric-estimation-lean-aware - Research

**Researched:** 2026-07-19
**Domain:** On-chain panel econometrics (Panoptic subgraph + BigQuery) · Haskell NLS/GMM · Lean4 bridging lemma
**Confidence:** MEDIUM (toolchain HIGH; subgraph mainnet endpoint LOW; bridging-lemma obstruction HIGH)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Data access = hybrid**: Panoptic subgraph for positions/premia/strikes (tokenId-level); **BigQuery** for the underlying Uniswap pool swap ticks — used to construct σ̂²_t AND a second, independently-windowed variance estimator that instruments σ̂² (the EIV two-noisy-measures remedy).
- **Docs-first discovery**: start from `https://panoptic.xyz/docs/subgraph/schema`; do not guess subgraph IDs. Endpoints/auth/entities follow from the official docs.
- **No Dune MCP** in this session — the structural-econometrics skill's Dune mandate is explicitly overridden by this hybrid route (documented deviation).
- **Estimation stack = Haskell ONLY** (hard user directive, not a preference). No Python/R anywhere, not even for data munging.
- **Stack project at `econometrics/`** (Stackage LTS pin for reproducibility); outputs land in `notes/structural-econometrcics/{data,analysis}/`.
- **audit-econ gate = YES** — independent dispatch after estimation; FAIL blocks phase completion.
- **Market**: deepest ETH/USDC Panoptic market on the largest ETH/USDC Uniswap pool the subgraph covers; exact pool/chain/address confirmed from the subgraph during execution (not assumed).
- **Sample**: full history the subgraph has, daily epochs; σ̂²_t from within-day swap ticks; EIV instrument from a second daily windowing. Epoch length is a one-shot choice (not in the sensitivity set).
- **Bridging lemma** in `lean/vol_markets/Upsilon.lean`: exponential-moneyness family with κ > 0 witnesses `ATMOTMNullHypothesis`. Statement drafted locally; **proof via ONE serial Aristotle task** (new project). Reuse the 08-05 bundle recipe.
- **Cross-reference discipline**: the Haskell estimator encodes υ, moneyness distance, and the tick grid EXACTLY as the Lean definitions state them; a Lean↔Haskell↔spec cross-walk table lives in the analysis output.

### Claude's Discretion
- Numeric packages (survey and recommend with build implications).
- Exact Haskell module layout, GHC/LTS version choice (subject to what is installable), subgraph pagination strategy, BigQuery SQL shape, and **the bridging-lemma statement details** (explicitly including whether the moneyness-in-slope form is needed).
- Whether results feed back to the plank session's `spec/protocol/protocol_integrations/panoptic.md` — coordination note only, not a deliverable.

### Deferred Ideas (OUT OF SCOPE)
- Feeding estimation results back into the plank session's panoptic copy (peer `ul2inqpl` coordination).
- Epoch-length sensitivity (deliberately one-shot at daily).
- Multi-market extension (single-market by locked decision).
- On-chain Lens read of υ (plank/solidity tracks).
</user_constraints>

<phase_requirements>
## Phase Requirements

No formal REQUIREMENTS.md IDs exist for this phase. CTX-* tags are minted at planning per the Phase-8 convention. The spec `notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md` is the binding contract; the natural deliverable clusters (planner to tag) are:

| Provisional tag | Deliverable | Research support |
|-----------------|-------------|------------------|
| CTX-PANEL | Position-epoch panel from Panoptic subgraph (tokenId × daily epoch: π_it, i_K, width, Q_M) | §Subgraph — entity schema known; **mainnet endpoint is the open question** |
| CTX-VAR | σ̂²_t + second-window instrument from Uniswap swap ticks via BigQuery | §BigQuery — `crypto_ethereum` logs; Swap-event tick decode |
| CTX-EST | NLS/GMM of π = β₀ + υ₀·exp(−κ·\|i_K−i_t\|)·σ̂² + v, clustered-by-tokenId robust SEs | §Haskell stack + §Sandwich SE |
| CTX-TEST | Committed tests υ₀>0, κ>0, κ⁺=κ⁻ | §Sandwich SE + §Validation |
| CTX-ALT | Four alternative specs (semiparametric, seed-linear, position-FE, collateral-channel) | spec §6.2 |
| CTX-BRIDGE | Bridging lemma: exp family ⊨ `ATMOTMNullHypothesis`, proved via one serial Aristotle task | §Bridging Lemma — **statement needs correction, see below** |
| CTX-AUDIT | audit-econ gate PASS on the analysis output | §audit-econ |
</phase_requirements>

## Summary

Phase 9 executes an already-locked econometric spec in Haskell against Panoptic on-chain data, and closes the loop back to Lean by proving that the fitted exponential-moneyness vega profile is a formal witness of `Upsilon.ATMOTMNullHypothesis`. Three findings dominate the planning surface.

**(1) The Haskell toolchain is ready; GSL is not.** GHC 9.10.3, Stack 3.11.1, and Cabal 3.16 are installed. System BLAS/LAPACK/CBLAS are present (`liblapack.so`, `libblas.so`, `libcblas.so` in `ldconfig`), so **`hmatrix` will build**. But **GSL is absent** (`gsl-config` missing, no `gsl.pc`, no `/usr/include/gsl`), so **`hmatrix-gsl` will NOT build without a Wave-0 system install**. Recommendation: use `hmatrix` (linear algebra, present BLAS) + `ad` (autodiff Jacobians) + a hand-rolled Levenberg–Marquardt/Gauss–Newton loop, avoiding `hmatrix-gsl` entirely. This dodges the missing-GSL dependency with no loss of capability.

**(2) The mainnet subgraph endpoint is the real data risk.** The official docs (`/docs/subgraph/schema`, `/docs/subgraph/queries`) publish the full entity schema and one working endpoint — but that endpoint is **Sepolia testnet only** (Goldsky: `panoptic-subgraph-sepolia`). No mainnet ETH/USDC gateway endpoint is stated in the docs. The locked decision ("deepest ETH/USDC market, full history") assumes a mainnet-scale subgraph exists; confirming a mainnet (or production L2) endpoint must be an explicit **Wave-0 discovery gate** — the phase cannot build the panel on testnet-only data.

**(3) The bridging lemma is FALSE as the committed `Prop` is currently stated** — and this is a parameter-independent obstruction, exactly the trap flagged for research. The symmetric exponential family's *forward-difference* slope is symmetric about `iK − ½`, not `iK`, so the **entire left branch** `i < iK` violates conjunct 3's envelope `exp(−c·|i−iK|)` for *every* `c > 0` (numerically verified). The fix is a one-line correction to conjunct 3's envelope (straddle-tolerant / slope-centered form) plus choosing `c ≤ κ·Δi`; `ATMOTMNullHypothesis` has no downstream consumers, so amending it breaks no existing proof. Details and the exact corrected statement are below — this must be settled *before* the single Aristotle submission, not discovered at Aristotle time.

**Primary recommendation:** Plan a Wave-0 that (a) confirms a mainnet/production Panoptic subgraph endpoint + auth, (b) confirms BigQuery reachability and the Uniswap Swap topic0, (c) scaffolds the `econometrics/` Stack project against an LTS carrying `hmatrix` (no GSL), and (d) locks the corrected `ATMOTMNullHypothesis` statement locally. Only then build the panel, estimate, and submit the single Aristotle proof.

## Standard Stack

### Core (Haskell — `econometrics/`)
| Library | Version (verify vs LTS) | Purpose | Why Standard |
|---------|-------------------------|---------|--------------|
| `hmatrix` | ~0.20.2 | Dense linear algebra (matrix inverse, solve, SVD) for normal equations + sandwich SE | The canonical Haskell LA lib; links the **present** system BLAS/LAPACK, no GSL needed |
| `ad` | ~4.5.x | Reverse/forward-mode autodiff for the NLS Jacobian ∂π̂/∂(β₀,υ₀,κ) | Exact derivatives of the exponential model; avoids finite-difference error in Gauss–Newton |
| `statistics` | ~0.16.x | Distributions (Normal/χ²/t/F) for Wald/t p-values, summary stats | Standard; supplies the test-statistic tail probabilities |
| `math-functions` | ~0.3.4 | `logGamma`, `erf`, numerically-stable helpers under `statistics` | Dependency-level, but call directly for stable exp/log in the kernel |
| `vector` | ~0.13.x | Unboxed arrays for the panel columns | Performance substrate for `hmatrix`/`ad` |
| `cassava` | ~0.5.3 | CSV read/write for panel + analysis outputs | Pure-Haskell CSV; satisfies "no Python munging" and the skill's `{data,analysis}/` CSV layout |
| `aeson` | ~2.2.x | Parse GraphQL JSON responses + BigQuery JSON | Standard JSON; the subgraph and BigQuery REST both return JSON |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `req` OR `http-conduit` | ~3.13 / ~2.3 | HTTPS client for the subgraph POST and BigQuery REST | `req` for ergonomic typed requests; `http-conduit` if streaming large result pages |
| `morpheus-graphql-client` | ~0.28.x | Typed GraphQL client (compile-time schema-checked queries) | **Optional** — only if you want schema-typed queries; plain `http-conduit`+`aeson` POST of a query string is simpler and recommended for a fixed handful of queries |
| `text` / `bytestring` | (boot) | String/byte handling | Everywhere |
| `containers` | (boot) | `Map` for tokenId → cluster grouping in the sandwich SE | Cluster aggregation |
| `optparse-applicative` | ~0.18 | CLI for the pipeline stages (fetch / build-panel / estimate) | Reproducible stage invocation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `hmatrix` + hand-rolled LM | `hmatrix-gsl` (`nlFitting`, L-M) | **Rejected**: needs GSL, which is NOT installed → adds a system-install Wave-0 task and a non-reproducible native dep. Only revisit if GSL install is cheap. |
| hand-rolled LM | `nonlinear-optimization` (CG_DESCENT C binding) | Viable, but wraps a C solver (extra native build) and is unconstrained-only; hand-rolled Gauss–Newton/LM with `ad` Jacobians is fully in-Haskell, testable, and small for a 3-parameter model. |
| plain `http-conduit`+`aeson` | `morpheus-graphql-client` | Typed queries are nice but overkill for ~5 fixed queries; adds schema-codegen ceremony. |
| `cassava` CSV | `parquet` (e.g. `parquet-hs`) | Parquet support in Haskell is immature; CSV is the reproducible, skill-aligned choice. The spec's `{data}/` layout is CSV-native. |

**Installation (representative — pin to the chosen LTS):**
```bash
# in econometrics/  (stack manages its own GHC per resolver; system GHC 9.10.3 need not match)
stack new econometrics
# package.yaml deps: hmatrix, ad, statistics, math-functions, vector, cassava, aeson, req, optparse-applicative
stack build
```

**Version verification (do at plan/Wave-0 time — these are training-informed, MEDIUM confidence):**
```bash
# choose an LTS that ships hmatrix and pairs with a recent GHC, then:
stack --resolver lts-XX.Y ls dependencies | grep -E 'hmatrix|ad |statistics|cassava|aeson'
```
> IMPORTANT: I could not reach Stackage from the researcher toolset — versions above are from training and MUST be confirmed against the pinned LTS during Wave-0. `hmatrix` builds against the **already-present** BLAS/LAPACK; do NOT add `hmatrix-gsl`.

## Architecture Patterns

### Recommended Project Structure
```
econometrics/
├── package.yaml / stack.yaml     # LTS pin (reproducibility)
├── src/
│   ├── Panel/
│   │   ├── Subgraph.hs           # GraphQL client + paginated fetch (positions, premia, collateral)
│   │   └── Variance.hs           # σ̂²_t + second-window instrument from BigQuery swap ticks
│   ├── Model/
│   │   ├── Upsilon.hs            # υ(iK,i_t)=υ₀·exp(−κ·|iK−i_t|); moneyness distance; tick grid — MIRRORS Lean
│   │   ├── NLS.hs                # Gauss–Newton / Levenberg–Marquardt with `ad` Jacobian
│   │   └── SandwichSE.hs         # cluster-robust (by tokenId) covariance — HAND-ROLLED
│   ├── Tests/Specification.hs    # υ₀>0, κ>0, κ⁺=κ⁻ Wald/t stats
│   └── Alternatives.hs           # 4 scheduled specs (semiparam, seed-linear, pos-FE, collateral)
├── app/Main.hs                   # optparse stages: fetch | build-panel | estimate | test
└── test/                         # stack test: SandwichSE golden test, model-gradient test
outputs → notes/structural-econometrcics/{data,analysis}/   # NOT under econometrics/ (skill layout)
```

### Pattern 1: NLS via Gauss–Newton/Levenberg–Marquardt with `ad`
**What:** Minimize Σ (π_it − f(θ))², f(θ)=β₀+υ₀·exp(−κ·d_it)·σ̂²_t, θ=(β₀,υ₀,κ). `ad` gives the exact 3-column Jacobian J; LM update θ ← θ − (JᵀJ + μI)⁻¹ Jᵀr with `hmatrix` solve; adapt μ on the residual-norm trend.
**When to use:** the primary NLS specification and the symmetric-decay variant (κ⁺,κ⁻ → 4 params, split d_it by sign of iK−i_t).
**Example:**
```haskell
-- Source: standard Gauss-Newton; ad + hmatrix idiom
import Numeric.AD (jacobian)
import Numeric.LinearAlgebra (Matrix, Vector, (<>), tr, inv, (#>))
model :: Floating a => [a] -> (a, a) -> a          -- theta=[b0,u0,k], (d,s2)
model [b0,u0,k] (d,s2) = b0 + u0 * exp (negate k * d) * s2
-- residuals r(theta); J = jacobian of r; step = inv (tr J <> J + mu*ident) #> (tr J #> r)
```

### Pattern 2: EIV via two-noisy-measures IV/GMM
**What:** σ̂²_t is mismeasured (M1 → attenuation on υ̂₀). Remedy per spec §4.3: instrument σ̂²_t with a *second, independently-windowed* daily variance estimate σ̃²_t (e.g. even-vs-odd swaps, or a disjoint intraday window). GMM moment: E[Z·v]=0 with Z built from σ̃². For the nonlinear model, use the linearized moment or 2-step GMM on the exp-transformed regressor.
**When to use:** the headline estimate (the spec makes this the load-bearing remedy).

### Pattern 3: Cumulative-accumulator → per-epoch delta
**What:** subgraph premia are cumulative totals (`premiaSettled*Total`, `PremiumSettled` running sums). π_it for epoch t = snapshot(end of t) − snapshot(start of t). Snapshot daily by block-at-timestamp; diff consecutive snapshots. This is exactly the M2 discretization error the spec models (inflates SE, no coefficient bias).
**When to use:** panel construction (CTX-PANEL).

### Anti-Patterns to Avoid
- **Reaching for a package's NLS-with-clustered-SE:** none exists in Haskell — the clustered sandwich SE is hand-rolled and unit-tested regardless (locked decision).
- **Using `hmatrix-gsl`:** GSL is not installed; adds a non-reproducible native dep for zero benefit over hand-rolled LM.
- **Mismatching the Lean formulas:** the Haskell `Model/Upsilon.hs` distance and grid must be byte-for-byte the Lean `upsilon` / `upsilonTickSlope` / `PosSpec.tickPrice` (λ=1.0001) forms, or the "formal witness" claim is hollow. Keep the cross-walk table.
- **Estimating with cumulative premia as the LHS:** must diff to per-epoch flows first.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Matrix inverse/solve/SVD | Custom Gaussian elimination | `hmatrix` (present BLAS) | Numerical stability, tested against LAPACK |
| Jacobian of the exp model | Finite differences | `ad` autodiff | Exact derivatives; finite-diff step-size error corrupts κ̂ near the ATM peak |
| Normal/χ²/t/F tail probabilities | Series approximations | `statistics` | p-values for the committed Wald/t tests |
| JSON parsing (subgraph/BigQuery) | Manual string slicing | `aeson` | Robust to field ordering / nulls |
| CSV round-trip of the panel | `printf`/`split` | `cassava` | Quoting/escaping edge cases |
| **Cluster-robust sandwich SE** | — | **HAND-ROLL (no Haskell package ships it)** | This is THE in-phase code artifact; see formula + test below |

**Key insight:** the *only* thing you must hand-roll is the estimator glue (LM loop) and the clustered sandwich SE — everything numeric underneath is a library call. The sandwich SE is small, closed-form, and must be golden-tested against a hand-computed tiny dataset.

### Cluster-robust sandwich SE (the hand-rolled artifact)
For NLS with score contributions, the tokenId-clustered covariance is the CR0 sandwich:
```
V = (JᵀJ)⁻¹ · [ Σ_g (Σ_{it∈g} J_it·v_it)(Σ_{it∈g} J_it·v_it)ᵀ ] · (JᵀJ)⁻¹
```
where `g` indexes tokenId clusters, `J_it` is the row-gradient ∂f/∂θ at obs (i,t), `v_it` the residual. (Optionally apply a G/(G−1)·(N−1)/(N−k) finite-sample correction — decide and document.) SE(θ̂_j)=√V_jj; Wald for κ⁺=κ⁻ uses the 2×2 sub-block. **Test strategy:** golden test on a 2-cluster, 3-obs toy panel where V is computed by hand; assert `stack test` matches to 1e-9.

## Common Pitfalls

### Pitfall 1: Testnet-only subgraph mistaken for the mainnet data source
**What goes wrong:** the documented endpoint is Sepolia; building the "deepest ETH/USDC, full history" panel on it yields sparse/synthetic testnet data.
**Why it happens:** the docs' one worked example uses the Sepolia Goldsky endpoint; the mainnet endpoint is not published in the schema/queries pages.
**How to avoid:** Wave-0 gate — resolve and *ping* a mainnet (or production L2) endpoint, confirm ETH/USDC pool coverage and history depth, before any panel work.
**Warning signs:** pool `underlyingPool` addresses that are not the known mainnet ETH/USDC Uniswap v3 pools; block numbers in the testnet range.

### Pitfall 2: Cumulative premia treated as flows
**What goes wrong:** regressing cumulative `premiaSettled*Total` on σ̂² gives a trending LHS and spurious fit.
**How to avoid:** diff consecutive daily snapshots to per-epoch π_it (Pattern 3).
**Warning signs:** monotone LHS, R² near 1, υ̂₀ absurdly large.

### Pitfall 3: Forward-difference asymmetry breaks the bridging lemma (see full §Bridging Lemma)
**What goes wrong:** the symmetric exp family's discrete slope peaks at BOTH `iK` and `iK−1` and its magnitude profile is centered at `iK−½`; the committed conjunct-3 envelope `exp(−c|i−iK|)` is violated on the entire left branch for any c>0. Aristotle would return UNPROVABLE (or you'd be tempted to weaken to `sorry`).
**How to avoid:** correct the `Prop` envelope locally *before* submission (below); choose `c ≤ κ·Δi`.
**Warning signs:** the proof needs `c ≤ 0`, or an asymmetric family, to close.

### Pitfall 4: Tick-unit mismatch between σ̂² windows and premium epochs
**What goes wrong:** σ̂²_t built on a UTC-day window but premia snapshotted on block-height boundaries → misaligned t, non-classical M3 error becomes correlated.
**How to avoid:** define the daily epoch once (block-at-timestamp for a fixed UTC hour) and use the SAME boundary for both the subgraph snapshot and the BigQuery variance window; the second instrument uses a *disjoint sub-window within the same day*.

### Pitfall 5: Aristotle queue race (memory: lean-aristotle-heavy-workflow / aristotle-no-queue)
**What goes wrong:** submitting the bridging-lemma task while another is in-flight overwrites the prior proof upload.
**How to avoid:** strictly one in-flight task; poll `aristotle tasks` every ~5 min; integrate the returned archive with the `RequestProject.→vol_markets.` import rewrite (08-05 recipe).

## Code Examples

### Subgraph query — open positions for a pool (verified shape from docs)
```graphql
# Source: https://panoptic.xyz/docs/subgraph/queries
query GetOpenPanopticPositionsByAccountAndUniswapPool {
  panopticPoolAccounts(
    where: { panopticPool_: { underlyingPool: "<POOL_ADDR>" } }
  ) {
    panopticPool {
      underlyingPool { id token0 { name } token1 { name } feeTier }
    }
    accountBalances(first: 1000, where: {isOpen: 1},
                    orderBy: createdBlockNumber, orderDirection: desc) {
      createdBlockNumber isOpen positionSize
      tokenId { id }
      txnOpened { id eventType ... on OptionMint { hash timestamp } }
    }
  }
}
```

### Subgraph entities for π_it, i_K, width, Q_M (schema, verified)
```text
# Source: https://panoptic.xyz/docs/subgraph/schema
TokenId    { id, idHexString, pool, tokenCount, legs[] }
Leg        { strike, width, isLong, optionRatio, asset, tokenType, riskPartner, chunk }
PremiumSettled { settledAmount0/1, settledAmount0/1InEth, ...InUsd, legIndex }   # per-settlement event
AccountBalance { premiaSettled0Total, premiaSettled1Total, ...InEthTotal, ...InUsdTotal }  # CUMULATIVE → diff
Collateral { totalShares, poolUtilization }
PanopticPoolAccount { collateral0Shares, collateral1Shares, collateral0, collateral1 }
CollateralDeposit / CollateralWithdraw { shares, amounts, timestamp }
```
- **i_K (strike tick):** `Leg.strike` (convert price→tick via i_K = log_λ K, λ=1.0001, matching `PosSpec.tickPrice`).
- **width:** `Leg.width` (in tick-spacing units — matches `PosSpec.width_span`).
- **π_it:** daily delta of `AccountBalance.premiaSettled*Total` (or aggregate `PremiumSettled` events per epoch).
- **Q_M (collateral, robustness channel):** `PanopticPoolAccount.collateral*Shares` + `Collateral.totalShares`/`poolUtilization`.

### BigQuery — Uniswap v3 Swap ticks for σ̂²_t (approach; verify at exec)
```sql
-- Source: public dataset bigquery-public-data.crypto_ethereum.logs
-- Swap(address,address,int256,int256,uint160,uint128,int24) — topic0 = keccak256 of that signature
-- (compute topic0 at exec; the trailing int24 field in `data` is the pool tick)
SELECT block_timestamp, transaction_hash,
       -- decode last 32-byte word of data as int24 tick (sign-extend)
       data
FROM `bigquery-public-data.crypto_ethereum.logs`
WHERE address = LOWER('<UNISWAP_V3_ETH_USDC_POOL>')
  AND topics[OFFSET(0)] = '<SWAP_TOPIC0>'
  AND DATE(block_timestamp) BETWEEN '<start>' AND '<end>'
ORDER BY block_number, log_index;
-- σ̂²_t = realized variance of the within-day tick-implied log-price series;
-- instrument σ̃²_t = same estimator on a disjoint intraday sub-window.
```
> The public dataset `bigquery-public-data.crypto_ethereum` (tables `logs`, `transactions`, `blocks`) covers Ethereum **mainnet**. For an L2 Panoptic market, confirm the corresponding public dataset (e.g. an Optimism/Base/Arbitrum export) — coverage there is not guaranteed and is a Wave-0 check.

## Bridging Lemma — Feasibility Analysis (HIGH confidence; the phase's headline trap)

### The exact committed target (`lean/vol_markets/Upsilon.lean`)
```lean
def ATMOTMNullHypothesis (υfun : ℤ → ℝ) (Δi : ℝ) (iK : ℤ) (c : ℝ) : Prop :=
  (0 < c) ∧
  (∀ i : ℤ, |upsilonTickSlope υfun Δi i| ≤ |upsilonTickSlope υfun Δi iK|) ∧
  (∀ i : ℤ, |upsilonTickSlope υfun Δi i|
      ≤ |upsilonTickSlope υfun Δi iK| * Real.exp (-c * |(i:ℝ) - (iK:ℝ)|))
-- upsilonTickSlope υfun Δi i = (υfun (i+1) - υfun i) / Δi   (FORWARD difference)
```
The candidate witness (CONTEXT): `υfun i = υ₀ · exp(−κ·Δi·|i − iK|)`, i.e. with `β := exp(−κ·Δi) ∈ (0,1)`, `υfun(iK±n) = υ₀·β^n`.

### The obstruction (parameter-independent — verified numerically)
Compute the forward-difference slope magnitudes (take `υ₀>0`, `Δi>0`):
- `|slope(iK)|   = υ₀(1−β)/Δi`  ← peak
- `|slope(iK−1)| = υ₀(1−β)/Δi`  ← **equal peak (tie)**
- `|slope(iK+n)|   = υ₀·β^n·(1−β)/Δi`  for n ≥ 0
- `|slope(iK−1−n)| = υ₀·β^n·(1−β)/Δi`  for n ≥ 0

So the slope-magnitude profile is **symmetric about `iK − ½`, not `iK`**. Consequences:
- **Conjunct 2** (`∀i, |slope i| ≤ |slope iK|`): **TRUE** (β^n ≤ 1; ties allowed by `≤`). ✓
- **Conjunct 3** (`|slope i| ≤ |slope iK|·exp(−c|i−iK|)`, c>0): **FALSE on the whole left branch.** At `i = iK−1−n` the LHS is `peak·β^n` but the envelope is `peak·exp(−c(n+1))`; e.g. at `i=iK−1`, LHS=peak, envelope=peak·e^{−c} < peak. Requiring it for all left-branch i forces `c ≤ 0`, contradicting conjunct 1. Verified numerically (a=0.4): `i−iK ∈ {−4,−3,−2,−1}` all fail; the whole left half is over the envelope.

This is independent of υ₀, κ, Δi, c — no parameter choice rescues it. **The literal committed `Prop` cannot be witnessed by the symmetric exponential forward-difference family.**

### The fix (verified) — correct conjunct 3 to the slope-centered envelope
The forward difference is inherently right-shifted by one index; the honest discrete envelope tolerates the one-step straddle. Replace conjunct 3's exponent with a slope-centered distance. Verified-working forms (both pass for all i with `c ≤ κ·Δi`):
```lean
-- Option A (loosest, simplest): allow the ±1 forward-difference straddle
Real.exp (-c * (max 0 (|(i:ℝ) - (iK:ℝ)| - 1)))
-- Option B (tight, slope-centered about iK−½): distance to the peak-pair {iK-1, iK}
Real.exp (-c * (max ((i:ℝ) - iK) (-((i:ℝ) - iK) - 1)))
```
With `c := κ·Δi` (so `β = e^{−c}`), Option A gives `|slope(iK+n)| = peak·β^n ≤ peak·e^{−c·max(0,n−1)}` and `|slope(iK−1−n)| = peak·β^n ≤ peak·e^{−c·n}` — all ✓ (numerically confirmed, every i True). Option B is the exact envelope (`|slope| = peak·β^{g(i)}`, `g(i)=max(i−iK, −(i−iK)−1)`).

**Why amending is safe:** `grep` confirms `ATMOTMNullHypothesis` has **no downstream consumers** — no lemma references it (it is a pinned statement only). Editing conjunct 3 breaks no existing proof, and the two proved υ lemmas (`upsilon_volOption`, `upsilon_eq_deltaShares_slot`) are untouched. CONTEXT explicitly puts "the bridging-lemma statement details" and "whether the moneyness-in-slope form is needed" in Claude's discretion — this IS the moneyness-in-slope correction the user anticipated.

### Recommended bridging lemma to submit to Aristotle
```lean
-- Hypotheses: υ₀ > 0, κ > 0, Δi > 0, c = κ*Δi, υfun i = υ₀ * Real.exp (-κ*Δi*|(i:ℝ)-(iK:ℝ)|)
theorem exp_family_witnesses_ATMOTM
    (υ₀ κ Δi : ℝ) (iK : ℤ) (hυ : 0 < υ₀) (hκ : 0 < κ) (hΔ : 0 < Δi) :
    ATMOTMNullHypothesis
      (fun i => υ₀ * Real.exp (-κ * Δi * |(i:ℝ) - (iK:ℝ)|)) Δi iK (κ*Δi) := by
  sorry  -- Aristotle (single serial task, new project) — with conjunct 3 corrected as above
```
- **Difficulty for Aristotle:** MEDIUM. The heart is the real-analysis bound `β^n ≤ e^{−c·g}` and the abs/max case-split on `i` vs `iK` (`iK`, `iK−1`, right branch, left branch). Mathlib has `Real.exp_le_exp`, `Real.exp_nonneg`, `abs_le`, `pow_le_one`, monotonicity of `exp` — all present. Provide the algebraic normal form (β = exp(−c)) in the bundle notes to steer it.
- **Fallback if Aristotle balks at Option B:** submit with Option A (simpler `max 0 (·−1)`), which is a valid upper envelope and easier to bound.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dune SQL (structural-econometrics skill default) | Panoptic subgraph + BigQuery public data | This phase (documented deviation) | No Dune MCP; subgraph gives tokenId-level positions Dune can't easily reconstruct |
| `hmatrix-gsl` `nlFitting` for NLS | `hmatrix` + `ad` + hand-rolled LM | This phase (GSL absent) | Reproducible, no native GSL dep |
| Seed linear interaction υ(ī)+ (Δυ/Δi)·i | Exponential-moneyness υ₀·exp(−κ·d) | Spec 08-03 | Null is about *shape* (ATM max, OTM decay) — linear term can't express it |

**Deprecated/outdated for this phase:**
- Dune mandate in the structural-econometrics skill — overridden by the hybrid subgraph+BigQuery route (locked).
- Any assumption that the subgraph is mainnet by default — the docs' worked endpoint is Sepolia.

## Open Questions

1. **Mainnet (or production L2) Panoptic subgraph endpoint + auth** — CRITICAL.
   - What we know: full entity schema; one working endpoint (Sepolia, Goldsky, no key).
   - What's unclear: the mainnet/L2 endpoint URL, whether a Graph gateway API key is required, which chain hosts the deepest ETH/USDC market.
   - Recommendation: **Wave-0 discovery gate** — probe Goldsky for a `panoptic-subgraph-mainnet`/L2 sibling and/or The Graph Explorer; if a gateway key is needed, add `GRAPH_API_KEY` to the worktree `.env` the same way as `ARISTOTLE_API_KEY` (CONTEXT note). Do not start the panel until confirmed.

2. **BigQuery reachability from this session** — the `mcp__bigquery__*` tools and `ToolSearch` are **NOT available in the researcher agent's toolset**, so I could not run the dry-run/list-tables verification the brief suggested.
   - What we know: `bigquery-public-data.crypto_ethereum` (logs/transactions/blocks) is the standard mainnet source; Swap event signature is fixed.
   - What's unclear: whether the executing session actually has `mcp__bigquery__` connected, the exact Swap topic0 (compute via keccak256 at exec), and the L2 public-dataset name if the market is on an L2.
   - Recommendation: Wave-0 — from the *execution* session run `list-tables`/`describe-table` on `crypto_ethereum.logs` and a cheap `LIMIT 100` dry-run for the chosen pool address; confirm topic0.

3. **Exact Stackage LTS + package versions** — I could not reach Stackage.
   - Recommendation: Wave-0 — pick an LTS carrying `hmatrix`; confirm `stack build` links the present BLAS/LAPACK; pin in `stack.yaml`.

4. **GSL install policy** — if any reviewer insists on `hmatrix-gsl`, GSL must be system-installed (Arch: `pacman -S gsl`), which is outside the Lean session's clean scope. Recommendation: **avoid** by using the hand-rolled LM path.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework (Haskell) | `hspec` or `tasty` via `stack test` (choose at scaffold; `hspec` simplest) |
| Config file | `econometrics/package.yaml` test stanza — created in Wave-0 |
| Quick run command | `stack test econometrics:test:unit` (sandwich-SE + gradient goldens) |
| Full suite command | `stack test` (all Haskell) + `lake build vol_markets` (Lean gate) |
| Lean gate | `cd lean && lake build vol_markets` → exit 0, zero sorries; `#print axioms` scratch check |
| Artifact gates | `grep`/file-existence on `notes/structural-econometrcics/{data,analysis}/` outputs |

### Phase Requirements → Test Map
| Tag | Behavior | Test Type | Automated Command | Exists? |
|-----|----------|-----------|-------------------|---------|
| CTX-PANEL | Panel built, tokenId×daily, per-epoch π_it (delta of cumulative) | integration | `stack test econometrics:test:panel` (fixture JSON → expected rows) | ❌ Wave 0 |
| CTX-VAR | σ̂²_t + instrument from tick series match a golden window | unit | `stack test econometrics:test:variance` | ❌ Wave 0 |
| CTX-EST | LM converges on synthetic data to known (β₀,υ₀,κ) within tol | unit | `stack test econometrics:test:nls` (recover planted params) | ❌ Wave 0 |
| CTX-EST | **Cluster-robust sandwich SE** matches hand-computed toy panel | unit | `stack test econometrics:test:sandwich` (golden, 1e-9) | ❌ Wave 0 |
| CTX-TEST | Wald/t stats for υ₀>0, κ>0, κ⁺=κ⁻ computed correctly | unit | `stack test econometrics:test:specification` | ❌ Wave 0 |
| CTX-ALT | 4 alternative specs run and emit comparable estimates | integration | `stack test econometrics:test:alternatives` (smoke) | ❌ Wave 0 |
| CTX-BRIDGE | Bridging lemma builds sorry-free, axiom-clean | build | `cd lean && lake build vol_markets` + `#print axioms` | partial (lib green today; lemma new) |
| CTX-AUDIT | audit-econ PASS on the analysis output | manual/gate | invoke `audit-econ notes/structural-econometrcics/analysis/<file>` (3 Opus agents, Delphi) | ❌ post-estimation |

### Sampling Rate
- **Per task commit:** `stack test econometrics:test:unit` (fast goldens) and, for Lean-touching tasks, `lake build vol_markets`.
- **Per wave merge:** full `stack test` + `lake build vol_markets`.
- **Phase gate:** full suite green + `lake build vol_markets` sorry-free/axiom-clean + **audit-econ PASS** before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `econometrics/` Stack project scaffold + LTS pin + `stack build` green (BLAS/LAPACK link confirmed, NO `hmatrix-gsl`).
- [ ] `test/` suite skeleton (`hspec`/`tasty`) + the sandwich-SE golden fixture.
- [ ] Confirm mainnet/L2 subgraph endpoint + auth (blocks CTX-PANEL).
- [ ] Confirm BigQuery `mcp__bigquery__` connectivity from the exec session + Swap topic0 (blocks CTX-VAR).
- [ ] Lock the corrected `ATMOTMNullHypothesis` conjunct-3 statement locally + local `lake build` before the single Aristotle submission (blocks CTX-BRIDGE).

## audit-econ Gate (mechanics — verified)

- **Skill exists:** `/home/jmsbpp/.claude/skills/audit-econ/SKILL.md` (+ `references/`). Confirmed present.
- **Invocation:** `audit-econ <target_path> [--agents N] [--effort max|high|medium]`; defaults 3 Opus sub-agents, high effort.
- **Input it needs:** the analysis file(s) (`.md`/`.hs`/`.ipynb`/etc.) plus the **full data lineage** — it traces backwards from the analysis to raw data (subgraph pulls, BigQuery exports) and audits every file in the lineage. So the `notes/structural-econometrcics/{data,analysis}/` outputs must be self-describing (paths, construction steps) for the audit to trace.
- **Process:** independent sub-agents → Delphi consensus → severity-sorted findings (Critical/High/Mid/Low). Output at `quality_reports/audits/<date>-<phase>-audit.md` per the skill registry.
- **Different-agent rule (CONTEXT):** the audit dispatch is independent of the estimation author — satisfied by the skill's own independent-sub-agent design.
- **Gate semantics:** any Critical/High that maps to a spec-faithfulness or estimator-correctness defect FAILs the phase; fix and re-audit.

## Sources

### Primary (HIGH confidence)
- Local toolchain probe: `ghc 9.10.3`, `stack 3.11.1`, `cabal 3.16.1.0`, `lean 4.32.0 / lake 5.0.0`; `ldconfig` shows `liblapack/libblas/libcblas`, **no GSL** (`gsl-config`/`gsl.pc`/`/usr/include/gsl` absent).
- `lean/vol_markets/Upsilon.lean`, `Panoptic.lean`, `PosSpec.lean` — exact definitions (`upsilon`, `upsilonTickSlope`, `ATMOTMNullHypothesis`, `tickPrice`, λ=1.0001).
- `notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md` — the binding econometric spec.
- `.planning/phases/08-.../08-05-SUMMARY.md` — Aristotle bundle recipe (bundle layout, `RequestProject.→vol_markets.` rewrite, `aristotle tasks` watcher).
- `/home/jmsbpp/.claude/skills/audit-econ/SKILL.md` — gate mechanics.
- Numeric verification (local Python scratch) of the bridging-lemma obstruction and both envelope fixes — reproduced above.
- https://panoptic.xyz/docs/subgraph/schema — entity schema (TokenId, Leg, PremiumSettled, AccountBalance, Collateral, PanopticPoolAccount).
- https://panoptic.xyz/docs/subgraph/queries — worked query + **Sepolia** Goldsky endpoint.

### Secondary (MEDIUM confidence)
- Haskell package roles/versions (`hmatrix`, `ad`, `statistics`, `cassava`, `aeson`, `req`) — training-informed; **confirm versions against the pinned LTS in Wave-0**.
- `bigquery-public-data.crypto_ethereum` schema (logs/transactions/blocks) and Uniswap v3 Swap signature — standard public knowledge; confirm topic0 + L2 dataset at exec.

### Tertiary (LOW confidence — flagged for validation)
- Existence/URL of a **mainnet or L2** Panoptic subgraph endpoint — NOT found in docs; only Sepolia is published. Wave-0 discovery required.
- Whether `mcp__bigquery__` is actually connected in the executing session — NOT verifiable from the researcher toolset.

## Metadata

**Confidence breakdown:**
- Toolchain / build implications: HIGH — direct local probe (GSL absent, BLAS/LAPACK present).
- Bridging-lemma analysis: HIGH — exact Lean source + numeric proof of the obstruction and fix.
- Haskell stack recommendation: MEDIUM — roles certain, exact versions need LTS confirmation.
- Subgraph data access: LOW on the mainnet endpoint (schema HIGH, endpoint unknown).
- BigQuery: MEDIUM on approach, LOW on session connectivity (tools unavailable to researcher).
- audit-econ: HIGH — skill inspected.

**Research date:** 2026-07-19
**Valid until:** ~2026-08-18 for the toolchain/lemma findings; ~7 days for the subgraph-endpoint question (deployment state moves fast).

---

## ADDENDUM (2026-07-19, post-research)

**SUPERSEDED FINDING — GSL.** The "GSL ABSENT → avoid hmatrix-gsl" finding above was correct at research time but was superseded minutes later: the user installed **GSL 2.8-1** via pacman (verified: `gsl-config --version` → 2.8, headers at /usr/include/gsl/). Current constraint (authoritative, reflected in the plans): **hmatrix-gsl is REQUIRED** — `Numeric.GSL.Fitting` LM is the PRIMARY NLS optimizer; the `ad`-based hand-rolled loop is retained only as a cross-check golden. Sandwich SEs / Wald tests / EIV-IV remain hand-rolled as recommended.

**ARCHITECTURE ADDITION.** User decision post-research: Haskell-primary + **GAMS point-estimate differential cross-check** (CTX-XCHECK, plan 09-10) — panel CSV + verbatim NLS objective handed to the GAMS-development session via claude-peers; no `.gms` authored in this session; non-blocking for phase completion.
