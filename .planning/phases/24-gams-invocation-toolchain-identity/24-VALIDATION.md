---
phase: 24
slug: gams-invocation-toolchain-identity
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-16
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Authoritative source:** `24-RESEARCH.md` `## Validation Architecture` — the 30-row
> requirement→test map and the 41-row guard→firing-input table live there. Every value it marks
> MEASURED was captured against the real GAMS 54.1 binary on this machine.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name, check_run :: IO (Either String ()) }` in `offchain/test/Main.hs`. Every check runs; the process exits non-zero if any failed |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` |
| **Registration point** | `core_checks` — **a check not in this list does not exist** |
| **Quick run command** | `cabal build --enable-tests -j all` |
| **Full suite command** | `cabal test` |
| **Baseline (re-measured cold, 2026-08-16)** | **111/111**, wall **66 s** |
| **Runtime budget** | **900 s ceiling.** Wall clock MUST be recorded before and after each plan that adds checks. If exceeded, narrow the `RoundTripsAnyway` sentinel members — **never** drop a `SilentlyCorrupted` member or a swept artifact |
| **Max feedback latency** | **~66–120 s** (a full `cabal test`), not 30 s. This is a deliberate, budgeted trade in this codebase, recorded honestly rather than left at a template default |
| **Hard gates** | zero `-Wall` warnings under `offchain/`; **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** and never counts as evidence |
| **Chain / DB / GAMS dependency** | **NONE, and all three must be preserved.** No row in the req→test map needs a live GAMS inside `cabal test`. The DB-free grep stays at 0; a new GAMS-free grep (`Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams`) joins it |
| **New test file** | **None.** One file, one runner — a check outside `core_checks` is invisible to the sentinel harness |

### The three tiers

- **A — pure.** No IO. Version parsing, the exit taxonomy, argv rendering, the environment
  whitelist, BYTE-04's golden vector, the scan-scope growth guard.
- **B — real subprocesses against stubs the checks write themselves.** Precedent, not novelty:
  the suite already spawns `grep` in `purge_scan`/`aeson_scan`. Drives `Gams.Run`, never
  `Gams.Invoke`.
- **C — committed evidence.** Checks asserting over `gams-conformance.json`, captured out of band
  against the real GAMS 54.1. Tier C needed the solver at **capture** time, never at test time.

**`Gams.Run` and `Gams.Invoke` are split on purpose.** `Gams.Run` is the testable IO edge, driven
only against stubs; `Gams.Invoke` composes the real binary and is importable only by
`offchain/app/GamsConformance.hs`. The GAMS-free grep targets `Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams`
and deliberately excludes `Gams.Run` — otherwise the grep proving "no check shells out to GAMS"
would have to match the module that does exactly that.

---

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings), then `cabal test`.
- **Per wave:** the above, plus that wave's named guard firings demonstrated, verbatim in the commit.
- **Phase gate:** `cabal test` FAIL count **0**; the DB-free and GAMS-free greps both **0**; every
  guard the phase adds OBSERVED rejecting its named input; the 41-row guard ledger reconciled with
  any un-observed guard reported as a **named phase-level finding**, never silently omitted.

---

## Per-Task Verification Map

| Task | Plan | Wave | Requirements | Tier | Automated command | Status |
|---|---|---|---|---|---|---|
| 24-01-01 | 01 | 1 | GAMS-03, GAMS-04 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 24-01-02 | 01 | 1 | GAMS-01 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 24-01-03 | 01 | 1 | GAMS-01, GAMS-03, GAMS-04 | A | `cabal test` | ⬜ pending |
| 24-02-01 | 02 | 2 | GAMS-02 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 24-02-02 | 02 | 2 | GAMS-06, BYTE-04 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 24-02-03 | 02 | 2 | GAMS-02, GAMS-06, BYTE-04 | A | `cabal test` | ⬜ pending |
| 24-03-01 | 03 | 3 | GAMS-01, GAMS-02 | B | `cabal test` | ⬜ pending |
| 24-03-02 | 03 | 3 | GAMS-01, GAMS-02 | B | `cabal test` | ⬜ pending |
| 24-04-01 | 04 | 4 | GAMS-05 | B | `cabal test` | ⬜ pending |
| 24-04-02 | 04 | 4 | GAMS-03, GAMS-06 | B | `cabal test` | ⬜ pending |
| 24-04-03 | 04 | 4 | GAMS-03, GAMS-06 | A | `cabal test` | ⬜ pending |
| 24-05-01 | 05 | 5 | all 7 | C (capture) | `cabal build --enable-tests -j all` | ⬜ pending |
| 24-05-02 | 05 | 5 | all 7 | C | capture script, then `cabal test` | ⬜ pending |
| 24-05-03 | 05 | 5 | all 7 | C | `cabal test` | ⬜ pending |
| 24-06-01 | 06 | 6 | GAMS-03 | A + C | `cabal test` | ⬜ pending |
| 24-06-02 | 06 | 6 | GAMS-03 | C | capture script, then `cabal test` | ⬜ pending |

No task cites the bare `cabal build -j all`.

---

## Requirement Coverage

All seven IDs covered; per-check detail is `24-RESEARCH.md`'s 30-row map.

