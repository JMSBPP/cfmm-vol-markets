---
phase: 26-shock-assembly-fee-split-event-decode
plan: 03
subsystem: fee-splitter
tags: [ninth-refusal, ellipse-gate, splitmix64, seeded-pick, tier-b-observation, marker-stub, no-spawn, gams-recapture, band-degeneracy, fee-03, fee-04]

# Dependency graph
requires:
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 01
    provides: "Fee.Split's compose_scaled / nearest_partner / ellipse_test / is_admissible / min_admissible_dstar / FeeSplit / SplitRefusal / fee_in_domain -- the arithmetic this plan's band, pick and split_for are built out of, and the fee_in_domain predicate 26-01 landed precisely so blocker B1's step 0 could be written here"
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 02
    provides: "the MEASURED fact that render_argv had EIGHT refusals with a txlVolumeRate lower bound of 0 -- the two numbers this plan moves -- and an_all_zero_payload_is_rejected's arm 2, authored to be REWRITTEN by this plan rather than deleted"
  - phase: 24-gams-invocation-toolchain-identity
    provides: "Gams.Run's refused_before_spawn with its EMPTY cs_run_dir, the write_stub / with_tier_b_scratch / outside_repo Tier-B idiom, and the gams-conformance capture whose freshness oracle recomputes Gams/Argv.hs's digest from disk"
provides:
  - "Fee.Split: admissible_band, mix64, pick_from_band, split_for, and a sixth SplitRefusal constructor (NoBoundaryForAnAdmissiblePair)"
  - "Gams.Argv: the NINTH refusal -- volume_path.gms's own ellTest, in exact Integer arithmetic, evaluated AFTER distinct_fees -- and the Inadmissible constructor carrying both legs, the target, the exact E and the boundary"
  - "nine checks in core_checks (181 -> 190): eight Tier A and one Tier B"
  - "blocker B1 CLOSED: split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608), a Left where the plan's own band enumeration divided by zero"
  - "RC-M6 CONFIRMED BY MEASUREMENT and both documents corrected: admissible_band 3000 1000 has TWO members, not four"
  - "a re-taken gams-conformance.json driven against the REAL GAMS 54.1 with the ninth refusal in place: golden bytes reproduce, 9/9 verdicts pass"
affects: [26-04, 27]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A mixer whose stream a run log replays from is WRITTEN OUT with its constants in decimal, not imported: a library stream that moved would orphan every recorded split without changing a single stored byte"
    - "An impossible branch gets its own named refusal, never a default: the impossible case is the bug class the reviewer already found once"
    - "The emptiness test and the pick are ONE test when the pick is Nothing exactly on empty -- there is then no unreachable branch needing an invented message"
    - "A refusal's boundary is RECOMPUTED from the same function that fills the recorded field, so the operator's number and the artifact's number cannot drift"
    - "An ordering guarantee is asserted by CONSTRUCTOR, because the line-number reading expires at the next refactor"
    - "A string-containment arm is not enough: a wrong boundary that spells the right one as a substring passes it, and only the recomputation arm catches that"
    - "Editing a module a conformance capture digests means RE-TAKING the capture in the same commit; the freshness oracle is what makes that non-optional"

key-files:
  created: []
  modified:
    - offchain/lib/Fee/Split.hs
    - offchain/lib/Gams/Argv.hs
    - offchain/lib/Store/Key.hs
    - offchain/rig/gams-conformance.json
    - offchain/test/Main.hs
    - .planning/phases/26-shock-assembly-fee-split-event-decode/26-03-PLAN.md
    - .planning/phases/26-shock-assembly-fee-split-event-decode/26-VALIDATION.md

key-decisions:
  - "split_for's steps 1 and 2 are MERGED: pick_from_band is Nothing exactly when the band is empty, so the plan's separate null test and its 'impossible Nothing' branch would have been two tests that could disagree and one message that had to be invented"
  - "A SIXTH SplitRefusal constructor, NoBoundaryForAnAdmissiblePair, rather than reusing OutsideEllipse for the impossible Nothing -- the pair is INSIDE the ellipse there, and a refusal that lied about which fact failed would be worse than the default it replaced"
  - "ResidualTooLarge is applied in 26-01's SHIPPED positional order (f, x, m, r); 26-03-PLAN.md:239's (x, m, f, r) contradicts the constructor's own haddock and refusal_message"
  - "Inadmissible carries FIVE positional fields and no sentence field: a sixth String would make check 12's whole-value equality assert a transcribed sentence, and a transcribed sentence agrees with itself"
  - "The txlVolumeRate lower bound STAYS at 0. The ninth refusal subsumes the hole with the model's own test; raising the bound would be a second answer to one question in two places that can drift"
  - "in_range's txlVolumeRate upper bound is now pips_denominator - 1 rather than a second literal 999999 -- the rendered message is byte-identical and the constant is stated once"
  - "gams-conformance.json was RE-TAKEN against the real GAMS 54.1, not hand-edited. The plan does not mention it; the freshness oracle caught the edit and re-taking is the only honest fix"
  - "26-02's an_all_zero_payload_is_rejected arm 2 was REWRITTEN, as its own failure text instructed, to assert the Inadmissible refusal AND to redden if the range bound was raised instead"

