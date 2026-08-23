# Phase 28: Resident Loop & Fixture Publication - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning — **two prerequisites outstanding** (see `<prerequisites>`)

<domain>
## Phase Boundary

The long-running process that wires Phases 23–27 end to end: poll `eth_getLogs` for `Shock`
(`next`) events from a **persisted** watermark → pinned pool reads (`Chain.Read`, `BlockRef`
required) → `Fee.Split` → `Store.Key` content key → `Store.Cache.decide` → GAMS solve through the
`Store.Solver` seam → `Store.Postgres` → publish **exactly one** `volume_path.json` by atomic
rename into the other workstream's tree, in Phase 27's typed shape (`pool`, `blockNumber` as a
**string**, `chainId`, plus the golden's ten fields).

Delivers LOOP-01..05. The loop survives its own crash, never double-counts an event, never
conflates "already solved this shock" with "already saw this event", and a consumer can never
observe a half-written fixture. Nothing else: no concurrency, no retention, no determinism
re-verification (STORE-02..05 stay deferred), no new chain surface.

</domain>

<decisions>
## Implementation Decisions

### Startup identity (spike seam S1 — decided here, as 27-SUMMARY required)
- **Add `detect_toolchain` to the library** (Gams namespace): a version-only invocation of the
  toolchain — no model, no solve — parsed with the same `gams_ver` / `conopt_ver` validation
  `Gams.Version` already applies. Unreadable → abort loudly before the loop starts (v6.0's
  "never an empty key component" rule). This closes S1 in the library; the loop does **not**
  bootstrap with a throwaway solve and does **not** special-case its first event.
- **Identity is probed once and pinned for the process lifetime**, not re-probed per iteration.
- **Drift policy — user ruling, not the recommended default:** if a later `Produced` run reports
  a different `ToolchainIdentity` than the pinned one, the loop **adopts the new identity and
  continues**, logging the change (both identities, the block, the event). It does **not** halt.
  The ledger row for that event and every later one carries the identity that keyed it, so the
  switch is reconstructible after the fact.

### Event ledger vs the STORE-07 deferral
- **Minimal per-event ledger; STORE-07 stays deferred.** New table (name at planner's
  discretion, e.g. `model_run_event`): `tx_hash`, `log_index`, `block`, content `key` (nullable
  for inadmissible), `key_scheme`, `outcome` discriminator, the identity that keyed it,
  `observed_at`; **unique on `(tx_hash, log_index)`**. This is the chronology LOOP-02's
  criterion asks for (two distinct events, identical shock → one `model_run` row, two ledger
  rows; same event replayed → one ledger row, no second solve).
- STORE-07's **append-only enforcement (trigger hardening) remains deferred** — record the
  ledger as a partial-STORE-07 by construction in REQUIREMENTS.md, not as STORE-07 closed.
- **Every outcome gets a row**: `elided`, `stored`, `not_persisted`, `inadmissible`. Cache hits
  are visible as hits. The ledger is what a post-mortem reads.
- **Watermark = a dedicated single-row table** (`loop_watermark`: last block **fully
  processed**), **advanced in the same transaction** as that block's ledger inserts. It advances
  through event-free blocks, so a restart never re-scans a quiet stretch. LOOP-05's "watermark
  unadvanced, no half-written row" falls out of that one transaction.

### Publication target
- **One resolver, env override, repo-relative default** — exactly the `Chain.Endpoint` /
  `endpoint.sh` shape from 27-01: `FIXTURE_DIR` if set, else
  `test/models/mev_tax_model_one/fixtures/` relative to the repo root, the default stated once
  and asserted byte-equal against issue #25's contract string. File name is fixed:
  `volume_path.json`; temp sibling in the **same directory** (atomic rename requires it).
- **The loop never creates the directory** (LOOP-04). A missing directory is a precondition
  failure naming the path AND the owning workstream (`mev_tax_model_one`, issue #24/#25).
- **Directory ownership: the #24 track commits it.** Raise on issue #25 before planning — see
  `<prerequisites>`.
- **Cache HIT still publishes.** LOOP-03's "newest run" means the newest *event*: an `Elided`
  outcome publishes the stored artifact so the fixture always reflects the latest event, with
  `blockNumber` = the block that event was read at (not the block the bytes were first solved
  at — the bytes are content-keyed, the identity fields are per-event).

### Failure policy (spike seam S3 — the inadmissible/unsolvable split)
- **Inadmissible shock** (fee-split / ellipse refusal, the prover's line-109 class): ledger row
  `inadmissible`, **advance the watermark, continue.** Bad input is skipped, visibly.
- **Unsolvable** (admissible shock, CONOPT infeasible — the 171/173 class): ledger row
  `not_persisted`, **halt at the block boundary, watermark NOT advanced past that block**, exit
  non-zero naming the event. A model problem is never skipped silently.
- **RPC / chain-read failure**: bounded retry with backoff (counts/backoff at planner's
  discretion, env-configurable), then halt **without advancing**. Nothing is recorded as an
  event outcome — the block is re-processed on restart.
- **DB failure**: halt without advancing (the transaction never committed).
- To tell inadmissible from unsolvable the loop needs the discriminator S3 says is lost
  (`Store.Cache.Decision.NotPersisted` drops `CapturedStreams`; the abort line number lives only
  in the deleted run dir). **Closing S3 in the library is in scope** — the planner decides the
  shape (a richer `Decision`, or classification before `decide`), but the loop must not
  re-derive it by parsing logs.

### Run modes & reporting
- **Resident + `--once`, one code path.** Default: run forever, polling. `--once`: process
  every block from `watermark+1` to the current head, publish, exit 0. One iteration function;
  the mode only decides whether to loop back. `--once` is what tests, CI and LOOP-01's
  restart-skips-nothing proof drive.
- **Cadence:** poll `eth_blockNumber` on a fixed interval, `LOOP_POLL_MS` (default **1000**),
  resolved with the same env discipline as the endpoint; process new blocks as closed `[b, b]`
  ranges; sleep when caught up.
- **Reporting: one JSON line per block processed** on stdout — `block`, event count, per-event
  `{tx, logIndex, outcome, keyPrefix}`, published-or-not, fixture path. Machine-parseable for
  CI and the LOOP-03 race harness. No human-aligned text renderer.
- **Fixed exit-code table, named in one place:** `0` clean / drained; distinct non-zero codes
  for halt-unsolvable, halt-RPC-exhausted, halt-DB, and precondition failures (missing fixtures
  dir, `detect_toolchain` unreadable, endpoint unresolvable). Exact numbers at planner's
  discretion; the table is a single source the tests assert against.
- **Shutdown (LOOP-05):** SIGINT is observed only at a block boundary — the current block's
  transaction completes or rolls back, never half.

### Claude's Discretion
- The S2 adapter: how `Gams.Invoke.invoke_shock` (`EnvChoice -> Shock -> IO (Either InvokeError
  ProverOutcome)`) is fitted to `Store.Solver.solver_run :: Shock -> IO ProverOutcome`, and how
  a resolution failure gets a truthful `AbortReason` constructor — in the library, not in the
  loop.
- Ledger/watermark table names and migration numbering (continues `004_…`).
- Retry counts, backoff curve, exact exit-code numbers, JSON field names.
- LOOP-03's shape floor thresholds (minimum byte size; `length dQx == nEvents` is fixed).
- How the restart-with-events-while-down proof (LOOP-01) and the torn-read positive control
  (LOOP-03) are staged — but both MUST be observed, per the standing v6.0 rule.

</decisions>

<prerequisites>
## Prerequisites before `/gsd:plan-phase 28`

1. **Fixture directory (LOOP-04).** `test/models/mev_tax_model_one/fixtures/` does not exist in
   this worktree and the loop may not create it. **Action: comment on issue #25** asking the
   `mev_tax_model_one` track (issue #24) to land the directory on develop (a `.gitkeep` or
   their own fixture seed). Planning proceeds once it is on develop and merged here.
2. **CHAIN-01 is still BLOCKED** (issue #26: the plank/mev-migrate worktree does not yet emit a
   mined `Shock`). The loop's *live* path cannot be observed end to end until it does. Phase 28
   is planned so that LOOP-01..05 are proven **chain-free** — synthetic logs into the decoder,
   `Store.Memory`/`Store.Postgres`, a stub `Solver` — with the live run recorded as a Tier-C
   capture gated exactly as Phase 27 gated its captures. The phase does **not** wait on #26 to
   plan or to ship its chain-free proofs.

</prerequisites>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and the seams it must close
- `.planning/ROADMAP.md` §"Phase 28: Resident Loop & Fixture Publication" — goal, the five
  success criteria (verbatim obligations), the issue #29 closure note that makes LOOP-03 a
  *typed* obligation
- `.planning/REQUIREMENTS.md` — LOOP-01..05 text; the **STORE deferral block** (STORE-02..05,
  STORE-07 with their "why deferred"); the traceability table
- `.planning/SPIKE-end-to-end.md` — seams **S1, S2, S3** that did not mate; binding on this phase
- `.planning/phases/27-anvil-read-layer/27-SUMMARY.md` §"Carried forward into phase 28" — S1
  restated, CHAIN-01 block named with what discharges it
- `.planning/phases/27-anvil-read-layer/27-CONTEXT.md` — the "measured before written" plan
  shape, the chain-free `cabal test` rule, Tier-C capture gating
- `.planning/STATE.md` §"Accumulated Context" (Phase 27 and Phase 24 decisions) — the census
  rules every new file must satisfy; `setEnv k ""` routes to `unsetEnv`; `anvil_setStorageAt`
  does not mint a block

### The consumer's contract
- GitHub issue #25 — the fixture path `test/models/mev_tax_model_one/fixtures/volume_path.json`
  and the reader (`test__priceInvarianceUnderVolumePath`, `vm.skip`s until the file exists)
- GitHub issue #24 — the consuming Solidity test and its track (the directory owner)
- GitHub issue #29 (closed) / plank `f713089` — the test ATTACHES to the live pool; why
  `pool`/`blockNumber`/`chainId` must be published
- GitHub issue #26 — the `Shock` emitter block (CHAIN-01)
- `offchain/rig/volume-path-golden.json` — the ten artifact fields the fixture carries
  alongside the three identity fields

### Store and prover surfaces the loop composes
- `offchain/migrations/001_model_run.sql`, `002_byte_corpus.sql`,
  `003_version_columns_nonempty.sql` — schema conventions; the next migration is `004_`
- `offchain/lib/Store/Class.hs`, `Store/Types.hs`, `Store/Key.hs`, `Store/Cache.hs`,
  `Store/Solver.hs`, `Store/Postgres.hs`, `Store/Memory.hs` — the seams
- `offchain/lib/Gams/Run.hs` (`ProverOutcome`, `AbortReason`, `ToolchainIdentity`,
  `CapturedStreams`), `Gams/Invoke.hs`, `Gams/Version.hs`
- `offchain/app/SpikeEndToEnd.hs` — the one place the five components were wired; throwaway by
  construction, but the only worked example of the composition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Driver.Capture.write_json_atomically :: ToJSON a => FilePath -> a -> IO ()` — an atomic
  temp-then-rename JSON writer already exists (Phase 22). LOOP-03 should reuse or generalize
  it, not write a second one; the torn-read positive control must defeat it by bypassing it.
- `Chain.Endpoint` + `offchain/rig/endpoint.sh` — the one-resolver-two-languages pattern; the
  fixture-dir resolver copies its shape, and the 27-01 census will name any new file.
- `Chain.Read` — `BlockRef`-required pool reads with field-naming refusals;
  `Chain.Shock` — the `Shock` decoder proven against synthetic logs (CHAIN-04).
- `Fee.Split`, `Store.Key.key_identity`, `Store.Cache.decide`, `Store.Solver.Solver`,
  `Store.Postgres`/`Store.Memory` (same `Store` record — tests run chain- and DB-free).
- `Gams.Version` — the parser/validator `detect_toolchain` must reuse rather than re-implement.
- `Rig.Manifest` — addresses/selectors/topic0s the poll filter takes from, never re-typed.

### Established Patterns
- **Measured, not narrated:** every success criterion is an observed firing with the mutation
  applied, seen red, baseline restored and `sha256sum -c`'d (Phases 26–27).
- **`cabal test` is chain-free and DB-free by structural grep** with positive controls; live
  evidence is a committed Tier-C capture produced by an `offchain/rig/capture-*.sh` script.
- **Exit 0 means "it ran"** (Phase 24): gate on evidence (artifact, marker), never log text.
- **Prose inside a census's blast radius is declared, never argued away** (27-01).
- **Do not run `gsd-tools state …` or `phase complete`** — they rewrite `STATE.md`'s frontmatter
  on this multi-track repo; close plans and phases by hand.

### Integration Points
- New executable alongside `offchain/app/*Conformance.hs` (cabal stanza with the same
  `+0 packages` discipline), plus a `Loop.*` (or similar) library namespace.
- Migration `004_` adds the ledger + watermark tables; `Store.Postgres` (and `Store.Memory`
  for tests) grow the corresponding operations.
- `offchain/rig/` gains the capture script for the live Tier-C run, gated like 27's.

</code_context>

<specifics>
## Specific Ideas

- "The ledger is what a post-mortem reads" — every outcome, including cache hits, is a row.
- A cache hit is still *news*: the fixture tracks the newest event, stamped with that event's
  block, even when the bytes were solved earlier.
- The drift ruling is deliberate: keep the loop up and make the switch reconstructible from
  the ledger, rather than halting a resident process for a toolchain upgrade.

</specifics>

<deferred>
## Deferred Ideas

- **STORE-07 append-only enforcement** (trigger hardening) — the ledger lands without it;
  stays deferred with STORE-02..05 (08-17 scope cut unchanged).
- **Single-flight / concurrent solves** — already deferred (v7.0+); the loop is single-process.
- **Retention / GC of unpinned entries** — already deferred; nothing to sweep yet.
- **Re-probing toolchain identity per iteration** — rejected for this phase; revisit if the
  drift-adopt ruling proves noisy in practice.

</deferred>

---

*Phase: 28-resident-loop-fixture-publication*
*Context gathered: 2026-08-22*