| Req | Covered by | Tier | Needs live GAMS in `cabal test`? |
|---|---|---|---|
| **GAMS-01** | exit taxonomy is total; a stub exiting 0 writing nothing is REFUSED; a stub exiting 0 beside a **pre-existing** `volume_path.json` is REFUSED (fresh per-invocation temp dir) | A + B + C | **No** |
| **GAMS-02** | `action=c` exits 0 and writes no artifact — the firing input, reproducible with the real binary; no decision reads stdout/stderr | A + B + C | **No** |
| **GAMS-03** | garbage battery incl. the **measured** exit-0 no-argument banner, discriminated by **job name**; no constructible-empty `GamsVersion`; detection that finds nothing ABORTS; binary path + sha256 recorded | A + B + C | **No** |
| **GAMS-04** | CONOPT's true version read by **content, not position** (decoy line numbers move 34/38 → 42/47); both decoys — the GAMS link version and `libconopt464.so` — REJECTED | A + C | **No** |
| **GAMS-05** | hung **GRANDCHILD** terminated and reaped, `/proc/<pid>` liveness, with a **required negative control** observing the same stub SURVIVING a direct-child-only kill; 2 MB stderr flood completes | B | **No** |
| **GAMS-06** | explicit whitelist + `LC_ALL=C`; hostile ambient var yields byte-identical output; asserted on the **child's environment vector** | A + B + C | **No** |
| **BYTE-04** | golden vector: `dQx[0]` as `Double` is `-2613128317657530368`, **Δ = 32 wei**, 16/16 elements inexact, |Δ| ∈ [4, 328]; `[Integer]` exact — so no tolerance can absorb it | A + C | **No** |

---

## Standing Findings the Execution Must Carry

- **A guard never OBSERVED rejecting is treated as ABSENT.** 41 guards, each with its firing
  input named in `24-RESEARCH.md`. Phase 23 found a guard cited as evidence across three plans
  that had never once fired — reconcile the ledger and report any gap by name.
- **GAMS-05's obvious test CANNOT FAIL.** `readProcessWithExitCode` drains 2 MB of stderr and
  reaps a *direct* child — but a **grandchild survives at PPID 1**, and GAMS runs CONOPT at
  `Solvelink=2` as a separate process. The stub must be a grandchild; `/usr/bin/timeout -k 1`
  kills the group and exit 124 does not collide with GAMS's codes.
- **The artifact bytes are a function of the argv TOKEN.** `volume_path.gms:206` emits
  `"%sqrtPriceX96%"` **verbatim** — a leading zero gives exit 0, every §4 gate green, and sha256
  `d64a7b32…` instead of the golden `e7b14f38…`. Only the two echoed STRING fields are
  token-sensitive (`volTgtWad` is a double: `28e18` and `2.8e19` are byte-identical).
- **stderr is 0 bytes in EVERY mode** — a stderr-reading detector returns `""` always.
- **`purge_file_floor = 48` against exactly 48 scanned files — ZERO SLACK**, and this phase adds
  eight `Gams.*` modules. The floor moves in the SAME task as the first added module, by
  **re-measurement** (`find … | wc -l`), never by arithmetic. `credential_scan_floor` 56 and
  `sentinel_pair_floor` 3250 likewise: RE-MEASURE, never inherit.
- **Scope must GROW.** `aeson_storage_path` is a hardcoded list with no directory cross-check —
  its scope failed to grow when `Store/Schema.hs` appeared in phase 23. The bidirectional
  `listDirectory`-vs-manifest check over `offchain/lib/{Store,Gams}/` lands with the new modules.
- **`model_run.gams_ver text not null` does NOT forbid `''`** — a `"" == ""` one layer BELOW the
  Haskell guard, in phase 23's own schema. Migration `003` adds
  `check (length(gams_ver) > 0 and length(conopt_ver) > 0)`, and the rejection must be OBSERVED
  against a real server (SQLSTATE `23514`) through the store's own `Binary`-wrapped write path.
- **Restore mutated files from a SAVED COPY**, verified by diffing digests — not `git checkout`,
  which destroyed ~170 lines of uncommitted work in phase 23.
- **Prose is inside a grep's blast radius** — a comment near a grepping check can redden it.
- **The capture-freshness oracle has a written, asserted gap.** `volume_path.gms` lives in the
  `cfmm-wt/gams` worktree, so its digest cannot be recomputed here.
  `argv_module_sha256`/`artifact_module_sha256` ARE recomputable from this repo, so editing the
  renderer without re-capturing reddens. The model half is recorded as a gap in the
  `PGSTORE_DSN` shape — named, not silently dropped.

---

## Wave 0 Requirements

**None.** The six plans' Task 1s absorb what `24-RESEARCH.md`'s "Wave 0 Gaps" lists. Test
infrastructure already exists and is reused, not replaced.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Live GAMS 54.1 / CONOPT 4.39.0 observations | GAMS-01..06, BYTE-04 | Requires the real solver; deliberately out of `cabal test` to keep the suite GAMS-free | `bash offchain/rig/capture-gams-conformance.sh` — runs the real prover, writes `gams-conformance.json`, restores on failure |
| Postgres constraint rejection (SQLSTATE 23514) | GAMS-03 | Requires a real server; Dockerised, out of `cabal test` | `bash offchain/rig/capture-store-conformance.sh` after migration `003` |

---

## Validation Sign-Off

- [ ] `cabal build --enable-tests -j all` — zero warnings
- [ ] `cabal test` — FAIL count 0, total ≥ 111 baseline
- [ ] DB-free grep 0; **GAMS-free grep 0** with a proven positive control
- [ ] Every guard added observed rejecting its named input; 41-row ledger reconciled
- [ ] Tree-derived floors re-measured, not inherited
- [ ] `cabal test` wall recorded before and after; under the 900 s ceiling
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
