---
phase: 26
slug: shock-assembly-fee-split-event-decode
kind: review-findings
status: binding-on-execution
created: 2026-08-17
reviewers:
  - "Solidity Smart Contract Engineer (EVM domain) — COMPLETE"
  - "Reality Checker (evidence gate) — pending, appended below when it lands"
---

# Phase 26 — Reviewer Findings, Binding on Execution

> **These are executor constraints, not planner input.** By user ruling 2026-08-17 the plans are
> NOT revised again; the executor implements the plan AND these findings together. Where a finding
> contradicts a plan step, the finding wins and the deviation is recorded in the task's summary.
>
> Every claim below was verified against source — the vendored v4 contracts in `lib/`, the emitter
> at `341e409`, and `cast` — not inferred. Provenance is given per finding so the executor can
> re-check rather than trust.

---

## BLOCKER

### B1 — `Fee.Split` is not total on `f`; the v4 dynamic-fee sentinel divides by zero

**Owner: `26-01` Task 1 (`nearest_partner`, `SplitRefusal`), `26-03` Task 1 (`admissible_band`, `split_for`).**

`nearest_partner f x` divides by `(D − x)`. `admissible_band` enumerates `x ∈ [1, f−1]`, so it
reaches `x = 1000000` for **every `f > 1000000`**. Nothing bounds `f`, and `SplitRefusal`
(`EqualFees | OutsideEllipse | EmptyBand | ResidualTooLarge`) has no constructor that could carry
the refusal. The result is an **exception, not a `Left`**.

**The falsifying input is a real production value, not a hypothetical.** VERIFIED in this repo:

| Fact | Source |
|---|---|
| `DYNAMIC_FEE_FLAG = 0x800000` (= 8388608) | `lib/…/v4-core/src/libraries/LPFeeLibrary.sol:15` |
| `MAX_LP_FEE = 1000000` | `LPFeeLibrary.sol:25` |
| `isDynamicFee(self) => self == DYNAMIC_FEE_FLAG` | `LPFeeLibrary.sol:30-31` |
| "If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to `0x800000`" | `v4-core/src/types/PoolKey.sol:16` |
| `f = 8388608` reaches `x = 1000000` → `ZeroDivisionError` | reproduced 2026-08-17 |

A v4 pool whose hook sets the fee carries `0x800000` in `PoolKey.fee`. **This repo's own
DynamicFeeHook track produces exactly that class of pool.** Values in `(10⁶, 0x800000)` are quieter
and worse: they return `Right` a `FeeSplit` whose legs exceed 100%.

**Why this was easy to miss:** `0x800000 = 2^23` is *also* `26-02`'s `int24` tick bound. The same
number appears twice in the phase with two unrelated meanings.

**Required fix.** Add `FeeOutOfDomain Integer` to `SplitRefusal`. Make `split_for`'s **step 0**:

```haskell
unless (1 <= f && f < pips_denominator) $ Left (FeeOutOfDomain f)
```

placed **ahead of `admissible_band`** — and note this is ordering-sensitive in the same way the
ellipse gate is: it must not preempt `distinct_fees`' specific diagnosis for in-domain equal fees.
Add one check arm asserting `split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)`, with a
haddock naming the value as v4's `DYNAMIC_FEE_FLAG` and explicitly **not** an 8388608-pip fee.
**Firing input:** delete the guard, observe the exception rather than a `Left`.

---

## MAJOR

### M2 — The corpus has no independent oracle for the DATA-WORD layout; only topic0 has one

**Owner: `26-02` Task 2.**

topic0 is genuinely double-sourced and sound — `cast keccak` transcribed into `ground_truth` vs
`web3-crypto`'s keccak recomputed in-suite. Two implementations, one value.

The **data layout has no second source**. `synthetic_log` builds words from hand-transcribed
constants (e.g. `2^256 - 200` for the negative tick) expressing the *same belief* the decoder is
tested for. If that belief is wrong — right-padding, or masking without sign-extending — the corpus
is green and 26-02's headline claim is a **tautology**. Check 7's range guards catch a transposition
*inside `decode_shock`*, never one in the model.

