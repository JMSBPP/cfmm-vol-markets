# Phase 26: Shock Assembly — Fee Split & Event Decode — Research

**Researched:** 2026-08-17
**Domain:** exact rational/integer arithmetic over pips; EVM event-log decoding from synthetic logs
**Confidence:** HIGH on everything measured here (every number below was computed or executed on this
machine today); MEDIUM on the two open questions at the end.

> **Safe to quote hex here.** `sc3_literal_purge` scans `.hs`/`.sh`/`.sql` **under `offchain/`**
> only (`purge_scanned_extensions`, `Main.hs:974`). This file lives under `.planning/`, outside both
> scan roots, so the `0x`-prefixed values below are quotable **here** and are NOT quotable in any
> `offchain/**/*.hs`. That distinction is load-bearing and is repeated in the guard table.

---

## User Constraints

**No `26-CONTEXT.md` exists** — `/gsd:discuss-phase` has not been run for this phase. The
constraints below are copied from the orchestrator's brief and from `ROADMAP.md`'s Phase 26 block,
and are treated as locked.

### Locked

- Territory is `offchain/` and `.planning/` **only**. `model/` is the GAMS workstream's; `src/` is
  plank's. (Note: `model/mev_tax_model_one/` is **not in this worktree at all** — see M8.)
- `cabal build --enable-tests -j all`, **zero `-Wall` warnings**. The bare `cabal build -j all` is
  VACUOUS and must never be cited.
- `cabal test` must stay **DB-free AND GAMS-free**; both structural greps stay at 0.
- The whole phase **should be Tier A (pure)** where possible; anything needing the real solver
  belongs in a Tier-C capture, never in `cabal test`.
- Tree-derived floors MOVE and are **re-measured**, never incremented by arithmetic.
- **Evaluate in exact arithmetic over integer pips — never `Double`.**
- Issue #28's event signature is pinned and **supersedes ROADMAP SC-5's function selector**.
- The synthetic logs **MUST** carry a negative `tickDiff` and a nonzero `txlVolmDecay` that
  production never emits.
- `txlVolmDecay` (α_trans) is **not** a GAMS input (`VOLUME_PATH.md` §2). Decode it, record it,
  never feed it to the prover.

### Claude's discretion (recommendations made below, none pre-locked)

Module names and layout; the rounding rule's exact form; the seed's selection function; the shape of
the Tier-C conformance artifact; whether the admissibility refusal lives in `Gams.Argv` or a new
module.

### Out of scope

Changing `volume_path.gms` (another workstream — but see the **Correction of record** below, which
is a *finding to report*, not a change to make); the live chain (`CHAIN-01/02/03`, Phase 27); the
key formula (Phase 25); publication (Phase 28).

---

## Phase Requirements

| ID | Description | Research support |
|---|---|---|
| **FEE-01** | Given `f` and `δ*`, produce (φ_X, φ_M) with `(1−φ_X)(1−φ_M) = 1−f` exactly | M3/M4: the *exact* integer-pip level constraint is a **divisor problem** and is unsatisfiable for **95.07 %** of pool fees including **every canonical Uniswap tier**. The roadmap's own SC-1 anticipates this ("under a rounding rule pinned in writing"). Design in Architecture Patterns; residuals MEASURED at ≤ 5·10⁻⁴ pip |
| **FEE-02** | The pair satisfies `δ* ≥ 2ρ/(1+ρ²)`, checked before the solver is invoked | **M1/M2: this closed form is WRONG relative to the prover** — off by a factor of 2, and the prover's own `ellTest` is not ratio-only. The predicate must be `volume_path.gms:100–108` transcribed term for term. An all-**`Integer`** form is derived and verified on 20 000 random triples (M2) |
| **FEE-03** | An infeasible request is refused with reason + boundary, not read back as an exit code | M9: `Gams.Argv.render_argv` is already the total refusal gate (8 refusals incl. §1.2 equal fees) and is pure. M11: `Gams.Run` **is** importable by the suite, so a marker-stub Tier-B observation of "never spawned" is available without breaking GAMS-free |
| **FEE-04** | The choice of ρ within the admissible band is reproducible from a recorded seed | M4: band sizes MEASURED (2 686 admissible x-values at f = 3000, δ\* = 0.49), so the seed is genuinely load-bearing — but a band of size ≤ 1 makes the test vacuous, so band size is itself an assertion. `Driver.Seed` supplies the `Word32` + env convention at +0 packages |
| **CHAIN-04** | Decoding exercised against synthetic logs, before the event exists and without a chain | M6/M7: topic0 recomputed independently; the emitter read at source (`@evm_log2`, 96 bytes, `@evm_signextend(2,·)`, accessors return 0 when the flag bit is unset, `flags = 0` is legally emittable). M8: the E1 signature-parse idiom is **unavailable** — `ShockLib.plk` is not in this worktree |

---

## Summary

Two independent deliverables, one shared discipline. **Neither needs a chain and neither needs a
database; only one clause of one requirement needs the real solver.**

**The fee splitter is not the arithmetic the brief describes.** The brief supplied a settled closed
form, `δ* ≥ 2ρ/(1+ρ²)`, with the instruction to verify rather than rediscover. It was verified and
it **fails**: `volume_path.gms:100–108` — the gate the roadmap's SC-2 requires the Haskell verdict
to agree with — evaluates a different quantity. The prover sets `phiBar = 1−(1−phiX)(1−phiM)` (the
*composed* fee) and `dphi = phiM−phiX` (the *full* fee gap), where the brief read φ̄ as the
arithmetic mean `(φ_X+φ_M)/2` and Δφ as the ellipse *semi*-axis `(φ_M−φ_X)/2`. I re-derived the
disk-membership condition from the geometry in `VOLUME_PATH.md` §1 and it reproduces the prover's
expression **term for term**; the prover is right and the brief's reading is not. Consequences,
measured: the brief's bound is **exactly twice** the correct leading-order bound, it disagrees with
the prover on **36 of 70** near-boundary grid points, and at the fixture fees it **falsely refuses
82 713 pips** of admissible `δ*` — each such point being, in the roadmap's own words, a phase
failure. The brief's corollary "no target is reachable unless ρ ≥ 2+√3" is an artifact of the same
factor of 2 and is **false**: under the prover's gate the level-`δ ≤ ½` condition reduces to
`(ρ−1)² ≥ 0`, so **every** ρ ≠ 1 admits some target. Only `φ_X = φ_M` is structurally infeasible,
and that recovers §1.2 with the doc's own number (`δ = 1/(2−φ) = 0.50075` at 3000 pips), which the
brief's reading does not.

**The exactness in FEE-01 is a divisor problem, not a rounding problem.** Over integer pips the
level constraint is `(10⁶−φ_X)(10⁶−φ_M) = 10⁶(10⁶−f)`, so an *exact* pair exists only when that
product has a divisor in the open window `(10⁶−f, 10⁶)`. Measured over `f ∈ [1, 20000]`: **987 fees
(4.93 %)** admit any exact pair and **857 (4.29 %)** admit one the prover also accepts at
`δ* = 0.49`. **All four canonical Uniswap tiers — 100, 500, 3000 and 10000 pips — admit zero.** The
fixture's `f = 6497` admits exactly two: `(500, 6000)` and its mirror. So the splitter must round,
and the roadmap already says so; what research adds is the measured headroom — the best nearest-`m`
residual is `+8·10⁻⁶` pip at `f = 3000` and never worse than `5·10⁻⁴` pip at any tier, three orders
below SC-1's one-pip alarm.

**The decoder's hazard is that two of its three fields are guaranteed zero upstream.** Issue #28's
`flags = 0b010` means `tickDiff` and `txlVolmDecay` are always `0` in v6.0 traffic, and I confirmed
at source that the accessors return a literal `0` when their flag bit is unset — so a decoder that
never sign-extends, or that reads the wrong word, is **invisible** on every real log. Worse,
`shock_decode` accepts `flags = 0` (length 1) as well-formed, so an **all-zero 96-byte payload is
genuinely emittable**, not hypothetical. The synthetic corpus must therefore carry what production
never will, and the all-zero payload must be a named refusal rather than a shock of zeroes.

**Primary recommendation:** implement the admissibility predicate as an **all-`Integer`**
transcription of `volume_path.gms`'s `ellTest` (derived and verified below), install it as the
ninth refusal inside the existing pure `Gams.Argv.render_argv` so "refused before any subprocess" is
true by construction, and build the decoder as a `RealizedVol.Decode` sibling with an **exact**
96-byte length rule, per-word range checks, and an explicit all-zero refusal. Report the brief's
closed form as a finding; do not implement it, and do not implement it "with a tolerance".

---

## New Measurements

Every measurement below was executed on this machine on 2026-08-17. Nothing here is inherited.

### M1. The brief's closed form disagrees with the prover — by a factor of two

`ROADMAP.md` SC-2 requires: *"the Haskell verdict **AGREES with the GAMS prover's verdict on every
grid point** … A disagreement is a bug in one of them and fails the phase."* The brief's predicate
does not.

Measured, exact `Fraction` arithmetic, sweeping `δ*` across each pair's boundary ±3 pips:

| φ_X | φ_M | ρ | prover's min admissible `δ*` (pips) | brief's `2ρ/(1+ρ²)` (pips) | `ρ/(1+ρ²)` (pips) |
|---|---|---|---|---|---|
| 500 | 6000 | 12.0000 | **82 804** | 165 517.24 | 82 758.62 |
| 100 | 900 | 9.0000 | **109 769** | 219 512.20 | 109 756.10 |
| 1000 | 3000 | 3.0000 | **300 361** | 600 000.00 | 300 000.00 |
| 50 | 9950 | 199.0000 | **5 026** | 10 050.00 | 5 025.00 |
| 3000 | 3500 | 1.1667 | **495 865** | 988 235.29 | 494 117.65 |
| 700 | 800 | 1.1429 | **495 953** | 991 150.44 | 495 575.22 |
| 4000 | 5000 | 1.2500 | **490 075** | 975 609.76 | 487 804.88 |
| 250 | 1000 | 4.0000 | **235 364** | 470 588.24 | 235 294.12 |

