# Panoptic vol-claim upsilon: RUN 2, seller-side normalized LHS (v3)

**Phase 10, plan 10-10, run 2 — THE TERMINAL ESTIMATION RUN OF PHASE 10.**

Executed under pivot lock `phase10-plan10-10-run2`, locked BEFORE this run
and verified by hash at run time:

```
PIVOT_LOCK: .planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-10-PIVOT-LOCK.md
PIVOT_LOCK_SHA256: 56044349a035221874eb93d59ab64bd94239be698e4e47363118bffd743e9998  VERIFIED
```

The lock's own closing clause makes that hash load-bearing — "any post-commit
edit to this file voids the lock" — so the estimator ABORTS rather than run
against edited terms. Provenance: `10-10-DISPOSITION-MEMO.md` (the defect, what
was NOT done, the bug-fix exemption reasoning) and the user's verbatim
`escalate-anomaly` adjudication quoted there.

**Run 1 is not superseded and not corrected.** Its analysis
(`2026-07-20-upsilon-estimates-v2.md`) is frozen with a CORRECTIONS header and
stays on the record permanently, verdict included. This document adds a second
construction beside it; it does not replace the first.

Estimation of the spec section-4.3 equation, VERBATIM and unchanged:

> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`

Run date: 2026-07-27. Git commit: `cda0a15`.

## 0. Headline

**RUN 2 STOPPING_RULE: UNINFORMATIVE.** With the LHS normalized to the seller side — the single change this iteration was authorised to make — the upsilon0 clustered-CI half-width is +/-1.979569e-1 against the unchanged bar of +/-6.200000e-5. Run 1's half-width was +/-1.479533e-1 (verdict UNINFORMATIVE). upsilon0-hat moves 3.597340e-2 -> 0.106332 with clustered SE 7.548636e-2 -> 0.100998, and its CI still contains zero. kappa-hat = 3.041754e-2 (SE 1.245733e-2, p = 7.308348e-3), so the run-1 rejection of a flat vega profile PERSISTS. The bar was not met, and this is the terminal run.

## 1. THE SINGLE CHANGE

Rows belonging to LONG tokenIds have `premium_wei` multiplied by **−1**, so
long and short vega enter the regression with ONE sign. That is Phase 9's
documented convention: `Panel.Build.premiumUsd` applies
`sign = if isLong then -1 else 1` with the stated rationale *"the same vega
would enter the regression with two opposite signs and cancel"*. 10-09's
`assembleEpochPanel` kept the protocol's own sign instead, which is the
construction defect the HALT was called on.

The long/short label is the FROZEN `is_long` column of the 10-09 artifact.
Nothing was reclassified. The transformation is applied AFTER the variance
join, so the row set, the cluster set, the epoch set and every regressor are
provably identical across the two arms — only the LHS sign differs.

| affected | rows | tokenIds |
|---|---|---|
| long (sign flipped) | 2280 | 8 |
| short (untouched) | 4480 | 47 |

### Everything the lock held UNCHANGED, and that this run did not touch

| locked item | status |
|---|---|
| stopping bar 6.2e-5 | UNCHANGED, as-is. Not rescaled, not reinterpreted. |
| unit incoherence of the bar | RECORDED, not repaired (section 5.1 of the v2 output; restated below) |
| verdict rule + code path | UNCHANGED — the same `stoppingRuleVerdict`, blind to kappa's sign and all p-values |
| estimator / tests / alternatives | UNCHANGED and byte-untouched (diff evidence below) |
| multi-start protocol | UNCHANGED |
| panel rows / clusters / joins | UNCHANGED — 6760 rows, 55 clusters, 0 unmatched epochs |
| filters, trims, re-fetches | NONE |

Run-time evidence that the estimator source is untouched:

```
$ git diff --name-only -- econometrics/src/Model econometrics/src/Tests econometrics/src/Alternatives.hs
(empty — no uncommitted change to the estimator)

