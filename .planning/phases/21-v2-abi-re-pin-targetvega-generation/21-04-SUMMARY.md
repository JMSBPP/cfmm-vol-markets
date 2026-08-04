---
phase: 21-v2-abi-re-pin-targetvega-generation
plan: 04
subsystem: api
tags: [haskell, stochastic, mwc-random, log-uniform, volorder, units, tdd, mutation]

# Dependency graph
requires:
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 01
    provides: "VolOrder carrying target_vega, pack_vol_order_input, the rpin_base_* fixtures, vega_corners, mask_of, and mwc-random already in the test-suite build-depends"
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 03
    provides: "the measured finding that an inequality-shaped assertion never establishes correctness of the thing it is unequal about -- the reason this plan pins VALUES"
provides:
  - "VegaDraw: a one-constructor sum type (LogUniform vega_min vega_max) carrying the band derivation, the u96 headroom, the arXiv:2205.08904 shape evidence and the honest limit, in code"
  - "draw_target_vega: log-uniform draw in raw Uniswap L units with a loud draw-time domain guard"
  - "OrderShape: the placeholder-free partial order type; StochasticOrderGen.orders is now [OrderShape]"
  - "run_order_gen attaching one drawn targetVega per order at GENERATION time via attach_vega"
  - "Sample.sample_order_shapes (replacing sample_orders) and sample_order_gen carrying vega_draw"
  - "Three new named checks (vega01 anchor + the two VEGA-01 checks): 58 -> 61"
  - "log_uniform_reference + vega01_first_twelve: an independent second implementation and a golden RNG-stream pin"
