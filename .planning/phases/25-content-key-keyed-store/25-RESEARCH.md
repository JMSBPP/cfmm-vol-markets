# Phase 25: The Content Key & Keyed Store — Research

**Researched:** 2026-08-17
**Domain:** A content-addressed key over an external deterministic solver, plus cache elision,
on-demand determinism verification, quarantine, pin, scoped reset and an append-only run log —
in Haskell (GHC 9.10.3) over Postgres 18.4, under a hand-rolled `Check` runner that must stay
DB-free and GAMS-free
**Confidence:** HIGH — every claim in **New Measurements** was executed on this machine today,
against a real `postgres:18-alpine` (server 18.4) or against this repository's own tree and suite.
The prior-art cache/verification policy is inherited from `.planning/research/FEATURES.md` and is
cited, not re-derived.

> **This document does not re-derive the domain.**
> `.planning/research/{SUMMARY,FEATURES,STACK,ARCHITECTURE,PITFALLS}.md` settled the key SCOPE,
> the framing requirement, the Nix `--check` position, first-writer-wins + quarantine, the
> `bytea`/`jsonb` split and the three test tiers. `model/mev_tax_model_one/VOLUME_PATH.md`
> (in the sibling `cfmm-wt/gams` worktree) is the AUTHORITATIVE contract for §2's seven inputs and
> §3's determinism guarantee. Phases 23 and 24 delivered the schema, the store seam, the laws, the
> canonical renderer and the toolchain identity. What is NEW is in **New Measurements** and
> **Validation Architecture**, and **three of the measurements change how the phase's success
> criteria must be written.**

---

## User Constraints

**No `CONTEXT.md` exists for this phase** — `.planning/phases/25-content-key-keyed-store/` was
EMPTY at research time (verified: `ls` returns only `.` and `..`). There are therefore no locked
user decisions, no explicitly-delegated discretion areas and no deferred ideas beyond what
`ROADMAP.md`, `REQUIREMENTS.md` and the phase brief state.

### Locked — treated as binding, not to be relitigated

1. **Key = `H(canonical inputs ‖ GAMS version ‖ CONOPT version ‖ model source digest ‖ solver
   options digest)`**, with `key_scheme` INSIDE the unique constraint (shipped at 23-03,
   `001_model_run.sql`).
2. **ONE renderer feeds both the `execve` argv and the hash preimage.** Agreement is STRUCTURAL,
   never asserted. (`Gams.Argv.render_argv` is that renderer; it shipped at 24-02.)
3. **The preimage is FRAMED.** Unframed `H(a‖b‖c)` admits collisions.
4. **The pips denominator (`FEE_DENOMINATOR = 1e6`) is IN the preimage** — confirmed independently
   by issue #28's Algebra-convention rates.
5. **Normalize at the edge, once.** `28e18` → `28000000000000000000`. Shipped:
   `Gams.Argv.parse_shock_field`.
6. **Verification is ON DEMAND, not on every hit.** First-writer-wins, non-zero exit on mismatch,
   and QUARANTINE the divergent bytes rather than discard them.
7. **`bytea` authoritative, `jsonb` derived.** The prover's bytes never touch `Data.Aeson.Value`.

### Also locked (project-wide, enforced in every criterion below)

- **Territory:** `offchain/` and `.planning/` only. Nothing written into `test/`, `model/`, `src/`.
- **`cabal build --enable-tests -j all`**, zero `-Wall` warnings. **The bare `cabal build -j all`
  is VACUOUS** and must never appear in a plan, a task or a summary.
- **`cabal test` stays DB-free AND GAMS-free.** Both structural greps MEASURED at **0** today.
- **"It type-checks" is never acceptance. "The suite is green" is never acceptance** — a suite that
  skips is also green.
- **Tree-derived floors MOVE and must be RE-MEASURED, never inherited.** Two phase-24 summaries
  misreported them. Today's cold values are in §M8; treat even those as hypotheses at plan time.
- `.planning/config.json` sets `workflow.nyquist_validation: true`, so **Validation Architecture**
  below is mandatory and authoritative.

### Claude's discretion (recommendations made below, none pre-locked)

The framing function's exact spelling; whether `gams_sha256` enters the preimage or only the row;
the number of new migrations and their split; whether the run log and quarantine share one
migration; the `Solver` seam's shape; whether Phase 25 extends `store-conformance.json` or adds a
seventh swept artifact (**strongly recommended: extend** — see §M8).

### Out of scope

The fee splitter (Phase 26, and `splitter_version` is its product — `key_scheme` is what makes
adding it later non-destructive); any chain read (27); the resident loop and publication (28);
garbage collection, numeric-aware diff, single-flight and a second store tenant (all deferred to
v7.0 by `REQUIREMENTS.md`).

> ### A note on `./CLAUDE.md`
> The project `CLAUDE.md` in this worktree describes a **Hardhat + viem** layout and points at the
> `hardhat` skill. It is stale with respect to this workstream: there is no `hardhat.config.ts`, no
> `ignition/`, and this milestone is Haskell under `offchain/`. The two skills present
> (`.claude/skills/hardhat`, `hardhat-toolbox-viem`) have no bearing on a content key over a
> Postgres store and were not loaded. Flagged rather than silently ignored — the same note 24-RESEARCH
> made.

---

<phase_requirements>

## Phase Requirements

Fourteen IDs — the largest phase in the milestone.

| ID | Description | Research Support |
|----|-------------|-----------------|
| **KEY-01** | Key is `H(canonical inputs ‖ GAMS ver ‖ CONOPT ver ‖ model source digest ‖ solver options digest)` | Scope settled in `FEATURES.md` Part 1. **New (M4):** every component EXISTS today in `Gams.Run.ToolchainIdentity` — but `ti_model_sources` carries an **absolute machine path**, and `ti_conopt_version` is a **`Maybe`**. Both must be resolved before hashing |
| **KEY-02** | One renderer produces both the `execve` argv and the hash preimage | `Gams.Argv.render_argv` is that renderer (24-02). **New and load-bearing (M3):** the argv actually spawned is `wrapper_argv`, which contains `curdir=<per-run temp dir>` — hashing it gives a hit rate of **exactly zero** while every "the preimage reconstructs the argv" check still PASSES |
| **KEY-03** | Inputs normalized once at the edge, never re-rendered between uses | `Gams.Argv.parse_shock_field` + `render_decimal` shipped at 24-02, and `28e18`/`28000000000000000000` are already the same `Integer`. The gap is the **per-SHOCK assembler** (M5) |
| **KEY-04** | The preimage is framed — no two distinct input tuples share a preimage | **New and it CHANGES SC-1 (M1):** MEASURED, the seven argv tokens are ALREADY self-delimiting under `--name=` prefixes — **0 collisions in a 343-tuple sweep**. A framing test built only from the seven inputs CANNOT FAIL. The same 343 tuples under bare-decimal concatenation give **30 collisions**, with an admissible firing pair named in M1 |
| **KEY-05** | The pips denominator is part of the preimage | `VOLUME_PATH.md` §6 open ruling 2; issue #28 pins `FEE_DENOMINATOR = 1e6` (Algebra convention). A pure constant folded into the preimage; the firing input is changing it and observing every key move |
| **KEY-06** | A missing or unparseable input is an error BEFORE hashing | Half-shipped: `render_argv`'s eight refusals already reject `nEvents = 0`, `liquidity = 0`, `sqrtPriceX96 = 0` and equal fees. **New (M5):** the *omission* half has no subject — no `[(String,String)] -> Either _ Shock` assembler exists, so "omitting a field" is currently unrepresentable rather than refused |
| **KEY-07** | *(Phase 23 — CLOSED)* | Inherited: `(model, key_scheme, key)` in the DDL and the live catalogue; two executing laws |
| **STORE-01** | An identical shock returns the stored artifact **without invoking the solver** | The `Store` record-of-functions is the precedent for a `Solver` record whose `solve` fails the check if called. **New (M7):** `on conflict do nothing returning` returns NOTHING on conflict — the loser cannot tell "I wrote it" from "it existed". `xmax = 0` is the discriminator, MEASURED |
| **STORE-02** | A re-solve producing different bytes is a determinism failure with a non-zero exit | Nix `--check`: exit 1, keep the original. The comparands must be **distinct newtypes** so the tautology does not type-check (`DerivedDoc` idiom, OBSERVED at 23-01) |
| **STORE-03** | The original is kept and the divergent bytes are QUARANTINED | rebuilderd's position, adopted in `FEATURES.md` Part 2. `law_first_writer_wins_on_the_identity_triple` already executes and already carries the reason |
| **STORE-04** | Verification is on demand, not on every hit | Nix shipped `--repeat`/`enforce-determinism` and **removed both in 2.13** as long-broken. A structural scan is the honest instrument: the hot path must not name the verifier |
| **STORE-05** | A run can be pinned so retention never removes it | `model_run.pinned boolean not null default false` already exists (`001_model_run.sql`) |
| **STORE-06** | Reset is separate and cannot run as a side effect of a solve or publish | **New and it CHANGES the design (M2):** `truncate` walks straight through a row-level append-only trigger with **no error at all** — MEASURED, table went to 0 rows |
| **STORE-07** | An append-only run log records `(timestamp, key, event tx, block)` | **New (M2):** `REVOKE UPDATE, DELETE` does **not** stop a superuser — the update LANDED silently. A `BEFORE UPDATE OR DELETE` row trigger does, and a **second** `BEFORE TRUNCATE ... FOR EACH STATEMENT` trigger is required. Both MEASURED |
| **STORE-08** | A partial or failed run never becomes a cache entry | The absence-is-the-pass-condition shape. Phase 24's `Aborted` already carries no artifact; the persistence function must take a `ProverArtifact`, and the evidence needs 24-06's positive-control-that-LANDS instrument |

</phase_requirements>

---

## Summary

Phase 25's whole job reduces to one sentence: *a key must describe the run that actually happened,
and every instrument that says so must be capable of saying otherwise.* Phases 23 and 24 built
almost all the parts — the byte-exact schema, the `key_scheme` column, the store seam, the eight
executing laws, the canonical renderer, the unconstructible-empty version types, the total exit
taxonomy and a `ProverOutcome` whose `Aborted` cannot carry bytes. This phase composes them and
adds the four things that do not exist: the key, the elision path, the verification path, and the
run log.

**Three measurements change the plan materially.**

**First, the phase's flagship framing test, as the roadmap words it, CANNOT FAIL.** SC-1 asks for
"a crafted pair of distinct shocks whose unframed decimal renderings concatenate identically". I
swept 343 shock tuples through `render_argv`'s own token form and got **zero collisions** — because
every token carries a literal `--name=` prefix whose `-` and `=` are outside the digit alphabet, so
the concatenation is a uniquely-parsable regular language. A check built from the seven inputs
against the argv-token preimage passes whether or not anything is framed. The *same* 343 tuples
under bare-decimal concatenation give **30 collisions**, and the pair
`(sqrtPriceX96=1, liquidityRaw=1, txlVolumeRate=23, …)` versus
`(sqrtPriceX96=1, liquidityRaw=12, txlVolumeRate=3, …)` — both **admitted** by `render_argv`'s eight
range refusals — is a real, admissible instance of the roadmap's own `"1"‖"23"` vs `"12"‖"3"`. The
framing test must therefore point at either the framing function directly or the components that
are NOT `--name=`-prefixed: the version strings, the model-name, and the model-source path list.

**Second, the obvious implementation of KEY-02 gives a hit rate of exactly zero, and every KEY-02
check still passes.** `Gams.Run.spawn_into` builds `wrapper_argv` as
`["-k", …, budget, gams, model, "action=ce", "curdir=" ++ run_dir, "lo=2"] ++ argv`. "One renderer
feeds both the argv and the preimage" read literally means hashing that vector — which folds a
per-invocation temp directory into every key. Every shock then misses, every solve runs, the store
elides nothing, and the criterion "reconstruct the argv from the stored preimage and compare" is
*satisfied perfectly*. It is the tautology's sibling: a check that is true of the broken system.
The preimage must cover `render_argv`'s seven tokens plus the **fixed** model options (`action=ce`,
`lo=2`) and must be asserted, in both directions, to EXCLUDE `curdir`, the `/usr/bin/timeout`
wrapper, `-k` and the budget.