patterns-established:
  - "A firing input that is a no-op in the monad it is written for is reported as such: 'move the gate after the token list' does not change an Either do-block's evaluation order, so the only mutation that produces an argv is one that removes the gate"
  - "A mutation whose message LOOKS right is the strongest one: Just 828040 contains the substring 82804, so the naming arm passed and only the recomputation arm fired"

requirements-completed: [FEE-01, FEE-03, FEE-04]

# Metrics
duration: ~3h
completed: 2026-08-17
---

# Phase 26 Plan 03: The Ninth Refusal, and the Process That Was Observed Not Starting — Summary

**An inadmissible shock now has no representation that can reach an `execve`: `volume_path.gms`'s
own `ellTest` is the ninth refusal inside the pure `render_argv`, evaluated in exact `Integer`
arithmetic and ordered after `distinct_fees` so §1.2's diagnosis is not swallowed by a gate that
would refuse the same input for a different reason. It is structural AND it was OBSERVED: a
`/bin/sh` stub whose whole body touches a marker was driven through `run_prover`, its positive
control fired first at one pip above the boundary, and the subject left the marker absent and the
run directory the empty string. Blocker B1 is closed with a `Left` where the plan's own band
enumeration divided by zero, RC-M6's wrong firing number is confirmed at 2 and corrected in both
documents, and four plan-level defects were found with the measurement that found them.**

## Performance

| | Wave start (BASE) | After this plan |
|---|---|---|
| `cabal test` | **181/181** | **190/190** |
| FAIL | 0 | **0** |
| exit code | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall | **175 s** | **158–170 s** |
| `purge_file_floor` | 64 | **64** (unchanged, as predicted) |
| `credential_scan_floor` | 73 | **73** (unchanged, as predicted) |
| `render_argv` refusals | 8 | **9** |
| files created | — | **0** |

**BASE was measured COLD before this plan edited a single file:** `cabal build --enable-tests -j all`
exit `0` with `WARN=0`, then `cabal test` → `181 PASS`, `0 FAIL`, exit `0`, wall `175 s`. That
equals exactly what `26-02-SUMMARY.md` recorded on exit (181), so **there is no BASE finding to
report by name.** Every gate in this plan was `BASE + N` against 181 and no absolute total was
inherited. Final: **190 = 181 + 9**, against a 900 s wall ceiling with 158 s used.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | the band, the mixer, the seeded pick, and the domain check that comes first | `25a956c` |
| 2 | the ninth refusal in `Gams.Argv`, four Tier-A checks, and the re-taken capture | `0df4f12` |
| 3 | FEE-03 Tier B (the marker stub) and FEE-04 (the load-bearing seed) | `5edf629` |

## Gate readings, as PRINTED

