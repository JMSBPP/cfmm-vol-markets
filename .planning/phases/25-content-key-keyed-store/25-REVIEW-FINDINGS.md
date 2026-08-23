---
phase: 25
slug: content-key-keyed-store
kind: review-findings
status: binding-on-execution
created: 2026-08-17
reviewers:
  - "Reality Checker (evidence gate) — COMPLETE"
  - "Database Optimizer (PostgreSQL domain) — pending, appended below when it lands"
---

# Phase 25 — Reviewer Findings, Binding on Execution

> **These are executor constraints, not planner input.** By user ruling 2026-08-17 the plans are
> NOT revised again; each plan's executor implements the plan AND the findings that name it. Where a
> finding contradicts a plan step, **the finding wins** and the deviation is recorded in that task's
> summary, citing this file.
>
> Read the rows that name YOUR plan before you start. Every claim was measured against the tree at
> `558629a`+`d780019`; provenance is given so you can re-check rather than trust.

---

## Applicability index — find your plan

| Plan | Findings that bind it |
|---|---|
| **25-01** | **B1** (delivered mid-flight to the running executor) |
| **25-02** | **M2** (missing firing input), m1 (citation — already fixed in the file) |
| **25-03** | **B4a** (vacuous migration-ordering gate) |
| **25-04** | m5 (bare `grep -c` tail), m2 (summary under-count) |
| **25-05** | **B3** (`STORE_ADMIN_BIN` default cannot resolve), **B4b** (vacuous bare-reset gate) |
| **25-06** | **M3** (record the STORE-01 scope gap) |
| **25-07** | m5, m6 (no computed freshness oracle) |
| **25-08** | **B2** (task ordering breaks 25-05's guard), m5 |
| **25-09** | **B4c** (vacuous scan gate), **M3**/STORE-07 scope statements, m4 |

---

## BLOCKERS

### B1 — `25-01` Task 1/Task 2 ordering makes Task 2's gate RED *(already delivered mid-flight)*

Task 1's `<files>` omits `offchain/test/Main.hs`, so `Store/Key.hs` cannot join `aeson_storage_path`
in the task that creates it; the plan defers it to Task 3 step 3 (`25-01-PLAN.md:474`). But
`the_artifact_path_scan_covers_every_module_on_it` (`offchain/test/Main.hs:8994`) enumerates
`offchain/lib/{Store,Gams}/` **from the directory**, bidirectionally. Task 2's gate is a full
`cabal test` with FAIL 0 (`:405,409`). It will be RED.

Contradicts the plan's own `key_links` (`25-01-PLAN.md:38-41`) and `25-VALIDATION.md:217-221`.
**25-04 T1, 25-05 T1 and 25-06 T1 all carry the step correctly — 25-01 is the outlier, in wave 1.**

**Fix:** add `offchain/test/Main.hs` to Task 1's files; move the `aeson_storage_path` extension into
Task 1; drop step 3 from Task 3 (keep its firing observations).

### B2 — `25-08` Task 1 breaks a guard `25-05` shipped, and Task 2's gate runs before Task 3 repairs it

`25-08-PLAN.md:180` — Task 1 drives the divergence "through `Store.Verify.reverify_stored_key`",
i.e. it adds `import Store.Verify` to `offchain/app/StoreConformance.hs` (`:113-114` says so
outright). But `verifier_importers` gains its second entry only in **Task 3** (`:320-335,343`).
`verification_is_reachable_only_from_its_own_entrypoint` (25-05 T4, `25-05-PLAN.md:492-509`) asserts
the `offchain/app/` importer set **in both directions** against a one-entry list. Task 2's gate is
`capture && cabal test` with FAIL 0 (`:263,276`). **RED in the `unlisted` direction.**

25-05 T4 explicitly anticipated the widening — it placed the fix one task too late.

**Fix:** move the `verifier_importers` second entry into **25-08 Task 1**, the same task that adds
the import. Leave its three firing inputs in Task 3.

### B3 — `STORE_ADMIN_BIN`'s default resolver cannot resolve on this machine, and the plan mandates FAILURE rather than skip

`25-05-PLAN.md:466-471` specifies the default as *"the sibling of `getExecutablePath`'s directory
named `store-admin`."* MEASURED against the real `dist-newstyle`:

```
…/cfmm-replicationPlank-rpc-api-0.1.0.0/t/<test>/build/<test>/<test>        ← the test binary
…/cfmm-replicationPlank-rpc-api-0.1.0.0/x/store-admin/build/store-admin/…   ← the executable
```

Executables live under `x/<name>/build/<name>/`; the test binary under `t/<name>/build/<name>/`.
**`store-admin` is never a sibling of the test binary — they are four directory levels apart.**
`StoreConformance.hs:498` works only because it re-executes *itself*, which 25-05 correctly notes is
unavailable here.

Consequence: `a_determinism_mismatch_exits_non_zero` **fails on every run** with `STORE_ADMIN_BIN`
unset — permanent red, not a skip risk — and neither 25-05 T4's acceptance ("FAIL 0, total ≥ 187")
nor any later wave's can be met. **STORE-02's only real subprocess observation has no working
default path.**

**Fix:** replace the default with an upward walk from `getExecutablePath` to the package build root,
then `x/store-admin/build/store-admin/store-admin`. **Require the default resolution to be OBSERVED
once during execution before the check is registered** — a resolver that has never resolved is the
phase's own defect class.

### B4 — Three `<automated>` gates CANNOT FAIL, in the phase whose validation doc claims that class was fixed everywhere

| Where | Command tail | Why it is vacuous |
|---|---|---|
| **B4a** `25-03-PLAN.md:230` | `printf '%s\n' 004_run_log.sql 005_quarantine.sql 900_lock_probe.sql \| sort \| tail -1` | Sorts a **hardcoded literal list**, never the tree. Prints `900_lock_probe.sql` even if the executor names the probe `004_lock_probe.sql` (the exact collision it exists to prevent), even if neither migration was created. And `tail` always exits 0. Subject-free assertion **and** vacuous exit status — repeated verbatim as the acceptance criterion at `:243`. **Fix:** assert over `ls offchain/migrations` plus the probe name read from `StoreConformance.hs`. |
| **B4b** `25-05-PLAN.md:294` | `cabal run -v0 store-admin -- reset; echo "BARE RESET EXIT=$?"` | The compound's exit status is `echo`'s — **always 0**. Passes whether the bare reset exits 2, exits 0, or the binary fails to build. Per `:276-290` this one-shot is STORE-06's **only** observation of the CLI exit number. **Fix:** capture and `test "$ec" = 2 \|\| exit 1`. |
| **B4c** `25-09-PLAN.md:276` | `… \| awk -F: '{s+=$2} END{print s}'` | Final command is `awk` — **always exit 0**. `CONTROL(want 1)` printing `0` (a broken fragment join) and `PHASE(want 0)` printing `5` (real citations present) **both pass**, against the plan's own acceptance at `:288-289`. **Fix:** re-raise the control/phase comparison as the block's exit status. |

---

## MAJORS

### M1 — `25-VALIDATION.md`'s sampling claim was false, and it is the mechanism that hides B1 and B2

The doc claimed *"every one of the **28** tasks gates on a full `cabal test`."* **MEASURED: 16 of 28.**
The other 12 gate on `cabal build --enable-tests` only — 25-01 T1, 25-02 T1, 25-03 T1, 25-04 T1+T2,
25-05 T1+T2+T3, 25-06 T1, 25-07 T1, 25-08 T1, 25-09 T2.

**Already corrected in `25-VALIDATION.md` (2026-08-17).** Recorded here because of the consequence,
which binds every executor: **B1 and B2 are both red-suite states created by a build-only task and
discovered by the NEXT task's gate.** Treat a build-only task as **unverified**, never as passed, and
do not carry a known-red state across a task boundary.

### M2 — `25-02` registers a check with no firing input, violating the plan's own rule

25-02 registers ten checks (`:251-256`); its mutation table (`:348-361`) has twelve rows covering
**nine**. `no_field_is_re_rendered_between_the_edge_and_the_key` has none of its own. The only
candidate — "second renderer | seed a formatted print into `Store/Key.hs`" — is the firing input for
`key_and_invocation_agree_by_construction`, which scans for a second *decimal renderer*; a formatted
print is not a *re-parse of an already-normalized field*, so it need not fire the re-render scan.

Violates 25-02 T3's own acceptance (`:378-379`) and `25-VALIDATION.md:234`. **By the phase's own
standard the guard is ABSENT.** Give it its own firing input in 25-02 T3's table.

### M3 — Nothing builds a production `Solver`, so STORE-01 is proven at the seam and never end to end

`Store.Solver` (25-06) is a record of functions; the only implementations constructed anywhere are
`counting_solver` and `aborting_solver` in `Main.hs` and a stub in `StoreConformance.hs`
(`25-08-PLAN.md:187`). **No task wires `Gams.Run.run_prover` into a `Solver`, and no application
code calls `Store.Cache.decide`.** The two halves of the elision claim — "the key is stable across
real invocations" (25-02, real `run_prover`) and "an identical key elides the solve" (25-06, stub
solver) — are each proven and **never joined**.