**Third, `truncate` is invisible to an append-only trigger, and `REVOKE` is invisible to a
superuser.** Both MEASURED against PG 18.4 today. With `revoke update, delete on run_log from
postgres`, a superuser `UPDATE` **landed** and the row read back `TAMPERED` with no error — the
application connects as `postgres` in this deployment, so a REVOKE-only design is
advertised-and-dead by construction. A `BEFORE UPDATE OR DELETE ... FOR EACH ROW` trigger refuses
both, loudly, for the superuser — and then `truncate run_log` **emptied the table with no error**,
because row-level triggers do not fire on `TRUNCATE`. A second `BEFORE TRUNCATE ... FOR EACH
STATEMENT` trigger closes it, and was MEASURED refusing. STORE-06's `reset` is precisely the
operation a future author reaches for `truncate` to implement, so the hole and the requirement meet.

**Primary recommendation:** build `offchain/lib/Store/{Key,Verify,RunLog,Cache}.hs` as pure-plus-one-
seam modules; make the preimage a **netstring-framed, tagged** byte string built by one function
that also *derives* the shock argv, with `curdir` structurally unreachable from it; make
`CachedBytes` and `FreshlySolvedBytes` distinct newtypes with `FreshlySolvedBytes` constructible
only from a `Produced` outcome; land the run log with **both** triggers and assert their presence in
the live catalogue; renumber the lock probe **before** the first real `004_*.sql`; and extend
`store-conformance.json` rather than adding a seventh swept artifact.

---

## New Measurements

Everything below was executed on this machine today (2026-08-17) against `postgres:18-alpine`
(`server_version` **18.4**, container `cfmm_p25_probe` on host port 55434, removed afterwards), or
against this repository's own tree, suite and committed artifacts. Nothing under `offchain/`,
`model/`, `src/` or `test/` was modified.

### M1. SC-1's framing test, as worded, CANNOT FAIL — and the pair that CAN is named

343 shock tuples (the first three fields swept over `{1,2,3,12,23,123,1123}`, the remaining four
held at the fixture values `phiX=500, phiM=6000, volTgt=28e18, nEvents=8`), each rendered two ways
and checked for preimage collisions:

```
argv-token concatenation  ("--sqrtPriceX96=1--liquidityRaw=1--txlVolumeRate=23…")
    tuples: 343   collisions: 0

bare-decimal concatenation ("1"++"1"++"23"++"500"++"6000"++"28000000000000000000"++"8")
    collisions: 30
    (1,  1, 23, 500, 6000, 28e18, 8)
 vs (1, 12,  3, 500, 6000, 28e18, 8)   ->  112350060002800000000000…   IDENTICAL
```

Both members of that pair pass all eight of `render_argv`'s refusals (`sqrtPriceX96 ≥ 1`,
`liquidityRaw ≥ 1`, `txlVolumeRate ≤ 999999`, `phiXpips ≠ phiMpips`, …), so it is an **admissible**
crafted pair and not a contrived one.

**Why the argv form is collision-free, stated as the argument rather than as luck:** every token is
`--<literal name>=<decimal digits>`, the names are fixed and in a fixed order, and `-` and `=` are
not in the digit alphabet. The concatenation is therefore a uniquely-parsable regular language. The
`--name=` prefixes ARE a framing — an accidental one.

**Consequence for the plan.** SC-1's "crafted pair of distinct shocks" is only discriminating if the
preimage under test is the **bare** rendering. Three honest ways to keep the criterion falsifiable,
and the plan should take all three:

1. Assert the framing function directly: `frame ["1","23"] /= frame ["12","3"]` while
   `concat ["1","23"] == concat ["12","3"]` — a pure Tier-A property whose subject is the framer.
2. Point the shock-level collision test at the **bare-decimal** preimage as a NEGATIVE CONTROL
   (a named function that is *not* the production path), so the 30-collision fact is observed and
   the production path is shown differing on the same pair.
3. Build the crafted pair from the components that carry NO `--name=` prefix — the model name, the
   two version strings and the model-source path list. Those are free-form text and are where a real
   collision lives.

Verified by computation, transcript above. Framing arithmetic, for the record:
`sha256("1"++"23") == sha256("12"++"3") == a665a459…f7a27ae3`, while length-framed
`1:1|2:23|` → `25b0a484…48b54a83` and `2:12|1:3|` → `f0582772…ce916f57`.

### M2. `REVOKE` does not stop a superuser, and `TRUNCATE` walks through an append-only trigger

Three separate observations against a real PG 18.4, in this order.

**(a) `REVOKE` against the role the application actually uses is a no-op.**

```sql
revoke update, delete on run_log from postgres;
update run_log set outcome='TAMPERED' where run_id=1;
select run_id, outcome from run_log;   ->  1|TAMPERED
```

No error. The row was rewritten. `Store.Config.default_pgstore_dsn` is `""`, which falls back to
libpq's `PG*` environment, and the capture connects as `postgres` — a superuser, which bypasses all
permission checks. A REVOKE-only append-only design is advertised-and-dead in this deployment: the
exact class `every_advertised_override_is_honoured` exists to catch.

For completeness, REVOKE *does* work against a non-superuser:

```
appuser UPDATE  ->  ERROR:  permission denied for table run_log
appuser DELETE  ->  ERROR:  permission denied for table run_log
```

so role separation is a real defence *if* a non-superuser role is provisioned. It is not, today.

**(b) A row-level trigger refuses the superuser, loudly, and names the operation.**

```sql
create function run_log_is_append_only() returns trigger language plpgsql as $$
begin
  raise exception using errcode = '23514',
    message = 'run_log is append-only: ' || tg_op || ' is refused',
    hint    = 'append a correcting row instead';
end; $$;
create trigger run_log_append_only before update or delete on run_log
  for each row execute function run_log_is_append_only();
```

```
UPDATE  ->  ERROR:  run_log is append-only: UPDATE is refused
DELETE  ->  ERROR:  run_log is append-only: DELETE is refused
INSERT  ->  2|hit          (the POSITIVE CONTROL: appends still land)
rows    ->  1|miss_solved  2|hit
```

The SQLSTATE is settable and was observed inside a `DO` block as `SQLSTATE=23514`. **A bare
`raise exception` with no `errcode` yields `P0001`** — MEASURED. Recommendation: use a code
*distinct from `23514`*, because migration `003`'s empty-version exhibit already pins `23514` and
two exhibits that report the same SQLSTATE cannot be told apart by it. `P0001` (the default) is
naturally distinct and requires no `errcode` clause at all.

**(c) `TRUNCATE` empties the table with NO error while that trigger is installed.**

```
truncate run_log;
select count(*) from run_log;   ->  0
```

Row-level triggers do not fire on `TRUNCATE`. Adding the statement-level trigger closes it:

```sql
create trigger run_log_no_truncate before truncate on run_log
  for each statement execute function run_log_is_append_only();
```
```
truncate run_log;  ->  ERROR:  run_log is append-only: TRUNCATE is refused
select count(*);   ->  1
```

**(d) The honest limit, recorded rather than hidden.** A superuser can `drop trigger` and then
update — MEASURED (`TAMPERED3` landed after the drop). The trigger is a defence against the
application and against accident, not against a determined superuser. The evidence-grade answer is
that the trigger's **presence in the live catalogue** is asserted:

```sql
select t.tgname, t.tgtype from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
 where c.relname = 'run_log' and not t.tgisinternal order by t.tgname;
-- with only the truncate trigger installed:  run_log_no_truncate|34
```

`tgtype 34` = `BEFORE`(2) + `TRUNCATE`(32). A missing trigger is a missing row, by name — the
`live_identity_constraint_columns` idiom (23-04) applied one table over.

**Consequence for the plan.** STORE-07's append-only property needs **two** triggers, and STORE-06's
`reset` is exactly the operation that reaches for `truncate`. Both firing inputs are named in the
guard table below, and both were observed here.

### M3. Hashing "the argv that ran" gives a hit rate of ZERO — and every KEY-02 check still passes

`offchain/lib/Gams/Run.hs:294-303`, verbatim:

```haskell
let wrapper_argv =
      [ "-k", show (rr_kill_after_s request), show (rr_budget_s request)
      , rr_binary request, rr_model request
      , "action=ce", "curdir=" ++ run_dir, "lo=2" ] ++ argv
```

`run_dir` comes from `with_fresh_run_dir`, which uses the **exclusive** `createDirectory` under
`getTemporaryDirectory` — a different path on every invocation, by design (it is the stale-file
defence). So:

| preimage | key stability | KEY-02 "reconstruct argv from preimage" | STORE-01 elision |
|---|---|---|---|
| `wrapper_argv` (the argv that ran) | **different every run** | **PASSES perfectly** | **never hits** |
| `render_argv` tokens + fixed options | stable | passes | hits |

The first row is the failure mode: the criterion as worded — "reconstructing the argv actually
passed to the prover from the stored preimage and comparing" — is *most* satisfied by the design
that makes the store useless. `rr_binary` (absolute), `-k` and the budget are ambient in the same
way; `FEATURES.md` anti-feature A-5 names "absolute output path" explicitly.

**Consequence for the plan.** The preimage's argv component is `render_argv`'s **seven tokens**
plus the fixed model options `action=ce` and `lo=2` — and the check is a **two-directional set
assertion**: every included token present, every excluded token (`curdir=`, `/usr/bin/timeout`,
`-k`, the budget, `rr_binary`) absent. Its firing input is a preimage carrying `curdir=`, and its
independent corroboration is a **hit-rate observation**: two identical shocks solved in sequence,
the second MUST elide. A key that folds `curdir` fails the second check and passes the first.

### M4. Every KEY-01 component exists today — with two shapes that must be resolved before hashing

From `Gams.Run.ToolchainIdentity` and the committed `offchain/rig/gams-conformance.json`:

```json
"gams_version": "54.1.0",  "gams_build": "37378ce0",  "conopt_version": "4.39.0",
"gams_path":   "/usr/gams/gams54.1_linux_x64_64_sfx/gams",
"gams_sha256": "79cd3a575f40565c5954754a6b6b575dec6e95f966b12ed1e0f7d99236c319fc",
"model_sources": [ { "path":   "/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms",
                     "sha256": "79940449af9e166b00490e2a5e2a8dde7add29dfad04b304fcc07ffe85ca53ad" } ]
```

Two shapes are wrong for a key and both are cheap to fix:

1. **`ti_model_sources` carries an ABSOLUTE MACHINE PATH.** Folding it into the preimage makes every
   key machine-specific: the same shock solved on CI and on a developer's box produces two keys and
   two rows, so the store has a 0% cross-machine hit rate while looking healthy. **Relativise** —
   fold the sorted `(basename-or-model-relative path, sha256)` pairs, or the sorted digests alone.
   The LIST shape (rather than one digest) is correct and stays: `volume_path.gms` has **0**
   `$include` directives today, verified at 24-plan time, so a future include is covered without a
   code change.
2. **`ti_conopt_version :: Maybe ConoptVersion`.** KEY-06 forbids a `Maybe` on the key path. The key
   constructor must take `ConoptVersion` unwrapped, forcing the `Nothing` to be refuted at the edge
   — an abort, never `""`, never `"unknown"`. This is already consistent with migration `003`, whose
   `check (length(conopt_ver) > 0)` was OBSERVED refusing with SQLSTATE `23514` at 24-06.

**A decision the planner owes:** does `gams_sha256` enter the preimage, or only the row and the run
log? Recommendation: **the row and the log, not the key.** §3's determinism guarantee is phrased in
*versions* ("GAMS 54.1, CONOPT 4.39"), and 24-RESEARCH M13 records the binary digest as
machine-specific. Including it turns every reinstall of an identical version into a full-store miss,
which is a cost with no matching guarantee. It is the anti-shadow evidence GAMS-03 already owns, and
it belongs where evidence belongs. Record the decision either way — `key_scheme` makes reversing it
non-destructive.

