---
kind: spike
status: COMPLETE
created: 2026-08-17
approved_by: user
runs_after: 26-03
blocks: nothing
binding_on: phase-28
commit: e0b3600
---

# RESULT — the chain mates, and it reproduces a golden captured before it existed

**The headline, verified independently:**

```
golden, committed phase 23-04 (e7687e5, 2026-08-16):
  e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884
spike, end to end, 2026-08-17:
  e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884
```

That golden predates `Fee/Split.hs` (`cfce3d1`), `Store/Cache.hs` (`6eba818`) and `Store/Key.hs`
(`f00b40b`). So splitter → shock → real toolchain → key → real solve → store → elision reproduces
bytes captured by an **entirely different code path**. The milestone's headline claim — *same inputs
+ same toolchain → same bytes* — is exercised end to end for the first time.

Elision confirmed against the real prover: `DECIDE 2 Elided`, **solver invocations 1**, bytes
identical. A second independent process printed the same content key, so the key is stable across
two real prover runs.

Split landed on **(500, 6000)** at δ\* = 490000 — one of the three pairs measured SOLVED there —
with `residual 0, is_exact True` (`f = 6497` is the one fee admitting an exact integer-pip split, so
that zero is computed, not a tolerance met). The classifier's positive control was driven out of
band: δ\* = 82803, one pip below the pinned boundary, gives `exit 3` and `*** Error at line 109`
verbatim.

---

## THREE SEAMS DID NOT MATE — all binding on phase 28

Recorded in `SpikeEndToEnd.hs`'s haddock; none papered over. **This is the spike succeeding.**

### S1 — A `KeyIdentity` can only be obtained from a COMPLETED RUN *(most consequential)*

`Store.Key.key_identity` needs a `ToolchainIdentity`, and the **only** producer of one in this
package is the `Produced` arm of `Gams.Run.run_prover`. But `Store.Cache.decide` needs the identity
**before** it can compute the key — i.e. before the first solve. **There is no `detect_toolchain`
anywhere.**

The spike therefore pays a **bootstrap solve whose only product is the identity**. A phase-28 poller
must either detect once at startup by solving something throwaway, or the library needs a detection
function that does not require a solve. **Decide this before phase 28 plans its loop** — it changes
the loop's startup shape.

### S2 — `Gams.Invoke.invoke_shock` does not fit the `Store.Solver` seam

Its type is `EnvChoice -> Shock -> IO (Either InvokeError ProverOutcome)`; the seam wants
`Shock -> IO ProverOutcome`. **`Gams.Run.AbortReason` has no constructor for "binary or model could
not be resolved"**, so an `InvokeError` arriving inside a solver has nowhere truthful to go — it
must throw, or be mapped to a lie.

The spike resolves binary and model **once, outside the seam**, and closes over them, calling
`run_prover` directly — which is what `Store.Solver`'s own haddock prescribes. So this is a shape
mismatch rather than a defect, **but the composition function you would reach for first is the wrong
one**, and phase 28 will reach for it.

### S3 — `Store.Cache.Decision` drops `CapturedStreams`, so a caller cannot classify a failure

`NotPersisted` carries only the reason and the exit code. The abort **line number** — the
discriminator `26-PROVER-SWEEP.md` measured, **109 = ellipse refusal vs 171/173 = CONOPT
infeasible** — lives only in `volume_path.log`, inside a run directory `Gams.Run` **deletes on every
exit path**.

**A caller of `decide` cannot tell an inadmissible shock from an unsolvable one.** The spike's
solver wrapper stashes the outcome so the executable can classify. Phase 28 needs the same wrapper
or a wider `Decision` — and it matters, because those two failures call for opposite responses:
inadmissible means *fix the shock*, infeasible means *the fixture cannot answer this one*.

---

## Constraints honoured

Not in `cabal test` (one `executable` stanza, +0 packages); `cabal test` unchanged at **190/190**;
both structural greps **0**; floors re-measured by running each `find` separately, 64/73 → **65/74**;
fixture written to `/tmp/cfmm-spike-end-to-end/`, nothing into `test/models/.../fixtures/`;
territory grep empty.

**No importer-count check existed** — checked before adding the second importer of `Gams.Invoke`.
What did exist were **three prose claims** that `GamsConformance.hs` is the ONLY importer (cabal
file, `Gams/Invoke.hs`, `GamsConformance.hs`), all corrected in the same commit: the load-bearing
property is the **directory** (every importer under `offchain/app/`, none under `offchain/test/`),
never the count.

**Reproduce:**
`GAMS_BIN=... GAMS_MODEL=... cabal run -v0 spike-end-to-end`

---

# Spike — the seams mate, end to end, once

> **Throwaway by construction.** Not a phase, not a requirement, not in `cabal test`. It exists to
> answer one question — *do the five components we built actually connect?* — while each is still
> fresh, instead of discovering the answer in phase 28 when five integration bugs surface at once.

## Why this exists

Measured 2026-08-17, after phases 23–26 shipped **8,640 lines of library code and 181 checks**:

- **No app calls `Store.Cache.decide`.**
- **Nothing wires `Gams.Run` into the store's `Solver` seam.**

Every component is proven *at its seam, against stubs*. Phase 25's Reality Checker recorded this as
**M3** — *"the two halves of the elision claim are each proven and never joined."* The pieces have
never met. Phase 28 is currently the first place they would, and it is also the phase with the
least slack (crash recovery, watermarks, atomic publication).

This spike moves that meeting forward, into a place where failure is cheap.

## What it does

One executable, `offchain/app/SpikeEndToEnd.hs`, roughly 150 lines. No chain, no polling, no tests.

1. **One hardcoded shock.** `VOLUME_PATH.md` §2's fixture: `sqrtPriceX96 = 2^96`
   (79228162514264337593543950336), `liquidityRaw = 2^64`, `nEvents = 8`. Pick `volTgtWad` and `δ*`
   from the window the prover can actually solve — see the warning below.
2. **Split the fee** — `Fee.Split.split_for seed f dstar` → `(φ_X, φ_M)`. Print the pair, the
   realized fee, the exact residual, and whether it is exact.
3. **Build the real `KeyIdentity`** — detect GAMS and CONOPT versions off the real toolchain
   (`Gams.Version`), digest the real model sources. Not a fixture identity.
4. **Compute the content key** and print it.
5. **Solve for real** — wire `Gams.Run`/`Gams.Invoke` into a `Store.Solver`. This is the wire that
   does not exist today and is the whole point.
6. **Store it**, then **call `decide` a second time with the same shock** and observe:
   - the second call returns `Elided`,
   - the solver invocation counter stays at **1**, not 2,
   - the returned bytes are byte-identical to the first call's.
7. **Write the fixture** to a scratch path and print where. Print its sha256 and its size.

## What it proves that nothing proves today

| Claim | Proven today | Proven by the spike |
|---|---|---|
| The fee split feeds a real argv | at the seam | **for real** |
| The key is stable across two REAL prover runs | against stubs (25-02) | **for real** |
| An identical shock elides a REAL solve | against a counting stub (STORE-01) | **for real** |
| The stored bytes are what GAMS emitted | at the store boundary | **end to end** |

That last row is the milestone's headline claim — *same inputs + same toolchain → same bytes* —
exercised against the actual solver for the first time.

## Constraints — these are the ones that will bite

- **It must NOT enter `cabal test`.** An `executable` stanza only. The suite stays DB-free and
  GAMS-free; both structural greps over `offchain/test/Main.hs` stay **0**. The spike costs nothing
  per gate, which is the point.
- **`Gams.Invoke` is importable from `offchain/app/`** — `GamsConformance.hs` already does it, and
  `Gams/Invoke.hs` is exempted by name from the module scan. Confirm no *importer-count* check
  exists before adding the second importer; if one does, extend it with a written reason in the same
  commit.
- **A new file under `offchain/` moves both floors.** Re-measure `purge_file_floor` and
  `credential_scan_floor` from what `find` PRINTS and move them in the same commit. Currently
  **64 / 73** with zero slack.
- **Do NOT write into `test/models/mev_tax_model_one/fixtures/`.** That is another workstream's
  tree; publication there is LOOP-04, phase 28's requirement, with its own rules about never
  creating the directory. The spike writes to a scratch path and prints it.
- **Territory grep must end empty**; leave the four untracked root files alone; never merge develop.

## The prover warning — read this before picking δ\*

The phase-26 Reality Checker **drove the real prover** and measured that most of the plan's grid
does not solve: every `boundary+1` row and three of four controls abort with CONOPT infeasible.
Raising `volTgtWad` does **not** rescue them — six values and three `nEvents` settings were swept
and all aborted. See `26-REVIEW-FINDINGS.md` **RC-B1**.

**The measured solvable window for `(φ_X, φ_M) = (500, 6000)` at `volTgtWad = 28e18` is
δ\* ∈ [0.490, 0.4965]** — δ\* = 490000 and 495000 exit 0; 480000 and 499000 exit 3.

So: **use `δ* = 490000`**, and if the splitter's chosen pair does not solve, sweep δ\* within that
window rather than raising the volume. **A GAMS exit 3 here is a finding about the fixture, not a
bug in the wiring** — say which it is, with the exit code, rather than reporting the spike failed.

## Done when

The executable runs to completion and prints, in order: the fee split with its residual, the content
key, GAMS's exit code for the first solve, the artifact sha256, then `Elided` plus an invocation
counter of **1** for the second call, then the fixture path and size.

If any seam does not mate, **that is the spike succeeding** — report the exact mismatch (types,
argv, missing wiring) rather than working around it. A discovered seam bug here is worth more than a
clean run, because it is a bug that would otherwise have surfaced in phase 28.

## After

Report findings, then resume **26-04** (the Tier-C differential). The spike does not block it, and
26-04 is where RC-B1's grid must be rebuilt from a measured solvable window anyway — the two share
the same prover-sweep discipline.