affects: [21-05 phase verification, 22 drivers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A draw law's justification lives in the type's haddock, including the honest limit -- the caveat is a comment, never a hedge that weakens the implementation"
    - "A partial type (OrderShape) rather than a placeholder field: a value that is silently discarded is the stale-literal defect in a new costume"
    - "A generator check pins VALUES three ways -- an independent reference on the same uniform, a golden literal pin of the RNG stream, and a distributional shape statistic -- because bounds and spread assertions are inequalities"
    - "When a plan predicts which assertion kills a mutant, MEASURE the prediction; here it was false"

key-files:
  created: []
  modified:
    - offchain/lib/StochasticOrderGen/Types.hs
    - offchain/lib/StochasticOrderGen/Simulate.hs
    - offchain/lib/StochasticOrderGen/Rpc.hs
    - offchain/app/Sample.hs
    - offchain/test/Main.hs

key-decisions:
  - "The plan's predicted discriminator FAILED: a linear-uniform draw spans 9 distinct bit-lengths (62..70) over 256 fixed-seed draws and CLEARS the >= 8 spread assertion. A bottom-decade mass assertion (77 vs 4 of 256, MEASURED) was added as the real shape discriminator."
  - "The zero-lower-bound rejection is INCIDENTAL, not explicit: it works only because the log transform evaluates 0 * Infinity = NaN. MEASURED by the linear mutant, under which vega_min = 0 sailed through and returned a value."
  - "cabal build -j all confirmed vacuous for the THIRD consecutive plan: exit 0 against a test suite that would not compile. Every gate ran as cabal build --enable-tests -j all."
  - "The plan's `grep 'initialize' produces NO output` criterion contradicted its own instruction to say in-file why create is used instead. The comment was reworded to satisfy the criterion genuinely -- the ninth instance of this pattern in the repo."
  - "app/Main.hs needed NO edit, exactly as the plan predicted."

patterns-established:
  - "A golden value pin and an independent-reference pin are complementary: the reference follows an RNG-stream change, the golden catches it"
  - "A mutation demo must measure WHICH assertion killed, then neutralise that assertion and re-run -- otherwise a check's claimed discrimination is folklore"
  - "A refuted prediction is removed from the in-file comment, not left beside the code it misdescribes"

requirements-completed: [VEGA-01]

# Metrics
duration: 15min
completed: 2026-08-01
---

# Phase 21 Plan 04: targetVega Generation Summary

**`StochasticOrderGen` now DRAWS each order's `targetVega` log-uniformly on `[1e18, 1e21]` raw Uniswap-L units — a band derived from the v3 liquidity relation on the rig's own pool and a shape backed by arXiv:2205.08904 — with the placeholder trap removed by an `OrderShape` type, a loud draw-time guard driven to fire on three mis-parameterisations against a passing control, and 256 fixed-seed draws pinned by VALUE rather than by inequality after the plan's own predicted discriminator was measured and found not to discriminate.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-01T19:03:47Z
- **Completed:** 2026-08-01T19:18:15Z
- **Tasks:** 2 (task 1 executed TDD, so 4 commits)
- **Files modified:** 5

## Task Commits

1. **Task 1 (TDD RED): failing behaviour anchor for the drawn targetVega** — `301e6ff` (test)
2. **Task 1 (TDD GREEN): VegaDraw, draw_target_vega, OrderShape, generator wiring** — `3b18dd9` (feat)
3. **Task 2: VEGA-01 fixed-seed band check and the loud-guard negative** — `d299ba5` (test)
4. **Task 2 (extra): the bottom-decade shape assertion** — `9eeed32` (test)

No REFACTOR commit was needed.

---

## Requested Evidence

### 1. The first 12 fixed-seed draws with their bit-lengths

Reproduced from `System.Random.MWC.create`'s default-seeded stream under
`LogUniform 1e18 1e21`, and pinned in-code as `vega01_first_twelve`:

```
 1  1186946348279245568    bits=61
 2  166952222113890402304  bits=68
 3  3006703757638344704    bits=62
 4  121844603607608246272  bits=67
 5  4798878527208134656    bits=63
 6  22362718531875102720   bits=65
 7  37052572198576381952   bits=66
 8  2315392034344841216    bits=62
 9  37999405005355057152   bits=66
10  1475274689841291776    bits=61
11  546508318830051721216  bits=69
12  181491393322483220480  bits=68
```

**These are IDENTICAL to the plan's probe values, as a set and in sequence.** The plan
printed them in a two-column layout; read column-wise (left column top-to-bottom, then
right), its twelve numbers are exactly the twelve above in exactly this order. The
planner's probe and this implementation therefore agree independently — the law was
re-derived, not transcribed.

### 2. The observed bit-length spread over all 256

| law | distinct bit-lengths | range | min draw | max draw | distinct values |
|---|---|---|---|---|---|
| **log-uniform (shipped)** | **11** | **60..70** | 1.0250e18 | 9.6986e20 | 256/256 |
| linear-uniform (mutant) | 9 | 62..70 | 4.5665e18 | 9.9557e20 | 256/256 |

The band's own bit-length range is 60..70 (1e18 = 2^59.8, 1e21 = 2^69.8), so the shipped
law sweeps it completely.

### 3. OBSERVED RED — the linear-interpolation mutant, and the plan's prediction REFUTED

`draw_target_vega`'s exponent replaced by linear interpolation
(`lo + round (fromIntegral (hi - lo) * u)`). `cabal test` exits **1 at 58/61**:

```
FAIL vega01_draw_behavior: a zero lower bound (vega_min = 0) RETURNED 24810362882962010112 instead of failing. A draw law that does not guard at draw time hands a nonsense targetVega to the encoder, where it is either rejected far from the cause or silently skipped by the batch path.
FAIL vega01_fixed_seed_draw_is_in_band: draw 0 = 25785552520079048704 but the independent log-uniform reference gives 1186946348279245568 for the same uniform 2.481036288296201e-2 -- the library's transform is not the decided law
FAIL vega01_out_of_band_draw_fails_loudly: a zero lower bound (vega_min = 0, which would violate the on-chain vega_target_is_complete > 0 predicate and pack to a batch tuple that is SILENTLY SKIPPED) RETURNED 24810362882962010112 instead of failing loudly

58/61 checks passed
3 FAILED: vega01_draw_behavior, vega01_fixed_seed_draw_is_in_band, vega01_out_of_band_draw_fails_loudly
```

Restored with `git checkout`: `Simulate.hs` sha256
**`5e90d9955c7feb46ea33b872bf94e5f7f1e840a2c72882ed7d8fc237db9a4f96` before and after**,
`git diff --exit-code` clean, suite back to 61/61 at zero warnings.

#### WHICH ASSERTIONS STAYED GREEN — the honest negative, and it changed the plan

The plan's acceptance criterion states the mutant reddens
`vega01_fixed_seed_draw_is_in_band` **on the bit-length-spread assertion**, with bounds
alone still passing. **That prediction is FALSE, and it was measured rather than
assumed.** With the mutant applied and only the two VALUE pins neutralised
(`matches_reference` and the golden), the suite reports:

```
PASS vega01_fixed_seed_draw_is_in_band
59/61 checks passed
2 FAILED: vega01_draw_behavior, vega01_out_of_band_draw_fails_loudly
```

Every remaining assertion — the ABI bound, the band, `> 200` distinct, bit-lengths
inside 60..70, and **`>= 8` distinct bit-lengths** — is satisfied by a draw law that is
not the decided law. The cause, measured directly: over 256 draws a linear-uniform law
still reaches down to 4.57e18 (bit-length 62), because the smallest of 256 uniforms is
about 1/256, so it spans **9** distinct bit-lengths and clears a threshold of 8. The
plan's reasoning ("a linear-uniform draw would concentrate at 69-70 and fail this") holds
for the *bulk* of the mass but not for the *extremes*, and a distinct-count statistic
sees only the extremes.

This is precisely the failure mode wave 2 recorded and this plan was directed to avoid:
an assertion whose conclusion is an inequality survives any mutant that stays inside the
inequality. **The value pins are what killed it** — `matches_reference` fires at draw 0.

#### The assertion that was ADDED as a result

A distributional statistic separates the two laws cleanly where the distinct-count does
not. Log-uniform places a third of its mass in each decade; linear-uniform places a
thousandth in the bottom one. **MEASURED over the same 256 fixed-seed draws: 77 draws
below 1e19 under the shipped law, 4 under the mutant.** The check now requires `>= 40`
(margin of 37 above the mutant, 37 below the shipped value).

Re-measured with the mutant applied AND both value pins still neutralised, the new
assertion kills it on its own:

```
FAIL vega01_fixed_seed_draw_is_in_band: only 4 of 256 draws land in the band's BOTTOM DECADE [1e18, 1e19). Log-uniform puts about a third of its mass there (measured 77); a linear-uniform draw puts about a thousandth (measured 4). This is the assertion that discriminates the SHAPE of the law, as distinct from its range.
```

So the check now has **two independent discriminators** — one on shape (bottom-decade
mass), one on value (reference + golden) — and the refuted claim was deleted from the
in-file comment rather than left standing next to the code it misdescribes.

### 4. The three loud-guard messages as thrown

All three carry `draw_target_vega`'s own message, which the check pins as a substring:

```
inverted bounds  : user error (targetVega draw out of band: <v> not in [1000000000000000000000, 1000000000000000000])
zero lower bound : user error (targetVega draw out of band: <NaN-rounded garbage> not in [0, 1000000000000000000000])
above u96 ceiling: user error (targetVega draw out of band: <v> not in [79228162514264337593543950336, 158456325028528675187087900672])
```

The CONTROL (`LogUniform 1e18 1e21`) returns normally and in band. Without it, all three
assertions above would be satisfied by a `draw_target_vega` that always throws.

### 5. Determinism across runs

`cabal test` run twice back-to-back; the `vega01_` lines and the total are byte-identical
(`diff` clean):

```
PASS vega01_draw_behavior
PASS vega01_fixed_seed_draw_is_in_band
PASS vega01_out_of_band_draw_fails_loudly
61/61 checks passed
```

### 6. The drawn values are NOT the packing corpus — and why

A `Double` carries 53 significand bits; the top of the band needs 70. A draw near 1e21
therefore has roughly **17 forced-zero low bits**, so the drawn set barely exercises the
bottom of the u96 field and never lands on a field boundary. `vega_corners` — the
CONSTRUCTED corpus from 21-01, carrying `1`, `2^95`, `2^96-1` and an alternating-bit
pattern — remains the packing corpus, and the two are kept separate by intent. This is
stated in three places: `vega_corners`' own haddock (21-01), `draw_target_vega`'s
significand note, and `vega01_fixed_seed_draw_is_in_band`'s header.

The drawn values ARE asserted to pack cleanly (all 256 `Right`, bits >= 224 zero) — that
is a smoke test on the generator's output, not field-boundary coverage.

### 7. Check count

`cabal test`: **58 -> 61**, exit 0, `SC-3 and SC-4 OK`, zero `-Wall` warnings. Three new
checks — the two the plan names plus the `vega01_draw_behavior` anchor introduced as the
TDD RED.

---

## Accomplishments

- **The fourth field now comes from somewhere, and that somewhere is written down.**
  `VegaDraw`'s haddock carries the full derivation: the dimension (raw Uniswap L,
  `notes/UNITS_AND_SCALES.md` section 2 — not X96, not WAD, not collateral, with the
  reason a slip is invisible on chain), the four-row
  `L = amount1 / (1 - 1.0001**(-w/4))` table instantiated on the rig's own pool
  (`initTick = 0`, both tokens 18 decimals), the u96 headroom figure (7.9e7x), the
  bit-length range, the arXiv:2205.08904 mean/median ~= 10 finding, the explicit
  rejection of linear-uniform and of a fixed constant, and the honest limit.
