# Panoptic vol-claim upsilon: re-estimation on the POSITION-EPOCH panel (v2)

**Phase 10, plan 10-10.** Supersedes
`notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md`
(Phase 9, plan 09-09), which is retained unchanged as the baseline this
document is read against.

Estimation of the spec section-4.3 equation, VERBATIM:

> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`

Run date: 2026-07-27. Git commit: `ddf649e`.

## 0. Headline

**STOPPING_RULE: UNINFORMATIVE.** The realised upsilon0 clustered-CI half-width is +/-1.479533e-1 against a bar of +/-6.200000e-5 fixed before the run. The interval remains uninformative. upsilon0-hat = 3.597340e-2 (clustered SE 7.548636e-2), kappa-hat = 3.090495e-2 (clustered SE 1.318375e-2), beta0-hat = -1.635539e-8 ETH/hour (clustered SE 4.253788e-8), on 6760 position-epoch observations over 55 tokenId clusters. **Separately, and for the first time in this project, THE NULL TEST REJECTS:** kappa-hat = 3.090495e-2 > 0 with clustered SE 1.318375e-2 (z = 2.344171, p = 9.534719e-3), so H0 of a flat vega profile is rejected in the direction the conjecture predicts. That result stands on its own and is NOT a substitute for the stopping rule: `upsilon0 > 0` does NOT reject (p = 0.316840) and its interval contains zero, so the Lean witness does not obtain (section 6), and the phase's pre-committed verdict is the one stated above.

## 1. What changed from Phase 9, and what did not

**The estimator stack did not change. Only the left-hand side did.**

Phase 9 could not construct the spec's section-1 unit of observation and fell
back to the accrual SPELL (one row per mint-to-burn pair, `pi` in USD per day,
`sigma2` averaged over the whole spell window): 61 rows, no within-position
time variation at all. Plans 10-01 through 10-09 reconstructed the streaming
premium directly from the SFPM X64 accumulators and rebuilt the panel at the
unit the spec asks for — one row per (tokenId, hourly epoch), with `pi` the
premium that accrued IN that hour and `sigma2` the variance measured over the
SAME hour.

| | Phase 9 (09-09) | Phase 10 (this run) |
|---|---|---|
| unit of observation | accrual spell (mint to burn) | position-epoch (tokenId x hour) |
| LHS `pi_it` | USD per day over the spell | ETH per hour (a FLOW) |
| rows | 61 | 6760 |
| tokenId clusters | 55 | 55 |
| within-position variation | none | 52 of 55 positions (10-09) |
| LHS validated against chain truth | no | yes — `GATE: PASS`, section 3 |
| estimator | `fitGSL` / `clusterSandwich` / `Tests.Specification` / `Alternatives` | THE SAME, unmodified |

Evidence, generated at run time by this binary rather than asserted:

```
$ git diff --name-only -- econometrics/src/Model econometrics/src/Tests econometrics/src/Alternatives.hs
(empty — no uncommitted change to the estimator)

