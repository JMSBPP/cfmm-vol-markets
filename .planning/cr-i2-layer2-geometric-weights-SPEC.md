# CR-I2 Layer 2 — geometric leg weights design spec (v2)

Status: IMPLEMENTED (weight vector), v2. Two-step-reviewed, then built via 3 TDD increments
(shared helper refactor + `geometric_cumulative_density_x96` primitive @ `2252f7f`;
`geometric_leg_weights` @ `5706f0e`). 8 Layer-2 tests green; Layer-1 (10) + PanopticTokenId (4)
regressions green. Mint SIZING (LiquidityChunk/positionSize) and optionRatio quantization remain
future increments — CR-I3's sized deliverable stays OPEN.

Prior status: DRAFT v2 (post review-round-1). Reviewed by Reality Checker + Solidity Smart Contract
Engineer; both NEEDS WORK, no fixed-point BLOCKER (all Q96 arithmetic assumptions verified sound).
v2 folds in: shared split-point helper + explicit preconditions (RC BLOCKER), exact-sum invariant +
per-weight bounds + ordering guard (both MAJOR), restated monotonicity test, dropped `xi>1` branch,
downgraded CR-I3 claim. Scope unchanged: **weight vector only**, home = `src/lib/ldf/LDFLib.plk`.

## 0. Context

CR-I2 Layer 1 (DONE) builds a mintable 4-leg Panoptic tokenId skeleton (uniform `optionRatio=1`).
Layer 2 computes the **geometric weights** the legs should carry (Carr–Madan/Demeterfi replication;
"longing options = providing liquidity" — the weights ARE the replication). This increment computes
ONLY the normalized weight vector; mint sizing (positionSize/token amounts, the `LiquidityChunk`) and
optionRatio quantization are LATER increments.

## 1. Objective

Two deliverables:

1. **`geometric_cumulative_density_x96(m, iota, xi_x96) -> u256`** in `GeometricDistribution.plk` —
   the reusable, single-`u256` primitive `cumMass(m) = (1 − ξ^m)/(1 − ξ^ι)` in Q96 (matches the
   file's existing single-`u256` style; is the differentially-tested unit).
2. **`geometric_leg_weights(i_l, i_u, Δ, i_star, m_p, m_c) -> LegWeights`** in `LDFLib.plk` — returns
   `LegWeights { w0, w1, w2, w3 }` (Q96), the four legs' normalized geometric masses over the CR-I2
   sub-bucket tiling. `Σ w_k == Q96` EXACTLY (§3.2). Struct return has precedent
   (`vol_order_to_panoptic_token_id` returns `PanopticTokenId`, green in
   `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol`).

## 2. Grounding — proven lean statements (all verified present, no sorry/admit/axiom)

| Claim | Lean lemma | File:line |
|---|---|---|
| `w_k = ξ^k(1−ξ)/(1−ξ^ι)`, `Σ_{k<ι} w_k = 1` | `GeomProfile.geomWeight`, `geomWeight_sum` | `GeomProfile.lean:54, 65` |
| geometric family IS the varswap strike weighting | `varswapWeight_normalized`, `strikeWeight_bridge` | `GeomProfile.lean:259`, `VolInstrument.lean:348` |
| liquidity-layer ratio `ξ⋆ = 1.0001^(−Δ/2)` | `logContractLiquidity_geometric` | `GeomProfile.lean:301` |
| per-column concentration `ξ<1` | `geomWeight_strictAnti` | `GeomProfile.lean:136` |

Honesty (unchanged from Layer 1): `logContractLiquidity_geometric` proves geometricity GIVEN the
`K^(−1/2)` density; the density premise is asserted (curvature bridge future work,
`GeomProfile.lean:294–299`). So ξ⋆ is "geometricity proven, density premise asserted" — NOT
"ξ⋆ proven". `geometric_leg_weights` is thus a SPECIALIZATION of the general kernel (which takes
`xi_x96` as a free parameter, `GeometricDistribution.lean:11`) under that asserted premise.

## 3. The math

### 3.1 Closed form (verified correct by both reviewers)
`cumMass(m) = Σ_{k=0}^{m-1} ξ^k(1−ξ)/(1−ξ^ι) = (1 − ξ^m)/(1 − ξ^ι)`. `cumMass(0)=0`, `cumMass(ι)=1`.
Leg over columns `[c_lo, c_hi)` has weight `cumMass(c_hi) − cumMass(c_lo) = (ξ^{c_lo}−ξ^{c_hi})/(1−ξ^ι)`.

### 3.2 EXACT sum (corrected from v1's wrong "±dust")
The 4 weights are differences of SHARED, deterministic cumulative endpoints (`den` computed once,
each `cumMass(c_k)` a pure function of its input). They telescope:
`Σ w_k = cumMass(c4) − cumMass(c0) = cumMass(ι) − cumMass(0) = Q96 − 0 = Q96`, EXACTLY. Endpoints are
exact: `rpow(ξ,0,Q96)=Q96 ⇒ cumMass(0)=0`; `cumMass(ι)=mulDiv(den,Q96,den)=Q96`. Interior roundings
at `cumMass(c1..c3)` each appear once `+` and once `−` and cancel. **The implementation MUST telescope
(differences of a single shared `cumMass`), and the test MUST assert `Σ w_k == Q96` exactly** — a
tolerance test would pass a broken non-telescoping impl.

### 3.3 xi>1 branch: OMITTED (YAGNI)
`ξ⋆ = getSqrtRatioAtTick(−Δ) < Q96` for every `Δ ≥ 1`, so the CR-I2 caller provably never reaches
`xi > 1`. Per "no untested/unreachable path", the `xi > 1` branch is NOT implemented. The `xi <= 1`
formula naturally reverts (via `mulDiv` div-by-zero) on the impossible `xi == Q96`. If a future caller
needs `xi > 1`, add the branch `(ξ_inv^{ι−m} − ξ_inv^{ι})/(1 − ξ_inv^{ι})` WITH its own test then.

### 3.4 Parameters
- `ξ⋆ = getSqrtRatioAtTick(0 -% Δ)` = `1.0001^(−Δ/2)` in Q96 (verified; retires the M2 fractional-rpow
  debt — integer-tick lookup, no fractional exponent).
- `ι = (i_u -% i_l) </ Δ`; column of tick `t`: `c(t) = (t -% i_l) </ Δ`. Unsigned `</` ≡ `@evm_sdiv`
  here because within `[i_l,i_u]`, `t ≥ i_l` ⇒ `(t -% i_l)` is a small positive `< 2^24` (high bit
  clear) — verified by both reviewers.

## 4. Preconditions & shared split-point helper (resolves RC BLOCKER + §6.1)

The weights correspond to legs ONLY if the column boundaries are computed from the IDENTICAL split
points Layer 1 used. Therefore:

1. **Extract a shared helper** `vol_order_split_points(i_l, i_u, i_star, Δ) -> (m_p, m_c)` (Δ-aligned
   mid split points, `round_tick`-floored) into a shared location, and have BOTH
   `vol_order_to_panoptic_token_id` (Layer 1) AND `geometric_leg_weights` (Layer 2) call it. Layer 1's
   inline `m_p/m_c` computation (`PanopticTokenIdSetterLib.plk:30-31`) is replaced by a call to it.
2. **`geometric_leg_weights` takes the split points as inputs** (`i_star, m_p, m_c`) rather than
   re-deriving — the caller (which built the tokenId) passes the exact values.
3. **Explicit preconditions** (documented; guarded where cheap):
   - `Δ ≡ tickSpacing` — the same quantity tiles the legs AND parameterizes `ξ⋆`. (Δ ≥ 1, else `</`
     reverts.)
   - `i_l, i_u, i_star, m_p, m_c` are all multiples of Δ (Layer 1 `round_tick`s all of them; `i_l/i_u`
     come from `split_tick`'s `round_tick`, `SpreadTickAssimetry.plk:39,41`) — so `</` is exact, not
     truncating.
   - Ordering `0 = c0 ≤ c1 ≤ c2 ≤ c3 ≤ c4 = ι` (Layer 1's ≥2Δ guard ⇒ strict interior).

## 5. Algorithm

```
// primitive (GeometricDistribution.plk)
const geometric_cumulative_density_x96 = fn (m: u256, iota: u256, xi_x96: u256) u256 {
    let den = Q96 -% rpow(xi_x96, iota, Q96);          // (1 - xi^iota); > 0 for xi<Q96, iota>=1
    mulDiv(Q96 -% rpow(xi_x96, m, Q96), Q96, den)      // (1 - xi^m)/(1 - xi^iota), floor
};

// weights (LDFLib.plk)
const geometric_leg_weights = fn (i_l, i_u, Δ, i_star, m_p, m_c) LegWeights {
    let xi   = getSqrtRatioAtTick(0 -% Δ);
    let iota = (i_u -% i_l) </ Δ;
    let c1 = (m_p    -% i_l) </ Δ;
    let c2 = (i_star -% i_l) </ Δ;
    let c3 = (m_c    -% i_l) </ Δ;
    // ordering guard (MINOR: surfaces a Layer-1 boundary bug as a revert, not a 2^256 leg)
    require(!@evm_slt(c1, 0) and !@evm_slt(c2, c1) and !@evm_slt(c3, c2) and !@evm_slt(iota, c3));
    let den = Q96 -% rpow(xi, iota, Q96);              // cache; reused across cum(c_k)
    // cum(m) = mulDiv(Q96 -% rpow(xi,m,Q96), Q96, den); cum(0)=0, cum(iota)=Q96
    let cum1 = mulDiv(Q96 -% rpow(xi, c1, Q96), Q96, den);
    let cum2 = mulDiv(Q96 -% rpow(xi, c2, Q96), Q96, den);
    let cum3 = mulDiv(Q96 -% rpow(xi, c3, Q96), Q96, den);
    // telescoping differences off shared endpoints: 0, cum1, cum2, cum3, Q96
    LegWeights { w0: cum1, w1: cum2 -% cum1, w2: cum3 -% cum2, w3: Q96 -% cum3 }
};
```

(`geometric_leg_weights` inlines `cumMass` with the shared `den` rather than calling the primitive 4×,
to cache `den` and reuse `rpow(xi,iota)`; the standalone primitive is the tested unit + future reuse.)

## 6. Resolved sub-decisions
1. **Return type:** `LegWeights { w0,w1,w2,w3 }` struct (precedent verified). Plus the single-`u256`
   `geometric_cumulative_density_x96` primitive as the differential-test unit.
2. **Split points:** passed in from Layer 1 via the shared helper (§4) — not re-derived.
3. **Sum invariant:** exact `== Q96` (§3.2), not a tolerance.
4. **LDFLib stub:** the malformed `liquidity_on_vega_with_tick_bucket(...) LiquidityChunk {}`
   (`LDFLib.plk:3`, non-compiling: missing `= fn`, undefined types) is REPLACED by
   `geometric_leg_weights`. The sized-`LiquidityChunk` intent stays a later increment.

## 7. Known limitations
- Weight vector only; no mint sizing (`LiquidityChunk`/positionSize) — later increment.
- No optionRatio quantization (weights deliberately stay out of the tokenId).
- ξ⋆ density premise asserted (curvature bridge open, §2).
- **CR-I3 (corrected):** this closes only the WEIGHT-VECTOR portion; CR-I3's sized-`LiquidityChunk`
  deliverable remains open. Do NOT mark CR-I3 fully done.

## 8. Test plan (TDD — RED first)

Extend `test/.../VolOrderToPanopticTokenId*` (or a sibling harness). Differential vs Solidity recompute.

1. **Primitive closed form.** `geometric_cumulative_density_x96(m, ι, ξ)` matches Solidity
   `(1−ξ^m)/(1−ξ^ι)` in Q96 over fuzzed `(m ≤ ι, ι, Δ)`; `cum(0)=0`, `cum(ι)=Q96` exactly.
2. **Exact sum.** `w0+w1+w2+w3 == Q96` EXACTLY (not a tolerance).
3. **Per-weight bounds.** `0 ≤ w_k ≤ Q96` for each leg (catches a wrapping-underflow leg that the
   exact-sum test alone would miss).
4. **Half-monotonicity (corrected).** For ξ<1: `w0 ≥ w1` and `w2 ≥ w3` only (equal put/call
   half-widths). NOT the cross-`i*` `w1 ≥ w2` (false when `i*` off-center).
5. **Golden vector.** CR-I2 golden bucket (`[-500,500]`, Δ=10, `i*=0`, split ∓250 ⇒ 4 equal-width
   25-column legs) ⇒ 4 explicit weights recomputed in Solidity. (Equal-width, so here `w0≥w1≥w2≥w3`.)
6. **Alignment with Layer 1.** The column boundaries equal Layer 1's ACTUALLY-EMITTED leg boundaries
   (decode the tokenId's legs, not a re-derivation), via the shared helper.
7. **Ordering guard.** A crafted boundary violation reverts (not a 2^256 leg).

## 9. References
- `JMSBPP/cfmm-vol-markets-spec` `lean/vol_markets/GeomProfile.lean` (geomWeight/sum/strictAnti/logContractLiquidity).
- `JMSBPP/cfmm-vol-markets-spec` `notes/VOLATILITY_INSTRUMENTS.md`; `refs/DemeterfietalVarianceSwaps.pdf` (App A, 1/K²).
- `src/lib/ldf/GeometricDistribution.plk` (density + cumulative amounts, primitives).
- `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` (Layer 1; shared-helper source).
- `.planning/cr-i2-vol-order-to-panoptic-token-id-SPEC.md` (Layer 1, the 3-layer split).