- **The honest limit is a comment, not a hedge.** No source pins a *sampling law* for a
  variance-instrument target vega in raw L units; the evidence pins the BAND exactly and
  the SHAPE as log-scale. That is recorded in the type's haddock along with the extension
  path (a second constructor), and the implementation commits to the decided law without
  qualification.
- **The placeholder trap is removed structurally, not by discipline.** `OrderShape`
  carries `shape_vol_target / shape_range_width / shape_skew` and no vega at all, so
  there is no field for a caller to populate and the generator to silently discard.
  `grep -n 'target_vega =' offchain/app/Sample.hs` returns exactly one line — `sample_order`,
  the single-call demo order that does not go through the generator and so needs a real
  value of its own.
- **The draw happens once per order at generation time**, before any transaction is built,
  so a retried send re-sends the same order rather than re-rolling the value it is
  retrying. `run_order_gen`'s mid-fold failure caveat was extended to say that
  `draw_target_vega`'s guard, unlike `create_orders`, cannot leave a partially-sent batch
  behind.
- **No new dependency.** `git diff --stat cfmm-replicationPlank-rpc-api.cabal` is empty
  against both the working tree and `HEAD`; `vector`, `tasty` and `hspec` appear nowhere.
  `System.Random.MWC.create` supplied the fixed seed.