**Required fix.** Add one `ground_truth` row carrying this second ABI coder's output:

```
cast abi-encode "f(int24,uint24,uint24)" -- -200 490000 7
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff38
0000000000000000000000000000000000000000000000000000000000077a10
0000000000000000000000000000000000000000000000000000000000000007
```

as one 192-char **bare** hex string (purge-safe: `0x[0-9a-fA-F]{64}\b` cannot match inside a
192-char run, and bare is the block's convention). Assert it equals the `negative-tick-and-decay`
member's `changeData`. **Firing input:** transpose words 1 and 2 in the **corpus** and watch it
redden — which nothing does today.

**Also cite the fixture the plans overlooked.** `test/models/mev_tax_model_one/shock/ShockRoundTrip.t.sol`
already round-trips against the **real emitter** — `assertEq(logs[0].topics[0], SHOCK_TOPIC0)`, then
`abi.decode(logs[0].data, (int24,uint24,uint24))`, and `test__unit__emit_negativeTick_signAwareData`
asserts `int24(-100)` round-trips. It is READ-ONLY territory: cite it as corroboration, never edit it.

### M3 — `AllZeroPayload` refuses a legal, meaningful production log

**Owner: `26-02` Task 1 + check 3.**

Issue #28: all three data words are always present, absent components emitted as `0`; v6.0 tags
`flags = 0b010`, so `tickDiff == 0` and `txlVolmDecay == 0` always. The only thing making a
production log non-all-zero is `txlVolmNormRate != 0` — and that is δ_trans, a rate in `[0,1]` pips.
**A period with no transactional volume gives δ_trans = 0**, producing a well-formed log whose 96
bytes are all zero. `decode_shock` returns `Left AllZeroPayload`, indistinguishable from corruption.

The refusal also buys nothing downstream: `render_argv`'s ninth refusal already kills
`txlVolumeRate = 0` for free, since `E(x,m,0) = D⁴xm > 0` (algebra checked). Net effect is to
collapse "quiet period" into "corrupt log".

**Required fix — pick one and write it down.** Either (a) rename the constructor `ZeroShock` and
haddock the consumer rule (Phase 27 treats it as a no-shock **skip**, never a decode alarm), or
(b) obtain an issue-#28 ruling that δ_trans is strictly positive by construction and cite that
ruling as the guard's provenance. Today the haddock cites `flags = 0`, the **rarer** of the two ways
to reach it. **(a) is the cheaper call and does not block on upstream.**

### M4 — The decoder discards block, log-index and emitting address

**Owner: `26-02` Task 1 + Task 2.**

`ShockEvent` is `(se_pool, se_tick_diff, se_norm_rate, se_txl_decay)`. `Change` carries
`changeBlockNumber`, `changeLogIndex`, `changeTransactionHash`, `changeAddress`; `decode_shock`
drops all four and the return type **cannot carry them**. Decode a batch and you get N `ShockEvent`s
with no way to say which block each came from — the "silently mix state from two blocks" failure in
its purest form.

The repo already learned this and wrote it down. `RealizedVol/Decode.hs` haddock: *"only the log's
EMITTING ADDRESS separates them when both carry a real poolId. This module cannot see intent, so the
caller must additionally filter `changeAddress == DynamicFeeHook`. Said here because there is
nowhere else a caller is guaranteed to look."* `Chain.Shock` has no equivalent — and needs it more:
**an event topic is unauthenticated. Any contract can emit topic0 `0x21b0e4f8…` with any address in
topic1.** `pool /= 0` and `pool < 2^160` make a log well-shaped, not authentic.

The corpus cannot expose this: `synthetic_log` hard-codes `changeBlockNumber = Nothing` and one
`filler_address` for all 18 members, so no phase-26 check can observe address or block
discrimination even in principle.

**Required fix (cheaper option, consistent with the E3 precedent):** give `decode_shock` a second
argument `expected_emitter :: Integer` alongside `expected_topic0`, add a `WrongEmitter Integer`
constructor, and put the block-coherence obligation in the "MUST NOT BE TRUSTED ON" paragraph. One
corpus member with a wrong `changeAddress` is its firing input.

**Scope note:** phase 26 is chain-free by construction, so it breaks no pinning discipline of its
own — but it hands Phase 27 a type that has thrown the pinning information away.

### M5 — The chain's own rounding is not modelled, and the band ignores on-chain representability

**Owner: `26-01` Task 1 (haddock only — no behaviour change required).**

The algebra is **correct**: `compose_scaled x m = D(x+m) − xm` is exactly `D·[1 − (1−φ_X)(1−φ_M)]`,
and it matches how v4 charges two fees in series — `ProtocolFeeLibrary.calculateSwapFee` is
commented `// protocolFee + lpFee - (protocolFee * lpFee / 1_000_000)`. Sequential, not additive.

Two gaps:

1. **The chain FLOORS the product term; the splitter does not.** v4 computes
   `x + m − ⌊xm/D⌋`, so the realized swap fee is high by `frac(xm/D)` — up to a whole pip, **always
   in the same direction**. The phase's one-pip alarm measures only the splitter's own ±0.5 pip
   nearest-rounding error. `26-RESEARCH.md:928` names the Phase 27 reconciliation
   `compose(read pair) == pool fee`; that check will disagree by exactly this floor term and will
   read as a splitter bug. **One haddock sentence on `compose_scaled` now costs nothing.**
2. **The band never asks whether a leg is on-chain representable.** `admissible_band` enumerates
   `x ∈ [1, f−1]` uncapped, and no plan says which two on-chain fields `(φ_X, φ_M)` are realized in.
   v4's protocol fee is masked to 12 bits and capped at `MAX_PROTOCOL_FEE = 1000` pips. The pinned
   seed-0 result at `f = 6497` is `(1036, 5467)` — **both legs exceed 1000 pips**, so neither
   orientation is expressible as a v4 `(protocolFee, lpFee)` pair. Either the legs are not those
   fields — say which, in the `Fee.Split` haddock, in this phase — or a pinned fixture is
   unrealizable. Recording "open, and the band is unbounded on purpose" is an acceptable close.

---

## MINOR — fold in, do not track separately

- **m6 — the `int24` guard's POSITIVE half never fires.** Corpus has `most-negative-tick`
  (`-8388608`) and `tick-below-range` (`-8388609`), but no `+8388607` in-range and no `+8388608`
  out-of-range member. So `tick < 8388608` — the half that would catch a decoder applying a 24-bit
  mask, since the mask answer `16777016` exceeds it — is a standing assertion with no observed
  firing. **Two corpus rows.**
- **m7 — the topic0 trip-wire does not re-verify the on-chain CONSTANT.** The pin proves
  `keccak(sig) == ground_truth`; what decides whether the decoder ever matches a log is
  `SHOCK_EVENT_TOPIC0` (hand-written in `ShockLib.plk`) `== keccak(sig)`. They agree at `341e409`
  (verified), but that agreement is prose. One sentence in the trip-wire's failure text: on merge,
  re-verify the **constant**, not just re-home the pin.
- **m8 — `NotAnAddress` hard-codes the address-keyed family.** A poolId-keyed sibling writer exists
  (`UniswapV4MevTaxModelOneShocksWriterInterface.plk`, bytes32 key). `pool < 2^160` would reject
  every one of its logs. Correct for the signature #28 pins, and it fails loudly — not a defect. One
  haddock line so a future reader does not relax the guard.

---

## Verified SOUND — do not "fix" these

Checked against the emitter and `cast`; changing them would be a regression.

- **Event shape.** `@evm_log2(buf, 96, SHOCK_EVENT_TOPIC0, pool)` → exactly 2 topics, exactly 96
  bytes, word order `[tickDiff, txlVolmNormRate, txlVolmDecay]`. `address` left-padded in topic1.
  Matches `26-02`'s model exactly.
- **Sign extension.** The emitter ends `shock_tick_diff` with `@evm_signextend(2, raw)` and masks the
  two rates with `& MASK_U24`. So `signed_word` (threshold `2^255`) is right for word 0 and would be
  a silent bug on words 1–2 — `26-02` Task 1 says exactly this. Check 2 pins **both** wrong answers
  (`16777016` and `115792…639736`) as values the result must not equal. **Strongest check in the phase.**
- **Range bounds.** `-8388608 <= tick < 8388608` is `int24` exactly; `< 16777216` is `uint24` exactly.
- **Zero address.** `ZeroPool` refuses `0x00…00` in topic1, ordered before the length check. No guard
  in the phase accepts an all-zero word as valid.
- **`== 96` over `>= 96`.** A real improvement on the E1/E3/E5 precedent; `length-128` is the right
  discriminating fixture.
- **The u24-vs-pip domain gap is closed BY OBSERVATION.** Check 7's fourth arm decodes
  `rate-above-a-million` to `Right … 5000000`, then shows `render_argv` refusing it by field name,
  with a firing input. **This is the model the rest of the phase should follow.**
- **`ellipse_test x m 0 = D⁴xm > 0`**, so `δ* = 0` is refused without a second bound.
- **The decoy selector.** `3548543755 = 0xd3827b0b`, confirmed via `cast sig`. Building it from the
  decimal rather than spelling it is correct under the purge rule.

## A brief premise that was STALE — in the plans' favour

`next(address,uint160,int24,uint24,uint24)` is a **function selector** on
`AlgebraIntegralShocksWriterInterface.plk`, never an event. The plans already superseded it per
issue #28 and demoted it to a negative fixture. **There is no `uint160 sqrtPrice` in the event and
no `next` decoder.** Do not reintroduce one.

---

## Reality Checker findings

> This reviewer **drove the real GAMS 54.1 prover** on the plan's own pinned grid. Its B1 is
> MEASURED, not predicted, and it is the finding that decides whether phase 26 can execute as
> planned. It also recomputed every Tier-A number independently — all reproduced exactly.

### RC-B1 — The pinned Tier-C grid is UNREALIZABLE against the real prover. **Only 1 of 16 planned invocations behaves as the plan says.**

**Owner: `26-04` Task 2 and its `<pinned_grid>`.**

Run against `/usr/gams/gams54.1_linux_x64_64_sfx/gams` on the real `volume_path.gms`, at the plan's
own pinned `volTgtWad = 28e18`, `nEvents = 8`:

| pair | δ* | role | exit | reason |
|---|---|---|---|---|
| 500,6000 | 82803 | boundary−1 | 3 | ellipse abort ✔ *(as planned)* |
| 500,6000 | 82804 | boundary | 3 | **not the ellipse** |
| 500,6000 | 82805 | boundary+1 | 3 | **CONOPT infeasible** |
| 500,6000 | 291401 | **control** | 3 | **CONOPT infeasible** |
| 100,900 | 109768 | boundary−1 | 3 | ellipse ✔ |
| 100,900 | 109770 | boundary+1 | 3 | **CONOPT infeasible** |
| 100,900 | 304884 | **control** | 3 | **CONOPT infeasible** |
| 1000,3000 | 300360 | boundary−1 | 3 | ellipse ✔ |
| 1000,3000 | 300362 | boundary+1 | 3 | **CONOPT infeasible** |
| 1000,3000 | 400180 | **control** | 3 | **CONOPT infeasible** |
| 700,800 | 495952 | boundary−1 | 3 | ellipse ✔ |
| 700,800 | 495954 | boundary+1 | 3 | **CONOPT infeasible** |
| 700,800 | 497971 | **control** | **0** | **solves — the only one** |

**Every `boundary+1` row aborts. Three of the four controls abort.**

The plan's own escape hatch is measured NOT to work. `<the_control_is_what_makes_it_a_differential>`
says "raise `volTgtWad` for that pair until it solves." At `(500,6000), δ* = 82805`,
`volTgtWad ∈ {5.6e19, 1.12e20, 2.8e20, 1.4e21, 5.6e21, 2.8e22}` — **all six still abort**;
`nEvents ∈ {16, 32, 64}` at 2.8e20 — **all three abort**. The model's `u.lo/u.up = [1e-3, 1e3]` box
and the delta-floor coupling in its own header (`dStar = 0.49` needs `kappa >= 1.4980`) mean low-δ*
targets are unreachable at any volume this fixture admits.

**The measured solvable window for `(500,6000)` at 28e18:** δ* ∈ {300000, 350000, 400000, 450000,
470000, 480000} all **exit 3**; **490000 and 495000 exit 0**; 499000 exits 3. Window ≈ `[0.490, 0.4965]`.

That is exactly **`δ* = 490000` — SC-2's original 0.49**, which CORRECTION C deliberately removed
from the GAMS differential as adding "no verdict the boundary rows do not already carry." It is the
only δ\* in the plan the prover can actually solve.

As written, 26-04 Task 2's `BADCTL=0` fails (3 of 4) and `DISAGREE=0` fails on every admissible row,
whereupon the task routes that into "STOP, report as a phase BLOCKER — a disagreement is a bug in
one of them." **It is neither.** It is the volume/δ\* coupling the plan names for controls and then
does not design around for grid rows.

**Required fix — this is EXECUTOR work, and it comes FIRST in the plan's Tier-C task.** Before
pinning anything, sweep `(pair, δ*, volTgtWad, nEvents)` against the real prover and record which
combinations reach `exit 0`. Then build the grid from the measured solvable window. Put `δ* = 490000`
back into the differential. If no four-pair two-sided grid exists at `nEvents = 8`, say so in the
summary and either pick a per-pair `volTgtWad`/`nEvents` with the measurement recorded, or reduce the
grid to what the prover can answer — **and record the reduction rather than reporting a false
disagreement.**

### RC-B2 — `gams_admits` has no pinned derivation, so the differential can be Haskell-vs-Haskell — and GAMS is never observed REFUSING

**Owner: `26-04` Tasks 2 and 3 (check 22).**

`26-04-PLAN.md:296-309` specifies the artifact fields `gams_exit`, `gams_artifact_present`,
`gams_admits` but **never states how `gams_admits` is computed**. Check 22 asserts recomputed-Haskell
`== haskell_admits` **and** `== gams_admits`. If `FeeSplitConformance.hs` writes
`gams_admits = haskell_admits` — the most natural mistake, and exactly the "tautology where both
sides derive from the same expression" class — then `DISAGREE=0`, the jq gate passes, check 22
passes, **and no GAMS run is load-bearing at all**.

Worse, in the direction that matters:
- **No check asserts `gams_admits == (gams_exit == 0 && gams_artifact_present)`.** The only recorded
  GAMS observable is never tied to the recorded GAMS verdict.
- **No check asserts a `boundary − 1` row has `gams_exit /= 0`.** Check 22's only exit-code arm is
  the positive one. So the four rows where the prover actually refuses — the only place GAMS is ever
  seen rejecting anything — carry **no in-suite assertion about GAMS's behaviour**. A guard never
  observed rejecting is ABSENT.

**Falsifying input:** hand-edit the committed artifact so every `gams_exit` is `0`, leaving
`gams_admits` untouched. Checks 21–24 all stay green.

**Required fix:** derive `gams_admits` from `(gams_exit == 0 && gams_artifact_present)` in the
capture, pin that derivation in the plan text, and add BOTH arms to check 22 — the identity above,
and `gams_exit /= 0` for every `boundary − 1` row.

### RC-B3 — `26-01` Task 1 mandates haddock text its own gate forbids

`26-01-PLAN.md:283` requires the `ellipse_test` haddock to state *"the `rho >= 2+sqrt(3)` corollary
is FALSE"*. `26-01-PLAN.md:350` gates on
`grep -cE 'Double|Float|realToFrac|fromRational|Data\.Ratio|Rational|sqrt|System\.|unsafePerformIO' offchain/lib/Fee/Split.hs`
with `:356` requiring `FLOATS=0`. **The mandated string contains `sqrt`.** Task 1 cannot pass as
written. The same collision recurs at `26-03-PLAN.md:252` (`BADDEPS`), so it does not self-heal.

**Required fix:** move the corollary sentence to the *check's* haddock in `offchain/test/Main.hs`
(outside the scanned set) — how all 21 prior instances of this class were resolved. Prose is inside
a grep's blast radius; this is instance 22, authored into the plan rather than inherited.

### RC-M4 — The specified `min_admissible_dstar` bisection is WRONG, and no pinned input exercises the bad branch

`26-01-PLAN.md:288-302` specifies `hi = min vertex (D-1)` with `vertex` the **floor** of `−B/2A`,
then returns `Nothing` if `not (is_admissible x m hi)`. `E` is convex with admissible set `[r₁, r₂]`
centred on the real vertex `v`; when `ceil(r₁) > floor(v)` the algorithm returns `Nothing` while an
admissible integer exists in `(floor(v), r₂]`.

**Exact counterexample: `x = 99, m = 101`.** Real vertex `499974.996…` → `hi = 499974`;
`ellipse_test 99 101 499974 = 27201107960480676 > 0` → spec says `Nothing`. But
`ellipse_test 99 101 499975 = −12498937537499375 ≤ 0` → the true answer is `Just 499975`.

None of the six pinned pairs nor the four-pair grid hits this branch (swept 300 000 random pairs and
250 000 near-equal-gap pairs; `(99,101)` is the only hit for `x < 3000, gap < 60`), so check 5's
corpus **cannot** catch it. Blast radius: `fs_boundary_pips` (26-03 T1 step 4 turns an unexpected
`Nothing` into an internal-inconsistency `Left` — a legal split gets refused), the `OutsideEllipse`
boundary message, and check 13, which recomputes `min_admissible_dstar` on **both sides** — a
tautology blind to this.

**Required fix:** `hi = min (vertex + 1) (D − 1)`, or bisect on `r₁` via integer sqrt of the
discriminant. **Add `(99, 101) → Just 499975` to check 5's pinned corpus.**

### RC-M5 — SC-1's "the derived pips reach the key" has no implementing task, and the ordering makes one impossible

The phase asserts only the **argv** half (26-03 check 15). No plan touches `Store.Key`,
`Store.RunLog` or `key_scheme`; `files_modified` across all four plans contains no `Store/*`.
`26-01-PLAN.md:309-311` claims `fs_seed`/`fs_splitter_version` are *"exactly what Phase 25's run log
and `key_scheme` consume"*, and `26-04-PLAN.md:643` requires the close to confirm *"Phase 26 owes
Phase 25 nothing else."* **But Phase 25 executes FIRST** — so when 25 builds `Store.Key`, `Fee.Split`
does not exist and cannot be imported. Phase 26 then adds two record fields no consumer reads.

This is the phase-25 STORE-02/03 shape exactly: assertions with no implementing task.
ROADMAP:1288-1289 does soften it (adding `splitter_version` later is non-destructive via
`key_scheme`) — **so say that instead of claiming the debt is settled.** Replace the "owes nothing
else" line with a named carry-forward citing ROADMAP:1288-1289.

### RC-M6 — `26-03` check 20's required firing observation names a number that will not appear

`26-03-PLAN.md:209-211` defines `admissible_band` with `m > x` (ρ > 1). `:448-449` requires using
`δ* = 1000` as the empty case and *"watch this check redden with the measured size 4."*
**MEASURED: `admissible_band 3000 1000 == [(1,2999),(2,2998)]`, length 2.** The failure message will
print `2`; `4` is the *unrestricted* count. `26-03-PLAN.md:178`'s own table is internally
contradictory on this ("band size (ρ>1)" / "4 (2 under ρ>1)"), and `26-VALIDATION.md:232` repeats
the 4. **Use 2.** Correct both documents at the same time.

### RC-M7 — CHAIN-04's payload layout has no independent oracle, and check 10's trip-wire is structurally unfireable here

Independently corroborates the Solidity reviewer's **M2**. topic0 IS genuinely independent
(in-suite `keccak256` vs a `cast`-measured bare-hex row, plus a perturbed-signature cross-check) —
reproduced. But **word order, exact-96 length and sign-extension all come from one reading of
`ShockLib.plk`**, which `26-02-PLAN.md:112` confirms is not in this worktree
(`git ls-tree -r origin/develop | grep -c models/mev_tax_model_one` = 0, verified). Encoder and
decoder are the same mistake twice.

Additionally: check 10 (`the_upstream_shocklib_pin_is_a_live_trip_wire`) has as its subject
`doesFileExist "src/models/mev_tax_model_one/libraries/ShockLib.plk"` — **zero hits on
`origin/develop`**, reachable only via a merge nobody in this phase controls. It is permanently
satisfied-by-absence, and its "mandatory positive control" proves only that `doesFileExist` can see
a file that exists — nothing about whether the subject can ever become true. That is the
zero-address-passing-a-hex-shape-guard pattern one level up.

**Required fix:** add the `cast abi-encode`/`abi-decode` payload fixture (see Solidity **M2** above —
the two reviewers converged on this independently), and either give check 10 a subject that can
become true in this worktree or re-scope it to "assert the merge has not landed" with that
limitation written into its failure text.

### RC-M8 — The sentinel-sweep wall budget is wrong in KIND, not just magnitude

`26-VALIDATION.md:101-102` reasons from "phase 23's 134-leaf artifact added 793 pairs and ~19 s."
But `sentinel_falsification_harness` (`Main.hs:6129-6316`) re-runs the **whole** `core_checks` list
once per pair. The 19 s benchmark was 793 pairs over a `core_checks` of ~100; after 25 (+~43) and 26
(+31) it is ~190. So the new ~720 pairs cost ~1.65× more each than the benchmark implies **and the
existing 3828 pairs each also pay the +31** — the dominant term, which the budget never mentions.
The 400 s narrow-trigger and 900 s stop are real gates so this is recoverable at execution, but
**`sentinel_pair_floor` (3828, `Main.hs:6077`) is the number that will surprise.** Re-measure; do not
reason forward from the 19 s figure.

### RC minors

- **m9** — `26-01:310` and `26-03:421` cite **ROADMAP:1202** for `fs_seed`/`fs_splitter_version`.
  Line 1202 is `#### ✅ ISSUE #29 CLOSED`, a Solidity test attaching to a live pool. Correct anchor:
  **ROADMAP:1288-1289**. An executor following the instruction writes a false citation into haddock.
- **m10** — `26-VALIDATION.md:55-59` says ROADMAP still claims "fully parallelizable with 23-25" and
  appoints itself the authority. **Commit `e19e5e7` already fixed ROADMAP:969-970.** The note is
  stale and now misdescribes the file it corrects.
- **m11** — Seven of `FeeSplit`'s twelve fields (`fs_pool_fee_pips`, `fs_dstar_pips`,
  `fs_realized_scaled`, `fs_is_exact`, `fs_ellipse_e`, `fs_boundary_pips`, `fs_band_size`) are
  asserted by **no check in any plan**. In a repo whose rule is "a leaf nothing reads is a claim that
  survived the phase unasserted," an unread record field is the same shape.