$ git log -1 --format='%h %ad %s' --date=short -- econometrics/src/Model econometrics/src/Tests econometrics/src/Alternatives.hs
bb15a96 2026-07-20 feat(09-09): live estimation run + self-describing analysis output
```

## 2. RUN 1 vs RUN 2 — side by side

Both columns are produced by the SAME function (`runOn`) in the SAME process,
so they cannot differ by anything except their input panel.

### Primary parameters (GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 SEs)

| parameter | RUN 1 (as-is sign) | RUN 2 (seller-side) |
|---|---|---|
| beta0 (ETH/hour) | -1.635539e-8 (SE 4.253788e-8) | -5.468404e-8 (SE 4.893660e-8) |
| upsilon0 (vega level) | 3.597340e-2 (SE 7.548636e-2) | 0.106332 (SE 0.100998) |
| kappa (per tick) | 3.090495e-2 (SE 1.318375e-2) | 3.041754e-2 (SE 1.245733e-2) |

| 95% CI | RUN 1 | RUN 2 |
|---|---|---|
| beta0 | [-9.972964e-8, 6.701885e-8] | [-1.505998e-7, 4.123171e-8] |
| **upsilon0** | [-0.111980, 0.183927] | [-9.162517e-2, 0.304289] |
| kappa | [5.064810e-3, 5.674509e-2] | [6.001184e-3, 5.483390e-2] |

### EIV IV (sigma~2 instruments sigma2)

| parameter | RUN 1 naive | RUN 1 IV | RUN 2 naive | RUN 2 IV |
|---|---|---|---|---|
| beta0 | -1.635539e-8 | -6.697557e-8 | -5.468404e-8 | -2.077831e-7 |
| **upsilon0** | 3.597340e-2 | 0.128861 | 0.106332 | 0.380385 |
| kappa (held at NLS) | 3.090495e-2 | 3.090495e-2 | 3.041754e-2 | 3.041754e-2 |

### The three committed specification tests (spec section 5)

| # | restriction | RUN 1 stat / p / reject | RUN 2 stat / p / reject |
|---|---|---|---|
| 1 | upsilon0 > 0 | 0.476555 / 0.316840 / no | 1.052806 / 0.146215 / no |
| 2 | **kappa > 0 (THE null test)** | 2.344171 / 9.534719e-3 / **REJECT** | 2.441739 / 7.308348e-3 / **REJECT** |
| 3 | kappa+ = kappa- | 26.670688 / 2.412538e-7 / **REJECT** | 29.109283 / 6.840842e-8 / **REJECT** |

Run-2 test-3 identification: 2030 observations above the money, 4730 below.

### Optimizer

| diagnostic | RUN 1 | RUN 2 |
|---|---|---|
| SSE at the returned solution | 8.664527e-6 | 8.655848e-6 |
| SSE from the fixed kappa=0.2 start alone | 8.665559e-6 | 8.665559e-6 |
| multi-start strictly improved | True | True |
| median moneyness (kappa's scale) | 6.305000e2 | 6.305000e2 |

The median moneyness is identical across the arms, as it must be: the sign
flip touches the LHS only.

## STOPPING_RULE

The verdict for RUN 2, computed mechanically by the same code path, from the
tokenId-clustered CR0 half-width alone:

```
PRECOMMITTED_HALFWIDTH_BAR: 6.200000e-5
UPSILON0_HAT: 1.063317e-1
UPSILON0_SE_CLUSTERED: 1.009984e-1
UPSILON0_CI_HALFWIDTH: 1.979569e-1
STOPPING_RULE: UNINFORMATIVE
```

For the record, run 1's verdict, unchanged and unedited:

```
UPSILON0_CI_HALFWIDTH: 1.479533e-1
STOPPING_RULE: UNINFORMATIVE
```

**The bar was not moved between the runs.** It is the same literal 6.2e-5
named constant `precommittedHalfwidthBar`, and the pivot lock froze it
explicitly: *"Stopping bar: 6.2e-5, as-is. Its unit incoherence (defined
against Phase 9's USD/day·daily grid) is recorded, not repaired."* That
incoherence still stands and is still not repaired: the bar carries Phase 9's
USD/day units, the realised half-width carries this panel's ETH/hour units.
Recording it is not the same as acting on it, and this run did not act on it.

**The bar was NOT met on run 2 either, and the pre-authorised terminal
outcome applies with BOTH constructions on the record:**

> **This market cannot identify `upsilon`.**

The phase reports that and stops. The sign-convention defect was real and
has been fixed; fixing it did not change the conclusion. That is a
stronger result than run 1 alone could support — the uninformative
interval now survives the one construction change that had a clearly
signed effect on it, so it cannot be attributed to that defect. No
further iteration follows, per the lock.

## 3. The pre-registered descriptors D1 / D2 / D3

Declared in the pivot lock BEFORE run 2 executed, precisely so they could not
be chosen after seeing the answer. **They do NOT override the mechanical
verdict above.**

| descriptor | RUN 1 | RUN 2 |
|---|---|---|
| **D1** half-width / \|upsilon0-hat\| | 4.112851 | 1.861692 |
| **D2** does the upsilon0 CI exclude zero | no | no |
| **D3** upsilon0-hat | 3.597340e-2 | 0.106332 |
| **D3** clustered SE(upsilon0) | 7.548636e-2 | 0.100998 |

D3 movement, stated as ratios so the direction is unambiguous:

- `|upsilon0-hat|` ratio run2/run1 = 2.955843 (moved AWAY from zero: YES)
- `SE(upsilon0)` ratio run2/run1 = 1.337969 (narrowed by at least 20%: no)
- D1 ratio run2/run1 = 0.452652

The 20% figure is a reporting threshold for the word "materially", which the
lock left unquantified. **Nothing below turns on it.** The branch was selected by the first disjunct — `upsilon0-hat` moved away from zero — which is threshold-free. The SE disjunct is false here under ANY narrowing threshold, because the SE widened (ratio 1.337969).

## 4. The pre-registered interpretation branch that obtained

The lock declared two branches in advance. The one that obtained:

> *"If upsilon0-hat moves away from zero and/or its SE narrows
> materially: consistent with the mixed-sign attenuation mechanism;
> report both runs side by side."*

**This branch obtained — via the FIRST disjunct only.**

- `|upsilon0-hat|` moved AWAY from zero by a factor of 2.955843. This is the part consistent with the
  attenuation mechanism the disposition memo named in advance: a common
  vega carried with two opposite signs partially cancels, and de-mixing
  the signs un-cancels it.
- The clustered SE did **not** narrow — it WIDENED by a factor of 1.337969, which is expected when the
  left-hand side's magnitudes grow, and is NOT evidence for the mechanism.
  The second disjunct is false, and would be false under any narrowing
  threshold whatsoever.
- The scale-free ratio D1 nevertheless improved, 4.112851 -> 1.861692: the estimate grew faster than
  its own uncertainty.

**What this does NOT establish.** Consistency with a pre-named mechanism
is not proof of it. One arm moved in the predicted direction; that is a
single comparison on one panel, not an identified effect, and no
directional claim about the vega profile is made here beyond what the
tests in section 2 support.
Decisively: the mechanical verdict is still UNINFORMATIVE and D2 is still "no" — the CI contains zero in BOTH arms. The direction improved; the identification did not follow.

### Does the kappa > 0 rejection persist?

**It persists.** Run 1: kappa-hat = 3.090495e-2 (SE 1.318375e-2, p = 9.534719e-3). Run 2: kappa-hat = 3.041754e-2 (SE 1.245733e-2, p = 7.308348e-3). H0 of a flat vega profile is rejected at the 5% level under BOTH LHS constructions, which is what the lock anticipated: sign normalization acts primarily on upsilon0's level. The rejection is a statement about the SHAPE of the profile and it survives the fix. It remains separate from — and no substitute for — the stopping rule, which is about upsilon0.

## 5. FORMAL WITNESS statement

The Lean library proves, axiom-clean and sorry-free
(`lean/vol_markets/Upsilon.lean`):

```lean
theorem exp_family_witnesses_ATMOTM
    (u0 k di : R) (iK : Z) (hu : 0 < u0) (hk : 0 < k) (hd : 0 < di) :
    ATMOTMNullHypothesis
      (fun i => u0 * Real.exp (-k * di * |(i:R) - (iK:R)|)) di iK (k*di)
