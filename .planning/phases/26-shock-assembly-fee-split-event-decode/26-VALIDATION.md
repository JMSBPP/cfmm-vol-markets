---
phase: 26
slug: shock-assembly-fee-split-event-decode
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-17
---

# Phase 26 — Validation Strategy

> **Authoritative source:** `26-RESEARCH.md` `## Validation Architecture` — a 29-row
> requirement→test map (all five IDs) and a 39-row guard→firing-input table. Every value it marks
> MEASURED was computed on this machine.
>
> The **Per-Task Verification Map** is filled after `gsd-planner` runs. Marked pending rather than
> left with template placeholders — phase 24 shipped an unpopulated template and the plan checker
> correctly blocked on it.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner in `offchain/test/Main.hs` (11,187 lines, one file, one runner) |
| **Registration point** | `core_checks` — **a check not in this list does not exist** |
| **Quick run** | `cabal build --enable-tests -j all` |
| **Full suite** | `cabal test` |
| **Baseline (measured cold 2026-08-17)** | **151/151**, exit 0, wall **149.5 s** — **PRE-PHASE-25 and therefore a HYPOTHESIS.** Phase 25 executes FIRST and adds ~43 checks to this same suite; every phase-26 gate is `BASE + N` against a BASE re-measured at that wave's start. See "Serial ordering with phase 25" below |
| **Runtime budget** | **900 s ceiling.** Record wall before/after; the sentinel harness pays each added check ~3828 times, over a `core_checks` phase 25 has already grown. Wall is RE-MEASURED at each wave's start, never compared to 149.5 s |
| **Hard gates** | zero `-Wall` warnings; **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** |
| **Chain / DB / GAMS** | **Exactly ONE clause of ONE requirement is Tier C** (FEE-02's agreement with the prover). Everything else is Tier A/B and stays out of `cabal test`. Both structural greps remain **0** |
| **New test file** | **None** |

### Tiers

- **A — pure.** The splitter's arithmetic, the admissibility predicate, the decoder against
  synthetic logs. This is most of the phase.
- **B — stubs.** FEE-03's "the solver is never spawned" is a real **marker-stub observation**, not
  merely a structural argument — the GAMS-free grep forbids `Gams.Invoke`, **not** `Gams.Run`, so
  the IO edge can be driven and observed *not* firing.
- **C — committed capture.** FEE-02's grid agreement with the real prover, captured out of band.

---

## Serial ordering with phase 25 — and the three inherited numbers it invalidates

**Phase 25 executes FIRST. Phase 26 executes AFTER it. This is decided, not hypothesised.**

Both phases edit the single-file suite `offchain/test/Main.hs` and register into the same
`core_checks` list, so they cannot run concurrently. Phase 25 has **9 unexecuted plans** whose own
gates target totals up to `>= 199` against the same 151 measurement recorded above.

`ROADMAP.md` says of phase 26: "Nothing structural — fully parallelizable with 23-25", and the
execution-order line repeats it. **That is WRONG about 25** and is recorded here rather than fixed
there, because this phase does not own the roadmap. Whoever next revises `ROADMAP.md` should carry
this correction; until then, this file is the authority for the ordering and `26-01-PLAN.md` carries
the binding rule.

What that invalidates, and how each plan now expresses it:

| Inherited number | Status | Replaced by |
|---|---|---|
| `cabal test` total 151, and every 155 / 158 / 165 / 169 / 173 / 178 / 183 derived from it | HYPOTHESIS | `BASE + N`, BASE re-measured at each wave's start; phase total `BASE_26_01 + 31` |
| `purge_file_floor` 59 / `credential_scan_floor` 68 and the 60-63 / 69-73 derived from them | HYPOTHESIS | `BASE_purge + N` / `BASE_cred + N`, both measured COLD by running the two `find` commands |
| wall 149.5 s | HYPOTHESIS | the WAVE-START wall, measured alongside BASE |

This is the house rule that already governs the tree-derived floors — RE-MEASURED, never incremented
by arithmetic — applied to the check count and to the wall.

**The +31 arithmetic, stated so a shortfall is visible.** 26-01 adds 7 (4 + 3), 26-02 adds 11
(7 + 4), 26-03 adds 9 (4 + 5), 26-04 adds **4** (checks 21-24). 7 + 11 + 9 + 4 = 31.
26-04's item 25 is NOT a fifth check: `every_advertised_override_is_honoured` is one `Check`
registered once at `Main.hs:11107`, and `swept_artifacts` / `artifact_field_floors` are consumed
INSIDE `sentinel_falsification_harness`, itself one `Check` appended at `Main.hs:11025`. The earlier
183 figure double-counted an extension as an addition; the delta is 4.

**Wall reconciliation (the two "measured cold 2026-08-17" figures).** `25-VALIDATION.md` records
152.9 s and this file records 149.5 s. Both were measured cold on the same tree on the same day; the
3.4 s spread is 2.3 % run-to-run variance on a shared machine, not a tree difference, and neither is
a comparand for phase 26 anyway — 25 lands first, so the phase-26 wall baseline is RE-MEASURED at
wave 1's start. Recorded rather than silently reconciled.

---

## Recorded deviation — the SEVENTH swept artifact

`25-VALIDATION.md` line 32 carries standing guidance: **"Extend `store-conformance.json`
(+22 leaves ~ +0.2 s) rather than add a seventh swept artifact (+19 s)."** Plan 26-04 adds
`fee-split-conformance.json` as the SEVENTH swept artifact. This is a deliberate deviation and is
recorded here rather than dropped:

- **Why the guidance does not fit.** `store-conformance.json` is a POSTGRES capture written by
  `capture-store-conformance.sh` against a live server; this artifact is a GAMS capture written by
  `capture-fee-split.sh` against the real solver, with a different producer, a different gate script
  and a different `CFMM_REQUIRE_*` contract. Folding a solver capture into a database capture would
  put two producers behind one path and one freshness oracle — and 24-05 already split the solver
  capture out for exactly that reason (`gams-conformance.json` is the SIXTH, and it did not extend
  the fifth either).
- **The cost, budgeted.** Phase 23's 134-leaf artifact added 793 sentinel pairs and ~19 s. This one
  is capped at **120 leaves** by design (`26-04`'s `<pinned_grid>`), so ~19 s is the ceiling of the
  sweep cost. Against the pre-25 baseline that projects to roughly 215 s before the new checks' own
  cost — comfortably inside 900 s, but that projection is against a baseline phase 25 moves, so the
  number that governs is the MEASURED wall at 26-04's wave.
- **The stop condition.** 26-04's acceptance criteria require NARROWING the artifact if the total
  exceeds 400 s, and STOPPING and reporting if it approaches 900 s. The deviation is answerable to
  that measurement, not to this argument.

---

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings), then `cabal test`.
- **Per wave:** the above plus that wave's named guard firings demonstrated verbatim.
- **Phase gate:** FAIL 0; both structural greps 0; every added guard OBSERVED rejecting its named
  input; the 39-row ledger reconciled with any un-observed guard reported **by name**.

---

## Per-Task Verification Map

FILLED 2026-08-17 from the four PLAN files. Every task's quick gate is
`cabal build --enable-tests -j all` with zero `-Wall` warnings, followed by `cabal test`. The
variant that omits `--enable-tests` is VACUOUS and is cited by no task.

**Every total below is a DELTA.** `BASE_n` is the `^PASS` count of a `cabal test` run made at the
START of that plan's wave, before the plan edits anything; each `BASE_n` is expected to equal the
count the preceding plan recorded on exit, and a mismatch is a FINDING reported by name. The
absolute column that used to sit here (151 / 155 / 158 / 165 / 169 / 173 / 178 / 183) predates phase
25 and has been removed rather than corrected: phase 25 executes first and moves all of it.

| Plan / task | Tier | What it verifies | Expected `cabal test` total |
|---|---|---|---|
| 26-01 T1 | A | `Fee.Split` compiles; one import; no hex literal, no float, no rational type; `Downloading = 0` | `BASE_01` |
| 26-01 T2 | A | FEE-01: exact level constraint, fixture recomposes to 6497, exact-split rarity both ways, residual recorded AND bounded | `BASE_01 + 4` |
| 26-01 T3 | A | FEE-02 Tier A: the prover's own `ellTest`, the integer/rational agreement, the float scan with a proven bait | `BASE_01 + 7` |
| 26-02 T1 | A | `Chain.Shock` compiles; `== 96` not `>= 96`; no 24-bit mask; nine positional error constructors | `BASE_02` |
| 26-02 T2 | A | CHAIN-04 decode: computed topic0, sign-aware negative tick, all-zero refusal, wrong length/topic/pool/range, and the u24-vs-pip-domain composition | `BASE_02 + 7` |
| 26-02 T3 | A | corpus discriminates as a NAME SET; decay never reaches the argv (three arms, three firings); the `ShockLib.plk` trip-wire fires under its positive control | `BASE_02 + 11` |
| 26-03 T1 | A | the band, the decimal-constant mixer, the seeded pick, `split_for` — still zero IO, zero float | `BASE_03` |
| 26-03 T2 | A | the NINTH refusal, its boundary in the message, the section 1.2 diagnosis kept distinct BY CONSTRUCTOR, derived pips in the argv | `BASE_03 + 4` |
| 26-03 T3 | **B** + A | no subprocess spawned for an inadmissible shock (marker stub, positive control FIRST); seed load-bearing; band size > 1 | `BASE_03 + 9` |
| 26-04 T1 | A | `render_argv_ungated` with one consumer and the NON-inverted composition (check 14 green, the inversion observed reddening it); both override registrations; the capture driver builds clean | `BASE_04` |
| 26-04 T2 | **C** (capture) | the real GAMS run: 12 rows, 4 controls, 0 disagreements, 2 verdicts present, 0 bad controls, <= 120 leaves | n/a (out of band) |
| 26-04 T3 | **C** | FOUR Tier-C checks (21-24; item 25 EXTENDS an existing check and adds none), the seventh swept artifact, all four floors re-measured | `BASE_04 + 4` |
| **phase gate** | — | 31 checks added across the phase (7 + 11 + 9 + 4) | `BASE_01 + 31` |

**Guard-to-task allocation.** The 39-row ledger in `26-RESEARCH.md` maps as: guards 1-5, 12-13 to
26-01; 21-33 to 26-02; 6-11, 14-15, 19-20 to 26-03; 16-18, 34-36, 39 to 26-04; 37-38 to every plan's
verify block. The phase gate reconciles the whole ledger and reports any guard with a standing
assertion and NO observed firing **by name**.

---

## Requirement Coverage

| Req | Tier | Note |
|---|---|---|
| **FEE-01** | A | `(1−φ_X)(1−φ_M) = 1−f` exactly — **but see the divisor finding**: only 4.93% of pool fees admit an exact integer-pip split, and 100/500/3000/10000 pips admit **zero**. A rounding rule must be stated, with the residual measured against SC-1's one-pip alarm |
| **FEE-02** | A + **C** | The **prover's own** admissibility test, transcribed — see the correction below. Tier C is the grid agreement with the real GAMS |
| **FEE-03** | **B** | Infeasible is refused **before any subprocess spawns** — observed with a marker stub that must be shown NOT to fire |
| **FEE-04** | A | The seed is load-bearing: a **different** seed must produce a **different** ρ. A same-seed-only test establishes nothing |
| **CHAIN-04** | A | Decode against synthetic logs; topic0 **computed in the test** from the signature string, never transcribed; sign-aware `int24`; an all-zero payload REJECTED |

---

## Standing Findings the Execution Must Carry

### 1. The admissibility formula was WRONG in the roadmap and is now corrected

`volume_path.gms:100-108` is the authority:

```gams
phiBar  = 1 - (1-phiX)*(1-phiM);      dphi = phiM - phiX;
ellTest = (sqr(phiBar)+sqr(dphi))*sqr(dStar) - (phiX+phiM)*phiBar*dStar + phiX*phiM;
```

**φ̄ is the COMPOSED fee; Δφ is the FULL gap.** An earlier reading took them as the arithmetic
mean and the ellipse SEMI-axis, giving `δ* ≥ 2ρ/(1+ρ²)`. MEASURED at the fixture fees, that form's
roots are `[0.165517, 1.000000]` against the prover's `[0.082803, 0.500000]` — **exactly 2× too
large**, falsely refusing ~**82,700 pips** of admissible `δ*`, each a phase failure by SC-2's own
wording. Its corollary "ρ ≥ 2+√3 required" is **false**.

The prover's form independently reproduces `VOLUME_PATH.md` §1.1's ceiling `δ ≤ 1/2` as its upper
root; the mistaken form gives 1.

**Transcribe in all-`Integer` arithmetic** — the research supplies
`E = Pn²d² + D²(m−x)²d² − D²(x+m)Pn·d + D⁴xm ≤ 0` with `Pn = D(x+m) − xm`, verified
`E = D⁶·ellTest` in sign and value on 20,000 random triples. **No `Rational` needed, no `Double`
anywhere.**

Note also: requirement A sets φ̄ **exactly equal to the pool fee**, so the two constraints are more
coupled than "level and skew" suggests — the boundary does move with `f`, in the 5th decimal.

### 2. The zero-trap is real, not hypothetical

`Shock.plk`'s `shock_decode` **accepts `flags = 0`**, so an all-zero 96-byte payload is legally
emittable. Accessors return literal `0` when a flag bit is unset. And issue #28 guarantees that in
v6.0 scope `tickDiff == 0` and `txlVolmDecay == 0` **by construction** — so two of three data words
are always zero in production, and `tickDiff` is the sign-extended one.

**A decoder exercised only on in-scope events cannot distinguish "decoded 0 correctly" from
"failed to decode and defaulted to 0."** The synthetic logs MUST carry a **negative** `tickDiff`
and a nonzero `txlVolmDecay` that production never emits.

`shock_tick_diff` ends in `@evm_signextend(2, raw)`, so `RealizedVol.Decode.signed_word` is exactly
right and a 24-bit mask is **wrong**.

### 3. `ShockLib.plk` is not in this worktree

So RPIN-04's parse-the-signature-from-`.plk` idiom is **unavailable**, and `"Shock"` must **NOT**
go into `expected_topic_pins`. Use a bare-hex `ground_truth` row plus a merge trip-wire — with a
**mandatory positive control**, since a trip-wire never seen to fire is absent.

topic0 = `0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`, **computed in the
test from the signature string `Shock(address,int24,uint24,uint24)`**, never transcribed.

### 3b. TWO of this document's named firing inputs were re-measured at plan time and DO NOT FIRE

Both were recomputed in exact `Integer` arithmetic on 2026-08-17. The plans carry the corrected
inputs; this note exists so the originals are not restored from here.

- **Guard 5 (rounding residual).** A `floor` rounder's worst residual over the whole `rho > 1` band
  is **999799** at f = 10000 — strictly BELOW the one-pip bound, so it never trips it. `m + 1` fires
  for **0 of 44** members at f = 100. The input that fires for every member at every f measured is
  **`m + 2`** (minimum abs residual 1997448 / 1499790 / 1497248 / 1493931 at f = 100 / 3000 / 6497 /
  10000). The residual therefore gets TWO assertions — a recorded VALUE and a bound — and only the
  bound uses `m + 2`. Relatedly, the "~10^3 headroom" figure is the band MINIMUM; an arbitrary
  seeded pick measures up to **0.4997 pip**, so the real headroom is **2x**.
- **Guard 20 (band non-degenerate).** `f = 3000, delta* = 1000` is named as "band EMPTY". MEASURED:
  `admissible_band 3000 1000 == [(1,2999),(2,2998)]`, a band of **2**. *(CORRECTED AT EXECUTION,
  RC-M6, 2026-08-17: this line said **4**. Four is the count of BOTH orientations —
  `(1,2999)`, `(2,2998)`, `(2998,2)`, `(2999,1)` — and `admissible_band` keeps only `m > x`, so
  what the function returns, and what the check's failure message prints, is 2. Observed verbatim:
  `admissible_band 3000 1000 is [(1,2999),(2,2998)] with size 2`.)* The EMPTY input is
  `delta* = 200`; the SINGLETON input
  — the one that makes FEE-04 vacuous, since all eight pinned seeds then map to index 0 — is
  `delta* = 500`, sole member `(1, 2999)`.

Two further plan-time measurements worth carrying: `min_admissible_dstar 3000 3000 == Nothing`
(at equal fees NO integer `delta*` is admissible, strictly stronger than section 1.2's prose, and
the reason the ellipse gate must run AFTER `distinct_fees`); and the gate's upper root is **499999**
for three of the four grid pairs, independently reproducing `VOLUME_PATH.md` section 1.1's
`delta <= 1/2` ceiling that the arithmetic-mean misreading gives as 1.

### 3c. ROADMAP SC-2's NAMED GRID POINT does not exist under the prover's gate

SC-2 requires agreement "including the `rho* = 3.8198` / `delta* = 0.49` boundary and one pip either
side". MEASURED: `3.8198417` is the root of `2*rho/(1+rho^2) = 0.49`, i.e. of the arithmetic-mean /
semi-axis form that is 2x too large; the correct leading-order root at `delta* = 0.49` is
`1.2234668` (or its reciprocal `0.8173495`). And the EXACT boundary is not a function of `rho` alone
because `phiBar = phi_X + phi_M - phi_X*phi_M` carries the product term, so no single `rho*` names a
boundary for every fee.

The grid therefore brackets in the `delta*` direction at four FIXED pairs, at each pair's exact
integer boundary (82804 / 109769 / 300361 / 495953) and one pip either side, with the boundary
RECOMPUTED in-suite by bisection. `delta* = 490000` is exercised throughout Tier A but is
deliberately not a row of the GAMS differential (leaf budget, and it adds no verdict the boundary
rows do not carry). One measured consequence worth stating: at `delta* = 490000` the pair
`(700, 800)` is INADMISSIBLE, its boundary being 495953 — SC-2's named `delta*` is not even uniformly
admissible across this grid's own pairs.

**SC-2's load-bearing clause is untouched:** "the Haskell verdict AGREES with the GAMS prover's
verdict on every grid point" is check 22. Only the predicate clause and the named point yield, and
`26-04-PLAN.md`'s `<planning_corrections>` CORRECTION C is the full record.

### 3d. FEE-01's requirement text and PROJECT.md are FALSE as written, and 26-04 closes them

`REQUIREMENTS.md` FEE-01 says the pair satisfies the level constraint "exactly"; `PROJECT.md`
asserts the composed fee "equal to `f` exactly". 26-01's locked decision 1 (round-and-report) makes
both false: `exact_pairs_for` is EMPTY for 100 / 500 / 3000 / 10000 pips, and
`split_for 0 3000 490000` composes to **3000.308** pips. ROADMAP SC-1 authorises the relaxation.
The corrections are a `<phase_close>` item in `26-04-PLAN.md`, with the exact replacement wording
for both documents; no earlier plan may make them, and no plan in this phase edits `ROADMAP.md`.

### 4. Other measured facts

- **`Gams.Argv` admits `txlVolumeRate = 0`** — a live hole the ellipse refusal closes for free,
  since `E(x,m,0) = D⁴xm > 0`.
- **GAMS-free does not forbid `Gams.Run`**, which is what makes FEE-03's "never spawned" a real
  observation rather than an argument.
- Floors: `purge_file_floor` **59**, `credential_scan_floor` **68**, both **zero slack**. They
  moved every wave of phases 23–24 and **two phase-24 summaries misreported them** — every
  inherited number is a hypothesis; RE-MEASURE.
- **A guard never OBSERVED rejecting is treated as ABSENT.** Restore mutated files from a **saved
  copy** verified by digest — never `git checkout`.
- **Prose is inside a grep's blast radius** — fifteen-plus instances across phases 23–24.
- `txlVolmDecay` (α_trans) is **NOT a GAMS input** (`VOLUME_PATH.md` §2 rules `txlDecayRate` out):
  decode it, record it, never feed it to the prover.

---

## Wave 0 Requirements

**None.** Test infrastructure exists and is reused.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Grid agreement with the real prover | FEE-02 | Requires GAMS; deliberately out of `cabal test` to keep the suite GAMS-free | Capture out of band, assert over the committed artifact |

---

## Open Questions (named, none blocking)

Which branch of the ρ↔1/ρ symmetry the splitter takes; whether the splitter or the chain read is
authoritative for (φ_X, φ_M); whether the rounding residual (~5e−10) interacts with the model's
1e−10 tolerance; and whether a `control` re-run separates the ellipse abort from κ/volume aborts,
since **exit 3 is ambiguous by construction**.

---

## Validation Sign-Off

- [ ] `cabal build --enable-tests -j all` — zero warnings
- [ ] `cabal test` — FAIL 0, total **`BASE_26_01 + 31`** (BASE re-measured at wave 1's start, AFTER
      phase 25 lands; the 151 baseline predates it and is a hypothesis)
- [ ] Both structural greps 0
- [ ] Every added guard observed rejecting its named input; 39-row ledger reconciled
- [ ] Tree-derived floors re-measured, not inherited
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