**Solver options digest — what is actually in it.** The fixed, artifact-affecting options are
`action=ce` and `lo=2`. There is no CONOPT options file on this path today (`Gams.Env`'s whitelist
is `PATH`/`HOME`/`LC_ALL=C`; there is no `conopt.opt`). Fold the sorted fixed-option list, and make
it a **list** for the same reason the model-source list is a list.

### M5. KEY-06's *omission* half has no subject today

`Gams.Argv` exports `parse_shock_field :: String -> Either ArgvError Integer` (per-token) and
`render_argv :: Shock -> Either ArgvError [String]` (per-shock, eight refusals). There is **no**
`[(String, String)] -> Either ArgvError Shock` assembler anywhere in `offchain/lib/`. So:

| KEY-06 clause | Subject today | Status |
|---|---|---|
| "an unparseable value fails" | `parse_shock_field` | **SHIPPED** (24-02; `1.5`, `2.8e1`, signs, whitespace, radix prefixes all refused, each naming the token) |
| "`nEvents = 0`, `liquidity = 0`, `sqrtPriceX96 = 0` are refused" | `render_argv`'s `in_range` | **SHIPPED** (24-02) |
| "the key type carries no `Maybe` and no defaultable field" | `Shock`'s seven strict `Integer`s | **SHIPPED** (24-02) — but see M4's `Maybe ConoptVersion` |
| **"omitting it makes key construction FAIL naming the field"** | *nothing* | **MISSING.** A field cannot be omitted from a record, so the criterion has no subject until an assembler over named inputs exists |

**Consequence for the plan.** Wave 0 must add `parse_shock :: [(String, String)] -> Either ShockError Shock`
that refuses (a) a missing name, (b) a duplicate name, (c) an unknown extra name — each naming the
field. Then "omit `nEvents`" is a real firing input. Note (c) is not decoration: a caller that
supplies `nEvent` (typo) would otherwise get the default the record does not have.

### M6. The lock probe collides with Phase 25's first real migration — again

`offchain/app/StoreConformance.hs:152-153`:

```haskell
lock_probe_filename = "004_lock_probe.sql"
```

It is written into a **scratch copy** of the migration directory, and `postgresql-migration` sorts
by FILENAME. 24-06 renumbered it `003 → 004` for exactly this reason. `offchain/migrations/` now
holds `001`, `002`, `003`, so Phase 25's first real migration is `004_*.sql` — and
`"004_lock_probe.sql"` sorts **before** every plausible name (`004_r…`, `004_q…`, `004_run_log…`),
re-creating the interleaved-probe condition one plan after it was fixed.

**Consequence for the plan.** Renumber the probe in the SAME task as the first real `004`, and give
it a prefix that cannot collide with a numeric sequence — `900_lock_probe.sql` sorts after any
`0xx`. Record it as a decision so the next phase does not pay it a third time.

### M7. `on conflict do nothing returning` cannot tell "I wrote it" from "it existed"

MEASURED:

```sql
insert into cas values ('\x01','\xaa') on conflict do nothing returning k;  --  \x01
insert into cas values ('\x01','\xbb') on conflict do nothing returning k;  --  (NO ROWS)
select k, raw from cas;                                                     --  \x01|\xaa
```

First-writer-wins holds (the `\xbb` did not land), but the caller gets an empty result set on
conflict — indistinguishable from "the statement affected nothing" and from several failure shapes.
STORE-01 and STORE-02 both need that distinction: a hit is an elision (and a `hit` run-log row), a
miss is a solve (and a `miss_solved` row).

The discriminator, also MEASURED:

```sql
insert into cas values ('\x02','\xcc')
  on conflict (k) do update set raw = cas.raw
  returning k, (xmax = 0) as was_inserted;              --  \x02|t   (inserted)
insert into cas values ('\x02','\xdd')
  on conflict (k) do update set raw = cas.raw
  returning k, (xmax = 0) as was_inserted;              --  \x02|f   (already existed)
```

`set raw = cas.raw` assigns the **existing** row's value (`cas.` is the table, `excluded.` is the
proposed), so first-writer-wins is preserved while a row is always returned and `xmax = 0`
distinguishes the two cases atomically, in one statement, with no read-then-write race.

Cost, recorded honestly: the no-op `DO UPDATE` writes a new tuple version (bloat) and takes a row
lock. At this workload — low-KB artifacts, one loop, a handful of solves — that is irrelevant, and
it buys the one bit the elision requirement is about.

### M8. The tree, the suite and the floors — MEASURED COLD today

```
$ cabal build --enable-tests -j all        exit 0,  warnings 0
$ cabal test                               exit 0,  151/151 checks passed,  real 2m32.850s
$ grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs   -> 0
$ grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams'          offchain/test/Main.hs   -> 0
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l    -> 59
$ find offchain \( … -o -name '*.json' \) -type f | wc -l                              -> 68
census under offchain/:  hs 47, sh 9, json 9, sql 3, md 3, txt 2
```

| Constant | `Main.hs` line | Value TODAY | Note |
|---|---|---|---|
| `purge_file_floor` | 1058 | **59** | zero slack against exactly 59 |
| `credential_scan_floor` | 7635 | **68** | zero slack against exactly 68 |
| `sentinel_pair_floor` | 6077 | **3828** | raise until the harness names what it reached |
| `artifact_field_floors` | 6115 | 6 entries; `store-conformance.json` **156**, `gams-conformance.json` **76** | |
| `purge_scanned_extensions` | 975 | `[".hs",".sh",".sql"]` | `.sql` already admitted (23-03) |
| `expected_store_laws` | 6326 | 8 laws | SET in both directions |
| `expected_store_observation_blocks` | 6783 | 14 blocks | SET in both directions (24-06) |
| `aeson_storage_path` | 7807 | 16 files | **plus** the directory-coverage growth guard |

**Wall budget: 152.9 s measured against a 900 s ceiling.** Two cost facts, both from phase-24
measurement and both decisive for the plan's shape:

- **Extending an existing swept artifact is nearly free.** 24-06 added 22 leaves to
  `store-conformance.json` (+130 sentinel pairs) for **+0.2 s**, because `sweep_one`'s `readable`
  filter runs each store-conformance check once per pair of ITS artifact rather than 3828 times.
- **Adding a NEW swept artifact is not.** Phase 23's fifth artifact took the wall 78 s → 97 s.

**Recommendation: extend `store-conformance.json` with Phase 25's blocks. Do not create a seventh
swept artifact.** The subject is the same database and the same capture script.

**Treat every number in this section as a hypothesis at plan time.** Two phase-24 summaries carried
stale floors into a plan brief (55/63 against a disk that read 58/67) and the discrepancy was only
visible because the executor re-measured cold. Re-measure.

---

## Standard Stack

**No new package.** Every dependency this phase needs is already resolved.

### Core

| Library | Version | Purpose | Why |
|---|---|---|---|
| `crypton` | **1.0.6** | SHA256 over the preimage | **+0 packages** — already resolved via `web3-crypto`'s `crypton <1.1` cap. `Store.Types.sha256_hex` exists and renders **bare** hex |
| `postgresql-simple` | **0.7.0.1** | the run log, the quarantine table, the keyed store | already in the plan (+4 at 23-01). `Store.Postgres` is the **sole** importer and stays so |
| `postgresql-migration` | **0.2.1.8** | migrations `004`/`005` | already in the plan. Sorts by FILENAME (see M6) |
| `bytestring`, `containers`, `directory`, `filepath`, `process` | already present | preimage bytes, sets, paths | |
| PostgreSQL | **18.4** | server | pinned image `postgres:18-alpine`; the artifact records image tag AND server version |

### Not needed, and named so nobody adds them

