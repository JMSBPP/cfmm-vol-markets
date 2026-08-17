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
| **Baseline (measured cold 2026-08-17)** | **151/151**, exit 0, wall **149.5 s** |
| **Runtime budget** | **900 s ceiling.** Record wall before/after; the sentinel harness pays each added check ~3828 times |
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

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings), then `cabal test`.
- **Per wave:** the above plus that wave's named guard firings demonstrated verbatim.
- **Phase gate:** FAIL 0; both structural greps 0; every added guard OBSERVED rejecting its named
  input; the 39-row ledger reconciled with any un-observed guard reported **by name**.

---

## Per-Task Verification Map

**PENDING — filled from the PLAN files once `gsd-planner` has run.** Every task's quick gate will
be `cabal build --enable-tests -j all` with zero warnings. No task may cite the bare
`cabal build -j all`.

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
- [ ] `cabal test` — FAIL 0, total ≥ 151 baseline
- [ ] Both structural greps 0
- [ ] Every added guard observed rejecting its named input; 39-row ledger reconciled
- [ ] Tree-derived floors re-measured, not inherited
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