**Fix:** record this as a scope statement of record in 25-09's traceability table, the way STORE-07's
PARTIAL closure is (`25-VALIDATION.md:155-165`). Do not let it be discovered in Phase 28.

---

## MINORS

- **m1** — `Main.hs:7845` was a wrong citation in three documents; the `aeson_bait_source` binding is
  7840–7841 and the fragment-concatenation idiom is **7842**. **Already fixed** in `25-02-PLAN.md`,
  `25-09-PLAN.md` and `25-VALIDATION.md` (2026-08-17).
- **m2** — Summary templates under-record. 25-02 acceptance requires **twelve** mutation
  observations, its `<output>` (`:410`) says "the nine"; 25-04 acceptance requires **twelve**, its
  `<output>` (`:474`) says "the eleven".
- **m3** — The 343-tuple sweep is unsourced prose: no script, no artifact, no test regenerates it.
  Independently recomputed and it HOLDS — 7³ = 343, argv-token form 343 distinct (0 collisions),
  bare-decimal form 313 distinct → **30** tuples lose identity. Note "30" is correct only under
  *collisions = tuples − distinct*; the colliding **pair** count is 39 and the tuples involved 52.
  Nothing load-bearing depends on it (25-01's checks point at a constructed pair), but nothing would
  catch it going stale either.
- **m4** — `25-03-PLAN.md:264` quotes a precedent whose arithmetic does not close: "134 → 156 leaves,
  3698 → 3828 pairs" implies +132 → 3830, not 3828. The gap is the equal-value skip in `step`
  (`Main.hs:5751`). **The committed floor 3828 is RIGHT** — re-derived exactly as 643 leaves × 6 =
  3858 minus 30 skipped equal-value pairs. The quoted *delta* is just not something to reason
  forward from, which is what the plan's own "raise until named, never arithmetic" rule says.
- **m5** — Bare `grep -c` gate tails at `25-04-PLAN.md:340`, `25-07-PLAN.md:223`,
  `25-08-PLAN.md:199`. Polarity happens to be right (count 0 → exit 1 → fail), but they also pass on
  any count ≥ 1 while 25-04 T2's acceptance is exactly `1`.
- **m6** — No computed freshness oracle over `Store/Postgres.hs` or `Store/Schema.hs` for
  `store-conformance.json`. Within the phase this is sufficient (25-03/07/08 each recapture after
  the code they cover changed), but compare `gams_freshness_subjects` (`Main.hs:10255`), which does
  exactly this for the GAMS artifact. **After 25-08 the store artifact goes stale silently on any
  Postgres-side edit**, and 25-09's phase gate only re-runs the capture and checks "exit 0".

---

## Verified SOUND — do not "fix" these

- **STORE-08 is the best-handled requirement in the phase.** Absence is not the pass condition alone:
  `an_aborted_run_produces_no_cache_entry` (`25-06-PLAN.md:258-263`) evaluates a `Produced` positive
  control FIRST with `entries == 1` from the store's own count, then drives four abort variants
  against **fresh** stores — and the check **is shown failing when an entry appears** (`:345-346`,
  and again over the artifact at `25-08-PLAN.md:359,361`). Done properly.
- **Cache elision is genuinely closed against the zero-hit-rate design.** Three instruments failing
  on opposite designs: the real `run_prover` run twice with a subject guard asserting
  `outcome_run_dir` **differs**; `per_run_forbidden_tokens` built from fragments with a shared proven
  positive control and a firing input that replaces one fragment with a string nothing contains, so
  the joins themselves are asserted; and `decide` taking a `KeyIdentity` never a `RunRequest`,
  asserted structurally. Elision proven by **VALUE** (seeded bytes B, not the solver's B′) **and** by
  a zero counter, with the two mutations failing *different halves*.
- **STORE-02/03 now has a real end-to-end path.** `reverify_stored_key`: `store_lookup` →
  caller-supplied re-solve → `verify` over two mutually-unconstructible newtypes →
  `store_quarantine_put` **then** `store_log_append`. First-writer preservation obtained by *not
  writing*, asserted structurally. Six of T4's seventeen firing inputs drive it, including two that
  must fail **different** assertions, and "the absent-key arm appends a `VerifiedMatch` row" so a
  fabricated verdict is caught. Placing it inside `Store.Verify` rather than a new module — so it
  adds no importer — is a correct read of its own guard.
- **Every recomputable measurement reproduces exactly:** `purge_file_floor` 59,
  `credential_scan_floor` 68, `sentinel_pair_floor` 3828, baseline 151 (115 static + 35 per-pin + 1
  harness), the 47-row map, the 50-row guard table, `store-conformance.json` at 14 top-level keys,
  the 14→18→21 progression, the 207 arithmetic, and all nine per-plan addends. **3828 reproduces only
  under the equal-value skip rule — i.e. it was measured, not computed.** No repeat of the phase-24
  stale-floor problem.
- **The wave chain is sound at plan granularity.** Every guard *widening* is handled in-place with
  fresh firings: `pips_denominator_scan_path_count` 1→2 in 25-06 T1, `lock_probe_filename` 004→900
  in the same task as migration 004, `expected_store_observation_blocks` 14→18→21,
  `aeson_storage_path` in 25-04/05/06. **Both failures (B1, B2) are intra-plan TASK ordering, not
  cross-wave.**

---

## Database Optimizer findings

> Every "verified" below is a transcript run against a throwaway `postgres:18-alpine` container,
> not a recollection. **Adds these plans to the applicability index: 25-03 (DDL), 25-04 (insert
> shape), 25-06 (a check with no subject), 25-07 (trigger evidence), 25-08 (readback leaves).**

### DB-B1 — The `text not null` hole from migration 003 is RE-OPENED in both new tables

`003` exists because `not null` does not forbid `''`. **25-03 Task 1 repeats it exactly.** Verified
on PG 18.4 against the plan's own quarantine DDL: `insert into q values ('','','x')` → `INSERT 0 1`.
A quarantine row with an **empty `original_sha256`** satisfies `quarantine_digests_differ`
(`'' <> 'x'`) and is stored. Nothing constrains either digest to 64 bare hex characters, and nothing
ties `divergent_sha256` to `divergent_raw`. Same for `run_log.outcome`: the taxonomy is total and
injective *in Haskell*, but the column takes `''` and `'Verified Match'`.

**This outranks a trigger for durability: CHECK constraints are NOT bypassable by
`session_replication_role`; triggers are (see DB-M1, verified).**

**Fix in `004`/`005`, every constraint NAMED per 003's precedent:**
`run_log`: `check (outcome ~ '^[a-z][a-z_]*$')`; `check (gams_ver is null or length(gams_ver) > 0)`
and likewise `conopt_ver` — else the log carries the exact empty toolchain version 003 was written
to make unstorable. `quarantine`: `check (original_sha256 ~ '^[0-9a-f]{64}$')` and the same for
`divergent_sha256`; `check (length(model) > 0)`; keep `quarantine_digests_differ`.

### DB-B2 — `quarantine.divergent_raw` is a new `bytea` write nothing reads back, and there is NO structural guard on `Binary`

`ToField ByteString` is `Escape`; `ToField (Binary ByteString)` is `EscapeByteA`. A bare
`ByteString` on a `bytea` parameter **type-checks, runs, and corrupts silently** (6 bytes in →
3 out, measured). No compile error, no helper, no source scan — the suite's four `Binary`
occurrences are all prose or capture-value assertions.

25-04 T2 adds **five** new `bytea` write parameters; the plan text mentions `Binary` for exactly
one. And the later captures **cannot catch a miss**: `quarantine_exhibit` records
`original_sha256`/`divergent_sha256`/`stored_sha256_after`, **all computed in Haskell before the
write**. Drop `Binary` from `divergent_raw` and every 25-08 assertion still passes **while the
phase's only preserved evidence of a determinism failure is corrupted.** `run_log.key` is never
compared after readback either.

**Fix (take both):** add `readback_divergent_sha256` computed by the **server**
(`encode(sha256(divergent_raw),'hex')` from the stored row) and gate it equal to
`divergent_sha256`; same shape for `run_log.key`. Plus the schema backstop — `sha256()` is IMMUTABLE
(`provolatile = 'i'`, verified), so this is legal:
`check (encode(sha256(divergent_raw),'hex') = divergent_sha256)`. Verified: mislabelled row refused,
correct row accepted.

### DB-M1 — `session_replication_role = replica` walks through BOTH triggers, and the catalogue check cannot see a DISABLED trigger

The two-trigger model is correct as far as it goes and TRUNCATE really is the hole the row trigger
leaves — the whole matrix reproduced. **It is not complete, and one gap is a `SET`, not DDL:**

```
set session_replication_role = replica;
update run_log set outcome='TAMPERED';   -> UPDATE 2       (NO ERROR)
truncate run_log;                        -> TRUNCATE TABLE (NO ERROR)
```

A superuser GUC, one statement, reversible, **no schema trace** — precisely what someone reaches for
when a trigger is "in the way", and the app connects as `postgres`. **Fix, verified to close it
completely:** `alter table run_log enable always trigger run_log_append_only;` and likewise
`run_log_no_truncate`. Afterwards `pg_trigger.tgenabled` reads `A` instead of `O`.

**Second half:** `alter table run_log disable trigger all` **leaves both `pg_trigger` rows in
place** with identical `tgname` and `tgtype`; only `tgenabled` becomes `D` — and `delete` then
succeeds. **25-07 T1 records `run_log_triggers` as `{tgname, tgtype}` and T3 asserts exactly those.
Both pass against a fully disabled pair.** `tgenabled` must be a recorded leaf, pinned to `A`.

| Vector | Real? | Verdict |
|---|---|---|
| `TRUNCATE` | yes | **closed** by the statement trigger — verified |
| `session_replication_role = replica` | yes, one `SET` | **guard it** — `ENABLE ALWAYS` |
| `ALTER TABLE … DISABLE TRIGGER` | yes | **detectable** — assert `tgenabled`, not presence |
| `DROP TRIGGER` / `DROP TABLE` | yes | accept-and-document; a dropped trigger is a missing row, already handled |
| direct catalog `UPDATE pg_trigger` | yes, superuser | accept-and-document; also caught by `tgenabled` |
| `COPY` | **NO** | `COPY FROM` fires INSERT triggers only and cannot update or delete. **Say so plainly rather than leaving it open** |
| partition detach | n/a | note in the DDL: TRUNCATE statement triggers are unsupported on partitioned tables, so partitioning this later silently removes the guard |
| **back-dated `INSERT`** *(not previously listed)* | yes | `started_at` has a DEFAULT, not a constraint. A `BEFORE INSERT` trigger forcing `new.started_at = now()` closes it. Do NOT use `check (started_at <= now())` — a dump/restore footgun |

### DB-M2 — "REVOKE is a no-op" is true; the conclusion skips the actual remedy

The measurement is "REVOKE does not work **against a superuser**." The plans convert that into
"REVOKE does not work" and reach for triggers as the boundary — but triggers are bypassable by that
same superuser two ways (DB-M1), whereas a grant boundary against a **non-superuser** role is not.
Three lines in the rig: `create role cfmm_app login; grant select, insert on run_log to cfmm_app;`
(no update/delete/truncate) `grant usage, select on sequence run_log_run_id_seq to cfmm_app;` with
`PGSTORE_DSN` pointing at it. Triggers then become defence-in-depth, and the capture gains a genuinely
new observation: the same UPDATE refused by **permission** as well as by trigger. **Not doing this is
defensible — but it must be a written decision of record**, because the plan currently reads as if
REVOKE were ruled out in general.

### DB-M3 — `xmax` is sound, but it is NOT the hit/miss discriminator — and 25-06's check has NO SUBJECT

The mechanics are fine and were reproduced on the exact statement shape (`t`, `t`, then `f`; first
writer's bytes kept). The subtleties raised do not bite: a locking `xmax` lives on the *old* tuple
and there is no old tuple on the INSERT path. Under READ COMMITTED autocommit (which is what this
code does — `withTransaction` appears **nowhere** in `offchain/`) the classic `DO NOTHING`-then-
`SELECT` race does not fire either: verified, the statement waits ~3 s and the follow-up SELECT finds
the row. **But it is an implementation detail, not a documented contract, and the failure mode if it
ever inverts is silent** — every hit reports as an insert while the bytes stay correct.

**The load-bearing point:** per 25-06, `decide` does `store_lookup` FIRST; on a hit it returns
`Elided` and `persist_produced` is never called. So in the hot path `PutOutcome` is only ever
`Inserted`, and `AlreadyPresent` is reachable **only** under a concurrent double-solve.
**25-06 T2's `a_miss_is_told_from_a_hit_through_the_decision_path` — "asserting the `PutOutcome`
pair `[Inserted, AlreadyPresent]` through `decide`" — has no subject as specified.** A second
`decide` returns `Elided` and produces no second `PutOutcome`; `Decision` has no `PutOutcome` field.
Either extend `Decision`, or drop the check and let 25-04's raw-seam check plus 25-07's server-side
`xmax_discrimination` carry it.

**Recommended:** keep `DO UPDATE`, but extend to
`RETURNING (xmax = 0) as was_inserted, raw, created_at` — returning `raw` removes the second round
trip **and** the window in which a concurrent `store_reset` can delete the row and make
`AlreadyPresent` disagree with a `Nothing` lookup. Add one capture leaf asserting `(xmax = 0)` agrees
with `(created_at = transaction_timestamp())`, so a future PG that changes this is loud. **Specify
that zero rows returned is an invariant violation raising a named error** — nothing in 25-04 says
what happens if `query` returns `[]`.

### DB-M4 — The derived `doc` column can be silently fed the wrong parameter

`001`'s comment says `doc` is written "from the SAME bytea parameter as raw". Same *statement*, but
two different placeholders bound to the same value — and positions 3, 4, 5 are **all**
`Binary ByteString`. **Transposing 3 and 4 compiles, runs, and gives a store whose `doc` is derived
from the key.** No type help, no check in the phase.

A generated column would close it but is **unavailable**: `convert_from` is STABLE
(`provolatile = 's'`, verified) and `generated always as (…) stored` fails *"generation expression
is not immutable"*. So two placeholders are forced — but naming `raw` once is not. Verified working,
preserving both the arbiter and the `xmax` discriminator:

```sql
insert into model_run (model,key_scheme,key,raw,doc)
select v.model, v.key_scheme, v.key, v.raw, convert_from(v.raw,'UTF8')::jsonb
from (values (?,?,?,?)) as v(model,key_scheme,key,raw)
on conflict on constraint model_run_identity do update set raw = model_run.raw
returning (xmax = 0) as was_inserted;
```

**Keep `on conflict ON CONSTRAINT model_run_identity`** — 25-04's spelling switches to a bare column
list, discarding the `Store.Schema.identity_constraint_name` threading that `Postgres.hs:211-214`
documents as deliberate.

### DB-M5 — `jsonb` cannot store every legal JSON artifact, and `doc not null` lets that VETO the authoritative bytes

The split is the right call and normalization was verified (`{"b":1,"a":2,"a":3,"n":1.500,"e":1e2}`
→ reordered, duplicate dropped, `1e2` → `100`). **But:** `{"a":"\u0000"}` is RFC-8259-valid, aeson
accepts it, `::json` accepts it, and `::jsonb` **refuses** it — *"unsupported Unicode escape
sequence … \u0000 cannot be converted to text."* Because `doc` is `not null` and derived in the same
statement, **a legal prover artifact containing that escape cannot be stored at all** — the derived
projection vetoes the authoritative bytes, the exact inversion the schema comment is written
against. Same class: a JSON number overflowing `numeric`.

**Needs a decision of record in 25-03 or 25-04 plus one Tier-A admissibility case.** Honest options:
(a) accept and document the restriction on admissible artifacts, (b) make `doc` nullable with a
fallback to NULL on conversion failure, (c) use `json` not `jsonb` (costing the `jsonb_path_ops`
GIN index). **`Store.Memory`'s json gate must predict whichever you pick, or Tier B stops predicting
Tier C.**

### DB-M6 — No transaction boundaries: evidence can be filed without its chronology row, and log reads have no defined order

**(a) Ordering.** 25-04 specifies `store_log_rows` returns rows "IN INSERTION ORDER" and
`the_run_log_outlives_a_reset` compares row lists for equality — but **no `ORDER BY` is specified**.
A bare `select *` is a Seq Scan (verified) and `synchronize_seqscans` is `on` by default: once the
table exceeds a quarter of shared_buffers a concurrent scan starts at an arbitrary block and rows
come back **rotated**. It will pass in dev forever and then not. `started_at` cannot order it either
— `now()` is the transaction timestamp, so two rows appended in one transaction share it exactly
(verified). **Specify `order by run_id`**, and note in the DDL that `run_id` **has gaps** (a rolled-
back insert consumes a sequence value — verified rows `1, 3`), so it is an order, not a count.

**(b) Atomicity.** 25-05 T3's "quarantine before log" ordering is correct, but with autocommit the
reverse failure is open: a crash between them leaves a quarantine row with **no chronology row**.
Same for `persist_produced` → `store_log_append`. **Both pairs want one `withTransaction`.** If a
transaction is ever added it must stay READ COMMITTED — `ON CONFLICT DO UPDATE` raises `40001` under
REPEATABLE READ.

### DB minors

- **`block_no numeric` accepts `NaN` and `Infinity`** (verified, along with `-1` and `1.5`). For a
  chain height that is a value passing every guard while meaning nothing. Use `numeric(78,0)` plus
  `check (block_no >= 0)`.
- **`run_log.key` and `key_scheme` are independently nullable** (both half-populated rows storable).
  The intent is "a pre-key abort has neither" — say it: `check ((key is null) = (key_scheme is null))`.
- **`elided = true` with a non-null `solve_ms` is storable.** The DDL calls NULL-on-elision "the
  elision METRIC"; that wants `check (not elided or solve_ms is null)`.
- **25-04's acceptance `grep -c 'on conflict do nothing' Store/Postgres.hs` is `0` is ALREADY
  SATISFIED by the unmodified file** — the current text is `"…on conflict on constraint " <> … <>
  " do nothing"`, so the literal never appears. **The guard cannot fail and cannot detect a
  regression.** Grep for `do nothing`, or assert the `returning` clause is present.
- **`grep -c 'xmax = 0' Store/Postgres.hs` is `1` is fragile in this module**, which documents every
  wart in haddock at length — a wart this subtle *will* be documented and the count becomes 2. That
  is the **nineteenth** instance of prose inside a grep's blast radius on this branch.
- **25-07 step 2 drops and restores the triggers inside the capture.** If the restore is skipped on
  an exception, every later block observes a triggerless table. **Order `run_log_triggers` AFTER
  `append_only`, and assert restoration from the catalogue, not from control flow.**
- **`migration_list_is_ordered_and_gapless`'s `>= 3` floor is not raised to 5 by 25-03** — harmless
  (the set arm catches deletions) but stale by two.

### Verified SOUND by the DB reviewer — do not change

- **Migration ordering, gaplessness and stray-file detection.** `migration_list_is_ordered_and_gapless`
  (`Main.hs:6467`) reads `listDirectory` **unfiltered** and asserts the set in *both* directions, so
  a `README.md`, a `.sql.bak` or an editor swap file reddens `cabal test`. The capture's self-check 5
  independently compares `.migrations | length` to `ls -A | wc -l`. The lock probe is written only
  into a scratch dir **outside the tree** (`StoreConformance.hs:529-531`) and `900_` does sort last.
  The caller-side `pg_advisory_lock(872304)` is on the same connection, `bracket_`-released,
  session-scoped, deliberately outside the migration transaction, and `run_migrations_or_exit`
  inspects the result and calls `exitFailure`. **All already shipped and correct.**
- **Indexing.** `model_run_identity unique (model, key_scheme, key)` has all three predicates as
  leading equality columns — exactly the access pattern; verified an **Index Only Scan** even with
  `key_scheme smallint` compared to a bigint parameter, so `postgresql-simple` sending `Int` costs
  nothing. `delete … where not pinned` plans as a Seq Scan — **correct**; an index on `pinned` would
  pessimize a delete touching most rows, and `pinned` is `not null` so `not pinned` has no
  three-valued trap. `jsonb_path_ops` GIN is right and untouched by the upsert.
- **The byte-corpus split is correct.** `byte_corpus` having no jsonb column is exactly right —
  `0x00`, `0xFF` and `0xC3 0x28` cannot become jsonb, and `model_run.doc not null` could not carry
  them even in a perfect implementation.