## Files Created/Modified

- `offchain/lib/StochasticOrderGen/Types.hs` — `VegaDraw` (one constructor, with the full
  justification in haddock), `OrderShape`, and `StochasticOrderGen` gaining
  `vega_draw :: VegaDraw` with `orders :: [OrderShape]`. `VolOrder.Types` is no longer
  imported here — `-Wall` confirmed it dead, as the plan anticipated.
- `offchain/lib/StochasticOrderGen/Simulate.hs` — `draw_target_vega` with the loud domain
  guard, a comment on why the guard is not dead code (ulp overshoot at the top of the band;
  mis-parameterisation) pointing at `StochasticPriceGen.Simulate.euler_step` as the sibling
  discipline, and the 53-vs-70 significand note with the do-not-use-as-packing-corpus
  instruction.
- `offchain/lib/StochasticOrderGen/Rpc.hs` — `attach_vega` and the rebuilt `run_order_gen`;
  the length-guard message reworded to "order shapes"; the failure caveat extended.
- `offchain/app/Sample.hs` — `sample_orders` renamed to `sample_order_shapes` and retyped;
  `sample_order_gen` gains the `vega_draw` band; `sample_order` keeps its real `10^18`.
- `offchain/test/Main.hs` — `vega01_band`, `vega01_draw_behavior`, `attempt_draw`,
  `bit_length`, `log_uniform_reference`, `vega01_first_twelve`,
  `vega01_fixed_seed_draw_is_in_band`, `vega01_out_of_band_draw_fails_loudly`.
- `offchain/app/Main.hs` — **NOT modified**, exactly as the plan predicted. It imports
  `sample_order`, `sample_order_gen`, `sample_price_gen` and `sample_tick`, none of which
  changed name or type.