`base16-bytestring` (the digest is `show` on crypton's `Digest`, already bare lowercase hex);
`cryptohash-sha256` (`crypton` is already there); `binary`/`cereal`/`serialise` (the framing is
~10 lines and hand-rolling it is the *correct* trade here — see Don't Hand-Roll for why the
exception is justified); `hashable` (a `Hashable` instance is not a content hash and is not stable
across runs); `uuid` (`bigserial` is the run id).

### Pins that constrain future work

| Package | Constraint | Source |
|---|---|---|
| `crypton` | `<1.1` — forced by `web3-crypto`; resolves 1.0.6 | STACK.md |
| `aeson` | `<2.3` — forced by `web3-crypto`; pinned 2.2.5.0 | STACK.md |
| `base` | `web3-crypto` allows `<4.21`, so GHC 9.12 would break it | STACK.md |

**Verification, executed today:** `cabal build --enable-tests -j all` exit 0, **0 warnings**; the
plan is unchanged from 24-06. Any new package MUST be MEASURED by `plan.json` set-diff against the
current **158** and recorded in the `.cabal` comment discipline (lines 107–115) — never estimated.

```bash
cabal build --enable-tests -j all     # WITHOUT --enable-tests this is VACUOUS
```

---

## Architecture Patterns

### Module layout — role-named, one IO edge per area

```
offchain/lib/Store/
├── Key.hs        PURE.  The framer, the preimage, ContentKey. NO IO. NO curdir reachable.
├── Verify.hs     PURE.  CachedBytes vs FreshlySolvedBytes -> DeterminismVerdict.
├── RunLog.hs     PURE.  RunEvent/Outcome as a total sum type + the column list as data.
├── Cache.hs      IO.    THE SEAM: Store -> Solver -> Shock -> IO Decision. One edge.
└── Solver.hs     IO.    The Solver record-of-functions (Store.Class's shape, one area over).
offchain/migrations/004_run_log.sql        run log + BOTH append-only triggers
offchain/migrations/005_quarantine.sql     divergent bytes, joined to the log
```

Five modules, one IO edge. Every Tier-A check below tests a pure function, so the suite's
discriminating power never depends on a database or a subprocess — the same split that made
Phase 24's `Gams.Run`/`Gams.Invoke` boundary work.

### Pattern 1: the framer, and the tag that makes a component's ABSENCE visible

```haskell
-- Store/Key.hs -- netstring framing (djb): <len> ':' <bytes> ',' -- unambiguous even when the
-- payload contains ':' , ',' or any byte at all.
frame :: BS.ByteString -> Builder
frame bs = intDec (BS.length bs) <> char8 ':' <> byteString bs <> char8 ','

-- TAGGED, not merely framed. A tag makes a DROPPED component a different preimage rather than a
-- shorter one that happens to look like a different shock.
field :: BS.ByteString -> BS.ByteString -> Builder
field tag v = frame tag <> frame v
```

Tagging is the part `FEATURES.md` K5 implies and does not spell: with framing alone, deleting the
`conopt` component gives a preimage that is a *valid* preimage of a shorter tuple. With tags, it is
not — and the check that asserts the tag SET in both directions is the growth guard this repository
has now installed on five separate lists.

### Pattern 2: the preimage cannot reach `curdir` — structurally

```haskell
-- Store/Key.hs  -- takes a Shock and a ToolchainIdentity. It CANNOT take a RunRequest, a
-- FilePath, or a run directory, because none of them is in the signature.
content_key :: KeyScheme -> ModelName -> Shock -> KeyIdentity -> ContentKey

data KeyIdentity = KeyIdentity          -- NOT ToolchainIdentity: no absolute paths, no Maybe
  { ki_gams_version   :: GamsVersion
  , ki_conopt_version :: ConoptVersion  -- unwrapped: the Nothing was refuted at the edge (M4)
  , ki_model_sources  :: [(FilePath, String)]   -- RELATIVISED paths, sorted (M4)
  , ki_fixed_options  :: [String]               -- ["action=ce","lo=2"] -- never curdir (M3)
  , ki_pips_denom     :: Integer                -- KEY-05
  }
```

M3's failure mode becomes unrepresentable rather than untested — the `DerivedDoc` / `Aborted`
instrument, applied a third time.

### Pattern 3: the two comparands are different types

```haskell
-- Store/Verify.hs -- constructors NOT exported.
newtype CachedBytes        = CachedBytes Artifact
newtype FreshlySolvedBytes = FreshlySolvedBytes Artifact

cached_bytes  :: StoredRun     -> CachedBytes           -- the ONLY way to make one
freshly_solved :: ProverOutcome -> Maybe FreshlySolvedBytes  -- Just only on `Produced`

verify :: CachedBytes -> FreshlySolvedBytes -> DeterminismVerdict
```

`verify c c` does not type-check. The residual hole — someone writes a
`CachedBytes -> FreshlySolvedBytes` converter — is closed by the `aeson_scan`-shaped source scan
with a proven positive control, exactly as 23-01 closed `DerivedDoc`'s.

**And the length floor, because a type is not a value check.** Both sides asserted (a) non-empty,
(b) length ≥ a floor, and (c) **decodable by `Gams.Artifact.decode_artifact`** before comparison.
(c) is strictly stronger than (b) and it already exists: it enforces `length dQx == length dQM == nEvents`,
so `"" == ""` and `"{}" == "{}"` are both unreachable.

### Pattern 4: the Solver seam, and the hit test that cannot be satisfied by an echo

```haskell
data Solver = Solver
  { solver_label :: String
  , solver_solve :: Shock -> IO ProverOutcome }
```

The STORE-01 check is a *pair* of assertions, and the second is what makes it non-tautological:

1. seed the store DIRECTLY (`store_put`) with bytes **B**;
2. call the elision path with a solver that would return **B′ ≠ B** if spawned and that also
   increments a counter;
3. assert the returned artifact is **B** — so a path that re-solved and returned the fresh bytes
   fails on the VALUE, not only on the counter;
4. assert the counter is **0** — so a path that solved and then discarded the result fails too.

Either assertion alone is passable by a broken implementation. Both together are not. Step 1 is
deliberately a different code path from the elision path, so "the store returned what we just put
in" is the *intended* observation rather than the confound.

### Pattern 5: the run log is a retention root and carries no foreign key

`FEATURES.md` R1 (git's reflog-as-GC-root): an entry referenced by a recent log row must not be
collected. Applied here, plus one thing R1 does not say: **do not put a foreign key from
`run_log.key` to `model_run`.** Three reasons, all concrete:

- a pre-key abort (an unparseable input, a refused shock) has **no key** — the column is nullable
  and an FK would force a fabricated one;
- STORE-08's failed runs log rows for keys that deliberately have **no** `model_run` row;
- `reset` must be able to delete `model_run` rows while the log survives as evidence, and an FK
  would either block it or cascade the evidence away.

### Anti-patterns

- **Hashing `wrapper_argv`.** M3. Zero hit rate, every KEY-02 check green.
- **`REVOKE` as the append-only guard.** M2(a). Silent no-op against the role in use.
- **A row-level trigger as the whole append-only guard.** M2(c). `truncate` goes straight through.
- **`reset` implemented as `truncate`.** It reaches for exactly the hole in M2(c), and it must never
  touch the run log.
- **An FK from the log to the store.** Pattern 5.
- **Comparing a cached row to a cached row.** The named tautology; answered by types, not a comment.
- **Verifying on every hit.** Nix shipped it and removed it in 2.13 as "broken under many
  circumstances for a long time."
- **A TTL on entries.** Content-keyed entries do not go stale with time. `FEATURES.md` A-10.
- **Overwriting stored bytes on mismatch.** Destroys the only evidence of the only finding the store
  exists to produce. `FEATURES.md` A-1.
- **Fuzzy / nearest-neighbour key matching.** The store silently becomes an interpolator.
  `FEATURES.md` A-3.
- **A tolerance in the identity comparison.** §3's tolerances certify the solver's own output; using
  one as the cache's identity predicate launders a real non-determinism into a pass. `FEATURES.md` A-4.
- **Absolute paths anywhere in the preimage.** M4. Machine-specific keys, 0% cross-machine hits.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| SHA256 | `cryptohash-sha256`, `base16-bytestring` | `Store.Types.sha256_hex` | +0 packages, already renders **bare** hex (a `0x`-prefixed 64-hex literal under `offchain/` reddens `sc3_literal_purge`) |
| the canonical decimal rendering | a second `show`/`printf` on the key path | `Gams.Argv.render_decimal` | It IS the renderer that decided the golden bytes (24-02, M7 of 24-RESEARCH). A second one is two renderers, which is the thing KEY-02 forbids |
| edge normalization of a token | a new parser | `Gams.Argv.parse_shock_field` | `28e18` → `28000000000000000000` already, in `Integer` arithmetic with no floating intermediate |
| the store contract | new laws | `Store.Laws` (8 laws, executing) | `law_first_writer_wins_on_the_identity_triple` already carries STORE-03's invariant and already runs against `Store.Memory` with no server |
| a deliberately-wrong store | a bespoke harness | a record update over `Store.Memory.new_memory_store` | This is why `Store.Class` is a record and not a typeclass — stated in its own header |
| "was this row inserted or already there?" | `select` then `insert` | `on conflict (…) do update set raw = <table>.raw returning (xmax = 0)` | M7. The read-then-write has a race; the `do nothing returning` form returns nothing |
| migration ordering + checksum drift | your own table | `postgresql-migration` + `Store.Schema.expected_migrations` | The manifest is asserted against the directory's WHOLE contents in both directions (23-03) |
| mutual exclusion for migrations | a lock file, a CI `flock` | `pg_advisory_lock(872304)` in `Store.Postgres` | Already there; the library has none (source-read at 23-RESEARCH) |
| "is the committed artifact stale?" | a `generatedAt` comparison | the COMPUTED freshness oracle (recompute migration md5s from the repo) | 21-02 MEASURED that `generatedAt` is not a regeneration witness; 24-06 obs 1 watched the oracle catch a real new migration |
| proving a field is asserted | a one-off probe | register the artifact in `swept_artifacts` | The harness ships positive and negative controls; 24-06 used it to find a field that could only be compared to itself, and DELETED the field |
| proving an env override is live | a README line | an `OverrideProbe` in `advertised_overrides` | Three overrides were MEASURED advertised-and-dead |
| a JSON writer for the capture artifact | hand-rolled | **aeson, in the executable only** | `app/StoreConformance.hs` already does this. The report describes an experiment; it is never an artifact byte, which is why BYTE-03's scan is scoped to the library's storage modules |

**The one JUSTIFIED hand-roll: the framer.** `binary`/`cereal`/`serialise` all exist and all solve
this. They are rejected because (a) each is a new package against a `+0` alternative of ~10 lines,
(b) their encodings are *their* stability contract, not ours — a library version bump that changes a
varint encoding silently reinterprets every stored key, which is precisely the hazard KEY-05 exists
to prevent, and (c) a netstring is auditable by eye in a failure message. The framer is written here,
pinned by a golden preimage vector in Haskell source, and `key_scheme` covers the day it changes.

**Key insight:** almost nothing in this phase is new machinery. Twelve of the thirteen rows above
already exist in this repository. The phase's novel content is the *key contract* and the *elision
decision*, and both are pure.

---

## Common Pitfalls

Phase 25 owns the reincarnations `.planning/research/SUMMARY.md` predicted, plus four found today.

### Pitfall 3 (owned, predicted): the determinism check that compares a cached row to itself
The tautology, named in the milestone research as a *predicted* instance. **Answer:** two newtypes
with unexported constructors, `FreshlySolvedBytes` producible only from a `Produced` outcome, so the
comparison does not type-check. **The input that makes the guard fire:** write
`verify (cached_bytes r) (cached_bytes r)` in a scratch module and OBSERVE the GHC error, in the
shape 23-01 observed `[GHC-39999] No instance for 'Eq DerivedDoc'` and 24-03 observed the refused
`ProverOutcome -> ProverArtifact` accessor.

### Pitfall 6 (owned, predicted): unframed `H(a‖b‖c)` collisions
**Answer and CORRECTION (M1):** the seven argv tokens are already self-delimiting, so the roadmap's
crafted-shock-pair test is vacuous against the production preimage. Point it at the framer, at a
named bare-decimal negative control, and at the free-form components.
**The input that makes the guard fire:** `frame ["1","23"]` vs `frame ["12","3"]`, plus the
admissible shock pair in M1.

### Pitfall 2 (owned, predicted): `nEvents` absent → `0` before hashing
**Answer:** `Shock`'s seven strict `Integer`s and `render_argv`'s `nEvents ≥ 1` refusal already close
the *zero* half (24-02). **The gap is the omission half (M5)** — there is no assembler to omit a
field from. **The input that makes the guard fire:** `parse_shock [( "sqrtPriceX96","1"), …]` with
`nEvents` absent → `Left (MissingField "nEvents")`.

### Pitfall 5 (owned): GAMS exit code `0`
Inherited closed from Phase 24 — `Aborted` carries no artifact and the exit taxonomy is total. Phase
25's job is only that the **persistence function takes a `ProverArtifact`**, so there is no code path
from an abort to an insert. STORE-08.

### New, phase-local: the hit-rate-zero key that passes every KEY-02 check
M3. The most likely way this phase ships broken. Answered by a two-directional token set assertion
AND an elision observation, which fail on opposite designs.

### New, phase-local: `truncate` is invisible to an append-only trigger
M2(c). Two triggers, and the catalogue asserts both are present by name.

### New, phase-local: `REVOKE` against a superuser is a silent no-op
M2(a). The update LANDED and read back `TAMPERED`. If a role-separation design is chosen, the
non-superuser role must be provisioned and the refusal OBSERVED under that role — otherwise the
guard is advertised-and-dead.

### New, phase-local: the absolute model-source path in the key
M4. Machine-specific keys, invisible in every single-machine test.

### New, phase-local: STORE-08's pass condition is an ABSENCE
"A partial or failed run never becomes a cache entry" is green when the store is switched off, when
the connection is dead, when the table does not exist and when the insert path was never called.
**The only instrument that fixes it is 24-06's:** a POSITIVE CONTROL that LANDS, evaluated FIRST —
the same driver, the same key, a `Produced` outcome, `rows_after = 1` from the **server's own
count** — and then each abort variant DRIVEN separately with `rows_after = 0` and exactly one
run-log row. "An exception was raised" and "nothing was written" are different claims.

### Inherited and still live: prose inside a grep's blast radius
Eighteen instances on this branch (24-06 deviation 6). Any haddock in a new `Store/*.hs` that
*names* a scanned token reddens the scan that reads that file. Describe, do not name.

---

## Code Examples

### The framed, tagged preimage (KEY-01, KEY-04, KEY-05)

```haskell
-- Store/Key.hs
-- Netstring framing: <len> ':' <bytes> ','  -- unambiguous for ANY payload byte.
-- The TAG is what makes a dropped component a different preimage rather than a shorter one.
--
-- MEASURED (25-RESEARCH M1): sha256("1"++"23") == sha256("12"++"3") == a665a459..f7a27ae3,
-- while the framed forms differ.  MEASURED (M3): curdir is NOT reachable from this signature.
key_preimage :: KeyScheme -> String -> Shock -> KeyIdentity -> BS.ByteString
key_preimage scheme model shock ident = toStrict . toLazyByteString $ mconcat
  [ field "scheme"    (c8 (show_scheme scheme))
  , field "model"     (c8 model)
  , field "shock"     (frames (map c8 (must_render shock)))   -- render_argv's SEVEN tokens
  , field "opts"      (frames (map c8 (ki_fixed_options ident)))   -- ["action=ce","lo=2"]
  , field "pipsdenom" (c8 (render_decimal (ki_pips_denom ident)))
  , field "gams"      (c8 (gams_version_text (ki_gams_version ident)))
  , field "conopt"    (c8 (conopt_version_text (ki_conopt_version ident)))
  , field "modelsrc"  (frames [ c8 p <> c8 d | (p, d) <- sort (ki_model_sources ident) ])
  ]

content_key :: KeyScheme -> String -> Shock -> KeyIdentity -> ContentKey
content_key s m sh i = ContentKey (BS.pack (sha256_bytes (key_preimage s m sh i)))
```

### The append-only run log, with BOTH triggers (STORE-07)

```sql
-- 004_run_log.sql -- MEASURED against PG 18.4 on 2026-08-17.
--
-- NO FOREIGN KEY to model_run, deliberately: a pre-key abort has no key, STORE-08's failed runs
-- log rows for keys that have no store row, and reset must be able to remove store rows while the
-- chronology survives as evidence.
create table run_log (
  run_id     bigserial   primary key,
  started_at timestamptz not null default now(),
  key        bytea,                    -- NULLABLE: a pre-key abort has none
  key_scheme smallint,
  outcome    text        not null,     -- hit | miss_solved | verified_match | verified_mismatch
                                       -- | aborted_* | refused_*
  event_tx   bytea,                    -- the chain provenance the KEY deliberately excludes
  block_no   numeric,
  gams_ver   text,                     -- duplicated from the key ON PURPOSE: the log must stay
  conopt_ver text,                     -- readable after a key-scheme change
  exit_code  integer,
  elided     boolean     not null,
  solve_ms   integer                   -- NULL on an elision: that is the elision METRIC
);

create function run_log_is_append_only() returns trigger language plpgsql as $$
begin
  -- No errcode clause: the default is P0001, DELIBERATELY distinct from 23514, which migration
  -- 003's empty-version exhibit already pins. Two exhibits that report the same SQLSTATE cannot
  -- be told apart by it.
  raise exception 'run_log is append-only: % is refused', tg_op
    using hint = 'append a correcting row instead';
end; $$;

-- MEASURED: this one refuses a SUPERUSER's UPDATE and DELETE.  `revoke update, delete` does NOT.
create trigger run_log_append_only before update or delete on run_log
  for each row execute function run_log_is_append_only();

-- MEASURED: WITHOUT this one, `truncate run_log` emptied the table with NO ERROR AT ALL, because
-- a row-level trigger does not fire on TRUNCATE. This is the second half of the guard, not a
-- belt-and-braces extra.
create trigger run_log_no_truncate before truncate on run_log
  for each statement execute function run_log_is_append_only();
```

### Insert-or-hit, told apart in one statement (STORE-01)

```sql
-- MEASURED: `on conflict do nothing returning` returns NO ROW on conflict, so the caller cannot
-- distinguish "I wrote it" from "it existed". `set raw = model_run.raw` assigns the EXISTING
-- value (model_run. is the table, excluded. is the proposed), so first-writer-wins is preserved
-- AND a row always comes back.  xmax = 0  <=>  this statement inserted it.
insert into model_run (model, key_scheme, key, raw, doc, gams_ver, conopt_ver)
values (?, ?, ?, ?, convert_from(?, 'UTF8')::jsonb, ?, ?)
on conflict (model, key_scheme, key) do update set raw = model_run.raw
returning (xmax = 0) as was_inserted;
```

### The live-catalogue trigger assertion (STORE-07)

```sql
-- The live_identity_constraint_columns idiom (23-04), one table over. A dropped trigger is a
-- MISSING ROW, by name -- not a silently weaker guard.  tgtype 34 = BEFORE(2) + TRUNCATE(32).
select t.tgname, t.tgtype
  from pg_trigger t join pg_class c on c.oid = t.tgrelid
 where c.relname = 'run_log' and not t.tgisinternal
 order by t.tgname;
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None, by design.** A hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name :: String, check_run :: IO (Either String ()) }` (`offchain/test/Main.hs:512`), `guarded` at `:518`, `pure_check` at `:525`. Every check runs; the process exits non-zero if any failed |
| Config file | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` |
| Registration point | `core_checks :: IO [Check]` (`offchain/test/Main.hs:11042`). **A check not in this list does not exist** and the sentinel harness cannot re-run it |
| Quick run command | `cabal build --enable-tests -j all` — `--enable-tests` is load-bearing; the bare form exits 0 without compiling the suite and is **VACUOUS** |
| Full suite command | `cabal test` |
| Hard gates | zero `-Wall` warnings under `offchain/`; suite **DB-free** and **GAMS-free** (both greps MEASURED **0** today) |
| Baseline, MEASURED COLD 2026-08-17 | **151/151**, wall **152.9 s**, warnings **0**, budget **900 s**. RE-MEASURE at plan time |
| Subprocess precedent | The suite already spawns `grep` (`purge_scan`, `aeson_scan`) and writes stubs into its own temp dirs (24-03/24-04). Tier-B is an existing idiom |

**No new test file.** Phase 25 extends `offchain/test/Main.hs`. Deviating puts checks outside
`core_checks`, where the sentinel harness cannot reach them.

**The three tiers, for this phase:**

| Tier | What runs | Needs a DB or GAMS? |
|---|---|---|
| **A** | pure functions and source scans — the framer, the preimage, the key, the verifier's types, the run-log outcome taxonomy, the exclusion set, the DDL-vs-`Store.Schema` file half | **No** |
| **B** | real execution inside `cabal test` against `Store.Memory` and against `Solver` stubs the check constructs — elision, first-writer-wins, quarantine, the no-spawn assertion, the abort→no-entry path | **No** |
| **C** | assertions over the committed `offchain/rig/store-conformance.json`, extended by `offchain/rig/capture-store-conformance.sh` | **Only for the capture** |

### Requirement → Test Map

All fourteen IDs. **No row needs a database or GAMS inside `cabal test`.**

| Req | Check name | Lives in | Tier | The input that makes it FAIL | Needs DB/GAMS? |
|---|---|---|---|---|---|
| **KEY-01** | `content_key_preimage_names_every_required_component` | `Store.Key` + `pure_check` | A | The tag SET (`scheme, model, shock, opts, pipsdenom, gams, conopt, modelsrc`) differing from `Store.Key.key_component_tags` **in either direction** — a dropped `conopt` tag, or an added tag nothing names | No |
| **KEY-01** | `content_key_moves_when_any_component_moves` | `Store.Key` + `pure_check` | A | Changing exactly one component (each of the eight, one at a time) and getting the **same** key. Eight sub-cases, asserted as a set of eight distinct digests — a component the key ignores is a component the store cannot tell apart | No |
| **KEY-01** | `key_identity_carries_no_absolute_path` | `Store.Key` + `pure_check` | A | A `ki_model_sources` entry whose path `isAbsolute`. M4's firing input verbatim: `/home/…/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms` | No |
| **KEY-01** | `store_conformance_records_a_key_written_and_read_back` | `Main.hs` over the artifact | C | The artifact recording a key length ≠ 32, a key of all-zero bytes, or a readback key differing from the written one | No |
| **KEY-02** | `the_preimage_argv_is_exactly_render_argv_plus_fixed_options` | `Store.Key` + `pure_check` | A | The token list differing from `render_argv shock ++ ki_fixed_options` **as an ordered list**. Firing input: drop `lo=2`, or reorder two tokens | No |
| **KEY-02** | `the_preimage_excludes_every_per_run_token` | `Store.Key` + `pure_check` | A | **M3's firing input:** a preimage containing `curdir=`, `/usr/bin/timeout`, `-k`, the budget, or `rr_binary`'s absolute path. Asserted as a forbidden-substring SET with a **positive control** (a deliberately-polluted preimage the check is SHOWN rejecting) | No |
| **KEY-02** | `an_identical_shock_produces_an_identical_key_across_invocations` | `Main.hs`, `Store.Memory` + stub `Solver` | B | **The hit-rate observation.** Two `run_prover`-shaped invocations of the same shock through the real `Gams.Run.with_fresh_run_dir` (stubbed binary) yielding two DIFFERENT keys. This is the check a `curdir`-folding key fails and the reconstruct-the-argv check does not | No |
| **KEY-02** | `key_and_invocation_agree_by_construction` | `Main.hs`, `aeson_scan` idiom | A | A second decimal renderer appearing under `offchain/lib/{Store,Gams}/` — the scan matches `show ::.*Double`, `printf`, `showFFloat`, or a second `render_` on the key path. **Positive control mandatory** | No |
| **KEY-02** | `store_conformance_records_the_stored_preimage_reconstructing_the_argv` | `Main.hs` over the artifact | C | The recorded preimage failing to yield the recorded argv token list; **or** the recorded argv containing a `curdir=` token — the artifact would then be recording the broken design as evidence for the correct one | No |
| **KEY-03** | `edge_normalization_is_idempotent_and_single_pass` | `Gams.Argv` + `pure_check` | A | `parse_shock_field "28e18" /= parse_shock_field "28000000000000000000"`; or `render_decimal . parse_shock_field` not being the identity on the canonical form. Extends 24-02's shipped checks rather than duplicating them | No |
| **KEY-03** | `no_field_is_re_rendered_between_the_edge_and_the_key` | `Main.hs`, source scan | A | `Store/Key.hs` or `Store/Cache.hs` naming `show`, `printf` or a `String`-to-`Integer` reparse on a field already normalized. Positive control mandatory | No |
| **KEY-04** | `framing_separates_what_concatenation_conflates` | `Store.Key` + `pure_check` | A | **The framer's own firing input:** `frame ["1","23"] == frame ["12","3"]`. The check ALSO asserts `concat ["1","23"] == concat ["12","3"]`, so a framer that became the identity reddens because its subject vanished (the `aeson_round_trip_mutations_are_re_measured` idiom) | No |
| **KEY-04** | `the_bare_decimal_preimage_is_OBSERVED_colliding` | `Main.hs` + `pure_check` | A | **M1, as a negative control with a live subject.** The admissible pair `(1,1,23,500,6000,28e18,8)` vs `(1,12,3,500,6000,28e18,8)`: the bare-decimal renderings must be EQUAL and the production keys must DIFFER. If the bare renderings ever stop colliding, the control lost its subject and the check reddens | No |
| **KEY-04** | `free_form_components_cannot_be_conflated` | `Store.Key` + `pure_check` | A | The pair `(gams="54.1.0", conopt="4.39.0")` vs `(gams="54.1.0" <> "4.39.0", conopt="")` — the second is unconstructible by type, so the check is written over the framer's inputs directly. Also `model_sources` `[("a",h),("bc",h')]` vs `[("ab",h),("c",h')]` | No |
| **KEY-05** | `the_pips_denominator_is_in_the_preimage` | `Store.Key` + `pure_check` | A | Changing `ki_pips_denom` from `1000000` to `1000001` and getting the **same** key. Asserted as an inequality on digests, so no tolerance can absorb it | No |
| **KEY-05** | `the_pips_denominator_constant_is_stated_once` | `Main.hs`, source scan | A | The literal `1000000`/`1e6` appearing on the key path anywhere but its single named constant; or the constant's value differing from issue #28's `FEE_DENOMINATOR` recorded in `Store.Key` | No |
| **KEY-06** | `an_omitted_input_fails_key_construction_naming_the_field` | `Gams.Argv`(new assembler) + `pure_check` | A | **M5's firing input:** `parse_shock` over the six-of-seven named pairs → must be `Left (MissingField "nEvents")`. Seven sub-cases, one per field, asserted as a SET so a field that stopped being required is a set mismatch | No |
| **KEY-06** | `a_duplicate_or_unknown_input_name_is_refused` | new assembler + `pure_check` | A | `nEvents` supplied twice with different values, or `nEvent` (typo) supplied — either being ACCEPTED. The typo case is the one a record type cannot catch | No |
| **KEY-06** | `an_unparseable_input_fails_before_hashing` | `Gams.Argv` + `pure_check` | A | `"1.5"`, `"2.8e1"`, `" 8"`, `"+8"`, `"0x8"`, `"८"`, `""` reaching a digest. Already shipped at 24-02; this check asserts the KEY path routes through it rather than re-implementing | No |
| **KEY-06** | `the_key_type_carries_no_Maybe_and_no_defaultable_field` | `Store.Key` (compile) + scan | A | `KeyIdentity` gaining a `Maybe` field, or the scan finding `fromMaybe`, `<\|> pure`, `catch (\_ -> return` under `offchain/lib/Store/Key.hs`. **M4:** `ti_conopt_version` IS a `Maybe` and must be refuted at the edge | No |
| **KEY-07** | *(Phase 23 — CLOSED)* | `Store.Laws` ×2 + catalogue | B + C | Inherited. Phase 25 must not weaken it: `content_key` takes a `KeyScheme` and the store's identity stays the triple | No |
| **STORE-01** | `an_identical_shock_returns_the_stored_artifact` | `Main.hs`, `Store.Memory` + stub `Solver` | B | **Pattern 4's PAIR.** (a) the returned artifact being **B′** (the solver's bytes) rather than the seeded **B** — a path that re-solved; (b) the call counter being ≠ 0. Either alone is passable by a broken implementation | No |
| **STORE-01** | `the_solver_is_never_spawned_on_a_hit` | `Main.hs`, a `Solver` whose `solve` FAILS the check | B | The counting solver being called at all. **Not timing** — a counter, per the roadmap. Positive control: the same driver on a MISS must call it exactly once, else "never called" is satisfied by a driver that never runs | No |
| **STORE-01** | `a_miss_is_told_from_a_hit_by_the_server_itself` | `Main.hs` over the artifact | C | The artifact recording `was_inserted` identically for the first and second put of the same triple. **M7:** `xmax = 0` is `t` then `f`; equal values mean the discriminator stopped discriminating | No |
| **STORE-02** | `a_disagreeing_resolve_is_a_determinism_failure` | `Store.Verify` + `pure_check` | A | `verify` returning `Match` on two artifacts whose digests differ; or returning `Mismatch` on two identical ones | No |
| **STORE-02** | `the_two_comparands_are_different_types` | `Store.Verify` (compile) + scan | A | A `CachedBytes -> FreshlySolvedBytes` converter, an exported constructor, or `freshly_solved` accepting an `Aborted` outcome. **OBSERVE the GHC error**, the `DerivedDoc` / `ProverOutcome` idiom | No |
| **STORE-02** | `both_comparands_are_non_empty_and_decodable_before_comparison` | `Store.Verify` + `pure_check` | A | `verify` on two empty artifacts returning `Match`; on two `"{}"` artifacts returning `Match`; on an artifact shorter than the length floor returning anything but a refusal. **This is where `"" == ""` is made unreachable** | No |
| **STORE-02** | `a_determinism_mismatch_exits_non_zero` | `Main.hs`, subprocess over the verify entrypoint | B | The entrypoint exiting **0** on a mismatch. `postgresql-migration` exits 0 on a checksum mismatch and this repo has already been burned by it once — the observation is `echo $?` == 1, from a real subprocess | No |
| **STORE-03** | `the_original_survives_a_disagreeing_resolve` | `Store.Laws` (`law_first_writer_wins…`) | B | Already executing and already observed. Extended: after the mismatch the stored artifact must still be the FIRST writer's bytes, asserted on the digest | No |
| **STORE-03** | `divergent_bytes_are_found_in_quarantine` | `Main.hs`, `Store.Memory` | B | The quarantine holding **0** rows after a driven mismatch; or holding bytes equal to the original (which would mean the mismatch never happened); or the quarantine row not naming both digests and the key | No |
| **STORE-03** | `store_conformance_records_a_quarantined_divergence` | `Main.hs` over the artifact | C | `quarantine_rows_after == 0`; `original_sha256 == divergent_sha256` (the exhibit lost its subject); or the **POSITIVE CONTROL** — an AGREEING re-solve — recording a quarantine row, which would mean quarantine fires on agreement too | No |
| **STORE-04** | `verification_is_absent_from_the_lookup_path` | `Main.hs`, source scan | A | `Store/Cache.hs`'s lookup path naming `Store.Verify`, `freshly_solved` or the solver on the hit branch. **Positive control mandatory** — a seeded bait file the scan is SHOWN matching | No |
| **STORE-04** | `verification_is_reachable_only_from_its_own_entrypoint` | `Main.hs` + `pure_check` | A | More than one caller of `verify` in the tree; or zero (a verifier nothing calls is `--repeat` removed by accident) | No |
| **STORE-04** | `the_determinism_history_has_at_least_one_row` | `Main.hs` over the artifact | C | **The roadmap's own clause:** a determinism-check history with **zero** rows fails the phase. Asserted as a SET of verification outcome names in both directions, never a count — 24-06 MEASURED a count passing a rename | No |
| **STORE-05** | `a_pinned_run_survives_reset` | `Main.hs`, `Store.Memory` | B | The pinned row being absent after `reset --force`; or an UNPINNED row surviving it (which would mean reset deleted nothing and the survival is vacuous). **Both arms, always** | No |
| **STORE-05** | `store_conformance_records_the_pin_column_and_its_default` | `Main.hs` over the artifact | C | The live catalogue's `model_run.pinned` default not being `false`, or the column being absent | No |
| **STORE-06** | `bare_reset_refuses_when_a_pin_exists` | `Main.hs`, subprocess | B | Bare `reset` exiting **0** with pins present; or the message not naming the pinned count. Positive control: with no pins, bare `reset` must SUCCEED, else "it refused" is satisfied by a command that always refuses | No |
| **STORE-06** | `reset_is_unreachable_from_a_solve_or_a_publish` | `Main.hs`, source scan | A | `Store/Cache.hs`, the solve path or the publish path naming `reset`, `truncate`, `delete from model_run`, or `drop table`. Positive control mandatory | No |
| **STORE-06** | `store_conformance_records_truncate_refused_on_the_run_log` | `Main.hs` over the artifact | C | **M2(c)'s firing input, recorded.** The artifact recording `truncate_refused == false` — the row-level trigger alone lets `truncate` through SILENTLY, so this is the observation the second trigger exists for | No |
| **STORE-07** | `run_log_outcome_taxonomy_is_total_and_disjoint` | `Store.RunLog` + `pure_check` | A | An outcome string outside the named set reaching the writer; or two constructors rendering to the same string | No |
| **STORE-07** | `the_same_key_twice_yields_two_log_rows_and_one_entry` | `Main.hs`, `Store.Memory` | B | Two log rows and two entries (no elision), or one log row and one entry (the chronology lost the hit). **The pair is the assertion**, not either half | No |
| **STORE-07** | `run_log_columns_match_Store_RunLog_in_both_directions` | `Store.Schema` + `pure_check` | A | The DDL naming a column `Store.RunLog` does not, or vice versa. The `versions_nonempty_columns` idiom (24-06) | No |
| **STORE-07** | `store_conformance_records_the_append_only_refusals` | `Main.hs` over the artifact | C | **M2's firing inputs, all four.** `update_refused`, `delete_refused` or `truncate_refused` recorded `false`; the recorded SQLSTATE not the pinned VALUE; or the **POSITIVE CONTROL** (an INSERT that LANDS, `rows_after` from the server's own count) recording `accepted false` — without which every refusal is satisfied by a dead connection | No |
| **STORE-07** | `store_conformance_records_both_triggers_in_the_live_catalogue` | `Main.hs` over the artifact | C | The recorded `pg_trigger` rows not naming BOTH `run_log_append_only` and `run_log_no_truncate`, as a SET in both directions. **M2(d):** a dropped trigger is the guard's own bypass and this is what sees it | No |
| **STORE-08** | `an_aborted_run_produces_no_cache_entry` | `Main.hs`, `Store.Memory` + stub `Solver` | B | **Four DRIVEN variants**, each separately: non-zero exit, `TimedOut`, exit-0-with-no-artifact, and a pre-spawn `ArgvRejected`. Each must give `entries == 0` AND `log_rows == 1`. **The POSITIVE CONTROL runs FIRST**: a `Produced` outcome through the identical driver gives `entries == 1` | No |
| **STORE-08** | `no_code_path_converts_an_abort_into_an_entry` | `Store.Cache` (compile) + scan | A | The persistence function accepting a `ProverOutcome` rather than a `ProverArtifact`; or a `ProverOutcome -> ProverArtifact` accessor appearing. Inherited from 24-03's OBSERVED GHC error | No |
| **STORE-08** | `store_conformance_records_zero_entries_after_a_driven_abort` | `Main.hs` over the artifact | C | `entries_after == 0` recorded without a preceding `control_entries_after == 1`; or the four abort variants recorded as fewer than four distinct `AbortReason`s (a SET, never a count) | No |

### Every guard, and the input that makes it fire

A guard never seen to reject is the empty-log finding. One row per guard; **no row says "invalid
input"** — each names an exact value, and every value marked MEASURED was captured on this machine
today.

| # | Guard | The exact input that makes it fire | Observation |
|---|---|---|---|
| 1 | framer separates | `frame ["1","23"]` vs `frame ["12","3"]` | digests differ (`25b0a484…` vs `f0582772…`) while `concat` gives the identical `123`. **MEASURED** |
| 2 | framer's subject still exists | make `frame` the identity | the `concat` half of the same check reddens — the control lost its subject |
| 3 | bare-decimal preimage collides | shock `(1, 1, 23, 500, 6000, 28e18, 8)` vs `(1, 12, 3, 500, 6000, 28e18, 8)` | bare renderings IDENTICAL (`112350060002800000000000…`), production keys DIFFER. **MEASURED: 30 collisions in 343 tuples** |
| 4 | argv preimage is NOT the discriminator | the same pair through argv-token concatenation | **0 collisions in 343 tuples. MEASURED.** This is why guard 3 must exist |
| 5 | free-form component conflation | `model_sources` `[("ab",h1),("c",h2)]` vs `[("a",h1),("bc",h2)]` under an unframed join | equal preimages; framed, they differ |
| 6 | **preimage excludes `curdir`** | a preimage built from `wrapper_argv` (M3), containing `curdir=/tmp/…` | forbidden-substring set reddens, naming the token |
| 7 | **hit rate is not zero** | two identical shocks solved in sequence | the second MUST elide. A `curdir`-folding key fails HERE and passes guard 6's sibling |
| 8 | preimage includes every fixed option | delete `lo=2` from `ki_fixed_options` | ordered-list assertion reddens |
| 9 | tag SET growth guard | add a component to the preimage without naming it in `key_component_tags` | set mismatch in both directions |
| 10 | every component moves the key | change `conopt` from `4.39.0` to `4.40.0`, one component at a time × 8 | eight distinct digests; any repeat is a component the key ignores |
| 11 | pips denominator in the key | `1000000` → `1000001` | the key changes. An unchanged key means KEY-05 is decoration |
| 12 | no absolute path in the key | `ki_model_sources = [("/home/…/volume_path.gms", …)]` | `isAbsolute` refusal. **MEASURED present in `gams-conformance.json` today** |
| 13 | no `Maybe` on the key path | `KeyIdentity` gaining `Maybe ConoptVersion`, or `fromMaybe "unknown"` in `Store/Key.hs` | compile error / scan red with a proven positive control |
| 14 | **omitted field refused** | `parse_shock` over six of seven named pairs, `nEvents` absent | `Left (MissingField "nEvents")`. **M5: no subject exists today** |
| 15 | duplicate / typo'd field refused | `nEvents` twice with different values; `nEvent` (typo) | `Left`. The typo is the case a record type cannot catch |
| 16 | unparseable field refused | `"1.5"`, `"2.8e1"`, `"+8"`, `" 8"`, `"0x8"`, `""` | `Left NotADecimalInteger`, naming the token. Shipped 24-02 |
| 17 | zero-valued field refused | `nEvents = 0`, `liquidityRaw = 0`, `sqrtPriceX96 = 0` | `Left FieldOutOfRange`, naming the field. Shipped 24-02 |
| 18 | second renderer on the key path | seed `printf "%d"` into `Store/Key.hs` | scan red with a proven positive control |
| 19 | **hit returns the STORED bytes** | seed the store with **B**, run the elide path with a solver returning **B′** | the result must be **B**. A re-solving path fails on the VALUE |
| 20 | **hit spawns nothing** | the same call, with a counting solver | counter **0**. Positive control: the MISS path must call it exactly **once** |
| 21 | insert vs existing told apart | put the same triple twice | `xmax = 0` returns `t` then `f`. **MEASURED.** `on conflict do nothing returning` returns **no row** and cannot |
| 22 | verify comparands are distinct types | write `verify (cached_bytes r) (cached_bytes r)` | GHC error, OBSERVED — the `DerivedDoc` idiom |
| 23 | **`"" == ""` unreachable in verify** | two empty artifacts; two `"{}"` artifacts; one below the length floor | refusal, not `Match`. `decode_artifact` enforces `length dQx == length dQM == nEvents` |
| 24 | mismatch exits non-zero | a corrupted cached row against a fresh solve | `echo $?` == **1** from a real subprocess. Exit 0 ⇒ RED |
| 25 | original survives a mismatch | the disagreeing second put | the stored digest is still the FIRST writer's. `law_first_writer_wins…` already executes |
| 26 | divergent bytes quarantined | the same mismatch | quarantine holds **1** row naming the key and BOTH digests. **0 rows ⇒ RED** |
| 27 | quarantine does NOT fire on agreement | an AGREEING re-solve | quarantine holds **0** new rows. Without this, guard 26 is satisfied by a quarantine that records everything |
| 28 | verification off the hot path | seed a `Store.Verify` import into the lookup branch of `Store/Cache.hs` | scan red with a proven positive control |
| 29 | verifier has exactly one caller | delete the verify entrypoint | caller count 0 ⇒ RED (`--repeat` removed by accident); >1 ⇒ RED (it crept onto the hot path) |
| 30 | determinism history non-empty | an artifact whose verification block records zero outcomes | RED. The roadmap's own clause |
| 31 | pin survives reset | `reset --force` with one pinned and one unpinned row | pinned present, unpinned **gone**. Both arms — a reset that deletes nothing satisfies the first alone |
| 32 | bare reset refuses over pins | bare `reset` with one pin | non-zero exit naming the pinned count. Positive control: with **no** pins it must SUCCEED |
| 33 | reset unreachable from a solve | seed `truncate model_run` into `Store/Cache.hs` | scan red with a proven positive control |
| 34 | **`REVOKE` is not the guard** | `revoke update, delete on run_log from postgres;` then `update` | the row reads back `TAMPERED`, **no error**. **MEASURED.** Recorded so a REVOKE-only design is never mistaken for a guard |
| 35 | **row trigger refuses UPDATE/DELETE** | `update run_log set outcome='TAMPERED' where run_id=1` | `ERROR: run_log is append-only: UPDATE is refused`. **MEASURED**, against a superuser |
| 36 | **`TRUNCATE` walks through the row trigger** | `truncate run_log` with only the row-level trigger | table goes to **0 rows, no error**. **MEASURED.** With the statement trigger: `ERROR: … TRUNCATE is refused`, count **1** |
| 37 | the append-only POSITIVE CONTROL lands | an INSERT alongside the refusals | `rows_after == 1` from the **server's own count**. Without it every refusal is satisfied by a dead connection, a missing table and a malformed key |
| 38 | both triggers present in the catalogue | `drop trigger run_log_no_truncate on run_log` | the recorded `pg_trigger` SET is short, naming the missing trigger. **MEASURED shape:** `run_log_no_truncate\|34` |
| 39 | SQLSTATE is a pinned VALUE | the trigger's `raise` losing its message, or the code drifting | the recorded code ≠ the pinned one. **MEASURED: a bare `raise exception` yields `P0001`**; `23514` is already taken by migration 003 |
| 40 | same key twice ⇒ two log rows, one entry | solve, then solve the identical shock | `log_rows == 2 && entries == 1`. Either half alone passes a broken design |
| 41 | **abort ⇒ no cache entry** | four DRIVEN variants: non-zero exit, timeout, exit-0-no-artifact, pre-spawn `ArgvRejected` | `entries == 0 && log_rows == 1` for each. **The `Produced` POSITIVE CONTROL runs FIRST** and must give `entries == 1` |
| 42 | no abort→entry code path | make the persistence function take a `ProverOutcome` | compile error / scan red. Inherited from 24-03's OBSERVED refusal |
| 43 | run-log columns match the DDL | drop a column from `Store.RunLog` and not from `004_*.sql` | set mismatch in both directions (the `versions_nonempty_columns` idiom) |
| 44 | migration manifest growth | add `004_*.sql` without moving `Store.Schema.expected_migrations` | `migration_list_is_ordered_and_gapless` reddens naming the file. **DRIVEN twice already** (24-06 obs 1 and 4) |
| 45 | **lock probe collision** | add `004_run_log.sql` while `lock_probe_filename` is `004_lock_probe.sql` | the probe sorts BEFORE the real migration. **MEASURED shape** — 24-06 fixed the identical defect at `003` |
| 46 | capture freshness | edit any `.sql` (or `Store/Key.hs`) without re-capturing | recomputed md5 ≠ recorded md5. The COMPUTED oracle, DRIVEN twice |
| 47 | capture completeness, SET-not-count | delete an observation block; **and** RENAME one (count-preserving) | set mismatch in both directions. 24-06 obs 3b MEASURED that a count passes a rename |
| 48 | sentinel harness | any new artifact leaf that no check reads | reported as an **ABSORBED** pair, by name, with its sentinel. 24-06 DELETED such a field rather than pardoning it |
| 49 | `sc3_literal_purge` | a `0x`-prefixed 64-hex digest in any new `.hs`/`.sh`/`.sql` under `offchain/` | grep exit 0. Write digests **bare** |
| 50 | suite stays DB-free and GAMS-free | name `Store.Postgres` or `Gams.Invoke` in `Main.hs` — including **in a comment** | both greps non-zero. **Instance 18 of prose-inside-a-grep happened at 24-06**; describe, do not name |

### The four guards Phase 24 handed forward, and what Phase 25 owes each

24-06's phase-closing ledger names four guards with a **standing assertion and no mutation**. The
phase brief assigns #21 to this phase. All four are addressed here honestly:

| 24-RESEARCH guard | Status handed over | What Phase 25 owes |
|---|---|---|
| **#21 — the echoed-field cross-check** | STANDING, never observed REJECTING. 24-03 exercised it and it PASSED; the *freshness* conjunct did the catching | **OWED AND DELIVERABLE HERE.** Its firing input is *"change one argv token after rendering"* — which is exactly KEY-02's own mutant. **Instrument:** a Tier-B check that takes `render_argv`'s output, mutates ONE token (`sqrtPriceX96` + a leading zero), spawns a stub that echoes the *unmutated* token into its artifact, and asserts `Aborted (EchoMismatch "sqrtPriceX96" sent echoed)`. The freshness conjunct cannot catch it because the stub writes a fresh file. **This is the one carry-forward that must close in this phase** |
| #11 — `conopt_parse_is_position_independent` | never falsified; its firing input is *code* | Not this phase's subject (no CONOPT parsing here). **Re-report as a standing finding**, do not silently drop |
| #23 — the 2 MB stderr drain | firing input is a deadlock; no mutation removed the drain | Not this phase's subject. Re-report |
| #28/#30 — empty hostile-variable set; fewer-than-16-of-16 | asserted every run, never mutated | Not this phase's subject. Re-report |

**Rule of record:** a guard whose firing input was never applied is reported as a **named
phase-level finding**, never omitted — 23-05's guard #13 precedent, honoured at 24-06.

### Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all`. `--enable-tests` is load-bearing; the
  bare `cabal build -j all` is **VACUOUS and must never appear** in a plan, a task or a summary.
- **Per wave merge:** `cabal test` — full `core_checks` + `sentinel_falsification_harness` — with
  **zero `-Wall` warnings** under `offchain/`, and both structural greps at **0**.
- **Phase gate:** full suite green with FAIL count 0; `-Wall` clean;
  `bash offchain/rig/capture-store-conformance.sh` re-run from a fresh container producing an
  artifact whose verdicts are all `pass`; **every guard in the 50-row table OBSERVED firing at least
  once with its named input**, reconciled in a phase-closing ledger in 23-05/24-06's shape; carried
  guard **#21 CLOSED** or reported as a named finding with the reason.
- **Do not** run the capture inside `cabal test`; **do not** let any check open a socket or invoke
  `gams`; **do not** run a driver that rewrites a tracked artifact it is being checked against.
- **Budget note.** Wall is **152.9 s** against **900 s**, MEASURED cold today. Tier-B checks that
  drive `Store.Memory` and stub solvers are sub-millisecond. The real cost is the sentinel sweep:
  **extend `store-conformance.json`** (24-06: +22 leaves, +130 pairs, **+0.2 s**) rather than adding
  a seventh artifact (23-05: a new artifact took the wall 78 s → 97 s). Record the wall before and
  after every plan that adds checks.

### Wave 0 Gaps

No test *file* is created — one file, one runner. The gaps are registration points, schema and
infrastructure, all of which must exist before the first assertion is written.

- [ ] **Renumber `lock_probe_filename` (`app/StoreConformance.hs:153`) from `004_lock_probe.sql` to
      a prefix that cannot collide** — `900_lock_probe.sql`. **In the SAME task as the first real
      `004_*.sql`, not after.** M6; 24-06 paid this once already
- [ ] `offchain/migrations/004_run_log.sql` — the run log, **both** triggers, no FK to `model_run`
- [ ] `offchain/migrations/005_quarantine.sql` — divergent bytes with both digests and the key
- [ ] `Store.Schema` — `expected_migrations` extended to five; `run_log_columns` and the two trigger
      names stated as data (the `versions_nonempty_columns` idiom)
- [ ] `.cabal` — ~5 new `Store.*` `exposed-modules`. **No new package expected**; if one is proposed,
      MEASURE by `plan.json` set-diff against **158** and record it in the lines 107–115 comment
      discipline. Never estimate
- [ ] `offchain/lib/Gams/Argv.hs` (or a new `Store.Shock`) — `parse_shock :: [(String,String)] -> Either ShockError Shock`,
      refusing missing / duplicate / unknown names, each by name. **M5: KEY-06's omission clause has
      no subject without it**
- [ ] `offchain/test/Main.hs` — `expected_key_component_tags`, `expected_run_log_outcomes` and
      `expected_run_log_columns` as SETs in the `expected_store_laws` (`:6326`) idiom, each asserted
      in **both** directions. Three new lists; **this repository has found five lists without a
      growth guard in the last two phases** — do not ship a sixth
- [ ] `offchain/test/Main.hs` — `expected_store_observation_blocks` (`:6783`) extended with the new
      capture blocks, in both directions
- [ ] `offchain/test/Main.hs` — `aeson_storage_path` (`:7807`) extended with every new
      `offchain/lib/Store/*.hs`, **and** the existing directory-coverage growth guard re-verified
      against the new modules
- [ ] `offchain/test/Main.hs` — `purge_file_floor` (`:1058`, **59** today) and
      `credential_scan_floor` (`:7635`, **68** today) **RE-MEASURED** with two separate `find`
      commands, run independently. Deriving one from the other is what 24-02 did and 24-03 is how
      that was found out. Zero slack on both
- [ ] `offchain/test/Main.hs` — `sentinel_pair_floor` (`:6077`, **3828** today) and
      `artifact_field_floors` (`:6115`, `store-conformance.json` **156**) **RE-MEASURED** by raising
      each until the harness names what it reached. Never incremented by arithmetic
- [ ] `offchain/test/Main.hs` — ~35 new `Check` values wired into `core_checks` (`:11042`). **A check
      not in this list does not exist**
- [ ] A **stub `Solver` helper** in `Main.hs`: a counting, value-returning `Solver` built by record
      update, in the `Store.Memory` idiom. Built, never committed as a fixture
- [ ] `offchain/rig/capture-store-conformance.sh` — new blocks for the append-only refusals (with
      the POSITIVE CONTROL evaluated FIRST), the trigger catalogue, `xmax`-discrimination, the
      quarantine exhibit and the abort→no-entry exhibit. **One `jq -r` call per field** — the
      collapsing `read -r a b c <<< "$(jq …)"` hazard is live in three remaining sites (24-06
      carry-forward 2) and the new fields include several with a legitimate empty value
- [ ] `offchain/rig/store-conformance.json` — re-captured. Design the new blocks **NARROW**: every
      leaf asserted or pardoned in `absorbed_by_design` (`:5859`) with a written reason
- [ ] `.github/` — **no change needed and none should be made.** Nothing in `cabal test` touches a
      database or a solver. The `haskell` gate job has still never executed

---

## State of the Art

| Old approach | Current approach | Impact |
|---|---|---|
| Always-verify determinism | on-demand `verify` | Nix shipped `--repeat` / `enforce-determinism` and **removed both in 2.13** (2023-01-17) as "broken under many circumstances for a long time" |
| Last-write-wins on mismatch | first-writer-wins + **quarantine** | Bazel's ActionCache overwrite is *why* its cache poisoning is hard to find; rebuilderd publishes the disagreement as data |
| `insert … on conflict do nothing returning` | `on conflict … do update set c = t.c returning (xmax = 0)` | **MEASURED today:** the first returns NO ROW on conflict and cannot tell a hit from a write |
| `REVOKE UPDATE, DELETE` as append-only | a `BEFORE UPDATE OR DELETE` **row** trigger **plus** a `BEFORE TRUNCATE` **statement** trigger | **MEASURED today:** REVOKE is a no-op against the role in use, and `TRUNCATE` walks through a row trigger silently |
| RFC 8785 (JCS) canonical JSON | framed, tagged netstrings over exact `Integer`s | JCS mandates IEEE-754-double-expressible numbers; three of the seven inputs exceed binary64 |
| ccache's compiler mtime/size in the key | the reported **version strings** | §3's guarantee is phrased in versions; mtime invalidates on a rebuilt-identical toolchain and misses a touched-changed one |
| a TTL on cache entries | no stale state at all | Content-keyed entries go stale only when the key's inputs change, and they are all in the key |

**Deprecated / does not exist:**
- Bazel `--experimental_repeated_by` — **does not exist**; absent from the flag reference,
  `bazel_flags.proto` and the release notes (`FEATURES.md`, negative finding of record).
- An advisory lock inside `postgresql-migration` — does not exist at 0.2.1.8 (source-read at 23).
- `Database.PostgreSQL.Simple.Binary` — **not a module.** `Binary` is in `…Simple.Types`.
- `cryptonite` — deprecated (last upload 2022-03-13); `crypton` is already resolved.

---

## Open Questions

1. **Does `gams_sha256` enter the preimage, or only the row and the run log?**
   - Known: it exists (`ti_gams_sha256`), it is bare hex, and 24-RESEARCH M13 records it as
     machine-specific. §3's guarantee is phrased in *versions*.
   - Unclear: whether the project wants a key finer than the guarantee at the cost of a full-store
     miss on every reinstall of an identical version.
   - **Recommendation: row and log, not key.** Record the decision either way; `key_scheme` makes
     reversing it non-destructive. This is `FEATURES.md` K4's tradeoff and it should be *chosen*.

2. **Production `nEvents`** (`VOLUME_PATH.md` §6 open ruling 1; fixture 8).
   - Known: `nEvents` is in the key, so changing it is a clean **miss**, not a hazard. But it
     invalidates the entire store, and `volume_path.gms:202` sets `fj.pw = 4000`, so the put line
     wraps around **N ≈ 180 events** — production `nEvents` must stay under that.
   - Recommendation: confirm the production value **before the first row lands**, and record the
     180-event ceiling in the key module's haddock so a future change is costed rather than
     discovered.

3. **One migration or two?** `004_run_log.sql` + `005_quarantine.sql`, or one combined file.
   - Known: each `.sql` moves `purge_file_floor` AND `credential_scan_floor` by one and forces a
     re-capture (the freshness oracle recomputes every migration's md5 from the directory).
   - Recommendation: **two**, on the separation-of-concerns argument, and pay both floor moves in
     one task. The cost is two integers and one capture, and it is the same cost either way once the
     re-capture is paid.

4. **How does the run log record `event tx` and `block` before Phase 27 exists?**
   - Known: STORE-07 names them; CHAIN-01/02 are BLOCKED on the plank worktree emitting `next`.
   - Recommendation: **nullable columns, present from `004`**, with a check asserting the columns
     exist and a written note that they are unpopulated until Phase 27. Adding a column later is a
     migration and a re-capture; adding a nullable column now is free. Do **not** fabricate a value
     to make a check pass — a populated-with-zero column is `0x00…00` passing every hex-shape guard,
     verbatim.

5. **Does `reset` operate on `model_run` only, or also on `byte_corpus`?**
   - Known: `byte_corpus` is a test fixture table, not a cache.
   - Recommendation: `model_run` only, with the scope stated in the command's own help text and
     asserted by a check. A `reset` whose blast radius is undocumented is the next `truncate`.

6. **What is the length floor for the verify comparands?**
   - Known: the real artifact is **606 bytes** (`volume_path_golden_bytes_len`), and
     `decode_artifact` is strictly stronger than any length floor.
   - Recommendation: assert **both** — `decode_artifact` on both sides, plus a modest explicit floor
     — because the roadmap asks for a floor by name and because the decoder's refusal message and a
     floor's refusal message name different defects.

---

## Sources

### Primary — executed on this machine today, 2026-08-17 (HIGH)

- `postgres:18-alpine` in Docker (`server_version` **18.4**, container `cfmm_p25_probe`, host port
  55434, removed after measurement): the `REVOKE`-against-superuser no-op transcript; the row-level
  append-only trigger refusing `UPDATE`/`DELETE`; the `TRUNCATE` walking through it and then being
  refused by the statement trigger; `SQLSTATE = 23514` when set and `P0001` by default; the
  `drop trigger` bypass; the `pg_trigger`/`pg_class` catalogue query (`run_log_no_truncate|34`);
  `on conflict do nothing returning` returning no row on conflict; `on conflict … do update set
  raw = cas.raw returning (xmax = 0)` returning `t` then `f`
- A 343-tuple sweep of `render_argv`-shaped preimages: **0** collisions under argv-token
  concatenation, **30** under bare-decimal concatenation, with the admissible firing pair
  `(1,1,23,…)` vs `(1,12,3,…)`
- `sha256` of `"123"` (`a665a459…f7a27ae3`) against the two length-framed forms
  (`25b0a484…48b54a83`, `f0582772…ce916f57`)
- `cabal build --enable-tests -j all` → exit 0, **0** warnings; `cabal test` → exit 0,
  **151/151**, `real 2m32.850s`
- `find offchain … | wc -l` → **59** and **68**; the extension census `hs 47, sh 9, json 9, sql 3,
  md 3, txt 2`; both structural greps at **0**

### Primary — these repositories, read directly (HIGH)

- `offchain/lib/Gams/Run.hs` — `wrapper_argv`:294-303 (`curdir`, `action=ce`, `lo=2`, the
  `/usr/bin/timeout` wrapper), `ToolchainIdentity`:166-180 (`ti_conopt_version :: Maybe`,
  `ti_model_sources` as a sorted list), `ProverOutcome`:227-230, `AbortReason`:201-220,
  `with_fresh_run_dir`:264
- `offchain/lib/Gams/Argv.hs` — `Shock`:72-87 (seven strict `Integer`s), `render_argv`:131-158
  (eight refusals), `parse_shock_field`:211-222; **no** per-shock assembler in the export list
- `offchain/lib/Gams/Artifact.hs` — `ProverArtifact`:68-85 (the two echoed string fields),
  `decode_artifact`:109
- `offchain/lib/Store/{Types,Class,Laws,Schema,Config,Postgres,Memory,Json}.hs` — `Artifact`/
  `DerivedDoc`, the `Store` record, the eight laws, `expected_migrations`,
  `default_pgstore_dsn = ""`, `migrations_dir`, `new_postgres_store`
- `offchain/migrations/{001,002,003}*.sql` — the identity constraint, the corpus table, the named
  `model_run_versions_nonempty` CHECK
- `offchain/app/StoreConformance.hs:152-153` — `lock_probe_filename = "004_lock_probe.sql"`
- `offchain/test/Main.hs` — `Check`:512, `guarded`:518, `pure_check`:525,
  `purge_scanned_extensions`:975, `purge_file_floor`:1058, `advertised_overrides`:3780,
  `unprobed_overrides`:4006, `sentinels`:5543, `swept_artifacts`:5563, `absorbed_by_design`:5859,
  `sentinel_pair_floor`:6077, `artifact_field_floors`:6115, `expected_store_laws`:6326,
  `expected_store_observation_blocks`:6783, `credential_scan_floor`:7635, `aeson_storage_path`:7807,
  `core_checks`:11042
- `offchain/rig/{store,gams}-conformance.json` — the 14- and 26-key top-level surfaces, the
  toolchain identity fields, the absolute `model_sources[].path`
- `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/VOLUME_PATH.md` §§2, 3, 4, 6
  — the seven inputs, the output shape, the determinism guarantee, the named aborts, the two open
  rulings that touch this phase

### Secondary — settled prior research, cited not re-derived (HIGH)

- `.planning/research/{SUMMARY,FEATURES,STACK,ARCHITECTURE,PITFALLS}.md` (2026-08-16) — the key
  scope, K1–K5, the four divergence policies and the 3+4 recommendation, Parts 4–6, the
  anti-feature list
- `.planning/phases/23-*/23-RESEARCH.md` and `23-05-SUMMARY.md` — the schema, the `Binary` wart, the
  computed freshness oracle, the SET-not-count finding, the `CFMM_REQUIRE_DB` ruling
- `.planning/phases/24-*/24-RESEARCH.md` and `24-06-SUMMARY.md` — the 41-guard table, the four
  carried guards, the argv-token measurement, the `NOT NULL` ≠ non-empty finding, the floor history
- `.planning/ROADMAP.md` Phase 25 §, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`

### External (MEDIUM — official docs, inherited from FEATURES.md)

- PostgreSQL 18 — `sql-createtrigger` (statement-level `TRUNCATE` triggers), `functions-admin`,
  `sql-insert` (`ON CONFLICT`, `EXCLUDED`), `ddl-priv` (superusers bypass permission checks)
- Nix — Verifying Build Reproducibility (`--check`, `diff-hook`); Release 2.13 notes
  (`--repeat` / `enforce-determinism` removed)
- ccache manual (`CCACHE_COMPILERCHECK`); Bazel Remote Caching; git-gc(1) / git-reflog(1);
  RFC 8785 (JCS)

---

## Metadata

**Confidence breakdown:**

- **Standard stack: HIGH** — no new package; every dependency re-confirmed in today's build, which
  printed 0 warnings and resolved unchanged
- **Key design: HIGH for the mechanism, MEDIUM for two decisions.** The framing, the exclusion set
  and the component list are settled and now measured. `gams_sha256`'s membership and the production
  `nEvents` are open questions, both named, neither blocking
- **New measurements: HIGH** — every one executed or source-read today, transcripts inline. The
  Postgres observations were made against a real 18.4 server; the collision sweep was computed; the
  suite and floor numbers were run cold
- **Validation architecture: HIGH for the mechanism** (every instrument already runs in this
  repository and has proven positive and negative controls); **MEDIUM for the floors and counts**,
  which MUST be re-MEASURED at plan time — two phase-24 summaries carried stale ones
- **The four carried guards: HIGH** that #21 is closable here (its firing input is KEY-02's own
  mutant); the other three have no subject in this phase and are re-reported rather than closed

**Research date:** 2026-08-17
**Valid until:** ~2026-09-16 for the stack and the Postgres behaviours (stable). The suite count
(151), the wall (152.9 s), `purge_file_floor` (59), `credential_scan_floor` (68),
`sentinel_pair_floor` (3828) and `artifact_field_floors` are **tree-derived and go stale on any
commit** — re-measure them at plan time, never inherit them from this document.