| Gate | Command | Reading |
|---|---|---|
| build | `cabal build --enable-tests -j all` | exit `0`, `WARN=0` |
| imports, splitter | `grep -c '^import' offchain/lib/Fee/Split.hs` | `2` — `Data.Word (Word32)` and `Data.Bits ((.&.), shiftR, xor)` |
| bad deps, splitter (word-anchored) | `grep -cE 'Double\|Float\|realToFrac\|fromRational\|Data\.Ratio\|\bRational\b\|\bsqrt\b\|System\.\|Control\.Monad\.ST\|MWC\|unsafePerformIO'` | `BADDEPS=0` |
| bad deps, splitter (plan's UNANCHORED pattern) | same without `\b` anchors | **also `0`** — see finding 5 |
| hex literals, splitter | `grep -cE '0x…{40}\b\|0x…{64}\b\|0x…{8}\b'` | `HEXLIT=0` |
| `fromMaybe` on the boundary | `grep -n 'fromMaybe' offchain/lib/Fee/Split.hs` | 2 hits, **both prose**; `Data.Maybe` is not imported, so the function is not in scope |
| decay absent from the renderer | `grep -cE '[Dd]ecay' offchain/lib/Gams/Argv.hs` | `DECAY_IN_ARGV=0` |
| no wildcard arm | `grep -cE '^\s+_\s+->' offchain/lib/Gams/Argv.hs` | `WILDCARD=0` |
| `Inadmissible` present | `grep -c 'Inadmissible' offchain/lib/Gams/Argv.hs` | `3` (floor 2) |
| float scan over the renderer | `grep -cE 'Double\|Float\|…\|\bsqrt\b' offchain/lib/Gams/Argv.hs` | `0` |
| ordering, by line number | `grep -n 'distinct_fees shock\|admissible_pair shock'` | `206:` `distinct_fees`, `207:` `admissible_pair` |
| DB-free | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` | `DBFREE=0` |
| GAMS-free | `grep -cE 'Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams' offchain/test/Main.hs` | `GAMSFREE=0` |
| orphaned stubs | `pgrep -a marker` | `NO_ORPHANS` |
| NUL bytes | `wc -c` vs `tr -d '\000' \| wc -c` | equal on all five files written |
| territory | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | **empty** |

### The two floors, re-measured COLD as a pair

Both commands were RUN at task 3, not derived from each other and not obtained by arithmetic on the
wave-start reading. **This plan creates no file, and both are UNCHANGED — which is the prediction
the plan made and the measurement confirming it, not the prediction standing in for the
measurement.**

```
find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) | wc -l
64
find offchain -type f \( -name '*.hs' -o -name '*.sql' -o -name '*.sh' -o -name '*.json' \) | wc -l
73
```

Census under `offchain/`: `hs 52, sh 9, json 9, sql 3`. Both floors remain set to exactly those
printed values, **zero slack**. The absolutes `61 / 70` the plan carried predate phase 25 and were
hypotheses by the time it ran; 64 / 73 is what phase 26 has been measuring since 26-02.

## The firing ledger — nine guards, ten observations, every one OBSERVED

Every mutation was applied to the working tree, built, run, and then restored from a **saved copy
verified by `sha256sum` on all four files**, never `git checkout`. Restore was verified after every
single mutation:
`Fee/Split.hs` → `b3510f82f57f23019c3f5e6bb2d209e9f979dfb01e82ec5a9011838c7ec127ab`,
`Gams/Argv.hs` → `37e4dc3b8347ee7d7576c0c5031be5393bc31215b97a609d11127bf91b3bee61`,
`rig/gams-conformance.json` → `5eaa3a46054973fdb2626f0212f335eb9ed2cd6ddaaca8d9bfec1c88f4cdb081`,
`offchain/test/Main.hs` to the digest current at each stage
(`1241abe6…` at task 2, `eb4dcb79…` at task 3).

| # | Guard / arm | Firing input | What went red, VERBATIM |
|---|---|---|---|
| 12 | `an_inadmissible_shock_cannot_be_rendered_to_argv` | the ninth refusal deleted from `render_argv` | `the shock at txlVolumeRate = 82803 -- ONE PIP below the measured boundary for the fee pair (500, 6000) -- gave` / `Right ["--sqrtPriceX96=79228162514264337593543950336",…,"--txlVolumeRate=82803",…]` / `and must give` / `Left (Inadmissible 500 6000 82803 4991723980281000000000000 (Just 82804))` |
| 13a | `the_refusal_names_the_boundary_and_the_pair` **subject arm** | same | `the shock this check reads a refusal from RENDERED instead:` / `["--sqrtPriceX96=…","--txlVolumeRate=82803",…]` |
| 13b | same, **RECOMPUTATION arm** | the boundary replaced by the constant `Just 828040` | `the refusal carries the boundary Just 828040 and min_admissible_dstar recomputed here gives Just 82804. The number in the message must come from the same bisection a recorded split's fs_boundary_pips comes from; a constant frozen into the refusal is a second answer that can drift away from the first without either of them going red.` |
| 14 | `equal_fees_are_refused_in_haskell_with_the_1_2_diagnosis` | `distinct_fees` deleted from `render_argv` | `the equal-fee shock was refused by the ELLIPSE (Inadmissible, boundary Nothing), not by distinct_fees. MEASURED: min_admissible_dstar 3000 3000 == Nothing, so the ellipse refuses equal legs for EVERY integer target on its own. The refusal COUNT is identical either way and VOLUME_PATH.md section 1.2's specific diagnosis is what was lost. Either distinct_fees was deleted or the ninth refusal was moved ahead of it.` |
| 15 | `the_derived_pips_are_what_reach_the_argv` | the `Shock` built from `fs_pool_fee_pips` instead of `fs_phi_x_pips` | `the argv does not carry the DERIVED pips:` / `[…,"--phiXpips=3000","--phiMpips=2250",…]` / `ROADMAP SC-1: the derived pips, not f, are what reach the key.` |
| 16 | `no_subprocess_is_spawned_for_an_inadmissible_shock` | the ninth refusal removed from the rendering path, so the argv exists and `spawn_into` runs | `A CHILD RAN FOR AN INADMISSIBLE SHOCK. The marker at /tmp/gams24-tier-b-no-spawn/the-child-ran exists after driving run_prover at txlVolumeRate = 82803, which the prover's own ellipse refuses (E = 4991723980281000000000000 > 0). The stub's entire body is that touch, so its presence means execve happened -- and the ninth refusal is supposed to make the argv nonexistent, not merely unused.` / `Outcome: Aborted NoArtifact at exit 0 (run dir "/tmp/cfmm-gams-run-42")` |
| 17 | `the_splitter_holds_no_IO_and_names_no_process` | `import System.Process (readProcess)` added to `Fee/Split.hs` | `the fee splitter names a process spawn, the unsafe-IO escape hatch, an IO action or an environment reader.` / `offchain/lib/Fee/Split.hs:85:import System.Process (readProcess)` |
| 18 | `the_seeded_pick_is_a_pure_function_of_seed_and_band` | a `split_for` that discards its seed argument | `the split records fs_seed = 0 and was handed 7. A split_for that DISCARDED its seed argument returns the same pair twice and passes every determinism arm above; this is the arm that notices.` |
| 19 | `a_different_seed_produces_a_different_rho` | a `pick_from_band` returning the FIRST band member | `the eight pinned seeds select 1 DISTINCT pair(s) at f = 3000: [(1,2999)].` |
| 20 | `the_admissible_band_has_more_than_one_member` | `delta* = 1000` substituted for the empty case | `admissible_band 3000 1000 is [(1,2999),(2,2998)] with size 2, and it must be EMPTY. The research and the plan both name delta* = 1000 as the empty input; MEASURED, that one has TWO members -- [(1,2999),(2,2998)] -- because the 4 those documents quote is the count WITHOUT the m > x restriction. 200 is the empty one.` |