## What the VEGA-01 checks do and do not establish

Stated plainly, because wave 2's lesson was that this is where checks get over-claimed.

**`vega01_fixed_seed_draw_is_in_band` DOES establish:**

- every one of 256 fixed-seed draws fits the ABI field `[1, 2^96-1]` and the configured
  band `[1e18, 1e21]`;
- the draws are essentially all distinct (256/256) and sweep 11 bit-lengths across the
  band's full 60..70 range;
- at least 40 of 256 land in the bottom decade, which a linear-uniform law does not
  satisfy (measured 4) — this is the SHAPE discriminator;
- every draw equals an independent second implementation of the decided transform applied
  to the same uniform — this pins the VALUES, not a relation among them;
- the first twelve equal a pinned golden, which catches an mwc-random stream change that
  the reference above would silently follow;
- every drawn value packs with bits >= 224 zero.

**It DOES NOT establish:**

- that log-uniform on `[1e18, 1e21]` is the RIGHT law. That is a decision, argued in
  `VegaDraw`'s haddock from the v3 band derivation and arXiv:2205.08904. No test can
  supply it, and the golden pin in particular only establishes that the law is
  *unchanged*.
- field-boundary coverage of the u96 `targetVega` slot — see Requested Evidence 6.
- anything about the ON-CHAIN acceptance of a drawn value. The suite is chain-independent
  and nothing here was sent to the rig.

**`vega01_out_of_band_draw_fails_loudly` DOES establish** that the guard fires, with its
own message, on three distinct mis-parameterisations, and that it does not fire on the
configured band (the control).

**It DOES NOT establish** that the guard fires for the *stated reason* in the
zero-lower-bound case — see the finding below.

## Findings

**F3 (NEW) — the zero-lower-bound rejection is INCIDENTAL, not explicit.** The guard is
`v >= max 1 lo && v <= min hi (2^96 - 1)`. With `vega_min = 0` this reduces to
`v >= 1 && v <= min hi (2^96-1)`, which a perfectly ordinary in-band value satisfies. The
reason `LogUniform 0 (10^21)` fails today is that the *transform* evaluates
`0 * (1e21/0)**u` = `0 * Infinity` = `NaN`, and `round NaN :: Integer` produces garbage
that falls outside the bounds. **This was measured, not reasoned:** under the linear
mutant — which does not divide by `lo` — `vega_min = 0` sailed straight through and
returned `24810362882962010112`, reddening both `vega01_draw_behavior` and
`vega01_out_of_band_draw_fails_loudly`.

Consequence, and it lands exactly on the documented extension path: **when `VegaDraw`
gains its second constructor, that constructor must supply its own parameter validation.**
It cannot inherit a zero-lower-bound rejection from this guard, because this guard does
not implement one. Not fixed here: the plan states the implementation as DECIDED and
verbatim, the shipped behaviour satisfies the specified contract, and adding an explicit
parameter guard would change the error message the checks pin. Logged for 21-05 /
whoever adds the constructor.

**F1 / F2 (21-01, still open, not re-inspected)** — the stale V1 comment block and the
`TICK_SPACING = 20` vs pool `tickSpacing = 10` discrepancy both live in the plank track's
`src/`. This plan took no layout from either and edited neither.

**The `sc4_no_retired_value_is_live` padding hole (21-03)** remains in
`deferred-items.md`, untouched by this plan.

## Decisions Made

- **`cabal build -j all` is not a build gate — confirmed for the third consecutive plan
  and re-measured here.** With the RED in place (`Not in scope` on two imports),
  `cabal build --enable-tests -j all` exited **1** while `cabal build -j all` exited
  **0**. Every gate in this plan ran in the corrected form; the plan's original form was
  also run at final verification (exit 0) and is recorded, but only the corrected form is
  meaningful.
- **The bottom-decade assertion was added because the plan's predicted discriminator was
  measured and failed.** Leaving the check as written would have shipped VEGA-01 with a
  stated discrimination property that does not hold.
- **The zero-lower-bound guard was NOT changed**, only documented. See F3.
- **The drawn values were not sent to the rig.** The suite is chain-independent by design
  and 21-05 depends on the rig sitting at block 9 with `orderCount = 0`; nothing in this
  plan touched it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's build/warning gate does not build the test suite**