```

**No Lean file was modified and no Aristotle task was run.** The theorem is
already proved; at issue is only whether the run-2 fit instantiates it.

- `upsilon0-hat = 0.106332` (clustered SE 0.100998)  ->  `hu` satisfied in SIGN ONLY — the test does NOT reject (p = 0.146215), so the strict inequality is not supported.
- `kappa-hat = 3.041754e-2` (clustered SE 1.245733e-2)  ->  `hk` SATISFIED in sign AND statistically supported (p = 7.308348e-3).
- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED

**The witness does NOT obtain.** `hk : 0 < kappa` IS supported (kappa-hat = 3.041754e-2, p = 7.308348e-3), but `hu : 0 < upsilon0` is satisfied in SIGN only: upsilon0-hat = 0.106332 has a 95% clustered interval of [-9.162517e-2, 0.304289], which contains zero, and test 1 does not reject (p = 0.146215). Instantiating a machine-checked theorem at a parameter the data cannot distinguish from zero would assert more than the data supports — and the phase has just reported that the upsilon0 interval is uninformative, so it cannot simultaneously claim a witness resting on upsilon0. The Lean theorem remains PROVED and axiom-clean, and the conjecture remains OPEN. Nothing here bears on the theorem's correctness; only on whether this market's data instantiates it, and it does not.

## 6. The four locked alternative specifications (run 2)

The list is locked by the spec. Nothing added; nothing that failed to identify
was dropped.

#### semiparametric

Observations: 6760, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 2.366559e-7 | 1.417227e-7 |
| upsilon_bin0 | 5.834332e-3 | 6.206188e-3 |
| upsilon_bin1 | -3.284300e-5 | 2.244936e-5 |
| upsilon_bin2 | -2.606502e-5 | 1.320924e-5 |
| upsilon_bin3 | -2.819770e-5 | 1.869209e-5 |
| upsilon_bin4 | -0.147863 | 4.992517e-2 |

Estimated vega profile (the SHAPE the null is read off):

| moneyness d (ticks) | upsilon-hat(d) |
|---|---|
| 124.310831 | 5.834332e-3 |
| 368.459440 | -3.284300e-5 |
| 633.321244 | -2.606502e-5 |
| 952.424018 | -2.819770e-5 |
| 1247.008850 | -0.147863 |

Shape read-off: **NOT INTERPRETABLE.** The estimated profile is NON-MONOTONE in moneyness (bin values 5.834332e-3, -3.284300e-5, -2.606502e-5, -2.819770e-5, -0.147863), so it exhibits neither the exponential decay of H1 nor the flat profile of H0.

Note: degree-0 B-spline (regressogram) vega profile on 5 moneyness quantile bins, σ̂² linear; read the null off estCurve: declining υ̂ in moneyness = evidence for κ>0, flat = evidence for H₀

#### seed-linear

Observations: 6760, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 2.471863e-8 | 2.067708e-8 |
| upsilon_ibar | -6.243272e-3 | 5.122070e-3 |
| gamma | -3.665231e-6 | 3.117787e-6 |

Note: seed tick-linearization, strike centered at the mean pool tick i-bar = -199773. This form cannot express an ATM PEAK (it is monotone in the tick), so it detects only a local slope. gamma = -3.6652311249929826e-6 < 0 - the linear echo of kappa > 0 (vega falling as the strike moves above the money).

#### position-FE

Observations: 6757, clusters: 52.

| coefficient | estimate | clustered SE |
|---|---|---|
| kappa_FE | 3.162278e-2 | n/a |
| upsilon0_within | 0.117512 | 0.119574 |

Note: within (tokenId-FE) estimator, kappa concentrated over a grid; SE(kappa_FE) is NaN by construction — kappa is profiled, not jointly estimated. Compare kappa_FE with the primary kappa: a material move indicates strike-composition selection

#### collateral

Observations: 8787, clusters: 4.

| coefficient | estimate | clustered SE |
|---|---|---|
| QM_upsilon0 | 16669.806699 | 12655.779635 |
| upsilon_collateral | -228795.532970 | 237675.647321 |

Note: CAVEAT FIRST: Q_M here is DEPOSITED collateral shares reconstructed from CollateralDeposit/Withdraw events, NOT the protocol's required margin. The subgraph exposes no per-position collateral requirement (collateral*Shares is a CURRENT snapshot only; CollateralDayData is vault-level), so this is a behavioural quantity and is NOT the spec's Q_M. Any comparison with the premium-channel upsilon0 is suggestive at best. Clustered by ACCOUNT.

Collateral-channel observations formed on the 1-hour grid: 8787.

## 7. The panel and the join (unchanged from run 1)

| quantity | value |
|---|---|
| rows read from `notes/structural-econometrcics/data/panel-epoch.csv` | 6760 |
| rows joined to the variance series | 6760 |
| UNMATCHED_EPOCHS | 0 (the CLI exits non-zero on any) |
| usable in BOTH arms | 6760 |
| distinct tokenId clusters | 55 |
| distinct account clusters | 4 |
| distinct epochs | 1887 |
| rows flagged ChunkEmpty / AccFrozen | 50 / 0 |
| rows in a zero-swap hour (n_swaps = 0) | 3 |
| top-10 tokenId row share | 0.841272 |

Join cross-checks against the values the 10-09 artifact carries — sigma2
0, sigma2_instrument 0, pool tick 0, moneyness 0 mismatching rows.

**The cluster ceiling is untouched by this fix.** 6760 rows still sit in 55 tokenId clusters with 84.127219% of the rows
in ten positions. The sign normalization corrects a bias; it cannot manufacture
independent clusters, and precision here is bounded by clusters.

### The validation gate (unchanged — quoted from `notes/structural-econometrcics/data/reconcile.md`)

```
SPELLS_RECONCILED: 61
GROUND_TRUTH_UNIT: RawWei
GROUND_TRUTH_EXPR: truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units
MEDIAN_REL_ERROR_ALL: 0.000000
N_SHORT: 53
MEDIAN_REL_ERROR_SHORT: 0.000000
P25_REL_ERROR_SHORT: 0.000000
P75_REL_ERROR_SHORT: 0.000000
P90_REL_ERROR_SHORT: 1.220169e-9
MAX_REL_ERROR_SHORT: 5.447268e-4
SIGNED_BIAS_SHORT: 3/5
N_LONG: 8
MEDIAN_REL_ERROR_LONG: 0.000000
P25_REL_ERROR_LONG: 0.000000
P75_REL_ERROR_LONG: 0.000000
P90_REL_ERROR_LONG: 0.000000
MAX_REL_ERROR_LONG: 0.000000
SIGNED_BIAS_LONG: 0/0
LEGCOUNT_MISMATCHES: 0
ZERO_TRUTH_EXCLUDED: 0
LABEL_DISAGREEMENTS: 0
CENSUS_MISMATCHES: 0
GATE_TOLERANCE: 0.01
GATE: PASS
```

The gate validates MEASUREMENT, not identification. The sign normalization is
orthogonal to it: flipping a sign does not change |recon_wei|, so the
gate-validated telescoping identity is unaffected.

## 8. The Panoptic-vs-Lean wedge (unchanged from run 1)

The estimated `pi_it` is PANOPTIC'S premium — fee growth times a
utilization-based multiplier, `1 + nu*R/N` long and `1 + nu*R^2/(N*T)` short
with `nu = 1/VEGOID = 1/8 = 0.125` — not the bare `streamingPremium`
fee-revenue identity Lean models. Applied inside the contract's X64
accumulator, so it is already in the reconstructed premium and is never
re-applied here. MEASURED over the 8910 accumulator readings:

| statistic | value |
|---|---|
| median | 1.112500 |
| min / max | 1.000000 / 1.291667 |
| max long (2839) / max short (6071) | 1.291667 / 1.204167 |
| readings with R = 0 (wedge exactly 1) | 3467 of 8910 |
| implied max R/N on long readings | 2.333333 |

The measured maximum EXCEEDS the 1.125 figure quoted as its bound: `1 + nu`
caps the long branch only when `R <= N`, and here `R/N` reaches 2.333333.
Carry the measured figures, not 1.125, into the 10-11 cross-walk.

## 9. Threats to validity

Run 1's threats carry over except the one this run fixed.

1. **RESOLVED by this run:** the mixed-sign LHS. Both constructions are now on
   the record and the estimate is reported under the locked Phase-9 convention.
2. **A passing gate validates MEASUREMENT, not identification.**
3. **The cluster ceiling** — 55 clusters, 84.127219% of rows in ten positions. Unfixable by any
   LHS transformation.
4. **Scale non-comparability of the bar** — recorded in run 1, deliberately NOT
   repaired by the lock, and still not repaired here.
5. **Flagged rows** — 50 `ChunkEmpty`, 0 `AccFrozen`; retained and labelled, never dropped.
6. **The zero-swap hour** — 3 rows, sigma2 = 0 measured;
   the confirming re-fetch used the same public endpoint (reproducibility, not
   provider-independence).
7. **Long-stratum capping** — `_getAvailablePremium` caps SETTLED long premium
   while the accumulator reports ACCRUED. It did not bind in the gate sample,
   and the distinction survives the sign fix: normalizing the sign does not
   convert accrued premium into settled premium.
8. **`width == 0` exclusion**, **one strike per multi-leg position**,
   **residual sub-block reconstruction wedge** (bounded 5.447268e-4),
   **exponential functional form**, **strike-composition selection** — all as
   recorded in run 1.
9. **The Panoptic-vs-Lean multiplier wedge** (section 8).

## 10. DATA LINEAGE (audit trail)

Run date: 2026-07-27. Git commit: `cda0a15`.
Pivot lock sha256: `56044349a035221874eb93d59ab64bd94239be698e4e47363118bffd743e9998` (verified at run time).
All paths repo-root relative. Every endpoint is public and keyless; no
credential appears anywhere in this pipeline.

### The exact invocation

```
econometrics estimate --epoch-panel notes/structural-econometrcics/data/panel-epoch.csv --variance notes/structural-econometrcics/data/variance-hourly.csv --epoch-hours 1 --seller-side-normalize --endpoint https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn --pool 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a --rpc https://mainnet.base.org --from-block 43781657 --to-block 48879461
```

### Chain and contracts

| what | value |
|---|---|
| chain | Base mainnet (L2), chainId 8453 |
| Panoptic subgraph | `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn` |
| PanopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee 500, tickSpacing 10) |
| underlying pool (V4 poolId) | `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a` |
| SFPM | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` |
| VEGOID / nu | 8 / 0.125 |
| Base RPC | `https://mainnet.base.org`; failover `https://base.drpc.org` |
| V4 PoolManager (Swap log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |
| block range | 43781657 .. 48879461 |

The bulk accumulator read (10-06) issued 8,910 `eth_call`s over a six-cycle
resume chain; `FAILOVER_CALLS: 0` on the completing slice. Read lineage:
`notes/structural-econometrcics/data/premium-accumulators-lineage.md`.

### Files

| path | contents | rows |
|---|---|---|
| `notes/structural-econometrcics/data/burn-truth.csv` | frozen OptionBurn ground truth (INPUT); the is_long authority | 61 |
| `notes/structural-econometrcics/data/premium-accumulators.csv` | SFPM X64 accumulator readings | 8,910 |
| `notes/structural-econometrcics/data/epoch-blocks.csv` | hourly epoch -> first Base block | 2,832 |
| `notes/structural-econometrcics/data/reconcile-errors.csv` | per-spell gate error | 61 |
| `notes/structural-econometrcics/data/reconcile.md` | THE gate report | see section 7 |
| `notes/structural-econometrcics/data/variance-hourly.csv` | hourly sigma2, EIV instrument, pool tick, n_swaps | 1887 |
| `notes/structural-econometrcics/data/panel-epoch.csv` | THE position-epoch panel (LHS source) | 6760 |
| `notes/structural-econometrcics/data/estimation-panel-v2.csv` | RUN 1's export (as-is sign) | 6,760 |
| `notes/structural-econometrcics/data/estimation-panel-v3.csv` | RUN 2's export (seller-side normalized) | 6760 |
| `notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md` | RUN 1's analysis, FROZEN | — |
| `.planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-10-PIVOT-LOCK.md` | the binding lock | — |
| `notes/structural-econometrcics/data/collateral-flows.csv` | signed collateral share flows | see file |
| `notes/structural-econometrcics/data/swap-ticks-base-v4-full.csv` | raw (unix, tick) Swap cache (gitignored) | 632,315 |

### The epoch definition

`epoch = floor(unixSeconds / 3600)` via `Panel.Epoch.epochOfSeconds`, the SAME
function the variance series uses, so the join is an exact INTEGER match.
Block-index epoch `e` is the START of hour `e`, so a row's premium is the
accumulator difference over the interval STARTING at that boundary and meets
the variance of the SAME hour.

### The panel artifact's own banner (verbatim)

```
# panel-epoch.csv — THE position-epoch panel (spec §1 unit), plan 10-09
# 
# measured: 2026-07-27   git commit: a2c1f04
# command: econometrics epoch-panel --endpoint https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn --pool 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a
# working directory: repository root (all paths below are repo-relative)
# 
# subgraph endpoint: https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn
# underlying pool (V4 poolId): 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a
# PanopticPool: 0xb50e8bb68f5855da742f4579274902a20454174a (ETH/USDC, fee 500)
# SFPM read target: 0x8dcAa08cF298F8b4830FAf56d47930981AdE33af
# VEGOID / nu: 8 / 0.125 — applied INSIDE the contract's X64 accumulator, never re-applied here
# 
# accumulator readings: notes/structural-econometrcics/data/premium-accumulators.csv (8910 rows, blocks 43781657..48157721, epochs 492876..495306)
# gate population: notes/structural-econometrcics/data/panel.csv (55 tokenIds)
# gate verdict: notes/structural-econometrcics/data/reconcile.md — GATE: PASS, short-stratum median rel error 0.0, worst 5.447268e-4, tolerance 0.01
# telescoping cross-check: notes/structural-econometrcics/data/reconcile-errors.csv — TELESCOPE_MISMATCHES 0, PANEL_SUM_MISMATCHES 0
# variance series: notes/structural-econometrcics/data/variance-hourly.csv (hourly)
# 
# epoch rule: floor(unixSeconds / 3600) via
#   Panel.Epoch.epochOfSeconds — the SAME function the variance series uses.
#   The join is an exact INTEGER match; UNMATCHED_EPOCHS = 0.
# epoch attribution: a row's premium is the accumulator difference over the
#   interval STARTING at that epoch's boundary block, so it accrued during
#   epoch e and is regressed on sigma^2_e measured over the same hour.
# 
# premium_wei: Integer, currency0 (ETH), seller-side sign as the protocol emits it.
#   CANONICAL. premium_eth = premium_wei / 1e18 is the regression LHS.
#   Summing premium_wei over a tokenId's rows reproduces that spell's
#   gate-validated recon_wei EXACTLY (Panoptic.Premium.decomposePremium).
# strike_tick: Leg.strike, ALREADY an int24 tick — no round(log K / log 1.0001).
# pool_tick: the epoch's mean pool tick from the same V4 Swap series as sigma^2.
# moneyness: Model.Upsilon.moneyness strike_tick pool_tick = |i_K - i_t|.
# flags: ';'-separated Panoptic.Premium.PremiumFlag values; rows are RETAINED.
# n_swaps: swaps behind this epoch's sigma^2. n_swaps = 0 marks an hour in
#   which the pool saw no trade at all (sigma^2 = 0 measured, pool tick carried
#   forward); 3 such row(s) here.
# 
# PANEL_ROWS 6760 / PANEL_TOKENIDS 55 / PANEL_EPOCHS 1887 / MULTI_EPOCH_TOKENIDS 52 / FLAGGED_ROWS 6760
# SPELL_EPOCH_ROWS 6766 (the 10-01 census's per-SPELL count; PANEL_ROWS is per (tokenId, epoch), so a tokenId holding two spells that share an hour contributes one row where the census counted two)
# within-position epochs: median 10.000000, max 1176; top-10 tokenId row share 0.841272 — precision is bounded by the 55 CLUSTERS, not by the row count.
# Phase-9 baseline 61 spell rows; GAIN_FACTOR 110.819672
```

### The variance artifact's own banner (verbatim)

```
# Panoptic υ variance regressor σ̂²_t, EIV instrument σ̃²_t, pool tick i_t (CTX-VAR)
# EPOCH WIDTH: 3600 seconds (1.0 hour(s)).
#   epoch = floor(unixSeconds / 3600) via
#   Panel.Build.epochOfSeconds — the SAME single source of truth as
#   Panel.Build.dailyEpoch (which is epochOfSeconds 86400). The panel and
#   this series therefore share an exact INTEGER epoch key; the join is an
#   integer match and never a timestamp comparison or an offset adjustment
#   (the 09-05 40587-offset trap).
# σ̂²_t (sigma2)            = realized variance of the within-epoch V4
#   tick-implied log-price increments over the FULL within-epoch Swap series.
# σ̃²_t (sigma2_instrument) = the SAME estimator on the DISJOINT even-swap
#   sub-window (0-based even positions) — the two-noisy-measures IV.
# i_t (pool_tick_mean)     = mean underlying pool tick over the same epoch,
#   from the SAME Swap series (the panel's moneyness anchor).
# n_swaps                  = swaps in the epoch. σ̂² rests on n_swaps − 1
#   increments; a row with n_swaps <= 1 is a CONSTRUCTED zero, not a
#   measured one, and must not be read as a quiet market.
# Source: Uniswap V4 PoolManager Swap logs on Base via chunked eth_getLogs
#   (poolId 0x96d4…288c0a); BigQuery path retired (project suspended).
```

### The estimator (byte-identical to Phase 9 and to run 1)

- **Point estimates:** `Model.NLS.fitGSL` — `Numeric.GSL.Fitting.fitModel`,
  Levenberg-Marquardt, analytic Jacobian, data-scaled multi-start, lowest-SSE
  finite solution.
- **Standard errors:** `Model.SandwichSE.clusterSandwich` — tokenId-clustered
  CR0 `(J'J)^-1 [sum_g s_g s_g'] (J'J)^-1`, NO finite-sample correction,
  golden-tested to 1e-9.
- **EIV:** `Model.EIV.ivFit` — two-step two-noisy-measures IV.
- **Tests:** `Tests.Specification` — one-sided Normal for the sign
  restrictions, chi-squared(1) Wald for symmetry.
- **Alternatives:** `Alternatives` — the four locked spec section-6.2 forms.

### Reproduce

```sh
stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \
  --epoch-panel notes/structural-econometrcics/data/panel-epoch.csv \
  --variance notes/structural-econometrcics/data/variance-hourly.csv \
  --epoch-hours 1 \
  --seller-side-normalize \
  --estimation-out notes/structural-econometrcics/data/estimation-panel-v3.csv \
  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \
  --from-block 43781657 --to-block 48879461
```

---

**TERMINAL.** Per the pivot lock and the user's commitment of 2026-07-27, this
is the last estimation run of Phase 10. No further iteration follows, in either
branch of the pre-registered interpretation.