- Over the 70 near-boundary points: the brief's predicate **disagrees with the prover on 36**;
  `ρ/(1+ρ²)` disagrees on **30** (it is the leading-order limit, right to ~45 pips at the fixture
  but still wrong at the boundary pip).
- False-refusal widths (the prover admits, the brief refuses):
  `φ=(500,6000)` → **82 713 pips**; `(1000,3000)` → **299 639**; `(700,800)` → **495 197**;
  `(2000,2100)` → **498 810**.
- **No closed form is exact.** Only the prover's own expression, evaluated exactly, agrees.

Two corollaries of the brief that do **not** survive:

1. *"no target is reachable unless ρ ≥ 2+√3 ≈ 3.732"* — **false**. Under the prover, `δ ≤ ½`
   requires `ρ/(1+ρ²) ≤ ½ ⟺ (ρ−1)² ≥ 0`, true for all ρ, tight only at ρ = 1. MEASURED:
   `(998, 2004)`, ρ = 2.008, is admissible at `δ* = 0.49`.
2. *"at δ\*=0.49 the boundary is ρ\* ≈ 3.8198, independent of the pool fee"* — the correct
   leading-order boundary at `δ* = 0.49` is `ρ ≈ 1.2235` (or its reciprocal 0.8174), and the exact
   prover boundary **does** carry the fee level, because `phiBar = φ_X+φ_M−φ_Xφ_M` contains the
   product term. Pool-fee independence is an approximation, not a fact.

What the brief got right and must be kept: **exact arithmetic over integer pips, never `Double`**;
the ratio-symmetry `ρ ↔ 1/ρ` (both the brief's form and the prover's are symmetric under swapping
the two legs, so the admissible set is two intervals — see Open Question 1); and the fixture pair
recomposing to `f = 6497` (independently confirmed, M3).

### M2. The prover's gate, read at source — and an exact all-`Integer` form

`model/mev_tax_model_one/volume_path.gms` (read in the **gams** worktree, lines 88–110):

```gams
abort$(txlVolumeRate >= PIPS) "txlVolumeRate must be < 100%";
abort$(phiXpips = phiMpips)
    "equal fees: r^phi = phi path-free forces dStar = phi/phiBar > 1/2, infeasible";
Scalar phiX;   phiX   = phiXpips / PIPS;
Scalar phiM;   phiM   = phiMpips / PIPS;
Scalar dStar;  dStar  = txlVolumeRate / PIPS;
Scalar phiBar; phiBar = 1 - (1-phiX)*(1-phiM);      <-- COMPOSED FEE, not the mean
Scalar dphi;   dphi   = phiM - phiX;                <-- FULL gap, not the semi-axis
ellTest = (sqr(phiBar)+sqr(dphi))*sqr(dStar) - (phiX+phiM)*phiBar*dStar + phiX*phiM;
abort$(ellTest > 0) "dStar outside the half-ellipse: no path realizes the joint target", ellTest;
```

**The independent derivation, which is why I say the prover is right.** §1's geometry gives step
rate `r_n = φ_X + (φ_M−φ_X)x_n` and step delta `d_n = √(x_n(1−x_n))`, so each step lies on the
half-ellipse centred `c = (φ_X+φ_M)/2` with semi-axes `A = (φ_M−φ_X)/2` and `B = ½`; a path is a
weighted mean, so the reachable set is the half-**disk**. The prover's `eRate`/`eDelta` equations
target the point `(r, d) = (φ̄·δ*, δ*)` with `φ̄` the *composed* fee. Disk membership is

```
((φ̄δ − c)/A)² + (δ/B)² ≤ 1
⟺ (φ̄² + 4A²)δ² − 2cφ̄δ + (c² − A²) ≤ 0
⟺ (φ̄² + (φ_M−φ_X)²)δ² − (φ_X+φ_M)φ̄δ + φ_Xφ_M ≤ 0      [ 4A² = (φ_M−φ_X)², c²−A² = φ_Xφ_M ]
```

— the prover's `ellTest`, exactly. The `VOLUME_PATH.md` §1.3 prose never defines the symbol `Δφ`,
which is where the brief's halving entered.

**Confirmation from §1.2.** At `φ_X = φ_M = φ` the discriminant vanishes and the single root is
`δ = (φ_X+φ_M)/(2φ̄) = φ/φ̄ = 1/(2−φ)`. MEASURED at 3000 pips: **0.5007511266900351 > ½** — which is
*literally* §1.2's sentence "forcing `dStar = phi/phiBar > 1/2`". The brief's reading gives the root
`δ = 1`, which is also `> ½` but is not §1.2's number.

**The all-`Integer` form.** Let `D = 10⁶`, `x, m, d` the integer pips, and
`Pn = D(x+m) − xm` (an integer). Then

```
E := Pn²d² + D²(m−x)²d² − D²(x+m)·Pn·d + D⁴·x·m        and      E = D⁶ · ellTest
admissible  ⟺  E ≤ 0
```

**VERIFIED on 20 000 random triples** `(x, m ∈ [1,20000], d ∈ [0,999999])`: the sign test and the
scaled value agree with the `Fraction` evaluation on every one. Fixture `E(500, 6000, 490000) =
−2.950567391·10²⁹ ≤ 0` → admitted, matching `ellTest = −2.950567391·10⁻⁷`. **No `Rational` is needed
at all** — `Integer` suffices, which removes `Data.Ratio` from the path and makes "no floating value
appears here" a stronger statement than SC-2 asks for.

### M3. Exact integer-pip splits are RARE, and every canonical fee tier has none

Level constraint over integer pips: `(D−φ_X)(D−φ_M) = D(D−f)`, i.e. a divisor of `N = D(D−f)` in the
open window `(D−f, D)`. Measured by full factorisation (smallest-prime-factor sieve to 10⁶):

| pool fee `f` (pips) | exact integer-pip pairs | prover-admissible at `δ* = 0.49` |
|---|---|---|
| 100 (0.01 %) | **0** | 0 |
| 500 (0.05 %) | **0** | 0 |
| 3000 (0.30 %) | **0** | 0 |
| 10000 (1.00 %) | **0** | 0 |
| **6497 (the fixture)** | **2** — `(500, 6000)` and `(6000, 500)` | 2 |

Over `f ∈ [1, 20000]`: **987 (4.93 %)** admit any exact pair; **857 (4.29 %)** admit one the prover
accepts. The fixture recomposes exactly because `10⁶ ∣ 500·6000`:
`999500 × 994000 = 993 503 000 000 = 10⁶ × 993503`, so `f = 6497` pips — **independently confirmed**.