$ git log -1 --format='%h %ad %s' --date=short -- econometrics/src/Model econometrics/src/Tests econometrics/src/Alternatives.hs
bb15a96 2026-07-20 feat(09-09): live estimation run + self-describing analysis output
```

The estimator modules were last touched in Phase 9. Everything plan 10-10
added lives in `econometrics/app/Main.hs`: the `--epoch-panel` option, the
join, the export, and the stopping-rule verdict. That placement is deliberate
— it is what keeps "only the LHS changed" a one-line `git diff` audit rather
than a claim.

## 2. The validation gate — what licenses reading this estimate at all

The panel's premium column is a DECOMPOSITION of a quantity that was checked
against the protocol's own `OptionBurn.premium0` over all 61 Phase-9 spells,
in Integer ETH wei, at a tolerance fixed before the run (plan 10-08). The
gate's verbatim verdict block, quoted from `notes/structural-econometrcics/data/reconcile.md`:

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

Read the two strata separately, as 10-07 specified: the SHORT stratum is the
scored one; the LONG stratum is reported in full but excluded from the
pass/fail arithmetic because `_getAvailablePremium` caps SETTLED long premium
while the accumulator reports ACCRUED. On this sample the long cap did not
bind at all (8 of 8 exact).

Plan 10-09 then carried that verdict ONTO the panel rather than restating it:
each of the 55 tokenIds' per-epoch premia sum back to its gate-validated
`recon_wei` EXACTLY in Integer wei (`TELESCOPE_MISMATCHES 0`,
`PANEL_SUM_MISMATCHES 0`).

**A passing gate validates MEASUREMENT, not identification.** It says the
left-hand side is the quantity the protocol actually paid. It says nothing
about whether this market's variation can identify `upsilon`. That is what
the STOPPING_RULE section adjudicates.

## 3. The panel and the join

| quantity | value |
|---|---|
| rows read from `notes/structural-econometrcics/data/panel-epoch.csv` | 6760 |
| rows joined to the variance series | 6760 |
| UNMATCHED_EPOCHS | 0 (the CLI exits non-zero on any) |
| usable after the finiteness filter | 6760 |
| distinct tokenId clusters | 55 |
| distinct account clusters | 4 |
| distinct epochs | 1887 |
| moneyness d (ticks): median / min / max | 630.500000 / 1.000000 / 3129.000000 |
| sigma2: median / min / max | 4.399560e-6 / 0.000000 / 1.109781e-2 |
| pi (ETH/hour): median / min / max | 0.000000 / -1.585860e-3 / 1.584434e-3 |
| rows with pi = 0 exactly | 1657 |
| rows flagged ChunkEmpty | 50 |
| rows flagged AccFrozen | 0 |
| rows in a zero-swap hour (n_swaps = 0) | 3 |
| top-10 tokenId row share | 0.841272 |

**Join cross-checks against the values the 10-09 artifact carries.** The
panel already stores `sigma2`, `sigma2_instrument` and `pool_tick`; this run
re-derives all three from `notes/structural-econometrcics/data/variance-hourly.csv` and compares, so a
drift between the two files would surface as a defect rather than as an
estimate:

| check | mismatching rows |
|---|---|
| sigma2 | 0 |
| sigma2_instrument | 0 |
| pool tick (rounded) | 0 |
| moneyness \|i_K - i_t\| | 0 |

**The row count is not the precision.** 6760 rows sit in 55 tokenId
clusters, and the top ten positions carry 84.127219% of the rows. Standard errors
are clustered by tokenId, so the cluster count — not the row count — bounds
the achievable precision. This was recorded when the hourly re-scope was
accepted at 10-01 and again in the 10-09 summary; it is restated here because
it is the single most likely way to misread the table below.

### 3.1 Two properties of this LHS that Phase 9's did not have

Both are stated here rather than in the threats section because they bear
directly on how the numbers in section 4 should be read, and neither was
anticipated by the plan text.

**(a) The sign convention differs from Phase 9's.**

| | rows | of which negative pi | of which positive pi | tokenIds |
|---|---|---|---|---|
| long (`is_long = 1`) | 2280 | 1706 | 29 | 8 |
| short (`is_long = 0`) | 4480 | 78 | 3290 | 47 |

Phase 9 NORMALISED this: `Panel.Build.premiumUsd` multiplies a long spell's premium by -1, and the function's own comment gives the reason — "the same vega would enter the regression with two opposite signs and cancel". `Panel.Build.assembleEpochPanel` does NOT apply that flip; it carries the protocol's own seller-side sign, which is what `Panoptic.Premium.premiumWei` emits (negating long legs, mirroring `_getPremia`). So 2280 of 6760 rows (33.727811% of the panel, over 8 of 55 tokenIds) enter this regression with the OPPOSITE sign to the rest. The direction of the resulting bias is not ambiguous: a common vega expressed with two signs partially cancels, which pushes `upsilon0` toward zero and widens its interval — the exact quantity the stopping rule adjudicates. This divergence was NOT changed during this run: the estimate was already computed when it was found, and respecifying the left-hand side after seeing a verdict is precisely the goalpost move the phase's anti-fishing discipline forbids. It is reported here as a concrete, named candidate defect for adjudication, and it belongs to the panel artifact (plan 10-09), not to the estimator.

**(b) The modal position-hour accrues nothing.** 1657 of 6760 rows carry
`pi` exactly 0, and because long rows are negative the MEDIAN of the LHS is
exactly 0.000000. That is a genuine property of an hourly grid — a
position accrues premium only in the hours its chunk is in range and traded —
but it has a concrete consequence for the optimizer: `Model.NLS.multiStarts`
anchors its `upsilon0` start at `median(pi)/median(sigma2)`, which is
therefore 0.000000e0 on this panel, and its `beta0` start likewise. The
start grid still spans the informative `kappa` scale (that anchor is the
median MONEYNESS, which is well defined at 6.305000e2 ticks) and the
`upsilon0` gradient `exp(-kappa*d)*sigma2` is non-zero at a zero start, so the
fit is not stuck — see the head-to-head SSE in section 4.1 — but the margin by
which the multi-start beat the dead fixed start is small, and that is recorded
rather than smoothed over.

## 4. Estimates

### 4.1 Primary — GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 sandwich SEs

| parameter | estimate | clustered SE | 95% CI |
|---|---|---|---|
| beta0 (intercept, ETH/hour) | -1.635539e-8 | 4.253788e-8 | [-9.972964e-8, 6.701885e-8] |
| upsilon0 (vega level) | 3.597340e-2 | 7.548636e-2 | [-0.111980, 0.183927] |
| kappa (moneyness decay, per tick) | 3.090495e-2 | 1.318375e-2 | [5.064810e-3, 5.674509e-2] |

Account-clustered SEs (coarser, 4 clusters): beta0 1.376046e-8, upsilon0 1.154140e-2, kappa 1.813480e-3.
With that few clusters the Normal approximation is unreliable; reported for
transparency, not for inference.

**Optimizer.** The primary fit is `Model.NLS.fitGSL` — hmatrix-gsl
Levenberg-Marquardt with an analytic Jacobian — run from the DATA-SCALED
multi-start, keeping the lowest-SSE finite solution. This matters at tick-scale
moneyness: plan 09-09 established that a fixed `kappa = 0.2` start evaluates
`exp(-0.2*153) ~ 5e-14`, so the model is numerically zero at the start point,
the Jacobian vanishes, and the optimizer reports a start-value artifact (it
produced a spurious `kappa = 0.384` on the first live run before the fix).

| optimizer diagnostic | value |
|---|---|
| start grid | data-scaled multi-start (Model.NLS.multiStarts): median moneyness d = 6.305000e2 ticks, kappa anchors 1/(c*d) for c in {0.1,0.3,1,3,10,100,1000} = [1.586043e-2, 5.286809e-3, 1.586043e-3, 5.286809e-4, 1.586043e-4, 1.586043e-5, 1.586043e-6], u0 = +/-0.000000e0, b0 = 0.000000e0; plus the fixed fallback [0,1,0.2] |
| median moneyness setting kappa's scale | 6.305000e2 ticks |
| SSE at the returned solution | 8.664527e-6 |
| SSE from the fixed `kappa = 0.2` fallback start alone | 8.665559e-6 |
| multi-start strictly improved on the fixed start | True |

`Model.NLS` does not export its start grid and this plan may not modify it, so
the anchors above are RECOMPUTED by the CLI from the same design and the
head-to-head SSE is the evidence that the multi-start path engaged: had it not,
the two SSEs would coincide.

### 4.2 EIV IV (two noisy measures: sigma~2 instruments sigma2) — naive vs IV

The realized-variance regressor is estimated, hence EIV-mismeasured (spec
section 3.3 threat M1), which ATTENUATES the naive `upsilon0` toward zero. The
remedy is the spec's own: instrument `sigma2` with the disjoint even-swap
sub-window estimate `sigma~2` of the SAME epoch. `kappa` is identified off
moneyness rather than the variance level, so it is conditioned on at its NLS
value rather than re-estimated (spec section 4.3).

| parameter | naive (NLS) | EIV IV |
|---|---|---|
| beta0 | -1.635539e-8 | -6.697557e-8 |
| **upsilon0** | 3.597340e-2 | 0.128861 |
| kappa | 3.090495e-2 | 3.090495e-2 (held at the NLS value) |

Attenuation ratio naive/IV = 0.279165. Under classical EIV the IV estimate is the larger in magnitude; read the two together rather than either alone.

### 4.3 The three committed specification tests (spec section 5)

All computed on the tokenId-CLUSTERED covariance, never naive OLS SEs.

| # | restriction | statistic | p-value | reject at 5%? |
|---|---|---|---|---|
| 1 | upsilon0 > 0 (upsilon is a vega) | z = 0.476555 | 0.316840 | False |
| 2 | **kappa > 0 (THE null test)** | z = 2.344171 | 9.534719e-3 | True |
| 3 | kappa+ = kappa- (symmetric decay) | W = 26.670688 | 2.412538e-7 | True |

Test 3 identification: 2030 observations above the money, 4730 below.


Test 2 is the econometric twin of the Lean conjecture
`Upsilon.ATMOTMNullHypothesis`: H0 kappa = 0 (flat vega profile) versus
H1 kappa > 0 (maximal at the money, exponential decay out of the money).

**Verdict: H0 (kappa = 0) is REJECTED** at the 5% level in favour of kappa > 0, on the tokenId-clustered covariance.

### 4.4 The four locked alternative specifications (spec section 6.2)

The list is locked by the spec. Nothing was added, and nothing that failed to
identify was dropped.

#### semiparametric

Observations: 6760, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 2.584347e-7 | 1.398160e-7 |
| upsilon_bin0 | 1.949724e-3 | 4.439458e-3 |
| upsilon_bin1 | -3.622173e-5 | 2.257813e-5 |
| upsilon_bin2 | -2.955705e-5 | 1.243958e-5 |
| upsilon_bin3 | -3.103803e-5 | 1.872034e-5 |
| upsilon_bin4 | -0.148131 | 4.979578e-2 |

Estimated vega profile (the SHAPE the null is read off):

| moneyness d (ticks) | upsilon-hat(d) |
|---|---|
| 124.310831 | 1.949724e-3 |
| 368.459440 | -3.622173e-5 |
| 633.321244 | -2.955705e-5 |
| 952.424018 | -3.103803e-5 |
| 1247.008850 | -0.148131 |

Shape read-off: **NOT INTERPRETABLE.** The estimated profile is NON-MONOTONE in moneyness (bin values 1.949724e-3, -3.622173e-5, -2.955705e-5, -3.103803e-5, -0.148131), so it exhibits neither the exponential decay of H1 nor the flat profile of H0.

Note: degree-0 B-spline (regressogram) vega profile on 5 moneyness quantile bins, σ̂² linear; read the null off estCurve: declining υ̂ in moneyness = evidence for κ>0, flat = evidence for H₀

#### seed-linear

Observations: 6760, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 1.270853e-8 | 1.431708e-8 |
| upsilon_ibar | -2.308888e-3 | 4.333020e-3 |
| gamma | -1.296023e-6 | 2.605493e-6 |

Note: seed tick-linearization, strike centered at the mean pool tick i-bar = -199773. This form cannot express an ATM PEAK (it is monotone in the tick), so it detects only a local slope. gamma = -1.2960225102376225e-6 is SMALLER than its clustered SE (2.6054931627414603e-6), i.e. indistinguishable from zero: the linear benchmark detects no strike tilt in either direction.

#### position-FE

Observations: 6757, clusters: 52.

| coefficient | estimate | clustered SE |
|---|---|---|
| kappa_FE | 3.162278e-2 | n/a |
| upsilon0_within | 3.830398e-2 | 8.903186e-2 |

Note: within (tokenId-FE) estimator, kappa concentrated over a grid; SE(kappa_FE) is NaN by construction — kappa is profiled, not jointly estimated. Compare kappa_FE with the primary kappa: a material move indicates strike-composition selection

#### collateral

Observations: 8787, clusters: 4.

| coefficient | estimate | clustered SE |
|---|---|---|
| QM_upsilon0 | 16669.806699 | 12655.779635 |
| upsilon_collateral | -228795.532970 | 237675.647321 |

Note: CAVEAT FIRST: Q_M here is DEPOSITED collateral shares reconstructed from CollateralDeposit/Withdraw events, NOT the protocol's required margin. The subgraph exposes no per-position collateral requirement (collateral*Shares is a CURRENT snapshot only; CollateralDayData is vault-level), so this is a behavioural quantity and is NOT the spec's Q_M. Any comparison with the premium-channel upsilon0 is suggestive at best. Clustered by ACCOUNT.

Collateral-channel observations formed on the 1-hour grid: 8787.

## STOPPING_RULE

```
PRECOMMITTED_HALFWIDTH_BAR: 6.200000e-5
UPSILON0_HAT: 3.597340e-2
UPSILON0_SE_CLUSTERED: 7.548636e-2
UPSILON0_CI_HALFWIDTH: 1.479533e-1
STOPPING_RULE: UNINFORMATIVE
```

**The bar was fixed before this run and was NOT adjusted.** It was written
into `10-CONTEXT.md` ("Power / stopping rule") when the phase was scoped, at
one quarter of Phase 9's realised half-width of +/-2.48e-4, and it lives in
source as the single named constant `precommittedHalfwidthBar` in
`econometrics/app/Main.hs`.

**The verdict is result-blind by construction.** `stoppingRuleVerdict` takes
exactly one argument — the realised clustered half-width — and compares it to
that constant. It does not see `kappa`'s sign, any p-value, or whether the
answer is interesting. An INFORMATIVE interval pointing AWAY from the
conjecture is a success under this rule.

Phase-9 comparison: half-width +/-2.48e-4 on 61 observations over 55 tokenId
clusters. This run: half-width +/-1.479533e-1 on 6760 observations over 55 clusters.

**The bar was NOT met, and the pre-authorised terminal outcome applies:**

> **This market cannot identify `upsilon`.**

The phase reports that and STOPS. There is no respecification, no
subsample hunting, and no alternative-estimator fishing — those were
ruled out in advance precisely so that this outcome could be reported
honestly rather than escaped. With the left-hand side now validated
against the protocol's own ground truth in Integer wei (section 2), an
uninformative interval is evidence about the MARKET rather than about the
measurement, which is a stronger and more defensible claim than Phase 9's
ambiguous null: Phase 9 could not tell the two apart.

### Comparability of the bar — one fact recorded without acting on it

`upsilon0` is `d(pi)/d(sigma2)`, so its NUMERICAL SCALE is set by the units of
both. Phase 9 measured `pi` in USD per DAY against a DAILY realised variance
(median 2.217078e-4). This panel measures `pi` in ETH
per HOUR against an HOURLY realised variance (median 4.399560e-6). The
bar of 6.2e-5 was derived from Phase 9's half-width and therefore carries
Phase 9's units; the realised half-width above carries this panel's.

**Nothing was done about that.** The bar was not rescaled, not reinterpreted,
and not moved: it is the literal 6.2e-5 written into `10-CONTEXT.md` before the
phase began and into `precommittedHalfwidthBar` before this run, and the
verdict above is the literal comparison against it. Rescaling a pre-committed
bar after seeing the number it judges is exactly the move the phase's
anti-fishing discipline exists to catch, and this document is not the place to
make it. The fact is recorded because an auditor and the adjudicating user both
need it in front of them; what to do with it is theirs to decide, not this
run's.

For what it is worth as a UNIT-FREE reading, which is offered as description
rather than as a substitute criterion: the ratio of the half-width to the point
estimate is 4.112851, i.e. the interval is that many
times the estimate wide, and it contains zero.

## 6. The Lean witness

The Lean library proves, axiom-clean and sorry-free
(`lean/vol_markets/Upsilon.lean`):

```lean
theorem exp_family_witnesses_ATMOTM
    (u0 k di : R) (iK : Z) (hu : 0 < u0) (hk : 0 < k) (hd : 0 < di) :
    ATMOTMNullHypothesis
      (fun i => u0 * Real.exp (-k * di * |(i:R) - (iK:R)|)) di iK (k*di)