- **m12** — `26-04:293` requires `complete: true` be written **last** and atomically, but the
  artifact is a single JSON document — "written last" is not observable in the committed file and no
  check distinguishes it. The real guarantee is the atomic rename; say that instead.

### What the Reality Checker verified as SOUND

Every Tier-A number recomputed independently and matched exactly: `compose_scaled 500 6000`,
all four `ellipse_test` values, all six `min_admissible_dstar` rows, `exact_pairs_for`, band sizes
44/224/1344/2900/4447, the residual extrema, all eight mixer indices at both fees, CORRECTION B's
`m+2` minima, `E == D⁶·ellTest` in sign and value **on 20 000 random triples**, the four parabola
vertices, and topic0. The `volume_path.gms:100-108` citation is correct. The residual bound is
analytically right: `residual = (D−x)(m − m_exact)`, so nearest rounding gives `|residual| ≤ (D−x)/2`
— **the 2× headroom claim is correct** and the 10³ figure is correctly labelled a band minimum. The
31-check arithmetic matches, the `BASE + N` discipline is the right fix, and both file floors are
`>=` (`Main.hs:1141`, `Main.hs:7703`) so adding files does not redden them mid-plan.

**The corrected fee-split derivation is right. `c6c2646` fixed a real bug and the fix holds.**