- **Found during:** Task 1 (TDD RED), inherited from 21-01 and 21-03
- **Issue:** `cabal build -j all` — the plan's verify command in both tasks — builds only
  `lib` and `exe`. Used as written it reports a passing warning gate over a test suite
  that does not compile.
- **Fix:** every gate run as `cabal build --enable-tests -j all`. Re-measured directly
  against this plan's own RED: corrected form exit 1, plan's form exit 0.
- **Files modified:** none (procedural)
- **Committed in:** n/a

**2. [Rule 1 - Bug] The plan's `initialize` criterion contradicted the plan's own instruction**

- **Found during:** Task 2
- **Issue:** the action step instructs "Use `create`, NOT `initialize` — `initialize`
  would drag in `vector`" and the surrounding plan asks for that reasoning in-file, while
  the acceptance criterion requires `grep -q 'initialize' offchain/test/Main.hs` to produce
  NO output. Written naturally, the comment matches the grep. This is the ninth recorded
  instance of the self-contradicting-criterion pattern in this repo.
- **Fix:** the comment now names mwc-random's "OTHER seeding entry point — the one taking
  an explicit `Vector Word32` seed", preserving the whole reasoning (why it is not used,
  what it would cost) without the identifier, and states why the identifier is absent so
  the next reader does not helpfully add it back. The criterion is satisfied genuinely,
  not relaxed.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** `grep -n 'initialize' offchain/test/Main.hs` exits 1 with no output;
  suite still 61/61.
- **Committed in:** `d299ba5`

**3. [Rule 2 - Missing Critical] The check's stated shape discriminator did not discriminate**

- **Found during:** Task 2, mutation demo
- **Issue:** the plan specifies a `>= 8` distinct-bit-lengths assertion and claims it is
  what a linear-uniform draw cannot satisfy. Measured: the linear-uniform mutant spans 9
  distinct bit-lengths and clears it. With the value pins neutralised the whole check
  PASSES under the mutant. VEGA-01 would have shipped claiming a shape property it does
  not test.
- **Fix:** added a bottom-decade mass assertion (`>= 40` of 256 below 1e19; measured 77
  shipped vs 4 mutant), verified it kills the mutant on its own with the value pins still
  neutralised, and deleted the refuted claim from the in-file comment.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** mutant + neutralised value pins = `FAIL ... only 4 of 256 draws land
  in the band's BOTTOM DECADE`; restored = 61/61.
- **Committed in:** `9eeed32`

**4. [Rule 2 - Missing Critical] Value pins beyond what the plan specified**

- **Found during:** Task 2
- **Issue:** the plan's positive check ends in bounds and spread assertions, all of which
  are inequalities — the exact shape wave 2 measured surviving a value-destroying mutant.
  The orchestrator's direction was to pin the drawn sequence or a strong statistic of it.