```

**No Lean file was modified and no Aristotle task was run in this phase.**
The theorem is already proved; what is at issue is only whether the fitted
profile instantiates its hypotheses.

Its three hypotheses are `hu : 0 < upsilon0`, `hk : 0 < kappa` and
`hd : 0 < Delta_i` (the tick spacing, 10 on this market, so `hd` holds by
inspection). The fitted values:

- `upsilon0-hat = 3.597340e-2` (clustered SE 7.548636e-2)  ->  `hu` satisfied in SIGN ONLY — the corresponding test does NOT reject (p = 0.316840), so the strict inequality is not supported by the data.
- `kappa-hat = 3.090495e-2` (clustered SE 1.318375e-2)  ->  `hk` SATISFIED in sign AND statistically supported (test p = 9.534719e-3).
- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED

**The witness does NOT obtain.** `hk : 0 < kappa` IS supported — kappa-hat = 3.090495e-2 with clustered SE 1.318375e-2 and p = 9.534719e-3, so the null of a flat vega profile is rejected in the direction the conjecture predicts. It is `hu : 0 < upsilon0` that fails: upsilon0-hat = 3.597340e-2 is positive in SIGN, but its clustered 95% interval is [-0.111980, 0.183927], which contains zero, and test 1 does NOT reject (p = 0.316840). Instantiating a machine-checked theorem at a parameter this data cannot distinguish from zero would assert more than the data supports. This is also the reading the STOPPING_RULE forces: the phase has just reported that the upsilon0 interval is uninformative, and it cannot simultaneously claim a witness that rests on upsilon0. Note precisely what this does and does not say: the Lean theorem remains PROVED and axiom-clean, and the conjecture remains OPEN. Nothing in this estimate bears on the theorem's correctness; the question is only whether this market's data instantiates it, and here it does not.

## 7. The Panoptic-vs-Lean wedge

**The estimated `pi_it` is PANOPTIC'S PREMIUM, not the bare streaming-premium
fee-revenue identity that Lean models.** This is a real wedge between the two
objects and is recorded here rather than papered over.

`spec/refs/cfmm-discrete/STREAMING_PREMIUM.md` and `lean/vol_markets/Panoptic.lean`
model `streamingPremium` as LP fee revenue per unit liquidity. Panoptic pays
that fee growth multiplied by a UTILIZATION-BASED multiplier:

> `1 + nu*R/N` on the long side, `1 + nu*R^2/(N*T)` on the short side,
> with `nu = 1/VEGOID = 1/8 = 0.125`, `R` = removed liquidity, `N` = net
> liquidity, `T = N + R`.

The multiplier is applied INSIDE the contract's X64 accumulator, so it is
already in the reconstructed premium and is never re-applied by this code.
`Panoptic.Premium.multiplierWedge` exists solely to REPORT it. Its MEASURED
distribution over the 8910 accumulator readings backing this panel:

| statistic | value |
|---|---|
| median (all readings) | 1.112500 |
| min | 1.000000 |
| max (all readings) | 1.291667 |
| max over LONG readings (2839) | 1.291667 |
| max over SHORT readings (6071) | 1.204167 |
| readings with removed liquidity R = 0 (wedge exactly 1) | 3467 of 8910 |
| implied max `R/N` on long readings, `8*(wedge-1)` | 2.333333 |
| `1 + nu` — the figure 10-CONTEXT quotes as the bound | 1.125 |

**The wedge is present, and it BINDS.** The median reading carries a factor of 1.112500, so the typical premium in this panel is about 11.250000% larger than the bare fee-revenue quantity Lean models. This is not a rounding difference and it is not optional: the estimated `upsilon` is the vega of PANOPTIC'S premium, and any comparison with a Lean `streamingPremium` quantity must carry the factor. **And the measured maximum EXCEEDS the 1.125 figure the phase context quotes as the bound** — 1.291667 on the long side and 1.204167 on the short. That is arithmetic rather than a defect, and it is exactly why the plan asked for a MEASURED distribution instead of a quoted bound. `1 + nu*R/N <= 1 + nu` requires `R <= N`: removed liquidity never exceeding net liquidity. On this market it does — the long maximum implies `R/N` reached 2.333333. The short branch `1 + nu*R^2/(N*T)` with `T = N + R` likewise exceeds `1 + nu` once `R` passes about 1.62*N, and behaves like `nu*R/N` for `R >> N`. Neither branch is bounded by 1.125 in general, so citing that number as a ceiling would misstate the accrual law; the measured figures above are what should be carried into the 10-11 cross-walk.

Plan 10-11 records the same wedge in the Lean-Haskell cross-walk table.

## 8. Threats to validity

Phase 9's threats are carried forward, not discharged, except where this phase
actually changed something.

1. **A passing gate validates MEASUREMENT, not identification.** It certifies
   the LHS is the quantity the protocol paid. Whether this market's variation
   identifies `upsilon` is a separate question, and the STOPPING_RULE
   section is the only thing in this document that answers it.
2. **The cluster ceiling.** 6760 rows, but only 55 tokenId
   clusters and 84.127219% of the rows in ten positions.
   Adding hours to existing positions multiplies rows without multiplying
   clusters, so the clustered CI does not contract like 1/sqrt(N).
3. **Flagged rows.** 50 row(s) carry `ChunkEmpty`
   (the chunk's net liquidity was zero at the read, so a flat accumulator is
   ambiguous between "no fees" and "no chunk") and 0
   carry `AccFrozen`. They are RETAINED and labelled, never silently dropped:
   dropping them would be a selection decision taken after seeing the data.
4. **The zero-swap hour.** 3 row(s) sit in an hour with
   `n_swaps = 0`, carried as a MEASURED sigma2 = 0 after a bounded re-fetch
   reproduced the tick cache byte-identically (10-09). The confirming re-fetch
   used the SAME public endpoint, so it establishes reproducibility, not
   provider-independence.
5. **The long-stratum capping wedge.** `_getAvailablePremium` caps SETTLED long
   premium while the accumulator reports ACCRUED. It did not bind on any spell
   in the gate sample, but the panel's long rows are ACCRUED premium and the
   distinction survives this phase.
6. **The `width == 0` exclusion.** `PanopticPool._getPremia` skips legs with
   `width == 0`, so those legs contribute no premium and are absent from the
   panel. The 10-01 census found `width != 0` on 68 of 68 spell-legs, so the
   exclusion does not bind on this population — but it is a selection rule that
   would bind on a different one.
7. **Multi-leg positions carry one strike.** Premium is summed over legs within
   the hour, but `strike_tick` comes from the position's first resolved leg.
   `leg_count` is carried in the panel so the approximation is visible.
8. **Residual reconstruction error.** 53 of 61 spells reconcile exactly to the
   wei; the other 8 carry an irreducible sub-block end-of-block-versus-
   at-transaction `eth_call` read wedge, bounded at 5.447268e-4 relative
   (18x inside tolerance). Removing it needs transaction-level replay.
9. **Functional form.** `kappa`'s meaning is exponential-form dependent (spec
   section 6.1.1); the semiparametric alternative is the check.
10. **Strike-composition selection.** Strikes were never declared exogenous
    (spec section 2.5). The position-FE diagnostic is the intended check; read
    its outcome in section 4.4 before treating this threat as cleared.
11. **The Panoptic-vs-Lean multiplier wedge** (section 7).
12. **The LHS sign convention** (section 3.1a). 2280 long rows
    enter with the opposite sign to the 4480 short ones,
    where Phase 9 normalised both to the seller side. This attenuates
    `upsilon0` and widens its interval, and it is the most consequential
    unplanned difference between the two runs' left-hand sides.
13. **Scale non-comparability of the pre-committed bar** (STOPPING_RULE,
    comparability note). The bar carries Phase 9's USD/day units and the
    realised half-width carries this panel's ETH/hour units. Recorded; NOT acted on.
14. **The intercept changed meaning.** `beta0` is now ETH per HOUR, not USD
    per day, so it is not comparable with Phase 9's 2.36e-4 either.

## 9. DATA LINEAGE (audit trail)

Run date: 2026-07-27. Git commit: `ddf649e`.
All paths are repo-root relative. No credential is recorded anywhere in this
pipeline: every endpoint below is public and keyless.

### The exact invocation

```
econometrics estimate --epoch-panel notes/structural-econometrcics/data/panel-epoch.csv --variance notes/structural-econometrcics/data/variance-hourly.csv --epoch-hours 1 --endpoint https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn --pool 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a --rpc https://mainnet.base.org --from-block 43781657 --to-block 48879461
```

### Chain and contracts

| what | value |
|---|---|
| chain | Base mainnet (L2), chainId 8453 |
| Panoptic subgraph | `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn` |
| PanopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee 500, tickSpacing 10) |
| underlying pool (V4 poolId) | `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a` |
| SFPM (premium accumulator read target) | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` |
| VEGOID / nu | 8 / 0.125 |
| Base RPC (variance + accumulator reads) | `https://mainnet.base.org`; failover `https://base.drpc.org` |
| V4 PoolManager (Swap log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |
| block range | 43781657 .. 48879461 |

The bulk accumulator read (plan 10-06) issued **8,910 `eth_call`s** across a
six-cycle resume chain; wall time was dominated by public-RPC rate limiting
rather than call count (effective throughput ~0.25-7 calls/s; the final slice
ran 1,994 calls in 7,963 s). `FAILOVER_CALLS: 0` on the completing slice. Full
read lineage: `notes/structural-econometrcics/data/premium-accumulators-lineage.md`.

### Files

| path | contents | rows |
|---|---|---|
| `notes/structural-econometrcics/data/burn-truth.csv` | frozen OptionBurn ground truth (INPUT) | 61 |
| `notes/structural-econometrcics/data/premium-accumulators.csv` | SFPM X64 accumulator readings | 8,910 |
| `notes/structural-econometrcics/data/epoch-blocks.csv` | hourly epoch -> first Base block | 2,832 |
| `notes/structural-econometrcics/data/chunk-legs.csv` | per-leg chunk identity census | see file |
| `notes/structural-econometrcics/data/reconcile-errors.csv` | per-spell gate error | 61 |
| `notes/structural-econometrcics/data/reconcile.md` | THE gate report | see section 2 |
| `notes/structural-econometrcics/data/variance-hourly.csv` | hourly sigma2, EIV instrument, pool tick, n_swaps | 1887 |
| `notes/structural-econometrcics/data/panel-epoch.csv` | THE position-epoch panel (LHS) | 6760 |
| `notes/structural-econometrcics/data/collateral-flows.csv` | signed collateral share flows | see file |
| `notes/structural-econometrcics/data/estimation-panel-v2.csv` | the estimation panel handed to any later cross-check | 6760 |
| `notes/structural-econometrcics/data/swap-ticks-base-v4-full.csv` | raw (unix, tick) Swap cache (gitignored: large, regenerable) | 632,315 |

### The epoch definition

`epoch = floor(unixSeconds / 3600)` — hourly buckets — via
`Panel.Epoch.epochOfSeconds`, the SAME function the variance series uses, so
the join is an exact INTEGER match and never a timestamp comparison (the
09-05 40587-offset trap). Block-index epoch `e` is the START of hour `e`, so a
row's premium is the accumulator difference over the interval STARTING at that
boundary and is regressed on the variance of the SAME hour.

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

### The estimator

- **Point estimates:** `Model.NLS.fitGSL` — `Numeric.GSL.Fitting.fitModel`,
  Levenberg-Marquardt with an analytic 3-column Jacobian, run from the
  data-scaled multi-start and keeping the lowest-SSE finite solution. The
  chosen-start diagnostics and the SSE are in section 4.1.
- **Standard errors:** `Model.SandwichSE.clusterSandwich` — a hand-rolled
  tokenId-clustered CR0 sandwich `(J'J)^-1 [sum_g s_g s_g'] (J'J)^-1`, with NO
  finite-sample correction, golden-tested to 1e-9 against the frozen 09-01
  fixture. The Stata-style CR1 multiplier is exposed as `clusterCR1Factor` but
  deliberately not baked in.
- **EIV:** `Model.EIV.ivFit` — two-step two-noisy-measures IV, `kappa` from
  NLS then `(Z'X)^-1 Z'y` with `sigma~2` instrumenting `sigma2`.
- **Tests:** `Tests.Specification` — one-sided Normal for the sign
  restrictions, chi-squared(1) Wald for the symmetry restriction, p-values
  from the `statistics` package.
- **Alternatives:** `Alternatives` — the four locked spec section-6.2
  specifications, each reporting NOT IDENTIFIED with a reason rather than a
  meaningless number when the design cannot support it.

### Reproduce

```sh
stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \
  --epoch-panel notes/structural-econometrcics/data/panel-epoch.csv \
  --variance notes/structural-econometrcics/data/variance-hourly.csv \
  --epoch-hours 1 \
  --estimation-out notes/structural-econometrcics/data/estimation-panel-v2.csv \
  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \
  --from-block 43781657 --to-block 48879461
```

The endpoint, poolId and RPC URL are the values in the table above. No API key
is required for any of them.