**No guard added by this plan lacks an observed firing.** Checks 13a and 13b are reported separately
because the ORDER of arms inside a check is what makes them different guards.

### What the mutations also taught, recorded rather than smoothed over

- **The `distinct_fees` deletion was observed in BOTH halves at once, which is the whole point.**
  The refusal SURVIVED — the shock came back as
  `Inadmissible 6000 6000 490000 18944769600000000000000000000 Nothing`, so nothing was suddenly
  rendering and the refusal COUNT did not move — while check 14 reddened naming the constructor.
  That is this phase's named failure mode exhibited: a diagnosis lost with the arithmetic unchanged.
  Phase 24's `argv_rendering_is_canonical_and_total` reddened beside it, because its refusal battery
  asserts the field name; recorded so a future reader does not mistake it for collateral.
- **A boundary constant that SPELLS the right answer survives the string test.** Mutation 13b used
  `Just 828040`, which contains `"82804"` as a substring. The naming arm PASSED. Only the
  recomputation arm fired. A check that had asserted the message and stopped there would have been
  green on a refusal carrying a boundary an order of magnitude wrong.
- **Check 19's cardinality arm short-circuits at `f = 3000`, so the `f = 6497` collapse is not in
  the failure text.** It was measured separately under the same mutation rather than inferred:
  `[(1,2999)]` at 3000 and `[(1,6496)]` at 6497 — one distinct pair at BOTH fees, which is what the
  plan asks to observe.
- **Every mutation that touched `Gams/Argv.hs` also reddened `gams_conformance_is_present_and_fresh`
  by digest**, exactly as 26-02 recorded. That is the freshness oracle doing its job and it is why
  finding 1 below exists.

## The two research corrections this plan CONFIRMED by measurement

1. **RC-M6 — the firing number is 2, not 4.** `admissible_band 3000 1000 == [(1,2999),(2,2998)]`,
   measured twice: once outside the suite in an independent reimplementation, once by the check's
   own failure message under mutation 20. The 4 is the count of BOTH orientations —
   `(1,2999)`, `(2,2998)`, `(2998,2)`, `(2999,1)` — and `admissible_band` keeps only `m > x`, so it
   describes a band the function does not return. `26-03-PLAN.md:178`'s table row and
   `26-VALIDATION.md:232` are both corrected in this plan's docs commit, with the verbatim failure
   text quoted in each. The check asserts the corrected value directly, so it cannot drift back into
   prose.
2. **The empty input is `delta* = 200` and the singleton is `delta* = 500`.** Both are asserted BY
   VALUE — `admissible_band 3000 200 == []` with `split_for 0 3000 200 == Left (EmptyBand 3000 200 0)`,
   and `admissible_band 3000 500 == [(1,2999)]` with `fs_band_size == 1` on the split it produces. A
   size arm alone passes on the wrong members.