- **Fix:** two independent value pins added — `log_uniform_reference` (a second
  implementation of the transform, checked elementwise against the library's 256 draws on
  the same uniforms, in the spirit of 21-01's `pack_storage_reference`) and
  `vega01_first_twelve` (a golden literal pin of the RNG stream, which the reference
  cannot catch because it would follow a stream change).
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** the reference pin is what actually reddened under the linear mutant,
  at draw 0.
- **Committed in:** `d299ba5`

**5. [Rule 2 - Missing Critical] Second-order measurement of which assertion kills**

- **Found during:** Task 2
- **Issue:** the plan requires an observed RED but not an account of which assertion did
  the killing — the same gap 21-03 closed. Given that this plan's whole point is that
  inequality assertions over-claim, asserting discrimination without measuring it would
  have repeated the error being corrected.
- **Fix:** the mutant was re-run twice more with assertions selectively neutralised,
  establishing (a) that bounds + spread alone pass under the mutant and (b) that the new
  bottom-decade assertion kills it independently of the value pins.
- **Files modified:** none (all neutralisations reverted from a pristine copy)
- **Verification:** `Simulate.hs` sha256 `5e90d995…db9a4f96` before and after;
  `git diff --exit-code` clean.
- **Committed in:** n/a (evidence only)

---

**Total deviations:** 5 auto-fixed (1 blocking, 1 bug in the plan's own criterion,
3 missing-critical evidence/assertions)
**Impact on plan:** No scope creep. Deviation 3 is the material one — the plan's stated
discrimination property was false, and shipping it unmeasured would have put a wrong
claim in the requirement's evidence trail. Deviations 4 and 5 are the orchestrator's
carried-forward correction applied and then verified rather than asserted.

## Issues Encountered

- **The TDD RED is compile-level, as in 21-01 and unlike 21-03, and that is the honest
  situation rather than a shortcut.** The defect being fixed is the ABSENCE of a draw:
  before this plan the library had no vega-drawing surface at all, and `Sample.hs`'s
  constant lives in the executable's `other-modules`, which the test suite cannot import.
  No assertion expressible against the shipped library could fail. The RED is therefore
  `Module 'StochasticOrderGen.Simulate' does not export 'draw_target_vega'` plus the same
  for `VegaDraw(..)`. The assertion-level RED for the same code is the linear-interpolation
  mutant in Requested Evidence 3, which is genuinely assertion-level and reddens three
  checks.
- **`cabal exec -- runghc` stopped exposing the library package** partway through, after a
  `git checkout` of a library source file ("member of the hidden package"). The two
  measurements still outstanding at that point (bottom-decade counts) were taken from the
  test suite instead, by setting the new assertion's threshold to an impossible value and
  reading the count out of the failure message. Slower, but it measures the same numbers
  through the code path that will carry them.

## User Setup Required

None. `cast` (foundry) must be on `PATH`, as it already was.

## Next Phase Readiness

- **Ready for 21-05 (phase verification).** The rig was **not touched**: no transaction,
  no snapshot, no `cabal run`. It should still be at block 9 with `orderCount = 0` as
  21-03 left it, which 21-05's freshness assertion depends on.
- **VEGA-01 is satisfied**; with RPIN-01..06 from 21-01/02/03, Phase 21's requirements are
  complete apart from whatever 21-05 verifies at the phase level.
- **Three items are open for 21-05:** F3 (the incidental zero-lower-bound rejection, above),
  the `sc4_no_retired_value_is_live` padding hole, and the two unused `build-depends`
  (`web3-crypto` in the library; `mwc-random` is now genuinely used by the test suite, so
  that half of 21-03's note is discharged by this plan).
- **Carry-forward for Phase 22 (DRIV-02):** the generator's drawn orders have never been
  sent to a chain. `attach_vega` is exercised only through the type system and
  `run_order_gen`'s call site; the draw itself is covered, but the end-to-end path from a
  drawn vega to a mined order is Phase 22's assertion, not this plan's.
- **Carry-forward for anyone adding a second `VegaDraw` constructor:** read F3 first. The
  new constructor owns its parameter validation.

## Self-Check: PASSED

- All five modified files exist on disk; `offchain/app/Main.hs` is confirmed unmodified.
- All four task commits resolve in `git log`: `301e6ff`, `3b18dd9`, `d299ba5`, `9eeed32`.
- Final gates: `cabal build --enable-tests -j all` exit 0 / **0** warning lines;
  `cabal test` exit 0 at **61/61** with `SC-3 and SC-4 OK`.
- `git diff --stat cfmm-replicationPlank-rpc-api.cabal` empty against both the working
  tree and `HEAD`; no `vector` / `tasty` / `hspec` anywhere in the file.
- Purge grep over `offchain --include='*.hs' --include='*.sh'` — no output.
- `grep -n 'target_vega =' offchain/app/Sample.hs` — exactly one line, `sample_order`.
- `grep -n 'initialize' offchain/test/Main.hs` — no output.
- Mutated file restored sha256-identical: `Simulate.hs`
  `5e90d9955c7feb46ea33b872bf94e5f7f1e840a2c72882ed7d8fc237db9a4f96`.
- Territory clean: `git status --porcelain src/ test/ foundry-scripts/ Makefile
  foundry.toml remappings.txt` — no output. (`lib/forge-std`, `offchain/spec/types.md` and
  the untracked root files were already modified at session start and were not touched.)

---
*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Completed: 2026-08-01*