**Consequence for FEE-01 as written.** "Exactly" is achievable for 5 % of pool fees and for none of
the standard tiers. This is not a defect to fix; it is a property of the integer grid, and SC-1
already provides for it ("a rounding rule pinned in writing … the derived pips (not `f`) are what
reach the key"). But it must be a **first-class, asserted, recorded** fact, not a silent rounding.

### M4. The rounding residual is tiny, and the admissible band is wide

Rule measured: choose `φ_X = x`, take `m` = the nearest integer to the exact solution
`D(f−x)/(D−x)`, and record the exact residual `compose(x,m) − f` where
`compose(x,m) = x + m − xm/D`.

| `f` | admissible x-band at `δ* = 0.49` | best exact residual (pips) | best pair |
|---|---|---|---|
| 100 | **88** values, x ∈ [1, 99] | −9.9·10⁻⁵ | (1, 99), ρ = 99 |
| 500 | **448** values | −4.99·10⁻⁴ | (1, 499) |
| 3000 | **2 686** values | **+8·10⁻⁶** | (998, 2004), ρ = 2.008 |
| 10000 | **8 869** values | +1.0·10⁻⁴ | (101, 9900) |
| 6497 | **5 790** values | **0 (exact)** | (500, 6000), ρ = 12 — 2 exact members |
| 2500 | **2 240** values | −5.0·10⁻⁴ | (500, 2001) |

Two facts the plans need:

- **Residual headroom is ~3 orders of magnitude.** SC-1's alarm is "breaks the level constraint by
  a pip"; the worst best-residual measured is 5·10⁻⁴ pip. The guard therefore cannot fire on real
  data — its firing input must be a **deliberately broken rounder** (floor instead of nearest, or
  `m ± 1`), which is exactly how it should be stated.
- **The band is large, so the seed is load-bearing** — but a band of size ≤ 1 makes FEE-04's
  different-seed test vacuous, and empty bands exist (any `δ*` below every bound). Band size is an
  assertion, with its own firing input.

### M5. Exact-vs-`Double` sign margin at the boundary pip

GAMS evaluates `ellTest` in **double**; Haskell will evaluate exactly. They can only disagree where
the exact value is inside double's noise (~10⁻²² absolute for terms of this magnitude). Measured
`|ellTest|` at the boundary pip and its neighbours:

| φ_X, φ_M | boundary pip | `|ellTest|` at pip−1 / pip / pip+1 |
|---|---|---|
| 500, 6000 | 82 804 | 4.99e−12 / 2.52e−11 / 5.55e−11 |
| 100, 900 | 109 769 | 9.31e−14 / 5.47e−13 / 1.19e−12 |
| 700, 800 | 495 953 | 2.97e−15 / 6.15e−15 / 1.53e−14 |
| **3, 7** | 362 071 | **4.42e−18** / 1.16e−17 / 2.76e−17 |

Smallest margin seen: **4.4·10⁻¹⁸ ≈ 4·10⁴ × the noise floor**. So at realistic fee magnitudes the
exact and double verdicts cannot differ — **but the margin scales with the fee squared**, and at
single-digit-pip fees it is within five orders of the floor. Recommendation: keep the differential
grid at `φ ≥ 100` pips, and record the exact `|E|` for every grid point so a shrinking margin is
visible rather than inferred.

### M6. topic0 computed independently; the superseded selector is real and is a decoy

Executed here with `cast` (foundry, `/home/jmsbpp/.foundry/bin/cast`):

```
cast keccak "Shock(address,int24,uint24,uint24)"
  = 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64      <- topic0
cast sig    "next(address,uint160,int24,uint24,uint24)"
  = 0xd3827b0b                                                              <- the CALL's selector
```

Both reproduce the values in the brief. The second is **not wrong, it is the wrong artifact** — it
is the selector of the function that *causes* the event, and its first 4 bytes coincide with nothing
in a log. It makes an excellent **negative** fixture: a log whose topic0 is `0xd3827b0b` left-padded
to 32 bytes must not decode.

### M7. The emitter, read at source — and the trap confirmed structurally

`src/models/mev_tax_model_one/libraries/ShockLib.plk` @ `341e409` (plank worktree):

```
const SHOCK_EVENT_TOPIC0 = 0x21b0e4f8…55987d64;
const shock_emit = fn (comptime R: type, pool: u256, s: Shock(R)) void {
    @mstore32(buf,       shock_tick_diff(R, s));
    @mstore32(buf +% 32, shock_txl_volm_norm_rate(R, s));
    @mstore32(buf +% 64, shock_txl_volm_decay(R, s));
    @evm_log2(buf, 96, SHOCK_EVENT_TOPIC0, pool);
```

`@evm_log2` ⇒ **exactly two topics**; `96` ⇒ **exactly three data words**, in order
`[tickDiff, txlVolmNormRate, txlVolmDecay]`. This is the E1/E3/E5 shape one field narrower.

`Shock.plk` (same commit) settles four things a decoder would otherwise have to guess:

1. **`shock_tick_diff` ends in `@evm_signextend(2, raw)`** — the word on the wire is sign-extended
   to the full 256 bits, so `RealizedVol.Decode.signed_word` is **exactly** the right conversion and
   a 24-bit mask would be wrong. Same rule as E3's three signed fields.
2. **`shock_txl_volm_norm_rate` and `shock_txl_volm_decay` end in `& MASK_U24`** — unsigned,
   range `[0, 2²⁴)`. `signed_word` on them would be a *silent* bug (u24 never reaches 2²⁵⁵).
3. **Every accessor returns a literal `0` when its flag bit is unset.** With issue #28's
   `flags = 0b010`, words 0 and 2 are structurally zero on every production log — the trap, confirmed
   at source rather than taken on trust.
4. **`flags = 0` is well-formed**: `shock_decode` requires `buf.length == 1 + 3k`, and `k = 0` with
   length 1 passes. So an **all-zero 96-byte payload is emittable**, which upgrades SC-5's all-zero
   rejection from a hypothetical to a real firing input with a named provenance.

### M8. `ShockLib.plk` is not in this worktree — the E1 signature-parse idiom is unavailable

- `ls src/models/mev_tax_model_one/` → **absent**. `ROADMAP.md:1093` records the same measurement:
  `git ls-tree -r origin/develop | grep -c 'models/mev_tax_model_one'` = **0**; the tree is on
  `exp/mev_tax_model_one` only, 153 commits ahead of develop.
- Therefore the RPIN-04 idiom — parse the signature out of a local `.plk`, recompute topic0, compare
  to the generated pin — **cannot be used**. `generate-pins.sh` iterates local interface files, so
  adding `"Shock"` to `expected_topic_pins` (asserted in **both** directions, `Main.hs:675`) would
  redden immediately.
- **The blob IS reachable from this worktree**: `git show 341e409:src/models/…/ShockLib.plk`
  succeeds (shared object store). Usable by a Tier-C capture; **not** usable by a Tier-A check,
  which would then depend on an unmerged commit surviving `gc`/clone.
- Precedent that fits: `offchain/rig/{import-paths.txt,import-ref.txt,verify-import.sh,check-upstream.sh}`
  — the cross-branch source-of-truth machinery. `ShockLib.plk` is not among the 37 imported paths.

### M9. `Gams.Argv` is already the refusal gate — and it admits `txlVolumeRate = 0`

`offchain/lib/Gams/Argv.hs` is **pure** (imports only `Data.Char`), and `render_argv` performs
**eight refusals before building a single token**, including `distinct_fees`, which already refuses
`φ_X == φ_M` citing §1.2 — FEE-03's structural half is *already shipped*.

But: `in_range "txlVolumeRate" … 0 999999` **admits 0**, while every other field demands ≥ 1 with the
written reason that an absent value is not a shock. A `δ* = 0` shock therefore renders today.

**The ellipse refusal closes that hole for free.** `E(x, m, 0) = D⁴xm > 0` for `x, m ≥ 1`, so
`δ* = 0` is inadmissible under the prover's own gate. Installing the admissibility check as the
ninth refusal in `render_argv` subsumes the zero hole rather than adding a second bound that can
drift from it.

### M10. Baseline and floors, re-measured cold

| Quantity | Value | How |
|---|---|---|
| `cabal test` | **151/151 passed, exit 0**, wall **2 m 29.5 s** (budget 900 s) | run to completion today |
| `purge_file_floor` | **59** against exactly **59** files — **zero slack** | `find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) \| wc -l` |
| `credential_scan_floor` | **68** against exactly **68** — **zero slack** | same with `-o -name '*.json'` |
| extension census under `offchain/` | `hs 47, sh 9, json 9, sql 3, md 3, txt 2` | `find … \| sed 's/.*\.//' \| sort \| uniq -c` |
| DB-free grep | **0** | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` |
| `sentinel_pair_floor` | 3828 | source, `Main.hs:6077` |
| `artifact_field_floors` | 6 artifacts; newest `gams-conformance.json` = **76** leaves | `Main.hs:6115` |

The brief's inherited floors (59 / 68) were correct this time. They were still re-measured, because
two phase-24 summaries misreported them and the rule is the pair moves together.

### M11. GAMS-free does **not** forbid `Gams.Run` — so "never spawned" is observable in Tier B

`gams_free_pattern` (`Main.hs:10899`) is exactly three concatenated tokens:
`Gams\.Invoke`, `CFMM_REQUIRE_GAMS`, `/usr/gams`. `Main.hs` **already imports `Gams.Run`**
(`run_prover`, `RunRequest`, `ProverOutcome`) and phase 24 drove five Tier-B checks against
shell stubs it wrote itself.

So FEE-03's "verified by a check that **fails if the solver is invoked at all**" can be an
**observation**, not an argument: a stub that `touch`es a marker file when executed, driven through
the real assemble → `run_prover` path, with the marker asserted **absent** after an inadmissible
request. The positive control — an admissible request producing the marker — is mandatory and must
be evaluated **first**; "marker absent" is otherwise satisfied by a harness that never ran anything,
which is this repository's entire defect class.

### M12. The purge pattern makes the topic0 unspellable in the code it is for

`purge_pattern` = `0x[0-9a-fA-F]{40}\b | 0x[0-9a-fA-F]{64}\b | 0x[0-9a-fA-F]{8}\b`, over
`.hs`/`.sh`/`.sql` under `offchain/`. Both the topic0 (64 hex) and the superseded selector (8 hex)
are matched. Consequences, non-negotiable:

- topic0 must be **computed** (`topic0_of "Shock(address,int24,uint24,uint24)"`) or, as ground
  truth, written **bare** without `0x` — the existing `ground_truth` block (`Main.hs:480`) says so in
  its own haddock and is where the row belongs.
- the decoy selector likewise: build it, or write it bare.
- **This will be prose-in-a-grep's-blast-radius instance 19.** Every haddock in the new modules that
  wants to *explain* the topic0 must describe it without spelling it. Eighteen prior instances; the
  answer has never changed.

---

## Corrections of record to the phase's success criteria

### Correction 1 — SC-2's predicate is wrong and must be replaced by the prover's own

ROADMAP SC-2 states the predicate as `δ* ≥ 2ρ/(1+ρ²)`, `ρ = φ_M/φ_X`, *and* requires agreement with
the prover on every grid point. **These two clauses contradict each other** (M1: 36/70
disagreements; up to 498 810 pips of false refusal). The agreement clause is the load-bearing one —
it is the falsifiable claim — so the predicate clause yields. FEE-02 is implemented as the exact
integer transcription `E ≤ 0` of `volume_path.gms:100–108` (M2). The closed form survives only as a
documented approximation with its measured error, or not at all.

`REQUIREMENTS.md`'s FEE-02 text carries the same formula and needs the same correction at plan time.

### Correction 2 — SC-1's "exactly" is achievable for 4.93 % of fees

Not a defect: SC-1 already says "under a rounding rule pinned in writing". But the plan must state
which of two designs it takes, because they differ in *which pools are servable* (M3):

- **(A) exact-or-refuse** — refuse unless a divisor pair exists. Honours "exactly" literally;
  **refuses every canonical Uniswap tier**. Not recommended alone.
- **(B) round-and-report** *(recommended)* — nearest-`m`, record the exact realized fee
  `compose(φ_X,φ_M)` and the exact residual as first-class fields, refuse if `|residual| ≥ 1` pip
  (unreachable on real data — headroom ~10³, M4), and mark whether the pair is exact. The derived
  pips are what reach GAMS and the key, so the model is solved for the schedule it was actually
  given; the residual is an **off-chain** modelling error the prover cannot see, which is precisely
  why it must be recorded rather than absorbed.

### Correction 3 — SC-5 is superseded (already recorded) and needs one addition

The roadmap's superseding note is correct and complete except for one thing it could not know: M7
shows the all-zero payload is not merely "the shape an absent subject takes" but a **legally
emittable log** (`flags = 0`). State it that way — a refusal with a provenance is stronger than a
refusal with a rationale.

---

## Standard Stack

### Core — **+0 packages**, measured by inspection of the existing `build-depends`

| Library | Version | Purpose | Why |
|---|---|---|---|
| `base` | 4.20.2.0 | `Integer` arithmetic, `Data.Bits`, `Data.Char` | The whole splitter. `Integer` is unbounded and locale-free; M2's `E` needs nothing else |
| `bytestring` | already a dep | 32-byte word handling | `RealizedVol.Decode` idiom |
| `memory` (`Data.ByteArray.HexString`) | already a dep | `HexString`/`toBytes` for topics and data | same |
| `web3-ethereum` (`Network.Ethereum.Api.Types.Change`) | already a dep | the log type the decoder consumes | `synthetic_log` (`Main.hs:1589`) already builds these by hand |
| `web3-crypto` (`Crypto.Ethereum.Utils.keccak256`) | already a dep | `topic0_of` (`Main.hs:330`) | never hand-roll keccak; note it is **not** SHA3-256 |
| `mwc-random` | already a dep via `Driver.Seed` | optional seed→index selection in `ST` | only if the pure-ST route is chosen |

**Do not add `Data.Ratio`.** M2's integer form removes the need; `Rational` would also invite a
`fromRational`/`realToFrac` on the path, which is what the float scan exists to forbid.

**Version verification.** No package is added, so no registry check applies. The build plan is
whatever `cabal build --enable-tests -j all` currently resolves (158 packages at 24-02's
measurement); the phase's `.cabal` comment discipline (lines 94–128) requires the plan to state
`Downloading = 0` as a **confirmed** observation, not an estimate.

### Not in this phase

Postgres, aeson, the RPC providers, `process` beyond the existing Tier-B stub idiom. The splitter is
arithmetic; the decoder is a pure function of a `Change`.

---

## Architecture Patterns

### Module layout — role-named, one IO edge per area (the house convention)

```
offchain/lib/
├── Fee/Split.hs        # PURE. compose, the integer ellipse predicate, the band, the seeded pick,
│                       # the refusal type. No IO, no Double, no Rational.
├── Chain/Shock.hs      # PURE. ShockEvent + decode_shock. The RealizedVol.Decode sibling.
└── Gams/Argv.hs        # EXTENDED: the ninth refusal (admissibility), reusing Fee.Split's predicate
offchain/app/
└── FeeSplitConformance.hs   # the Tier-C capture driver (the only thing that may name the solver)
offchain/rig/
├── capture-fee-split.sh     # capture-gams-conformance.sh idiom
└── fee-split-conformance.json
```

`Chain/` vs `Shock/` is discretionary; `Chain.Shock` reads better beside `CHAIN-04` and leaves room
for `Chain.Pool` in Phase 27.

### Pattern 1: the admissibility predicate is a transcription, not a derivation

```haskell
-- | volume_path.gms:100-108, transcribed. Multiplied through by D^6 so every operand is an
-- Integer: E = D^6 * ellTest, and the prover aborts when ellTest > 0.
--
-- VERIFIED against the Rational evaluation on 20,000 random (x, m, d) triples: same sign, and
-- E == D^6 * ellTest as a value.
ellipse_test :: Integer -> Integer -> Integer -> Integer   -- phiXpips -> phiMpips -> dStarPips -> E
ellipse_test x m d =
  pn * pn * d * d
    + dd * (m - x) * (m - x) * d * d
    - dd * (x + m) * pn * d
    + dd * dd * x * m
  where
    dd = pips_denominator * pips_denominator          -- D^2
    pn = pips_denominator * (x + m) - x * m           -- D * phiBar

is_admissible :: Integer -> Integer -> Integer -> Bool
is_admissible x m d = ellipse_test x m d <= 0
```

Two properties worth stating in the haddock, because they are what make the check non-vacuous: the
`x == m` case has a double root at `δ = (x+m)·D/(2·pn)` which is `> D/2` (MEASURED 0.50075 at 3000
pips, recovering §1.2's own number), and `ellipse_test x m 0 = D⁴xm > 0`, so `δ* = 0` is refused by
the same expression that refuses everything else.

### Pattern 2: the level constraint, exactly, over integers

```haskell
-- | The pool fee that (x, m) actually compose to, as an exact rational scaled by D:
--   compose_scaled x m = D * (x + m) - x*m  = D * f'   (so f' is exact, integer-scaled)
-- f' == f exactly  <=>  D divides x*m.  MEASURED: true for 4.93% of f in [1,20000], and for
-- NONE of 100/500/3000/10000 pips.
compose_scaled :: Integer -> Integer -> Integer
compose_scaled x m = pips_denominator * (x + m) - x * m