The third correction the plan asks about — CORRECTION B's floor rounder — belongs to 26-01 and was
OBSERVED there (`26-01-SUMMARY.md`, "CORRECTION B, OBSERVED rather than argued"). Nothing in this
plan's subject matter re-exercises it, and it is cited rather than re-claimed.

## Deviations from Plan

### 1. `[NEW — found here, and the plan has no step for it]` Editing `Gams/Argv.hs` invalidates the GAMS conformance capture, and the capture had to be RE-TAKEN

`26-03-PLAN.md`'s `files_modified` lists `offchain/lib/Gams/Argv.hs` and its verification block says
nothing about the conformance artifact. But `gams_freshness_subjects` (`Main.hs:10454`) is exactly
`["offchain/lib/Gams/Argv.hs", "offchain/lib/Gams/Artifact.hs"]`, and
`gams_conformance_is_present_and_fresh` recomputes both digests from disk on every run. The first
green build of task 2 produced:

```
FAIL gams_conformance_is_present_and_fresh: the committed GAMS conformance capture is STALE.
These modules have been edited since it was taken:
```

26-02 predicted this in its own ledger ("the eighth-token mutation reddens
`gams_conformance_is_present_and_fresh` too, by digest, in every case where `Gams/Argv.hs` was
touched") and no plan of this phase acts on it.

**The artifact was RE-TAKEN against the real toolchain, not hand-edited**, which is the only honest
fix — the recorded digest is the capture's claim about which code produced its byte measurements,
and rewriting it by hand would make every one of those measurements a claim about code nobody ran.

```
CFMM_REQUIRE_GAMS=1 \
GAMS_BIN=/usr/gams/gams54.1_linux_x64_64_sfx/gams \
GAMS_MODEL=/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms \
  bash offchain/rig/capture-gams-conformance.sh
```

**exit 0, 9/9 verdicts pass.** The full diff of the artifact against its predecessor, with
`generatedAt` projected out, is THREE fields:

| field | before | after |
|---|---|---|
| `argv_module_sha256` | `e7475dd7…6e0409` | `37e4dc3b…3bee61` |
| `no_args.line1` | `… Start 08/16/26 23:12:16 …` | `… Start 08/17/26 15:17:20 …` |
| `version_flag.line1` | `… Start 08/16/26 23:12:17 …` | `… Start 08/17/26 15:17:20 …` |

Everything else is byte-identical, and that is a measurement worth more than the fix it was made
for: **with the ninth refusal installed, the real GAMS 54.1 still produces the committed golden
artifact at `e7b14f38..07d0d884`**, `action=c` still exits 0 writing nothing, the leading-zero token
still moves the bytes to `d64a7b32..14b9e650`, and all three environment runs still land on the
golden digest. The model file's own digest was unchanged (`79940449…ca53ad`), so the two captures
are comparable.

### 2. `[BLOCKER B1 — findings]` `split_for`'s step 0, and the ordering clause the finding attaches to it

The finding's fix shipped verbatim in effect: `split_for` tests `fee_in_domain f` **before**
`admissible_band` is ever called, because that enumeration reaches `x = 1000000` for every
`f > 1000000` and `nearest_partner` then divides by zero — an exception no `Either` can carry.
Verified as a value rather than argued:

```
split_for 0 8388608 490000  ==  Left (FeeOutOfDomain 8388608)
```

and 8388608 is `LPFeeLibrary.sol:15`'s `DYNAMIC_FEE_FLAG` arriving in `PoolKey.fee`, not a fee of
8388608 pips — this repository's own DynamicFeeHook track produces that class of pool.

**On the ordering clause the finding attaches ("it must not preempt `distinct_fees`' specific
diagnosis for in-domain equal fees"): the two cannot collide, and the reason is written into the
haddock rather than defended against.** Step 0 tests `f`, the POOL fee. It says nothing about the
two legs, and an in-domain request with equal legs never reaches `split_for` as a pair at all —
the legs are what `split_for` DERIVES. The caller-supplied pair is diagnosed in `Gams.Argv`, and
there the equal-fee refusal does run before the ellipse. Measured end to end: an in-domain
`(3000, 3000)` shock comes back as
`FieldOutOfRange "phiXpips" 3000 "…VOLUME_PATH.md section 1.2…"`, never as `FeeOutOfDomain` and
never as `Inadmissible`.

**26-01's measured boundary disagreement is CARRIED, not silently resolved.** v4's own `isValid`
admits `f = MAX_LP_FEE = 1000000`; `fee_in_domain` does not, because at a 100% pool fee the only
partner of any `x` is `m = 1000000`, which is not a leg fee in `[1, 999999]`. The two bounds look
identical and differ by one. The domain was NOT widened to match v4, and the reason is stated at
`fee_in_domain`.

### 3. `[PLAN ERROR]` `ResidualTooLarge`'s argument order in the plan contradicts the shipped constructor

`26-03-PLAN.md:239` specifies `Left (ResidualTooLarge x m f r)`. 26-01 shipped
`ResidualTooLarge Integer Integer Integer Integer` haddocked as *"the pool fee, `phi_x`, `phi_m`,
and the residual"*, and `refusal_message` destructures it as `ResidualTooLarge f phi_x phi_m residual`
and renders *"the pair (phi_x, phi_m) pips composes to a fee that misses f pips by …"*. Following
the plan would have produced a refusal whose sentence named the fee as a leg and a leg as the fee,
with nothing type-checking differently — four `Integer`s in a row. **The shipped order is used:**
`Left (ResidualTooLarge f x m r)`.

### 4. `[PLAN DESIGN — improved]` Steps 1 and 2 are ONE test, and the impossible `Nothing` gets a named constructor rather than a message nobody could write

The plan specifies step 1 (`if null band then Left (EmptyBand f dstar 0)`) and step 2
(`pick_from_band`, with an explicit `Left` for a `Nothing` that "cannot happen here"). But
`pick_from_band` returns `Nothing` **exactly** when the band is empty — that is its contract and its
haddock — so the two tests are the same test, and the step-2 branch would need a refusal message for
a state that cannot exist. Merged:

```haskell
let band = admissible_band f dstar
in case pick_from_band seed band of
     Nothing -> Left (EmptyBand f dstar (length band))
```

`length band` is `0` on that branch by construction, so the refusal is exact rather than invented —
and if it ever printed anything else, that number is itself the diagnosis.

The step-4 `Nothing` is genuinely impossible and genuinely needs a name. The plan says "an
internal-inconsistency `Left` … rather than a `fromMaybe` default" and does not say which
constructor. None of 26-01's five fits: the pair is INSIDE the ellipse there, so `OutsideEllipse`
would lie about which fact failed. **A sixth constructor was added,
`NoBoundaryForAnAdmissiblePair Integer Integer Integer`**, whose message says the two functions
disagree and that this is an inconsistency inside the splitter rather than a fact about the input.
The justification is RC-M4, verbatim: the bisection specified for this module DID return `Nothing`
on the admissible pair `(99, 101)`, and under a `fromMaybe 0` that split would have shipped carrying
a boundary nobody measured, with nothing red. `the_seeded_pick_is_a_pure_function_of_seed_and_band`
now also asserts `fs_boundary_pips <= fs_dstar_pips`, which is the same disagreement caught from the
outside.

### 5. `[RC-B3 — checked, and it does NOT bite this gate]` The `BADDEPS` collision was measured before being relied on

The prompt and RC-B3 both warn that `26-03-PLAN.md:252`'s `BADDEPS` pattern carries a bare `sqrt`
that matches `sqrtPriceX96` on 13 lines. **RUN before being relied on, on the actual scanned set:**
that gate scans `offchain/lib/Fee/Split.hs` **only**, and that file contains no `sqrtPriceX96`. The
unanchored pattern prints `0` there, exactly as the anchored one does. Both readings are in the
gate table above.

The collision is real, and it is real for a DIFFERENT gate: `no_floating_value_is_on_the_fee_path`
scans `artifact_float_path`, which includes `Gams/Argv.hs`, `Gams/Artifact.hs` and `Gams/Run.hs` —
the 13 lines. 26-01 word-anchored `fee_float_pattern` for that reason and it is still anchored. The
shipped `BADDEPS` reading here is the word-anchored one, for consistency with the check that
actually enforces it, but **the finding's premise does not hold for this particular gate and saying
otherwise would be repeating a claim without measuring it.**

### 6. `[PLAN ERROR — small, and it changes what was actually observed]` Check 16's stated firing input is a no-op

`26-03-PLAN.md:406-407` says: *"move the ninth refusal to AFTER the token list is built (so the argv
exists and `spawn_into` runs) and observe the marker PRESENT."* In an `Either` do-block the bind
runs before the value is returned regardless of where the token list is constructed, so moving the
call below the list changes nothing at all — `render_argv` still returns `Left` and no argv exists.
**The only mutation that produces an argv for an inadmissible shock is one that takes the gate off
the rendering path.** That is what was applied, and the marker was OBSERVED present with the run
directory `/tmp/cfmm-gams-run-42`. The plan's intent is honoured; its mechanism is not achievable as
written.

### 7. `[26-02 handoff, discharged]` `an_all_zero_payload_is_rejected`'s arm 2 was REWRITTEN, not deleted

26-02 wrote that arm with instructions inside its own failure text: *"If that bound has since been
raised to 1, this arm has done its job and should be REWRITTEN to assert the refusal — not
deleted."* The bound was **not** raised; the ninth refusal took the case instead. The arm now
asserts `Left (Inadmissible x m 0 _ _)` at the fixture's own pair, and has a dedicated
`FieldOutOfRange` branch that reddens with *"a range refusal here means the bound WAS raised, which
puts two answers to one question in two places that can drift apart. Pick one."* Its firing was
OBSERVED under mutation 12 (the ninth refusal deleted).

The check's haddock is rewritten to say what is now true without erasing what was true: RC-M3's
claim was **false when 26-02 measured it** — there were eight refusals and the lower bound was zero
— and 26-03 then added the ninth, so the finding's premise became true only after this commit and
in the opposite order from the one the finding assumed. The `ZeroShock` consumer rule is unchanged
and still load-bearing.

### 8. `[Consequence]` Two stale sentences in `Store/Key.hs`, corrected

`Store/Key.hs:10` and `:287` both counted `render_argv`'s refusals as **eight**. `:287` is now
"the NINE range, model and admissibility refusals", with a sentence recording that inheriting rather
than restating the list is what made the ninth free — a copy of the refusal list there would have
had to be found and updated, and missing it means a key computed for a shock that can never be run.

`:10` is a MEASUREMENT (25-RESEARCH M1's 343-tuple collision sweep) and was **not** restated as
nine, because the sweep was not re-run: whether either colliding tuple survives the ninth refusal is
unmeasured, and the line now says exactly that rather than asserting a number nobody measured.

### 9. `[Scope]` One small simplification in `in_range`

`txlVolumeRate`'s upper bound is now `pips_denominator - 1` rather than a second literal `999999`.
The rendered message is byte-identical (`render_decimal` prints `999999` either way) and the
constant is stated once. **The lower bound stays at `0`, deliberately** — the plan, 26-02 and the
findings all agree that a second bound beside the model's own test is a thing that can drift, and
the ninth refusal is what refuses a zero rate.

### 10. `[RC-m11 — closed rather than carried]` Three unread `FeeSplit` fields now have a reader

26-01 reported that seven of `FeeSplit`'s twelve fields were asserted by no check in any plan of this
phase. Check 15 reads `fs_pool_fee_pips`, `fs_dstar_pips`, `fs_realized_scaled`,
`fs_residual_scaled` and `fs_is_exact`; check 18 reads `fs_ellipse_e`, `fs_boundary_pips`,
`fs_seed` and `fs_splitter_version`; check 20 reads `fs_band_size`. **All twelve fields are now read
by a check.** `fs_ellipse_e` and `fs_boundary_pips` are asserted against `Fee.Split` recomputed at
the split's OWN pair and target, not against constants.

### 11. `[NEW — found here, and it corrects the standing guidance]` `gsd-tools state record-metric` is NOT safe on this STATE.md, and it is the SEVENTH occurrence

26-02's own recorded note, and this plan's execution brief, both list `state record-metric`,
`roadmap update-plan-progress` and `requirements mark-complete` as the three SAFE commands, with
only `state update-progress` and `state advance-plan` forbidden. Running the three in sequence
rewrote the frontmatter to `milestone: v2.0`, `milestone_name: milestone`, a `status:` line made of a
stray prose fragment from the body, `25` phases / `50` plans / `48` complete, and reverted
`stopped_at` and `last_activity` to older values.

**BISECTED, one command at a time on a scratch copy, checking line 3 after each:**

| command | `milestone` after |
|---|---|
| `state record-metric --phase 26 --plan 99 …` | **`v2.0`** |
| `roadmap update-plan-progress 26` | `v6.0` |
| `requirements mark-complete FEE-01` | `v6.0` |

**`record-metric` is the culprit; the other two are genuinely safe.** The metrics row it appends is
correct and worth having, and it also writes the duration without the `min` suffix every other row
carries. The rule recorded in STATE.md is therefore: run it, then restore the frontmatter by hand
and fix the units. The frontmatter and the metrics row were both repaired by hand here, and the body
— including this plan's Current Position block — survived untouched.

### 12. `[Beyond the plan's requirement list]` FEE-02 marked complete

`26-03-PLAN.md`'s `requirements` field is `[FEE-01, FEE-03, FEE-04]`. FEE-02 reads: *"The pair
satisfies the prover's own admissibility test, transcribed from `volume_path.gms:100-108` and
checked **before the solver is invoked**."* 26-01 shipped the transcription and claimed FEE-02 in
its summary frontmatter, but did not mark it in `REQUIREMENTS.md` — and the second clause had no
implementing task until this plan, because there was no place the check ran before an invocation.
It now does, and mutation 16 OBSERVED the invocation not happening. Marked complete here rather than
left pending against a clause that is satisfied.

## What actually shipped

### `Fee.Split`, +4 exports and +1 refusal constructor

| Function | What it is |
|---|---|
| `admissible_band f d` | every `(x, nearest_partner f x)` with `m > x` and admissible at `d`, ASCENDING in `x`. 44 / 224 / 1344 / 2900 / 4447 at `d = 490000` for `f = 100 / 500 / 3000 / 6497 / 10000`; `[(1,2999)]` at `(3000, 500)`; `[]` at `(3000, 200)`; `[(1,2999),(2,2998)]` at `(3000, 1000)` |
| `mix64` | the splitmix64 finalizer, five lines, constants in DECIMAL, every intermediate masked to 64 bits. `mix64 0 = 16294208416658607535` |
| `pick_from_band s b` | `Nothing` exactly when `b` is empty, else `b !! (mix64 s mod length b)` — a pure function of `(s, b)` |
| `split_for s f d` | domain, band+pick, residual alarm, boundary, record. Six refusals reachable |
| `NoBoundaryForAnAdmissiblePair` | the impossible `Nothing` from `min_admissible_dstar`, named rather than defaulted |

### `Gams.Argv`, the ninth refusal

| # | Refusal | Subject |
|---|---|---|
| 1–7 | `in_range` | `sqrtPriceX96`, `liquidityRaw`, `txlVolumeRate`, `phiXpips`, `phiMpips`, `volTgtWad`, `nEvents` |
| 8 | `distinct_fees` | `VOLUME_PATH.md` §1.2 — equal legs |
| **9** | **`admissible_pair`** | **`volume_path.gms:100-108`'s `ellTest`, in exact `Integer` arithmetic** |

`Inadmissible Integer Integer Integer Integer (Maybe Integer)` — both legs, the target, the exact
`E`, and the boundary recomputed by `min_admissible_dstar`. Its one non-`base` import is
`Fee.Split`.

## Structural facts held

- Both structural greps over `offchain/test/Main.hs` are **0** (`DBFREE`, `GAMSFREE`).
- `core_checks` is the sole registration point; all nine names are defined AND registered.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is **empty**.
  `develop` was never merged; `LPFeeLibrary.sol` and `PoolKey.sol` were read from the vendored `lib/`
  tree in place.
- The four pre-existing untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock`) were left alone.
- No file written by this plan contains a NUL byte.
- No orphaned stub process survives the suite.
- The Tier-B check's POSITIVE CONTROL is textually FIRST in the check body, before the marker is
  deleted and before the subject runs. Its failure text, verbatim: *"The harness spawned nothing at
  all, so \"the marker is absent\" below is satisfied by a harness that ran nothing -- which is this
  repository's entire defect class and the reason this arm is evaluated first."*

## Open, and named

1. **The line-number ordering evidence EXPIRES at 26-04.** `distinct_fees` is called at
   `Gams/Argv.hs:206` and `admissible_pair` at `:207`, in one do-block. 26-04 splits this function
   and the two calls then live in different functions where that comparison means nothing. **The
   durable gate is check 14's constructor arm**, which was OBSERVED firing and which reddens under
   the inverted composition while the refusal count stays unchanged.
2. **`26-04` must re-take `gams-conformance.json` too** if it edits `Gams/Argv.hs`, which its
   `render_argv_ungated` split necessarily does. The command and the environment are recorded in
   finding 1. It costs about 40 s and needs the sibling `cfmm-wt/gams` worktree on disk.
3. **SC-1's store half is still open.** The derived pips reaching the content KEY has no
   implementing task in phase 26; the argv half is asserted here and the gap is stated in
   `Fee.Split`'s module haddock.
4. **Which two on-chain fields `(phi_X, phi_M)` are realized in is still undecided** (M5). The
   pinned `f = 6497` seed-0 result `(1036, 5467)` exceeds v4's `MAX_PROTOCOL_FEE` of 1000 pips on
   both legs. `admissible_band` is unbounded on purpose and says so.
5. **`splitter_version` still has no consumer.** Phase 25 executed first and imports nothing from
   `Fee.Split`. Check 18 asserts the field round-trips into the record; nothing outside the splitter
   reads it. Recorded as the same named carry-forward 26-01 made.
6. **An untracked `.planning/SPIKE-end-to-end.md` appeared in the worktree during this execution**
   (timestamped 15:19, `runs_after: 26-03`). It was not written by this plan and was left untracked
   and unedited.

## Self-Check: PASSED
