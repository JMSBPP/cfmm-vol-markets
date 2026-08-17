---
phase: 25
slug: content-key-keyed-store
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-17
revised: 2026-08-17
---

# Phase 25 — Validation Strategy

> **Authoritative source:** `25-RESEARCH.md` `## Validation Architecture` — a **47-row**
> requirement→test map (all fourteen IDs plus inherited KEY-07) and a 50-row guard→firing-input
> table. Every row it marks MEASURED was captured on this machine. (An earlier draft of this line
> said 48; the table at `25-RESEARCH.md:878-926` has 47 rows, counted at revision time.)
>
> The **Per-Task Verification Map** below is POPULATED, from the twenty-eight tasks of the nine
> PLAN files. Phase 24 shipped an unpopulated template and the plan checker correctly blocked on it;
> a not-yet-filled marker left in place after the planner has run is the same defect with a
> different word. Plan 25-09 task 2 RECONCILES this map against the nine SUMMARY files — it does
> not author it.
>
> **That marker's own spelling is deliberately absent from this document**, because 25-09 task 2
> greps this file for it and requires zero. Prose is inside a grep's blast radius; a validation
> document that reddens its own phase gate by naming the thing it no longer contains would be the
> eighteenth instance of that defect on this branch rather than a new one.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner in `offchain/test/Main.hs`; every check runs, non-zero exit if any fails |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal` |
| **Registration point** | `core_checks` — **a check not in this list does not exist** |
| **Quick run** | `cabal build --enable-tests -j all` |
| **Full suite** | `cabal test` |
| **Baseline (measured cold 2026-08-17)** | **151/151**, wall **152.9 s** |
| **Projected end-of-phase total** | **207** = 151 + 8 + 10 + 3 + 8 + 7 + 7 + 6 + 6 + 1. A projection, not a target: each plan records what its run PRINTS |
| **Runtime budget** | **900 s ceiling.** Record wall before/after. The sentinel harness pays each added check ~**3828** times. **Extend `store-conformance.json` (+leaves ≈ +0.2 s) rather than add a seventh swept artifact (+19 s).** |
| **Hard gates** | zero `-Wall` warnings; **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** and never counts |
| **Chain / DB / GAMS** | **NONE of the three inside `cabal test`.** No row in the req→test map needs a DB or GAMS. Both structural greps stay **0** |
| **New test file** | **None.** One file, one runner |

### Tiers

- **A — pure.** Framing, edge normalization, preimage construction, refusal predicates, source scans.
- **B — stubs + `Store.Memory`.** The store contract executed for real; `Gams.Run` driven against
  shell stubs. This is where cache elision and the echo cross-check actually discriminate.
- **C — committed capture.** Assertions over `store-conformance.json`, captured out of band.

### A verify command whose status can disagree with its subject is not a gate

Fixed across every task at revision time, and recorded here because it is the phase's own defect
class one level up, living in the phase's verification harness:

- **`cmd | tee LOG | tail -3; test "$(grep -ci warning LOG)" = 0 && echo OK`** takes its exit status
  from the LAST command, and a FAILING build emits `error:` rather than `warning` — so a
  non-compiling tree counted 0, printed `ZERO_WARNINGS` and exited **0**. Every build task now runs
  `cabal build --enable-tests -j all > LOG 2>&1 || { …; exit 1; }` FIRST and greps afterwards.
- **`… ; grep -c '^FAIL ' LOG`** takes its status from `grep -c`, which exits **1** when the count is
  ZERO — so the GREEN case reported failure, and a `cabal test` that crashed before printing a
  `FAIL` line reported 0. Every test task now captures `cabal test`'s own exit code and re-raises it.

---

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings), then `cabal test`.
- **Per wave:** the above plus that wave's named guard firings demonstrated verbatim.
- **Phase gate:** FAIL 0; both structural greps 0; every added guard OBSERVED rejecting its named
  input; the 50-row ledger reconciled with any un-observed guard reported **by name**.

---

## Per-Task Verification Map

Twenty-eight tasks across nine plans and nine waves. Every task's quick gate is
`cabal build --enable-tests -j all` with **zero warnings**; the full gate is `cabal test` with
**FAIL 0**. **No task cites the bare `cabal build -j all`** — plan 25-09 task 2 scans the
`<automated>` commands and `<action>` bodies for it and requires zero.

| Task | Plan | Wave | Requirements | Tier | Automated gate (beyond the two standing ones) |
|---|---|---|---|---|---|
| T1 `Store.Key` — framer, tagged preimage, refusing identity | 25-01 | 1 | KEY-01, KEY-04, KEY-05 | A | build; `grep -c Downloading` = 0; `Maybe`/`Double`/`curdir`/`ti_gams_sha256` counts = 0; `1000000` count = 1 |
| T2 Eight Tier-A checks + the bare-decimal control | 25-01 | 1 | KEY-01, KEY-04, KEY-05 | A | `cabal test`; eight names in `core_checks`; both structural greps 0 |
| T3 Drive nine+three guards, re-measure floors, extend `aeson_storage_path` | 25-01 | 1 | KEY-01, KEY-04, KEY-05 | A | `cabal test`; twelve verbatim `FAIL` lines; two independent `find … \| wc -l` |
| T1 `parse_shock` — the assembler KEY-06 had no subject for | 25-02 | 2 | KEY-06 | A | build; `parse_shock ::` = 1; `Maybe` = 0; `parse_shock_field` ≥ 2 |
| T2 The KEY-02 pair: token-set assertion + hit-rate observation | 25-02 | 2 | KEY-02, KEY-03, KEY-06 | A + B | `cabal test`; `polluted_preimage` ≥ 2; `per_run_forbidden_tokens` ≥ 3 |
| T3 Drive twelve guards, re-measure, record | 25-02 | 2 | KEY-02, KEY-03, KEY-06 | A + B | `cabal test`; twelve verbatim `FAIL` lines; two independent `find` runs |
| T1 Migrations 004/005, `Store.Schema` data, lock-probe renumber | 25-03 | 3 | STORE-05, STORE-06, STORE-07 | A | build; both trigger declarations = 1; `errcode`/FK = 0; probe sorts last |
| T2 Re-take the capture; re-measure every floor it moves | 25-03 | 3 | STORE-06, STORE-07 | C | `cabal test`; five migrations in the artifact; six artifact floors + sentinel floor RAISED-until-NAMED |
| T3 DDL-side checks and the lock-probe guard that fires | 25-03 | 3 | STORE-06, STORE-07 | A | `cabal test`; seven verbatim `FAIL` lines; `lock_probe_filename` in exactly one module |
| T1 `Store.RunLog` — outcome taxonomy, reset decision, `aeson_storage_path` | 25-04 | 4 | STORE-05, STORE-06, STORE-07 | A | build; `ResetScope` single constructor; `truncate`/`byte_corpus` = 0; `RunLog.hs` on the scanned path |
| T2 The seam grows by eight; both implementations follow | 25-04 | 4 | STORE-01, STORE-05, STORE-06, STORE-07 | B | build; `xmax = 0` = 1; `on conflict do nothing` = 0; `truncate` = 0 |
| T3 Eight Tier-B checks against `Store.Memory`, each with both arms | 25-04 | 4 | STORE-01, STORE-05, STORE-06, STORE-07 | B | `cabal test`; twelve verbatim `FAIL` lines; two growth guards ≥ 3 occurrences each |
| T1 `Store.Verify` — two types that cannot be confused | 25-05 | 5 | STORE-02, STORE-04 | A | build; neither constructor exported; `decode_artifact` ≥ 2; `Verify.hs` on the scanned path |
| T2 `store-admin` — the entrypoint whose failure is an exit code | 25-05 | 5 | STORE-02, STORE-06 | B | build; bare `reset` exits **2**; scoped dry-run exits **0**; `verify_exit_code` call sites = 1 |
| T3 `reverify_stored_key` — the re-solve/verify/quarantine driver | 25-05 | 5 | STORE-02, STORE-03 | B | build; `store_quarantine_put` = 1; `store_put` = 0; importer count still 1 |
| T4 Seven checks, the OBSERVED GHC refusal, the subprocess exit | 25-05 | 5 | STORE-02, STORE-03, STORE-04 | A + B | `cabal test`; seventeen verbatim `FAIL` lines; `lib/` importers = 0, `app/` importers = 1 |
| T1 `Store.Solver` + `Store.Cache`; both list moves | 25-06 | 6 | STORE-01, STORE-04, STORE-08 | A | build; `Store.Verify`/`RunRequest` = 0; both modules on `aeson_storage_path`; denominator scan scope 1 → 2 |
| T2 Elision pair, four driven aborts, decision-path discriminator | 25-06 | 6 | STORE-01, STORE-08 | B | `cabal test`; `counting_solver` ≥ 3; control asserted before the variants |
| T3 Drive fourteen guards, re-measure, record | 25-06 | 6 | STORE-01, STORE-04, STORE-08 | B | `cabal test`; fourteen verbatim `FAIL` lines, with the two STORE-01 halves separated |
| T1 Four observation blocks, control evaluated first | 25-07 | 7 | STORE-01, STORE-05, STORE-06, STORE-07 | C | build; `pg_trigger` ≥ 1; `control_accepted` ≥ 2; both pin arms present; no hand-written `delete from model_run` |
| T2 Script gate, re-capture, every floor the artifact moves | 25-07 | 7 | STORE-05, STORE-06, STORE-07 | C | capture exits 0; artifact has **18** blocks; six artifact floors + sentinel RAISED-until-NAMED; both `find` runs |
| T3 Six Tier-C checks driven against a doctored copy | 25-07 | 7 | STORE-01, STORE-05, STORE-06, STORE-07 | C | `cabal test` (≥ 200); seventeen verbatim `FAIL` lines; committed artifact sha256 identical before/after |
| T1 Quarantine exhibit, abort exhibit, key round trip | 25-08 | 8 | KEY-01, KEY-02, STORE-03, STORE-08 | C | build; `agreement_control_rows_added` ≥ 1; no solver spawned; no `0x`-prefixed digest |
| T2 Gate, re-capture, the floors this artifact moves | 25-08 | 8 | STORE-03, STORE-04, STORE-08 | C | capture exits 0; artifact has **21** blocks; every floor RAISED-until-NAMED |
| T3 Six Tier-C checks; the verifier guard RE-SCOPED with fresh firings | 25-08 | 8 | KEY-01, KEY-02, STORE-03, STORE-04, STORE-08 | C + A | `cabal test` (≥ 206); eighteen verbatim `FAIL` lines; `lib/` importers = 0, `app/` importers = 2, both with written reasons |
| T1 The echoed-field mutant — carried guard #21, OBSERVED rejecting | 25-09 | 9 | KEY-02 | B | `cabal test` (≥ 207); `EchoMismatch` payload quoted verbatim; `Produced` control present |
| T2 Reconcile fifty guards, the map, and the traceability | 25-09 | 9 | KEY-02, STORE-02 | doc | the scoped fragment-built scan = **0** with its positive control = **1**; the not-yet-filled marker's count in this file = 0; fifty ledger rows |
| T3 The phase gate, measured cold | 25-09 | 9 | all fourteen | all | `cabal test`; both structural greps 0; both `find` outputs; every floor RAISED-until-NAMED; territory clean |

### Deviations of record in this map

- **25-05 carries FOUR tasks**, not the phase's usual three. Task 3 (`reverify_stored_key`) was added
  at revision time: STORE-02 and STORE-03 were asserted by 25-05's own mutation table and by 25-08's
  `quarantine_rows_after == 1` while NOTHING in the phase re-solved an existing key or called
  `store_quarantine_put` on a mismatch. It sits in this plan rather than in a tenth because the
  guard it must not break — `verification_is_reachable_only_from_its_own_entrypoint` — ships here.
- **`pin_and_reset` was added to 25-07.** `store_pin` and `store_reset` were written by 25-04 and
  executed by nothing: `cabal test` exercises `Store.Memory` only. It was also the ONLY row of the
  research's 47-row map that no plan delivered
  (`store_conformance_records_the_pin_column_and_its_default`). The map now reconciles at 47 of 47.
- **The artifact's block counts moved** from 14 → 18 (25-07) → 21 (25-08), one higher at each step
  than the original plan text, because of `pin_and_reset`.

---

## Requirement Coverage

All fourteen IDs covered; per-check detail is `25-RESEARCH.md`'s **47-row** map. **No row needs a DB
or GAMS inside `cabal test`.**

| Req | Tier | Plans | Note |
|---|---|---|---|
| **KEY-01** | A + C | 25-01, 25-08 | `H(inputs ‖ GAMS ver ‖ CONOPT ver ‖ model source digest ‖ solver options digest)`; `key_scheme` already inside the unique constraint from phase 23 |
| **KEY-02** | **B** | 25-02, 25-08, 25-09 | One renderer feeds argv AND preimage — see the standing finding below; a token-set assertion in BOTH directions **plus** an elision observation, because they fail on opposite designs |
| **KEY-03** | A | 25-02 | `28e18` → `28000000000000000000` normalized once at the edge; no `show`/`printf` on a float anywhere on the key path |
| **KEY-04** | A | 25-01 | Framing — see the standing finding; must point at the FRAMER, not at `render_argv`'s accidental framing, and both control pairs must GENUINELY collide unframed |
| **KEY-05** | A | 25-01, 25-06 | The pips denominator (`FEE_DENOMINATOR = 1e6`) is in the preimage; the scan's scope is pinned data and 25-06 moves it |
| **KEY-06** | A | 25-02 | A missing or unparseable input is an error BEFORE hashing — never a default. The omission clause had no subject; `parse_shock` is that subject |
| **STORE-01** | B | 25-04, 25-06, 25-07 | **Cache elision — the user called this critical.** An identical shock returns the artifact WITHOUT invoking the solver |
| **STORE-02** | B + C | 25-05, 25-08, 25-09 | A re-solve producing different bytes is a determinism failure with non-zero exit. **The re-solve itself is `Store.Verify.reverify_stored_key` (25-05 T3)** |
| **STORE-03** | B + C | 25-05, 25-08 | The original is KEPT and the divergent bytes **quarantined**, not discarded — by the same driver |
| **STORE-04** | B | 25-05, 25-06, 25-08 | Verification on demand, never on every hit (Nix shipped always-verify and removed it in 2.13 as broken). The load-bearing clause is that NOTHING under `offchain/lib/` imports the verifier |
| **STORE-05** | B + C | 25-03, 25-04, 25-07 | Pinning survives retention — Tier B against `Store.Memory` AND Tier C against a real server, because a map filter cannot predict `delete … where not pinned` |
| **STORE-06** | B + C | 25-03, 25-04, 25-05, 25-07 | `reset` is separate and explicit — and it is exactly the operation that reaches for `TRUNCATE`; see the standing finding |
| **STORE-07** | B + C | 25-03, 25-04, 25-07 | Append-only run log `(timestamp, key, event tx, block)`. **CLOSES PARTIAL** — see below |
| **STORE-08** | B | 25-06, 25-08 | **A partial or failed run never becomes a cache entry.** Absence is the pass condition — the empty-log `grep -q` shape; the check must be shown FAILING when an entry does appear |

### STORE-07 closes PARTIAL, and it is recorded here rather than discovered later

STORE-07 names four fields. `timestamp` and `key` are CLOSED and asserted. `event tx` and `block` are
**structurally present and semantically empty**: migration `004` creates `event_tx` and `block_no` as
NULLABLE columns, `RunEvent` carries `re_event_tx` and `re_block_no`, and the Postgres writer names
both — so the writer EXISTS and is exercised — but both are ALWAYS `Nothing` in this phase, because
CHAIN-01/02 are blocked upstream until **Phase 27**. A fabricated zero word would be `0x00…00`
passing every hex-shape guard in the tree, which is why the columns stay NULL rather than populated.
**No check asserts a non-`Nothing` value, deliberately** — an assertion over a field nothing
populates is the standing-assertion-with-no-mutation shape this phase exists to audit. Plan 25-09
task 2 writes this into the traceability table in these words.

---

## Standing Findings the Execution Must Carry

**Three of the roadmap's own success criteria are unsound as worded. Plan against these.**

1. **SC-1's framing test CANNOT FAIL as written.** 343 shock tuples swept through `render_argv`'s
   token form gave **0 collisions** — every token is `--<literal name>=<digits>` and `-`/`=` are
   outside the digit alphabet, so the concatenation is uniquely parsable. **The `--name=` prefixes
   are ACCIDENTAL framing.** The same 343 tuples under bare-decimal concatenation give **30**
   collisions. The test must point at the **framer directly**, at a named bare-decimal negative
   control, and at the free-form components.
   **Corollary, found at revision time and now binding: a "collision" pair must be VERIFIED to
   collide unframed.** The obvious free-form pair `[("a",h1),("bc",h2)]` vs `[("ab",h1),("c",h2)]`
   does NOT — `h1` is fixed-length, so the renderings differ at the second character and the check
   stays green with the framer deleted. 25-01 uses a constructed pair that genuinely collides, and
   carries `frames := BS.concat` as a firing input.
2. **The obvious KEY-02 implementation gives a cache hit rate of exactly ZERO — and every KEY-02
   check still passes.** `Gams.Run.spawn_into` puts `curdir=<per-run exclusive temp dir>` in
   `wrapper_argv`, so "reconstruct the argv actually passed from the stored preimage" is *most*
   satisfied by the design that makes the store useless. Answer: a two-directional token-set
   assertion (`curdir=`, the timeout wrapper, `-k`, the budget and the absolute binary all
   FORBIDDEN in the preimage) **plus** an elision observation — the two fail on opposite designs.
3. **`REVOKE` is a silent no-op and `TRUNCATE` walks through an append-only row trigger.**
   MEASURED on PG 18.4: after `revoke update, delete … from postgres`, a superuser UPDATE
   **landed** and read back `TAMPERED` with no error — **and the app connects as `postgres`**. A
   `BEFORE UPDATE OR DELETE` row trigger refuses it; then `truncate run_log` **emptied the table
   with no error**, which needs `BEFORE TRUNCATE … FOR EACH STATEMENT`. STORE-06's `reset` is
   precisely the operation that reaches for `TRUNCATE`.

**Two key-poisoning hazards, verified in the source:**

- **`ti_model_sources :: ![(FilePath, String)]` carries an ABSOLUTE machine path.** In the
  preimage that makes the key machine-specific — the same shock on another box misses the cache
  forever, silently. Digest the CONTENT, never the path.
- **`ti_conopt_version :: !(Maybe ConoptVersion)`.** Phase 24 built a version that cannot be
  constructed empty and then wrapped it in a type that can be **absent**. `Nothing` reaching the
  preimage is the empty-version hole one constructor up. KEY-06 must reject it.

**Other measured facts:**

- `on conflict do nothing returning` returns **no row** on conflict — `xmax = 0` is the
  discriminator (`t` then `f`).
- **`lock_probe_filename = "004_lock_probe.sql"` collides with the first real `004` migration** —
  the identical defect 24-06 fixed at `003`, one plan later.
- Tree-derived floors: `purge_file_floor` **59**, `credential_scan_floor` **68**,
  `sentinel_pair_floor` **3828**, all RE-MEASURED on 2026-08-17. They moved every wave of phases
  23–24 and **two phase-24 summaries misreported them**. **No plan states a predicted post-plan
  value** — the predictions were removed at revision time, because a number sitting beside a
  re-measurement instruction is a number the executor adopts.
- **A new module under `offchain/lib/{Store,Gams}/` joins `aeson_storage_path` in the task that
  CREATES it**, or `the_artifact_path_scan_covers_every_module_on_it` (`Main.hs:8994`) reddens: it
  enumerates the DIRECTORY and compares in BOTH directions. Four modules land this phase —
  `Store/Key.hs` (25-01), `Store/RunLog.hs` (25-04), `Store/Verify.hs` (25-05), `Store/Solver.hs`
  and `Store/Cache.hs` (25-06) — and every one of those tasks carries the step.
- **One file, one runner: a check name is a top-level binding.** Three plans observe the same
  insert-vs-hit distinction and therefore carry three names —
  `a_miss_is_told_from_a_hit_by_the_store_itself` (25-04, raw seam),
  `…_through_the_decision_path` (25-06, through `decide`), `…_by_the_server_itself` (25-07, over the
  capture). A shared name is a compile error, not a redundancy.
- **Carried guard #21** (the echoed-field cross-check, disclosed by phase 24 as having a standing
  assertion and no mutation) **is addressed here**: its firing input IS KEY-02's mutant — mutate
  one token post-render, have the stub echo the unmutated token, assert `EchoMismatch`. The
  freshness conjunct cannot catch it, because the stub writes a fresh file. The other three
  carried guards have no subject in this phase and are re-reported, not dropped.
- **A guard never OBSERVED rejecting is treated as ABSENT.** Restore mutated files from a **saved
  copy** verified by digest — never `git checkout`. **Every check a plan registers appears at least
  once in that plan's mutation table**; this was enforced across all nine plans at revision time.
- **A guard WIDENED must be re-fired.** 25-08 extends `verifier_importers` from one entry to two;
  that extension carries three fresh firing inputs of its own, one of which re-observes the clause
  that actually carries STORE-04 (`offchain/lib/` importers = 0).
- **Prose is inside a grep's blast radius** — eighteen-plus instances across phases 23–25. A
  forbidden token the test file may not spell is BUILT from fragments (`aeson_bait_source`'s idiom,
  `Main.hs:7845`), and the fragment joins are themselves asserted through a shared positive control.
- **The only precedent for spawning a project binary from `cabal test` is `getExecutablePath`
  self-re-execution** (`StoreConformance.hs:498`), which is unavailable when the binary under test is
  a different executable. 25-05's subprocess observation therefore resolves `store-admin` through a
  documented `STORE_ADMIN_BIN` override registered in `advertised_overrides`, and a failed
  resolution is a FAILURE naming the path, never a skip. `cabal run` nested inside `cabal test` is
  refused.

---

## Wave 0 Requirements

**None.** Test infrastructure exists and is reused. Every registration point is a plan task.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Live Postgres observations (trigger refusals, `xmax` discriminator, quarantine, pin/reset retention) | STORE-02/03/05/06/07 | Requires a real server; deliberately out of `cabal test` | `bash offchain/rig/capture-store-conformance.sh` — `postgres:18-alpine` on host port **55433**, not 5432 |
| The GHC refusal of `verify c c` | STORE-02 | A compile-failure check cannot live inside a suite that must compile | Write the scratch module outside the tree, build it, quote the `[GHC-…]` error, delete it (25-05 T4) |

---

## Validation Sign-Off

- [ ] `cabal build --enable-tests -j all` — zero warnings, and the command's OWN exit status checked
- [ ] `cabal test` — FAIL 0, total ≥ 207, and `cabal test`'s own exit status re-raised
- [ ] Both structural greps 0 (DB-free AND GAMS-free)
- [ ] Every added guard observed rejecting its named input; 50-row ledger reconciled
- [ ] Every row of the research's 47-row requirement→test map delivered or deviated BY NAME
- [ ] Tree-derived floors re-measured, not inherited — including in the plans expected not to move them
- [ ] Wall recorded before and after, under 900 s
- [ ] Per-Task Verification Map reconciled against the nine SUMMARY files (25-09 T2)
- [ ] STORE-07 recorded as closing PARTIAL, with Phase 27 named
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