residual_scaled :: Integer -> Integer -> Integer -> Integer   -- f_pips -> x -> m -> D*(f' - f)
residual_scaled f x m = compose_scaled x m - pips_denominator * f
```

Everything downstream (the "under a pip" guard, the reported residual, the exactness flag) is an
`Integer` comparison against `pips_denominator`. No division, no rounding, no tolerance.

### Pattern 3: the refusal is a value that names its boundary

```haskell
data SplitRefusal
  = EqualFees      { sr_phi :: Integer }                                   -- VOLUME_PATH.md 1.2
  | OutsideEllipse { sr_x, sr_m, sr_dstar, sr_E, sr_boundary_pips :: Integer }
  | EmptyBand      { sr_fee, sr_dstar, sr_band_size :: Integer }
  | ResidualTooLarge { sr_residual_scaled :: Integer }
  deriving (Eq, Show)
```

`sr_boundary_pips` is the *minimum admissible `δ*` for this pair*, computed by bisection on the
integer predicate — that is FEE-03's "the boundary value in the message", and it is a number the
operator can act on, not a restatement of the failure.

### Pattern 4: "refused before any subprocess" is a property of the gate, not of an ordering

Install the predicate as the **ninth refusal inside `render_argv`**. `Gams.Run.run_prover` cannot
build a command line without it, so an inadmissible shock has no representation that reaches an
`execve`. This is the same move as phase 24's `Aborted` carrying no artifact — the compiler and the
type do the work an ordering comment would only assert.

Then observe it anyway (M11): the marker-stub Tier-B check. Structural argument **and** observation;
neither alone is this project's standard.

### Pattern 5: the decoder — the E3/E5 sibling, with one deliberate divergence

```haskell
data ShockEvent = ShockEvent
  { se_pool          :: Integer   -- topic 1, indexed address (must be < 2^160 and /= 0)
  , se_tick_diff     :: Integer   -- data word 0, int24, SIGN-EXTENDED on the wire
  , se_norm_rate     :: Integer   -- data word 1, uint24 pips  -> GAMS txlVolumeRate
  , se_txl_decay     :: Integer   -- data word 2, uint24 pips  -> RECORDED, never sent to GAMS
  } deriving (Eq, Show)

decode_shock :: Integer -> Change -> Either ShockDecodeError ShockEvent
```

Divergences from `RealizedVol.Decode`, each deliberate:

1. **`Either`, not `Maybe`.** SC-5 distinguishes four rejection reasons; `Nothing` collapses them
   and makes the negative fixtures indistinguishable from each other.
2. **`BS.length payload == 96`, not `>= 96`.** The `>=` in E1/E3/E5 accepts a *longer* payload
   silently; SC-5 requires "wrong data length" to be rejected. `@evm_log2(buf, 96, …)` emits exactly
   96, and a 4-field event would carry a different topic0, so exact is strictly stronger and loses
   nothing.
3. **Per-word range checks** — `se_tick_diff ∈ [−2²³, 2²³)`, the two rates `∈ [0, 2²⁴)`. This is the
   only guard that catches a *garbage* 96-byte payload or a transposed word order, and it is
   derivable from `Shock.plk`'s own masks (M7).
4. **An explicit all-zero refusal** on the three data words together (M7: `flags = 0` emits exactly
   this). Note it does **not** subsume `se_norm_rate == 0` with a nonzero `tickDiff` — that is a
   semantic refusal and lives at the assembly boundary, where `render_argv`'s ellipse test already
   refuses `δ* = 0` (M9).

`expected_topic0` stays an **argument**, as in E1/E3/E5, for the reason `VolOrder/Decode.hs:32-45`
gives: a wrong topic0 does not look wrong, it simply matches nothing forever.

### Anti-patterns

- **Any closed form for admissibility.** M1 measured 36/70 disagreements for the best-known one.
- **`Rational`, `Double`, `sqrt`, `realToFrac` anywhere on the fee path.** The integer form removes
  every excuse; the existing float scan (`aeson_storage_path`, extended at 24-02) should be extended
  to cover `Fee/Split.hs` in the same commit that creates it — 24-02's finding was that a scan whose
  scope failed to grow is worse than no scan.
- **Reading `volume_path.gms`'s abort *name* to decide a verdict.** Exit 3 is `abort$`, `execerror`
  and the ellipse rejection alike (24-RESEARCH M4, guard 15), and `gams_verdict_ignores_the_streams`
  forbids log-text matching in `Gams/{Exit,Invoke}.hs`. Log text may be recorded as **evidence** in
  the Tier-C capture — never consulted by a verdict, and never from inside those two modules.
- **A `>=`-style length guard on the decoder.** See Pattern 5.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| keccak-256 of a signature | a hash | `Crypto.Ethereum.Utils.keccak256` via `topic0_of` (`Main.hs:330`) | Keccak-256 ≠ SHA3-256; the repo already made this mistake's opposite explicit |
| a synthetic log | an ad-hoc record | `synthetic_log :: [HexString] -> [Integer] -> Change` (`Main.hs:1589`) + `word32be`/`hexstring_of` | Already built for RPIN-04, already chain-free, already purge-safe (built by shifting, never from a hex string) |
| two's-complement conversion | a mask | `RealizedVol.Decode.signed_word` | Exported; the emitter sign-extends to the full word (M7), so the *same* function is correct here |
| big-endian word extraction | slicing | `VolOrder.Decode.data_word` / `be_integer` / `hex_to_integer` | And note `BS.drop` past the end yields `""` whose value is **0** — the documented reason the length guard exists at all |
| a seed contract | a new env var | `Driver.Seed` (`RIG_SEED`, `Word32`, refuses a malformed value rather than drawing) | Its haddock already argues why a typo'd seed must not silently become a random one |
| exact rational comparison | `Rational` | the integer form `E ≤ 0` (M2) | Verified equivalent on 20 000 triples; keeps `Data.Ratio` off the path |
| a bespoke "deliberately wrong" check | one | `sentinel_falsification_harness` + `swept_artifacts` | Positive and negative controls already built and proven |

---

## Common Pitfalls

### Pitfall A (owned, and the phase's headline): the settled closed form is not the prover's gate

**What goes wrong:** the plan implements `δ* ≥ 2ρ/(1+ρ²)`, the unit tests pass (it is a correct
implementation of *something*), and the Tier-C differential then disagrees with GAMS on a third of
the boundary grid. **Why it happens:** `VOLUME_PATH.md` §1.3 never defines `Δφ`, and §1's ellipse
sentence supplies a semi-axis that looks like it. **How to avoid:** transcribe
`volume_path.gms:100–108`; keep the derivation in M2 in the haddock so the next reader does not
re-halve it. **Warning sign:** a bound that is ratio-only. The prover's is not (it carries `φ_Xφ_M`).

### Pitfall B (owned): a decoder exercised only on in-scope events cannot fail

`tickDiff` and `txlVolmDecay` are structurally `0` in v6.0 (M7). A decoder that never sign-extends,
reads the wrong word, or returns a default is green on every real log. **Avoid:** the corpus carries
a **negative** `tickDiff` and a nonzero `txlVolmDecay`, asserted as a property of the corpus itself
(a SET over member names plus "at least one member has `tickDiff < 0`"), so deleting the
discriminating member reddens rather than shrinking a count. This is `tickSpacing = 0` (`Main.hs:1534`)
arriving pre-guaranteed by the emitter.

### Pitfall C (owned): a feasibility predicate whose refusal branch is never exercised

A grid that only contains admissible points proves the predicate returns `True`. **Avoid:** assert
the grid contains **both** verdicts and that its boundary triples are the *exact* roots recomputed in
Haskell (boundary pip, pip−1, pip+1), and assert the counts of each verdict are ≥ 1 in both
directions. A one-sided grid is a phase failure, not a passing test.

### Pitfall D (owned): FEE-04's seed can be decorative in two distinct ways

(i) the selector ignores the seed; (ii) the band has one member, so every seed agrees. Both produce
a green same-seed test. **Avoid:** assert `|{ρ(s) : s ∈ pinned seeds}| ≥ 2` **and** `band_size > 1`,
each with its own firing input (a selector returning `head band`; a `(f, δ*)` with an empty band).

### Pitfall E (inherited, instance 19): prose inside a grep's blast radius

The new modules must *explain* a 64-hex topic0 and an 8-hex selector inside files scanned for
exactly those shapes (M12). Every prior instance was resolved by moving the prose, never by relaxing
the pattern.

### Pitfall F (inherited): a scan whose scope failed to grow

`aeson_storage_path` covers `offchain/lib/{Store,Gams}/`. `Fee/` and `Chain/` are new directories;
the both-directions coverage check (24-RESEARCH guard 34) must be extended **in the same commit** that
creates them, or the float/aeson scan silently exempts the two modules that most need it.

### Pitfall G (new, phase-local): the exactness claim can be inverted silently

"An exact split exists for `f`" and "we rounded" are both true statements about different fees.
A check that asserts only one of them passes on the fixture forever. **Avoid:** assert **both**
directions with MEASURED constants — `f = 6497` has exactly 2 exact pairs, `f = 3000` has 0 — so a
splitter that stopped searching, or one that started claiming exactness, reddens.

---

## Code Examples

### Recomputing topic0 in the test, from the signature string

```haskell
-- Ground truth goes in `ground_truth` (Main.hs:480), value written BARE -- the block's own
-- haddock explains that the \b-anchored purge patterns would otherwise match this file.
--   ("topic0", "Shock(address,int24,uint24,uint24)", "21b0e4f8...55987d64")
shock_topic0 :: Either String Integer
shock_topic0 = do
  (sig, want) <- truth_for "Shock"
  let computed = to_hex (topic0_of sig)
  if computed == want then Right (be_integer (topic0_of sig))
                      else Left ("keccak of " ++ sig ++ " gave " ++ computed)
```

### A synthetic log carrying what production never emits

```haskell
-- tickDiff = -200 sign-extended to 256 bits; decay nonzero. Neither occurs in v6.0 traffic.
let neg_tick = 2 ^ (256 :: Int) - 200
    log_ok   = synthetic_log [hexstring_of t0, hexstring_of pool_addr]
                             [neg_tick, 490000, 7]
    log_zero = synthetic_log [hexstring_of t0, hexstring_of pool_addr] [0, 0, 0]
    log_long = synthetic_log [hexstring_of t0, hexstring_of pool_addr] [0, 490000, 0, 0]
-- decode_shock t0 log_ok   == Right (ShockEvent pool_addr (-200) 490000 7)
-- decode_shock t0 log_zero == Left AllZeroPayload
-- decode_shock t0 log_long == Left (WrongDataLength 128)     -- the `>=` precedent would ACCEPT this
```

### The differential grid record (one row of the Tier-C artifact)

```json
{ "phiXpips": 500, "phiMpips": 6000, "txlVolumeRate": 82803,
  "haskell_E": "24960...", "haskell_admits": false,
  "gams_exit": 3, "gams_artifact_present": false, "gams_admits": false,
  "control_exit": 0, "control_artifact_present": true }
```

`control_*` is the same fee pair re-run at a comfortably interior `δ*`. Without it, an abort at the
boundary is not attributable to the ellipse gate — exit 3 covers `abort$`, `execerror` and every
named abort alike (24-RESEARCH guard 15), and §4 forbids reading the log to decide. **The control is
what makes the differential a differential.**

---

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name :: String, check_run :: IO (Either String ()) }` (`offchain/test/Main.hs:512`), `guarded` at `:518`, `pure_check` at `:525` |
| Config file | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` |
| Registration point | `core_checks :: IO [Check]` (`offchain/test/Main.hs:11042`). **A check not in this list does not exist** and the sentinel harness cannot re-run it |
| Quick run command | `cabal build --enable-tests -j all` — `--enable-tests` is load-bearing; **the bare `cabal build -j all` is VACUOUS and must never appear** |
| Full suite command | `cabal test` |
| Hard gates | zero `-Wall` warnings under `offchain/`; suite **DB-free** (grep = 0, re-measured) **and GAMS-free** (`gams_free_pattern`, `Main.hs:10899` — note it does **not** forbid `Gams.Run`) |
| Baseline | **151/151, exit 0, wall 149.5 s** — RE-MEASURED COLD today, budget 900 s |
| New test file | **None.** Phase 26 extends `offchain/test/Main.hs`, as 23 and 24 did |

**Tiers for this phase:**

| Tier | What runs | Needs live GAMS? |
|---|---|---|
| **A** | pure functions and source scans — the integer predicate, `compose`, the band, the seeded pick, the decoder over synthetic logs, the float/IO scans, the topic0 recomputation | **No** |
| **B** | real subprocesses inside `cabal test` against **shell stubs the check writes itself** — the marker stub proving no spawn for an inadmissible shock, driven through `Gams.Run.run_prover` | **No** |
| **C** | assertions over the committed `offchain/rig/fee-split-conformance.json`, produced out of band by `offchain/rig/capture-fee-split.sh` | **Only for the capture** |

**Exactly one clause of one requirement is Tier C: FEE-02's "agrees with the GAMS prover".** Every
other clause of every other requirement is Tier A or B. The capture never runs inside `cabal test`.

### Requirement → Test Map

| Req | Check name | Lives in | Tier | The input that makes it FAIL | Needs GAMS? |
|---|---|---|---|---|---|
| **FEE-01** | `compose_is_the_exact_level_constraint` | `Fee.Split` + `pure_check` | A | Dropping the `−xm` term from `compose_scaled` — at the fixture that turns 6497 into 6500; or any pair whose recorded realized fee ≠ `compose_scaled` recomputed | No |
| **FEE-01** | `the_fixture_pair_recomposes_to_6497_pips` | `pure_check` | A | `compose(500, 6000) ≠ 6497` exactly (MEASURED: `999500 × 994000 = 993 503 000 000`). An equality on `Integer`s — no tolerance can absorb it | No |
| **FEE-01** | `exact_split_existence_is_measured_in_both_directions` | `pure_check` | A | Claiming an exact pair for `f = 3000` (MEASURED **0**), or failing to find both for `f = 6497` (MEASURED **2**: `(500,6000)`, `(6000,500)`). A one-directional assertion passes on a splitter that stopped searching | No |
| **FEE-01** | `rounding_residual_is_recorded_and_under_a_pip` | `Fee.Split` + `pure_check` | A | A rounder that floors where nearest differs, or `m ± 1`; or a residual field absent from the record. Guard fires at `\|residual_scaled\| ≥ D`; real headroom MEASURED at ~10³ | No |
| **FEE-01** | `the_derived_pips_are_what_reach_the_argv` | `Gams.Argv` + `pure_check` | A | `render_argv` emitting `f` or a re-derived φ instead of the recorded pair — the tokens must equal the split's own fields | No |
| **FEE-02** | `admissibility_is_the_provers_own_ellipse_test` | `Fee.Split` + `pure_check` | A | An implementation with `phiBar = (x+m)/2` or `dphi = (m−x)/2`. MEASURED: disagrees on **36 of 70** near-boundary points and falsely refuses **82 713 pips** at the fixture | No |
| **FEE-02** | `the_integer_form_equals_the_rational_evaluation` | `pure_check` | A | Any triple where `E ≤ 0` and the `Rational` `ellTest ≤ 0` disagree, over a pinned corpus incl. the four boundary pairs. VERIFIED on 20 000 random triples today | No |
| **FEE-02** | `no_floating_value_is_on_the_fee_path` | `Main.hs`, `aeson_storage_path` scan **extended** | A | `Double`, `sqrt`, `realToFrac`, `fromRational`, `Data.Ratio` appearing in `Fee/Split.hs`; **and** `Fee/Split.hs` missing from the scan's file list (the both-directions arm) | No |
| **FEE-02** | `haskell_and_gams_agree_on_every_grid_point` | `Main.hs` over `fee-split-conformance.json` | **C** | Any recorded grid row whose `gams_admits` ≠ the Haskell verdict recomputed in-suite from `(x, m, d)`; or a row whose `control_exit ≠ 0` (the abort is then unattributed); or **fewer than one** of each verdict in the grid | Capture only |
| **FEE-02** | `the_grid_brackets_each_boundary_by_one_pip` | `Main.hs` over the artifact | C | The recorded boundary pip ≠ the pip found by bisection on the integer predicate; or a pair present without its `±1` neighbours. MEASURED boundaries: `(500,6000)→82 804`, `(100,900)→109 769`, `(1000,3000)→300 361` | Capture only |
| **FEE-03** | `an_inadmissible_shock_cannot_be_rendered_to_argv` | `Gams.Argv` + `pure_check` | A | `render_argv` returning `Right` for `(φ_X=500, φ_M=6000, δ*=82 803)` — one pip below the MEASURED boundary | No |
| **FEE-03** | `the_refusal_names_the_boundary_and_the_pair` | `pure_check` | A | A refusal message that omits `sr_boundary_pips`, or that reports a boundary not equal to the bisected root. "Infeasible" with no number is the failure this check exists for | No |
| **FEE-03** | `equal_fees_are_refused_in_haskell_with_the_1_2_diagnosis` | `Gams.Argv` + `pure_check` | A | Deleting `distinct_fees`. Note the ellipse test **also** refuses `x == m` (MEASURED single root 0.50075 > ½ at 3000 pips), so the count survives — the check must assert the message names §1.2, else the specific diagnosis is lost while the refusal remains | No |
| **FEE-03** | `no_subprocess_is_spawned_for_an_inadmissible_shock` | `Main.hs`, marker stub through `Gams.Run.run_prover` | **B** | The marker file existing after an inadmissible request. **POSITIVE CONTROL ORDERED FIRST**: an admissible request MUST create it — otherwise "absent" is satisfied by a harness that ran nothing | No |
| **FEE-03** | `the_splitter_holds_no_IO_and_names_no_process` | `Main.hs`, `sc3_literal_purge` idiom + positive control | A | `System.Process`, `IO`, `unsafePerformIO`, `readProcess` appearing in `Fee/Split.hs`. The pattern must be SHOWN matching a seeded bait file | No |
| **FEE-04** | `the_seeded_pick_is_a_pure_function_of_seed_and_band` | `Fee.Split` + `pure_check` | A | Two evaluations with the same seed and band yielding different ρ (impurity, or a `GenIO` leaking into the path) | No |
| **FEE-04** | `a_different_seed_produces_a_different_rho` | `pure_check` | A | A selector that ignores the seed (returns `head band`). Asserted as `\|{ρ(s) : s ∈ pinned seed list}\| ≥ 2` **and** the named pair differing — a cherry-picked pair alone is not evidence | No |
| **FEE-04** | `the_admissible_band_has_more_than_one_member` | `pure_check` | A | A `(f, δ*)` whose band is empty or a singleton being used as the subject of the previous check. MEASURED band sizes: 2 686 at `f=3000, δ*=0.49`; 88 at `f=100`. Firing input: `f=3000, δ*=1000` pips → **empty** | No |
| **FEE-04** | `the_seed_and_splitter_version_are_in_the_record` | `Fee.Split` + `pure_check` | A | A `FeeSplit` record missing `fs_seed` or `fs_splitter_version` — Phase 25's run log and `key_scheme` consume both (ROADMAP:1202) | No |
| **CHAIN-04** | `shock_topic0_is_computed_from_the_signature_string` | `Main.hs`, `ground_truth` idiom | A | `keccak256 "Shock(address,int24,uint24,uint24)"` ≠ the bare-hex ground truth; or a signature perturbed to `Shock(address,uint24,uint24,uint24)` still matching | No |
| **CHAIN-04** | `the_call_selector_is_not_a_topic` | `pure_check` | A | A log whose topic0 is the left-padded `next(address,uint160,int24,uint24,uint24)` selector decoding. Built by concatenation, never spelled (M12) | No |
| **CHAIN-04** | `a_negative_tick_diff_decodes_sign_aware` | `Chain.Shock` + `pure_check` | A | `tickDiff = −200` decoding as `16777016` (24-bit mask) or `2²⁵⁶−200` (no conversion). Exact `Integer` equality; both wrong answers pinned as values | No |
| **CHAIN-04** | `an_all_zero_payload_is_rejected` | `Chain.Shock` + `pure_check` | A | 96 zero bytes decoding into `ShockEvent _ 0 0 0`. **The phase's headline zero-trap check.** Provenance: `flags = 0` is well-formed in `shock_decode` (M7) | No |
| **CHAIN-04** | `a_wrong_length_payload_is_rejected` | `pure_check` | A | 0, 64, 95 or **128** bytes decoding. The 128 case is the firing input for the exact-length rule — the `>=` precedent in E1/E3/E5 would ACCEPT it | No |
| **CHAIN-04** | `wrong_topic0_and_wrong_topic_arity_are_rejected` | `pure_check` | A | A one-topic log, a three-topic log, and a topic0 differing in one bit, any of which decodes | No |
| **CHAIN-04** | `the_pool_topic_is_a_nonzero_address` | `pure_check` | A | A topic1 with a nonzero byte above bit 159 decoding; or `pool = 0` decoding (the absent-subject address) | No |
| **CHAIN-04** | `out_of_range_words_are_rejected` | `pure_check` | A | `tickDiff` outside `[−2²³, 2²³)` after sign extension; either rate `≥ 2²⁴`. Firing input: data word 1 = `2²⁴`. This is the only guard that catches a transposed word order | No |
| **CHAIN-04** | `the_synthetic_corpus_carries_what_production_never_emits` | `pure_check` | A | A corpus in which no member has `tickDiff < 0`, or none has `txlVolmDecay ≠ 0`. Asserted as a SET over member names in **both** directions — a count is defeated by a rename (Phase 24 MEASURED exactly that) | No |
| **CHAIN-04** | `txl_volm_decay_never_reaches_the_prover` | `Main.hs` scan + `Gams.Argv` type | A | `Gams.Argv.Shock` gaining a decay field, or a decay value appearing in `render_argv`'s token list. `VOLUME_PATH.md` §2: *"`txlDecayRate` is **not** an input by ruling"* | No |
| **CHAIN-04** | `the_upstream_shocklib_pin_is_a_live_trip_wire` | `Main.hs` | A | `src/models/mev_tax_model_one/libraries/ShockLib.plk` **appearing** in this worktree while the topic0 is still pinned in `ground_truth` rather than generated into `rig-pins.json`. **Positive control mandatory** — the same predicate must be SHOWN firing against a path that exists, else it is a guard whose subject is absent (M8) | No |

### Every guard, and the input that makes it fire

A guard never seen to reject is the empty-log finding. One row per guard; **no row says "invalid
input"** — each names an exact value, and every value marked MEASURED was computed on this machine
today.

| # | Guard | The exact input that makes it fire | Observation |
|---|---|---|---|
| 1 | level constraint exact | `compose_scaled` with the `−xm` term deleted | fixture recomposes to **6500**, not 6497. MEASURED |
| 2 | fixture recomposition | `φ_X = 500, φ_M = 6000` | `999500 × 994000 = 993 503 000 000` ⇒ `f = 6497` exactly. MEASURED |
| 3 | exact-split existence, positive | `f = 6497` | **2** exact pairs found. MEASURED |
| 4 | exact-split existence, negative | `f = 3000` (and 100, 500, 10000) | **0** exact pairs. MEASURED — a splitter claiming exactness here is caught |
| 5 | rounding residual bound | a rounder using `floor` at `f = 3000, x = 998` | residual moves off `+8·10⁻⁶` pip; guard trips at ≥ 1 pip. MEASURED headroom ≈ 10³ |
| 6 | **ellipse predicate — the doc-prose reading** | `phiBar := (x+m)/2`, `dphi := (m−x)/2` | **36 of 70** near-boundary points flip; 82 713 pips of false refusal at the fixture. MEASURED |
| 7 | ellipse predicate — leading-order limit | `ρ/(1+ρ²)` | **30 of 70** flip. MEASURED — even the *correct* limit is not exact |
| 8 | integer form ≡ rational form | any of 20 000 random `(x, m, d)` triples | signs agree and `E = D⁶·ellTest` on every one. VERIFIED today |
| 9 | boundary is the exact root | `(φ_X=500, φ_M=6000, δ*=82 803)` | `Left OutsideEllipse`; at 82 804 it is `Right`. MEASURED |
| 10 | `δ* = 0` refused | `txlVolumeRate = 0` | `E = D⁴·x·m > 0` ⇒ refused. Closes the live hole at `Gams/Argv.hs:137` (M9) |
| 11 | equal fees refused | `φ_X = φ_M = 3000` | `distinct_fees` fires; **and** the ellipse single root is `0.50075 > ½`. MEASURED — both, so deleting one leaves the other |
| 12 | no float on the fee path | seed `sqrt` or a `Double` field into `Fee/Split.hs` | scan red, positive control proven |
| 13 | scan scope grows | add `offchain/lib/Fee/Split.hs` without listing it | the directory-vs-list set check reddens naming the unlisted module (24-02's fix, inherited) |
| 14 | no spawn on refusal | inadmissible request through `run_prover` with a marker-writing stub | marker **absent**; the admissible control **creates** it, evaluated first |
| 15 | splitter holds no IO | add `import System.Process` to `Fee/Split.hs` | scan red with a proven positive control |
| 16 | grid is two-sided | a conformance grid with only admitted rows | verdict-count assertion reddens in both directions |
| 17 | grid abort is attributed | a boundary row whose `control_exit ≠ 0` | the abort could be κ, volume or a §4 gate — exit 3 does not say which (24-RESEARCH guard 15) |
| 18 | exact-vs-double margin | a grid pair at `φ = (3, 7)` pips | `|ellTest| = 4.4·10⁻¹⁸`, only 4·10⁴× the noise floor. MEASURED — record `E`, keep the grid at `φ ≥ 100` |
| 19 | seed is load-bearing | a selector returning `head band` | `\|{ρ(s)}\| = 1` over the pinned seed list ⇒ red |
| 20 | band is non-degenerate | `f = 3000, δ* = 1000` pips | band **empty** ⇒ the seed test's subject is absent and says so. MEASURED band = 2 686 at `δ* = 490 000` |
| 21 | topic0 is computed | change the signature to `Shock(address,uint24,uint24,uint24)` | recomputed keccak ≠ the bare ground truth |
| 22 | the call selector is not a topic | topic0 = `d3827b0b` left-padded to 32 bytes | `Left WrongTopic0`. The selector is REAL (MEASURED with `cast sig`), which is what makes it a good decoy |
| 23 | **sign-aware decode** | data word 0 = `2²⁵⁶ − 200` | `se_tick_diff == −200`. A mask gives `16777016`; no conversion gives `2²⁵⁶−200`. Both pinned as values |
| 24 | **all-zero payload** | 96 zero bytes, valid topic0, valid pool | `Left AllZeroPayload`. Emittable upstream at `flags = 0` (M7) |
| 25 | wrong data length | **128** bytes (and 0, 64, 95) | `Left (WrongDataLength n)`. 128 is the case the inherited `>=` guard would ACCEPT |
| 26 | topic arity | a one-topic and a three-topic log | `Left WrongTopicArity`. `@evm_log2` emits exactly two (M7) |
| 27 | pool topic shape | topic1 with byte 11 nonzero; and topic1 = 0 | `Left NotAnAddress` / `Left ZeroPool` |
| 28 | word range | data word 1 = `2²⁴`; data word 0 = `2²³` after sign extension | `Left (WordOutOfRange …)`. The only guard that catches transposed words |
| 29 | corpus discriminates | delete the negative-`tickDiff` member | member-NAME SET assertion reddens (a count would not — Phase 24 MEASURED that) |
| 30 | decay never sent | add a decay token to `render_argv`'s list | the seven-token assertion reddens; `VOLUME_PATH.md` §2 rules it out by name |
| 31 | upstream trip-wire | `src/models/mev_tax_model_one/libraries/ShockLib.plk` appearing in this worktree | check reddens telling the reader to move the pin into `rig-pins.json`. **Positive control mandatory** — point the predicate at an existing path and see it fire |
| 32 | `expected_topic_pins` untouched | add `"Shock"` to `expected_topic_pins` before the merge | both-directions set assertion reddens (`Main.hs:675`) — recorded so nobody tries it |
| 33 | `sc3_literal_purge` | a `0x`-prefixed 8/40/64-hex literal in any new `.hs`/`.sh` under `offchain/` | grep exit 0. Write the topic0 and the decoy selector **bare** or build them |
| 34 | capture freshness | edit `Fee/Split.hs` or the grid definition without re-capturing | the recorded source digest ≠ the digest recomputed by the suite (`sc4_generated_from` idiom) |
| 35 | capture completeness | truncate the capture mid-run | `fs_complete == False`, or the grid-row **SET** short — a SET, never a count |
| 36 | sentinel harness | any leaf of `fee-split-conformance.json` that no check reads | reported as an **absorbed** pair, by name, with its sentinel |
| 37 | suite stays GAMS-free | add `Gams.Invoke` / `CFMM_REQUIRE_GAMS` / the absolute prover path to `Main.hs` | the three-token grep returns non-zero. `Gams.Run` is **allowed** and is how guard 14 works |
| 38 | suite stays DB-free | add `Store.Postgres` / `connectPostgreSQL` to `Main.hs` | the DB-free grep returns non-zero (re-measured at **0** today) |
| 39 | `FEE_SPLIT_CONFORMANCE` override | `FEE_SPLIT_CONFORMANCE=/nonexistent-override-probe/FEE_SPLIT_CONFORMANCE.json` | the consumer fails and the message CONTAINS that path. Registered in `advertised_overrides` |

### Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all`. `--enable-tests` is load-bearing;
  **the bare `cabal build -j all` is VACUOUS and must never appear.**
- **Per wave merge:** `cabal test` — full `core_checks` + `sentinel_falsification_harness` — with
  **zero `-Wall` warnings** under `offchain/`, and both structural greps at 0.
- **Phase gate:** full suite green; `-Wall` clean; `bash offchain/rig/capture-fee-split.sh` re-run
  from scratch producing an artifact whose grid rows are all `agree`; **every guard in the table
  above OBSERVED firing at least once with its named input**, recorded as a ledger in the phase
  summary in 23-05's / 24-06's shape. A guard with no observation is reported as a **phase-level
  finding**, named, never omitted (23-05 guard #13 and 24-06's four-guard precedent).
- **Do not** run the capture inside `cabal test`, and do not let any check invoke `gams`.
- **Budget:** wall is **149.5 s** of 900 s today. The Tier-B marker-stub check costs one subprocess
  (≈ +1 s, by 24-03's measurement of five stub checks at +5.2 s). The new swept artifact is the real
  cost: the harness re-runs `core_checks` once per (leaf × 6 sentinels), and Phase 23's 134-leaf
  artifact added 793 pairs and 19 s. **Design `fee-split-conformance.json` NARROW** — 12–24 grid
  rows, every leaf either asserted or pardoned in `absorbed_by_design` with a written reason.

### Wave 0 Gaps

No test *file* is created — the suite is one file and one runner. The gaps are registration points
and infrastructure, all of which must exist before the first assertion is written.

- [ ] `.cabal` library stanza — `Fee.Split` and `Chain.Shock` in `exposed-modules`, with the
      package-count comment discipline (lines 94–128): state `Downloading = 0` as a **CONFIRMED**
      observation of `cabal build --enable-tests -j all`, never an estimate. Expected **+0 packages**
- [ ] `.cabal` — a new `executable fee-split-conformance` stanza in the `gams-conformance` family,
      with `aeson` **in the executable only** (it writes the report, never an artifact byte)
- [ ] **Decide the rounding design** (Correction 2: exact-or-refuse vs round-and-report) **before**
      the first plan writes `Fee/Split.hs`. It changes which pools are servable
- [ ] **Decide where the admissibility refusal lives** — recommended: the ninth refusal inside
      `Gams.Argv.render_argv`, which makes FEE-03 structural. Not free: it moves `ArgvError` and
      touches a Phase-24 module every Tier-B check already drives
- [ ] **Decide the seed→index function** — pure `ST` `mwc-random` (+0 packages, reuses `Driver.Seed`'s
      `Word32` convention) or a hand-rolled documented integer mixer. It must be a **pure function of
      (seed, band)** so FEE-04 stays Tier A
- [ ] `offchain/test/Main.hs` — a `("topic0", "Shock(address,int24,uint24,uint24)", <bare hex>)` row
      in `ground_truth` (`:480`). **Bare, no `0x`** — the block's own haddock says why
- [ ] `offchain/test/Main.hs` — **do NOT** add `"Shock"` to `expected_topic_pins` (`:591`): the pin
      file is generated from local `.plk` files and `ShockLib.plk` is not in this worktree (M8).
      Record the reason in-file so it is not re-proposed, and add the trip-wire (guard 31) instead
- [ ] `offchain/test/Main.hs` — extend `aeson_storage_path` (`:7082`) to cover `offchain/lib/Fee/`
      and `offchain/lib/Chain/`, **plus** the both-directions directory-coverage arm, in the SAME
      commit that creates the modules
- [ ] `offchain/test/Main.hs` — a new `OverrideProbe` in `advertised_overrides` (`:3780`) for
      `FEE_SPLIT_CONFORMANCE`, following 23-05's `PGSTORE_DSN` ruling. **Do not manufacture a
      consumer in order to make a probe pass**
- [ ] `offchain/test/Main.hs` — `fee-split-conformance.json` added to `swept_artifacts` (`:5563`,
      it becomes the **seventh**) **and** a new `artifact_field_floors` entry (`:6115`), both
      **MEASURED, never incremented**
- [ ] `offchain/test/Main.hs` — `sentinel_pair_floor` (`:6077`, currently **3828**) **RE-MEASURED**
      by raising it until the harness reports what it reached
- [ ] `offchain/test/Main.hs` — `purge_file_floor` (`:1058`, **59** today, zero slack) and
      `credential_scan_floor` (`:7635`, **68** today, zero slack) **RE-MEASURED as a pair**. This
      phase adds ~2 `.hs` + 1 app `.hs` + 1 `.sh` (+1 `.json`, credential-scanned only)
- [ ] `offchain/test/Main.hs` — ~29 new `Check` values wired into `core_checks` (`:11042`).
      **A check not in this list does not exist**
- [ ] `offchain/test/Main.hs` — a **marker-stub helper** (guard 14) in the 24-03 stub-writing idiom:
      writes an executable `sh` script that `touch`es a path and exits 0. Built, never committed
- [ ] `offchain/rig/capture-fee-split.sh` — the `capture-gams-conformance.sh` idiom: refuses to emit
      a partial artifact, names `gams` when absent, runs in scratch directories, **never writes into
      `model/`**, and runs the `control` invocation for every boundary row. `CFMM_REQUIRE_GAMS`
      belongs **here**, never in `cabal test`
- [ ] `offchain/rig/fee-split-conformance.json` — committed evidence. **Design it NARROW**
- [ ] **Coordinate with Phase 25 (being planned in parallel):** phase 26 owes phase 25 two fields
      for the run log / key scheme — `fs_seed` and `fs_splitter_version` (ROADMAP:1202) — and phase 26
      owes nothing else. Phase 25 must not assume the splitter runs inside the key path
- [ ] `.github/` — no change needed and none should be made: nothing in `cabal test` invokes GAMS.
      The `haskell` gate job has still never executed

---

## State of the Art

| Old approach | Current approach | Impact |
|---|---|---|
| `δ* ≥ 2ρ/(1+ρ²)` as the admissibility rule | the exact integer transcription of `volume_path.gms`'s `ellTest` | 36/70 boundary disagreements and up to 498 810 pips of false refusal removed. MEASURED |
| `Rational` for "exact arithmetic" | `Integer` via `E = D⁶·ellTest` | keeps `Data.Ratio`/`fromRational` off the path entirely; verified equivalent on 20 000 triples |
| a 4-byte function selector for the decoder | topic0 of the **event**, computed from the signature string | superseded by issue #28; the selector survives as a **negative** fixture |
| `BS.length payload >= N` (E1/E3/E5) | `== 96` | the `>=` form accepts a longer payload silently; SC-5 requires wrong lengths rejected |
| `Maybe` decode results | `Either ShockDecodeError` | four distinct rejection reasons that `Nothing` collapses |
| topic0 parsed out of a local `.plk` (RPIN-04) | bare-hex ground truth + a merge trip-wire | `ShockLib.plk` is on `exp/mev_tax_model_one` only; the pin idiom returns when the merge lands |

**Deprecated / outdated for this phase:**

- ROADMAP SC-5's `next(address,uint160,int24,uint24,uint24)` selector — superseded by issue #28.
- `VOLUME_PATH.md` §1.3's quadratic *as prose* — its `Δφ` is undefined and reads as the semi-axis;
  the executable definition is `volume_path.gms:106`.
- The brief's `ρ ≥ 2+√3` reachability gate — an artifact of the same halving; **false**.

---

## Open Questions

1. **Which branch of the ratio symmetry does the splitter take?**
   Both the prover's gate and the brief's form are symmetric under `φ_X ↔ φ_M`, so the admissible set
   is two intervals (`ρ ≥ ρ_hi` and `ρ ≤ 1/ρ_hi`). MEASURED: at `f = 6497` the *exact* pairs are
   `(500, 6000)` **and** `(6000, 500)`. §2 says `phiXpips` comes from the DynamicFeeHook and
   `phiMpips` from `MevTaxModelOneFees`, so the two legs are not interchangeable **downstream** even
   though the model is symmetric. *Recommendation:* restrict the band to `ρ > 1` (`φ_M > φ_X`, the
   fixture's orientation) and **record** the restriction as a splitter-version decision, so a later
   widening orphans keys rather than silently changing them. Confidence: MEDIUM — this is a domain
   ruling, not a measurement.

2. **Is the splitter authoritative, or are the two fees read from chain?**
   FEE-01 says the splitter *produces* (φ_X, φ_M); `VOLUME_PATH.md` §2 says both are *read* (hook
   state / `MevTaxModelOneFees`). Both cannot be the source of truth. ROADMAP SC-1 settles it for
   v6.0 — *"the derived pips (not `f`) are what reach the key"* — so the splitter wins **here**, but
   Phase 27's read layer will surface the same pair from chain and the two must then be reconciled
   (`compose(read pair) == pool fee` is the natural check). *Recommendation:* record the decision in
   the splitter's haddock now; it is one sentence and it prevents a silent override in Phase 27.

3. **Does the model's own tolerance interact with the rounding residual?**
   §3 guarantees both rate targets to `1e-10`; the worst residual measured is `5·10⁻⁴` pip =
   `5·10⁻¹⁰` absolute — the same order. The residual is a mismatch between the *pool's* fee and the
   *model's* composed fee, which the prover never sees, so it cannot fail a §4 gate; but it is close
   enough to `tol` that stating "invisible to the prover" without the arithmetic would be a guess.
   *Recommendation:* record `residual_scaled` in the conformance artifact and compare it to `tol`
   once, as a documented one-off, rather than asserting an inequality nobody has measured.

4. **How many grid points can the capture afford?** Each row is one `gams` run (plus a control for
   boundary rows). 24-05 measured the real prover at seconds per run; 12–24 rows is minutes, which is
   fine out of band. Unverified: whether the boundary controls double that cost in practice.

5. **Does anything else in `volume_path.gms` gate on the fee pair?** The κ range check
   (`kappa ∈ [1e-12, 1e12]`) and CONOPT's own `Locally Infeasible` (§1.4, volume too small for `δ*`)
   are **not** fee-pair properties but they abort with the same exit code. The `control` column in
   the artifact is the mitigation; whether it fully separates them at every grid point is the one
   thing the capture will actually discover. Flagged, not assumed.

---

## Sources

### Primary — executed on this machine today (HIGH)

- `cabal test` → **151/151, exit 0, wall 2 m 29.5 s**.
- `find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) | wc -l` → **59**;
  with `-o -name '*.json'` → **68**; extension census `hs 47, sh 9, json 9, sql 3, md 3, txt 2`.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` → **0**.
- `cast keccak "Shock(address,int24,uint24,uint24)"` → `0x21b0e4f8…55987d64`;
  `cast sig "next(address,uint160,int24,uint24,uint24)"` → `0xd3827b0b`.
- Exact `Fraction`/`Integer` computations (scripts in the session scratchpad): the prover-vs-brief
  differential (M1), the integer-form equivalence over 20 000 triples (M2), the divisor survey over
  `f ∈ [1, 20000]` (M3), band sizes and residuals (M4), boundary margins (M5).
- `git cat-file -e 341e409` and `git show 341e409:src/models/…/ShockLib.plk` → reachable from this
  worktree; `ls src/models/mev_tax_model_one/` → absent (M8).

### Primary — these repositories, read directly (HIGH)

- `cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms:88–110` — the abort battery and `ellTest`.
- `cfmm-wt/gams/model/mev_tax_model_one/VOLUME_PATH.md` §1–§4 — the geometry, the seven inputs, the
  `txlDecayRate` ruling, the abort table.
- `cfmm-wt/plank/src/models/mev_tax_model_one/libraries/{ShockLib,Shock}.plk` @ `341e409` — the
  emitter and the codec (M7).
- `offchain/lib/Gams/Argv.hs` — the eight refusals, the edge normalizer, the `txlVolumeRate = 0` hole.
- `offchain/lib/{RealizedVol,VolOrder}/Decode.hs` — `signed_word`, `data_word`, the length-guard
  rationale, the topic0-as-argument rule.
- `offchain/lib/Driver/Seed.hs` — the `RIG_SEED` contract.
- `offchain/test/Main.hs` — `Check`/`guarded`/`pure_check` (`:512`), `topic0_of` (`:330`),
  `ground_truth` (`:480`), `expected_topic_pins` (`:591`), `purge_pattern` (`:957`),
  `purge_file_floor` (`:1058`), `synthetic_log` (`:1589`), `advertised_overrides` (`:3780`),
  `swept_artifacts` (`:5563`), `sentinel_pair_floor` (`:6077`), `artifact_field_floors` (`:6115`),
  `credential_pattern` (`:7571`), `gams_free_pattern` (`:10899`), `core_checks` (`:11042`).
- `offchain/rig/{generate-pins.sh,check-upstream.sh,import-paths.txt,import-ref.txt}` — the
  cross-branch source-of-truth machinery.

### Secondary — settled prior research, cited not re-derived (HIGH)

- `.planning/research/SUMMARY.md` — the aeson/`jsonb`/`Double` findings, the "six pitfalls"
  defect class, the `+0`-package hashing note.
- `.planning/phases/23-…/23-RESEARCH.md` — the Validation Architecture shape, the SET-not-count
  ruling, the `CFMM_REQUIRE_DB` relocation precedent.
- `.planning/phases/24-…/24-RESEARCH.md` — the exit taxonomy (exit 3 is ambiguous, guard 15), the
  Tier A/B/C split, the stub-writing idiom, the bare-digest rule (guard 41), the scan-scope-grows
  fix (guard 34).
- `.planning/STATE.md` (24-06) — the floors of record, the count-preserving-rename control, the
  four unmutated guards carried forward.
- `.planning/ROADMAP.md` — Phase 26 goal/SCs, the issue #28 superseding note, the issue #29 handoff,
  the 2026-08-17 blocker downgrade, Research Flag "the differential against the model is the work".

### External (MEDIUM — official docs)

- Foundry `cast keccak` / `cast sig` — used as the independent hash oracle.
- Solidity ABI specification — indexed value types occupy one 32-byte topic; static types are
  left-padded; signed integers are sign-extended.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| The prover-vs-brief discrepancy | **HIGH** | read at source, re-derived independently from §1's geometry, and quantified on a 70-point grid in exact arithmetic |
| The integer form of the gate | **HIGH** | verified against the `Fraction` evaluation on 20 000 random triples, value and sign |
| Exact-split rarity | **HIGH** | full factorisation over `f ∈ [1, 20000]`, no sampling |
| The event shape and the sign-extension | **HIGH** | read at source in `ShockLib.plk`/`Shock.plk` @ `341e409`; topic0 recomputed independently |
| The suite baseline and floors | **HIGH** | run and measured cold today |
| The GAMS-agreement grid's attributability | **MEDIUM** | exit 3 is ambiguous by construction; the `control` design is sound but unproven until the capture runs (Open Question 5) |
| The ratio-branch and source-of-truth rulings | **MEDIUM** | domain decisions, not measurements (Open Questions 1–2) |

**Research date:** 2026-08-17
**Valid until:** ~2026-09-16 for the arithmetic (it is algebra over a fixed source file); **re-verify
immediately** if `volume_path.gms` or `ShockLib.plk` moves, and **re-measure the floors and the
baseline at plan time** regardless — two phase-24 summaries misreported them.
