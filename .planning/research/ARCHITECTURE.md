# Architecture Research

**Domain:** Integrating a Postgres keyed store, a GAMS solver subprocess layer, and a resident event-driven loop into an existing Haskell offchain client (`offchain/lib/`, `hs-web3`, framework-free test suite)
**Researched:** 2026-08-16
**Confidence:** HIGH for everything measured in this repo and in the dependency sources; MEDIUM where noted per-claim

> **Read this first.** Two findings below invalidate parts of the milestone brief as written in
> `.planning/PROJECT.md`. Both were MEASURED, not inferred. See "Anti-Pattern 1" (jsonb destroys
> the byte-reproduction guarantee) and "Failure propagation" (`runWeb3'`'s `Left` branch is
> unreachable — the problem is one level worse than the brief states).

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│  EXECUTABLES  offchain/app/                                              │
│  ┌────────────────┐ ┌──────────────────┐ ┌─────────────────────────────┐ │
│  │ Main.hs        │ │ CheatSwapProof.hs│ │ VolumePathLoop.hs      NEW  │ │
│  │ (existing)     │ │ (existing)       │ │ the resident loop           │ │
│  └────────────────┘ └──────────────────┘ └──────────────┬──────────────┘ │
├──────────────────────────────────────────────────────────┼───────────────┤
│  ORCHESTRATION (the only broad exception handler)         ▼               │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Loop.Run          one block per iteration, watermark-driven       │  │
│  │  Loop.Publish      one file, atomic, raw bytes                     │  │
│  └───┬──────────────┬──────────────┬───────────────┬──────────────────┘  │
├──────┼──────────────┼──────────────┼───────────────┼─────────────────────┤
│  IO EDGES — exactly one module per area touches the outside world        │
│  ┌───▼─────────┐ ┌──▼───────────┐ ┌▼─────────────┐ ┌▼─────────────────┐  │
│  │VolumePath   │ │ Gams.Invoke  │ │Store.Postgres│ │ Driver.Capture   │  │
│  │  .Rpc       │ │ (subprocess) │ │ (SQL only)   │ │ (atomic writes)  │  │
│  │ (Web3)      │ │              │ │              │ │ EXISTING, extend │  │
│  └───┬─────────┘ └──┬───────────┘ └┬─────────────┘ └──────────────────┘  │
├──────┼──────────────┼──────────────┼─────────────────────────────────────┤
│  PURE CORE — no IO, no chain, no DB, no GAMS. The whole testable surface. │
│  ┌───▼─────────┐ ┌──▼───────────┐ ┌▼─────────────┐ ┌──────────────────┐  │
│  │VolumePath   │ │ Gams.Outcome │ │ Store.Logic  │ │ FeeSplit.Split   │  │
│  │  .Decode    │ │ Gams.Args    │ │ Store.Key    │ │ FeeSplit.Types   │  │
│  │VolumePath   │ │              │ │ Store.Schema │ │                  │  │
│  │  .Types     │ │              │ │ Store.Laws   │ │                  │  │
│  └─────────────┘ └──────────────┘ └──────────────┘ └──────────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│  STORE IMPLEMENTATIONS behind ONE record-of-functions (Store.Class)       │
│  ┌──────────────────────┐              ┌──────────────────────────────┐  │
│  │ Store.Memory (IORef) │              │ Store.Postgres (libpq)       │  │
│  │ drives cabal test    │              │ drives the capture step only  │ │
│  └──────────────────────┘              └──────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
        │                                            │
        ▼                                            ▼
  offchain/rig/store-conformance.json      test/models/mev_tax_model_one/
  (committed evidence, read by cabal test)   fixtures/volume_path.json
                                             (OTHER workstream's tree)
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `Store.Class` | The store as a record of `IO` functions; the seam both implementations satisfy | Record-of-functions, **not** a typeclass |
| `Store.Logic` | Cache-hit / re-solve / mismatch decision; byte-equality verdict | Pure, over what the store returned |
| `Store.Key` | `H(seven inputs ‖ gamsVer ‖ conoptVer)` | Pure; takes version **strings** as arguments |
| `Store.Postgres` | SQL. Nothing else. Makes no decision | Only module importing `postgresql-simple` |
| `Store.Memory` | Reference implementation; the suite's store | `IORef (Map Digest StoredRun)` |
| `Store.Laws` | The store contract as a shared, executable list | Consumed by BOTH tiers — never transcribed |
| `Gams.Invoke` | Spawn, collect `(ExitCode, rawBytes)`. Classifies nothing | `readProcessWithExitCode` |
| `Gams.Outcome` | Exit-code → verdict. Never reads log text | Pure |
| `FeeSplit.Split` | Closed-form `(φ_X, φ_M)` + feasibility predicate | Pure, base-only |
| `VolumePath.Rpc` | Block-pinned pool reads; `next` log fetch | The one `Web3` edge |
| `Loop.Run` | One block per iteration; watermark; shutdown | The one broad exception handler |
| `Loop.Publish` | One file into another track's tree, atomically, as raw bytes | Delegates to `Driver.Capture` |

---

## Recommended Project Structure

### Does `{Types,Encoding,Decode,Rpc}` fit a DB-backed area? No — and it does not need to.

That template is not actually the repo's convention. Measured across `offchain/lib/`:

| Area | Modules present |
|------|-----------------|
| `VolOrder` | Types, Encoding, Decode, Report, Rpc |
| `PriceSetter` | Encoding, Decode, Report, Rpc (no Types) |
| `StochasticPriceGen` | Types, **Simulate**, Report, Rpc |
| `CheatSwap` | Types, Encoding, Rpc (no Decode) |
| `RealizedVol` | Decode (only) |
| `Rig` | **Manifest** (only) |
| `Driver` | **Capture**, **Seed** |

`Rig.Manifest` and `Driver.Capture` — the two closest analogues to the new work (config resolution,
artifact writing) — already use role-named modules and neither resembles the four-module template.

**The real invariant, and the one to preserve: one directory per concern, module names name the
ROLE, and exactly ONE module per area touches the outside world.** In every existing area that
module is `Rpc`. In the new areas it is `Postgres`, `Invoke`, `Rpc`, and `Publish` respectively.

### New modules

```
offchain/lib/
├── Store/                       # phases 1-2
│   ├── Types.hs        NEW  PURE  StoredRun, RunLogEntry, Retention, Decision
│   ├── Key.hs          NEW  PURE  store_key :: ShockInputs -> Toolchain -> Digest
│   ├── Logic.hs        NEW  PURE  decide, verify_bytes  <- phase 2's real content
│   ├── Schema.hs       NEW  PURE  [Migration] as ordered (version, name, sql) values
│   ├── Class.hs        NEW  IO    the Store record-of-functions (the seam)
│   ├── Laws.hs         NEW  IO    store_laws :: [(String, Store -> IO (Either String ()))]
│   ├── Memory.hs       NEW  IO    IORef-backed Store
│   ├── Config.hs       NEW  IO    PGSTORE_DSN resolution, Rig.Manifest idiom
│   └── Postgres.hs     NEW  IO    the ONLY postgresql-simple importer
├── Gams/                        # phase 3
│   ├── Args.hs         NEW  PURE  render_overrides -> ["--sqrtPriceX96=...", ...]
│   ├── Outcome.hs      NEW  PURE  classify :: ExitCode -> Maybe ByteString -> Outcome
│   ├── Version.hs      NEW  IO+PURE  toolchain probe + its parser (exported separately)
│   └── Invoke.hs       NEW  IO    readProcessWithExitCode
├── FeeSplit/                    # phase 5 — zero dependencies beyond base
│   ├── Types.hs        NEW  PURE
│   └── Split.hs        NEW  PURE  feasible, split
├── VolumePath/                  # phase 4 (split: Types+Decode unblocked, Rpc blocked)
│   ├── Types.hs        NEW  PURE  ShockInputs — the seven, VOLUME_PATH.md §2
│   ├── Decode.hs       NEW  PURE  the `next` event; RealizedVol.Decode idiom
│   └── Rpc.hs          NEW  IO    BLOCKED — block-pinned pool reads
└── Loop/                        # phase 6
    ├── Types.hs        NEW  PURE  Watermark, IterationOutcome
    ├── Run.hs          NEW  IO    the resident fold
    └── Publish.hs      NEW  IO    one path, atomic, raw bytes
```

### Modified existing files

| File | Change | Why |
|------|--------|-----|
| `offchain/lib/Driver/Capture.hs` | **Add** `write_bytes_atomically :: FilePath -> ByteString -> IO ()`; redefine `write_json_atomically` on top of it, preserving the existing `onException` cleanup | Lines 356–360 already own the atomic-write primitive and lines 336–355 already document why. The fixture must be the prover's **raw bytes**, and the current entry point goes through aeson — see Anti-Pattern 1 |
| `cfmm-replicationPlank-rpc-api.cabal` | Add ~20 `exposed-modules`; add `postgresql-simple` and `unix` to the library `build-depends`; add an `executable volume-path-loop` stanza | Follow the existing comment discipline (lines 107–115) recording *whether a new package enters the build plan* |
| `offchain/test/Main.hs` | Extend `advertised_overrides` (:3562), `swept_artifacts` (:5019), `core_checks` (:5697); add `expected_store_laws` in the `expected_selector_pins` idiom (:424) | Mandatory — see "Testability" below. Skipping this makes every new falsification vacuous |
| `.gitignore` | Add `test/models/**/fixtures/.*.tmp` | The atomic rename needs a same-directory sibling |
| `Makefile` | Add `store-conformance`, `volume-path-loop` targets | Mirrors `compile-gams` / `price-setter-deploy` |

### New non-Haskell files

| File | Purpose |
|------|---------|
| `offchain/rig/capture-store-conformance.sh` | Stands up Postgres in Docker, runs `Store.Laws` against `Store.Postgres`, emits the committed artifact. `deploy-rig.sh` idiom |
| `offchain/rig/store-conformance.json` | **Committed evidence.** What `cabal test` asserts over |
| `offchain/app/StoreConformance.hs` | The capture executable, in the `CheatSwapProof.hs` family |

### Structure Rationale

- **`Store/Class.hs` is a record-of-functions, not a typeclass.** The codebase defines **zero**
  typeclasses of its own across all 26 library modules. A record can be constructed at runtime,
  swapped per-check, and partially overridden (a store whose `store_put` fails on the third call is
  one line) with no newtype-and-instance ceremony.
- **`Store/Logic.hs` separate from `Store/Postgres.hs`** is what makes phase 2 "mostly pure over an
  interface" true rather than aspirational. `Postgres.hs` answers *what rows exist*; `Logic.hs`
  decides *what that means*.
- **`Store/Key.hs` takes version strings as arguments**, so it does not import `Gams/Version.hs`.
  This breaks what would otherwise be a phase 2 → phase 3 dependency (the key needs GAMS and CONOPT
  versions) and makes the key testable against literal strings.
- **`VolumePath/Types.hs` holds `ShockInputs`** because the shock is what the Anvil layer produces,
  the store keys, and GAMS consumes. It is pure data transcribed from `VOLUME_PATH.md` §2 and is
  **not** blocked on the upstream event.

---

## Architectural Patterns

### Pattern 1: The store as a record-of-functions with a shared law list

**What:** One `Store` value; two constructors; one executable law list both are held to.
**When:** Whenever an implementation needs a service the test suite must not require.
**Trade-offs:** Costs one indirection. Buys a suite that never opens a socket, and makes it
*structurally impossible* for the in-memory and Postgres contracts to drift.

```haskell
-- offchain/lib/Store/Class.hs
data Store = Store
  { store_lookup     :: Digest -> IO (Maybe StoredRun)
  , store_put        :: StoredRun -> RunLogEntry -> Watermark -> IO ()  -- ONE transaction
  , store_pin        :: Digest -> Retention -> IO ()
  , store_reset      :: IO Int          -- returns rows removed; pinned rows survive
  , store_log_append :: RunLogEntry -> IO ()
  , store_watermark  :: IO (Maybe Watermark)
  }

-- offchain/lib/Store/Laws.hs -- consumed by BOTH tiers. Never transcribed.
store_laws :: [(String, Store -> IO (Either String ()))]
store_laws =
  [ ("cache_hit_elides_the_solve",        law_cache_hit)
  , ("resolve_reproduces_bytes",          law_byte_identity)
  , ("byte_mismatch_is_loud",             law_mismatch_refused)
  , ("pin_survives_reset",                law_pin_retained)
  , ("reset_removes_unpinned",            law_reset_scope)
  , ("run_log_is_append_only",            law_log_append_only)
  , ("same_key_twice_is_two_log_rows",    law_provenance_distinct)
  , ("watermark_advances_with_the_write", law_watermark_atomic)
  ]
```

The test suite runs `store_laws` against `Store.Memory`. `capture-store-conformance.sh` runs the
**same list** against `Store.Postgres` and commits the verdicts. A law present in one and absent
from the other cannot exist. This is the executable form of the rule
`offchain/test/Main.hs:11-16` states for pins: *a consumption check, not a transcription*.

### Pattern 2: The pinned read, recorded from the call and not from intent

**What:** Every chain read carries the `DefaultBlock` it was **made at**, not the block it should
have been made at.
**When:** Every read in `VolumePath.Rpc` and every read in the loop.
**Trade-offs:** One extra field per read record. Buys the only detection that exists for a read
that quietly slid to `Latest`.

This already exists and must be copied, not reinvented — `VolOrder.Rpc.PackedReadback`
(`offchain/lib/VolOrder/Rpc.hs:205-221`) plus `readback_height`
(`offchain/app/Main.hs:302-310`), which returns `Nothing` for any unpinned tag rather than
inventing a height. The haddock at `VolOrder/Rpc.hs:200-204` states the reason: on a
single-writer local node `Latest` returns byte-identical results, so the slide is invisible in
every other recorded value.

```haskell
data PinnedRead a = PinnedRead
  { pr_block :: DefaultBlock   -- where the call WENT
  , pr_value :: a
  }
```

### Pattern 3: The IO edge that classifies nothing

**What:** The subprocess/SQL/RPC module returns raw material; a pure sibling renders the verdict.
**When:** All four IO edges.
**Trade-offs:** Two modules where one would do. Buys full test coverage of the decision logic.

```haskell
-- offchain/lib/Gams/Invoke.hs -- IO. Decides nothing.
run_prover :: FilePath -> [String] -> FilePath -> IO (ExitCode, Maybe ByteString)

-- offchain/lib/Gams/Outcome.hs -- PURE. Decides everything.
data Outcome = Solved ByteString | Aborted Int | NoOutput
classify :: ExitCode -> Maybe ByteString -> Outcome
classify (ExitFailure n) _         = Aborted n
classify ExitSuccess     Nothing   = NoOutput   -- exit 0 with no file IS an abort
classify ExitSuccess     (Just bs) = Solved bs
```

`classify` is total, pure, and every branch is a `pure_check` in the suite with no GAMS installed.

**Exit-code gating is sound — MEASURED, resolving a contradiction inside this repo.**
`Makefile` (the `payoff-fixtures` recipe) asserts *"`gams` exits 0 even on compile errors"* and
greps the `.lst`; `VOLUME_PATH.md` §4 says *"gate on it, never on log text."* Measured at
GAMS 54.1 with `action=ce` (the prover's mode):

| case | exit |
|---|---|
| clean run | `0` |
| compile error | `2` |
| `abort$(...)` fires | `3` |

The exit code is faithful. The Makefile comment is not reproducible at this version and action;
follow `VOLUME_PATH.md`. The one gap it leaves is *exit 0 with no output file* — closed by the
`NoOutput` branch above, which is an **absence-of-artifact** test, not a log-text test.

### Pattern 4: One solve, one transaction — and the subprocess is outside it

**What:** The result row, the run-log row, and the watermark advance are a single
`withTransaction`. The GAMS run is not in it.
**When:** Every loop iteration that solves.

```haskell
-- Store/Postgres.hs
store_put run logEntry mark = withTransaction conn $ do
  _ <- execute conn "insert into model_run (key, raw, doc, ...) values (?,?,?,...)" ...
  _ <- execute conn "insert into run_log (ts, key, tx_hash, log_index, block) values (?,?,?,?,?)" ...
  _ <- execute conn "update store_state set last_processed_block = ?" (Only mark)
  pure ()
```

`postgresql-simple`'s `withTransaction` (`Transaction.hs:114`, verified in source) rolls back on
any exception, async included. So a failure anywhere in an iteration leaves the store exactly as
it was, the watermark unadvanced, and the block re-processed on restart. **Never write the result
and the log in two transactions** — that is the only way a partial failure can leave the store
describing a solve that has no provenance row.

A subprocess cannot be rolled back, so the CONOPT run happens *before* the transaction opens. A
crash in between costs one re-solve. That is the correct trade: the alternative holds a connection
and a row lock open across a multi-second solve.

---

## Data Flow

### The loop's iteration

```
      ┌── watermark b0 (a row in the store, not an IORef) ─────────────┐
      │                                                               │
      ▼                                                               │
  eth_blockNumber ──► h                                               │
      │                                                               │
      │  for b in [b0+1 .. h]      one block per iteration            │
      ▼                                                               │
  eth_getLogs {fromBlock=b, toBlock=b, address=emitter, topic0=next}   │
      │                                                               │
      ▼  VolumePath.Decode  (PURE)                                     │
  decoded `next` args                                                  │
      │                                                               │
      ▼  VolumePath.Rpc, EVERY read at BlockWithNumber b               │
  sqrtPriceX96, liquidity, φ_M                                         │
      │                                                               │
      ▼  FeeSplit.Split  (PURE)  ── infeasible ──► refuse, log, advance┤
  (φ_X, φ_M) proven feasible                                          │
      │                                                               │
      ▼  Store.Key  (PURE)                                            │
  digest ──► store_lookup ── hit ──► Store.Logic.decide = ElideSolve ──┤
      │ miss                                                          │
      ▼  Gams.Invoke ──► Gams.Outcome  (PURE)                          │
  Solved rawBytes                                                      │
      │                                                               │
      ▼  ONE transaction: result + log row + watermark := b ──────────┘
      │
      ▼  Loop.Publish  (raw bytes, atomic rename)
  test/models/mev_tax_model_one/fixtures/volume_path.json
```

### Key data flows

1. **Cache elision is keyed on CONTENT; loop idempotency is keyed on PROVENANCE.** Conflating them
   is the trap. A second `next` event carrying identical shock values produces the identical
   digest and correctly elides the solve — but it is a genuine second occurrence and gets its own
   `run_log` row (`UNIQUE (tx_hash, log_index)`). `PROJECT.md` says the log exists "for chronology
   the content key can't give"; this is that sentence made operational.
2. **The byte oracle flows through `bytea` and never through `Value`.** `Gams.Invoke` returns
   `ByteString`; `Store.Key` digests `ByteString`; `Store.Logic.verify_bytes` compares
   `ByteString`; `Loop.Publish` writes `ByteString`. `Data.Aeson.Value` appears on exactly one
   path — the queryable `doc jsonb` column — and never on the authoritative one.

---

## Testability: keeping the suite chain-independent AND db-independent

### What the suite actually is (measured, not assumed)

It never opens an RPC — but it is **not** self-contained. `offchain/rig/rig-manifest.json` is
gitignored (`.gitignore:58`) and 7 of 85 checks hard-require it; the CI job header
(`.github/workflows/develop-gate.yml:130-155`) records the measurement: 78/85 in a clean checkout.
So the real property is: **assertions run against captured evidence, never against a live service,
and an absent subject FAILS.** `sc3_load_succeeds` states it in one sentence
(`offchain/test/Main.hs:726-728`):

> *Deliberately FAILS rather than skips when the rig is down. […] a suite that goes quietly green
> because the rig is missing is worse than one that goes red.*

### THE DECISION

**Three tiers. Postgres is never a dependency of `cabal test`. Nothing ever skips.**

| Tier | What | Runs in `cabal test`? | Needs a DB? |
|------|------|----------------------|-------------|
| **A — pure** | `Store.Logic`, `Store.Key`, `Store.Schema`, `Gams.Outcome`, `Gams.Args`, `FeeSplit.*`, `VolumePath.Decode`, `Loop` decision fns | Yes, as `pure_check` | No |
| **B — interface laws** | `store_laws` driven against `Store.Memory` | Yes | No |
| **C — conformance capture** | The **same** `store_laws` against `Store.Postgres`, out of band; verdicts committed to `offchain/rig/store-conformance.json`; the suite asserts over the artifact | Asserts the artifact only | Only for the capture |

Tier C is the existing `driver-run-capture.json` pattern applied to a database instead of a chain.
It is the same answer the repo already reached for the chain, and it is the answer for the same
reason.

### The five anti-vacuity clauses — non-negotiable

This project has a documented history of exactly this failure. Three advertised path overrides were
measured **advertised-but-dead** (22-03 `RIG_MANIFEST`, 22-04 `RIG_CHEAT_SWAP_PROOF`, 22-07
`RIG_PINS`), each making every falsification aimed through it come back green. And a thinned pin
file was measured passing **52/52 with 29 selectors unverified** (`offchain/test/Main.hs:411-414`).

1. **Absent artifact ⇒ FAIL, never skip.** `store_conformance_is_present_and_fresh` in the
   `rpin05_capture_is_present_and_fresh` idiom.
2. **A completion flag, not a count.** `sc_complete :: Bool` + `sc_law_count :: Int` in the
   `dr_complete` / `dr_configured_size` idiom (`Driver/Capture.hs:93-98`), so a truncated
   conformance run is visible without arithmetic.
3. **A law SET, not a floor.** `expected_store_laws :: [String]` in the suite, in the
   `expected_selector_pins` idiom (`offchain/test/Main.hs:424`) — a set, because *"a floor of
   thirty is satisfied by thirty pins of which one has been swapped."*
4. **Register the overrides.** `PGSTORE_DSN`, `STORE_CONFORMANCE` and `VOLUME_PATH_FIXTURE` get
   `OverrideProbe` entries in `advertised_overrides` (`offchain/test/Main.hs:3562`). The probe
   asserts the resolver returns the override verbatim, differs from the default, **and** that the
   consumer fails loudly naming the path.
5. **Register the artifact.** `store-conformance.json` becomes a `MutableArtifact` in
   `swept_artifacts` (`offchain/test/Main.hs:5019`) so the sentinel harness mutates every leaf and
   reports any field nothing asserts. Raise `sentinel_pair_floor` and add an
   `artifact_field_floors` entry deliberately, with the measurement.

### The three alternatives, and where each belongs

| Approach | Verdict |
|----------|---------|
| **In-memory implementation** | **ADOPT** as Tier B. The store's laws are properties of the *interface*, not of Postgres. This is where ~90% of phase 2 gets tested. |
| **Transaction-rollback fixtures** | **ADOPT — but only inside Tier C.** `begin`/`rollback` (verified: `Transaction.hs:182-195`) wrap each law in the capture tool so the conformance run leaves no rows. **REJECT** as a way to make `cabal test` DB-backed: it still needs a live DB and would put a service dependency on the self-hosted `cfmm-build` gate runner. |
| **testcontainers / `tmp-postgres`** | **REJECT for the suite; ADOPT `docker run` for the capture script.** `tmp-postgres`'s last release is 2019-12-29 and it needs `initdb`/`pg_ctl` on `PATH`. Measured on this machine: only `/usr/bin/psql` exists — client, no server. Docker **is** present. So the capture script does `docker run --rm postgres:18-alpine` with a pinned tag, in the `deploy-rig.sh` idiom. Never from inside `cabal test`. |
| **"Skip if no DB"** | **FORBIDDEN.** The exact failure class the brief names and `sc3_load_succeeds` rejects. |

---

## Purity Boundaries

**Rule: one named IO edge per area, and the decision is never made inside it.**

| Boundary | Above it (pure, tested with nothing installed) | Below it (IO, exercised only by capture tools) |
|----------|-----------------------------------------------|-----------------------------------------------|
| Store | `Logic.decide`, `Logic.verify_bytes`, `Key.store_key`, `Schema.migrations`, `Types` | `Postgres.connect/execute/query` |
| GAMS | `Outcome.classify`, `Args.render_overrides`, `Version.parse_version` | `Invoke.run_prover`, `Version.probe` |
| FeeSplit | **all of it** | *(nothing)* |
| VolumePath | `Decode.decode_next`, `Types` | `Rpc.read_pool_state` |
| Loop | `next_block`, `Publish.fixture_path`, iteration decision fn | `Run.step`, `Publish.publish` |

**The total non-pure surface is six functions.** Everything else — the whole key computation, the
whole cache decision, the whole feasibility predicate, the whole event decode, the whole
exit-code classification, the migration list — is testable in `cabal test` with no chain, no DB
and no GAMS installed.

Config resolution follows `Rig.Manifest` exactly: mandatory fields, no defaulted fallback,
`Either String` returned so the caller decides how loudly to fail, and `either fail pure` **at
startup**. `Rig/Manifest.hs:363-378` is the canonical statement of why (`read` is partial *and*
lazy, so it throws from wherever the value is first forced — mid-fold, after transactions have
mined).

---

## The Resident Loop

### Polling, not subscription — and this is FORCED, not preferred

Verified from dependency source:

1. `Network.Ethereum.Api.Eth` exports `newFilter`, `getFilterChanges`, `getLogs`, `newBlockFilter`
   — and **no `eth_subscribe`**.
2. `jsonrpc-tinyclient`'s `call` is strictly one `WS.sendTextData` followed by one
   `WS.receiveData` (`TinyClient.hs:203-205`). It cannot receive unsolicited notifications; a
   subscription push would be mis-decoded as the response to the next request.
3. `runWeb3' (WsProvider …)` sends `WS.sendClose` the moment the action returns
   (`Provider.hs:92`), so a subscription cannot outlive one `runWeb3'` call regardless.

**Use `eth_getLogs` over an explicit closed `[b, b]` range.** Do **not** use
`newFilter`/`getFilterChanges`: a node-side filter is server state with its own expiry, invisible
to the artifact, and it returns "changes since last poll" — precisely the un-pinnable,
un-replayable shape.

### Pinning every read to one block

The loop's unit of work is a **block**, not an event. Every read in an iteration passes
`BlockWithNumber b` — the log fetch bounded `fromBlock == toBlock == b`, and every `eth_call`
pinned to the same `b`. `Latest` appears nowhere in `Loop` or `VolumePath.Rpc`. Each read is
recorded as a `PinnedRead` carrying the block it was made at, rendered through `readback_height`
so an unpinned tag surfaces as `null` in the artifact rather than as a plausible height.

### Idempotency: two mechanisms, because there are two questions

| Question | Mechanism |
|----------|-----------|
| "Have I already *solved* this shock?" | The content key. Identical seven inputs + identical toolchain ⇒ identical digest ⇒ cache hit ⇒ no solve. Replay is free and automatic. |
| "Have I already *seen* this event?" | The run log, `UNIQUE (tx_hash, log_index)`. Re-processing a block is a no-op on conflict. |

Two distinct `next` events in one block with identical shock values collapse to one key and **must**
produce two log rows. The content key cannot distinguish them and must not try.

### Backpressure: no queue at all

**The loop is a synchronous fold over a persisted watermark.** One block per iteration; the
watermark advances in the same transaction as the write.

- Solving slower than block production ⇒ the loop falls behind and `last_processed_block` records
  exactly how far. A visible, queryable lag instead of a growing heap.
- Catch-up processes blocks in order without skipping, so no event is ever dropped.
- Crash recovery is free: restart resumes from the watermark.

**Reject** an in-memory `TQueue`/`IORef` of pending events (invisible on crash, unbounded) and
"read `Latest` and skip ahead" (drops events silently — the exact failure class this codebase
keeps rediscovering).

### Clean shutdown

An `IORef Bool` stop-flag set by a `SIGINT`/`SIGTERM` handler (`System.Posix.Signals.installHandler`)
and checked at the **top** of each iteration — never mid-block. The whole fold sits under `finally`,
in the idiom of `offchain/app/Main.hs:194`.

Invariant: **a shutdown is only ever observed at a block boundary**, so the watermark is always
consistent and no iteration is ever half-recorded.

`unix` is a GHC boot package — no new package enters the build plan. Record that in the `.cabal`
comment, matching the discipline already used for `directory` and `vector` (lines 107–115).

### Interaction with cache elision

A cache hit still: appends a run-log row, advances the watermark, **and re-publishes the fixture**.
That last one matters — the fixture must reflect the newest *run*, and a run that hit cache is
still a run. It is also cheap and idempotent (identical bytes, atomic rename).

---

## Failure Propagation

### The measured facts — worse than the brief states

| Fact | Evidence |
|------|----------|
| `Web3 = StateT JsonRpcClient IO`, `deriving MonadFail` | `Provider.hs:43-44` |
| So `fail` = `IO`'s = `throwIO . userError` ⇒ `IOException` | GHC's `MonadFail IO` |
| `runWeb3'` is `liftIO . try . …` at type `Either Web3Error a` | `Provider.hs:84-86` |
| **`web3-ethereum` never constructs a `Web3Error`** — 0 occurrences of the string across `src/` | `grep -rc Web3Error` |
| Real RPC failures throw `JsonRpcException (ParsingException \| CallException)` — a **different** type | `TinyClient.hs:157-161, 216-217` |

**Therefore `runWeb3'`'s `Left` branch is unreachable for this codebase.** The
`Left web3_error -> putStrLn ("rpc error: " ++ …)` handlers at `offchain/app/Main.hs:235` and
`offchain/lib/VolOrder/Rpc.hs:279` are dead code. Not only `fail` — *every* real failure, including
a node error response and a decode failure, arrives as an uncaught exception from anywhere in the
fold, after transactions may have mined.

### The error model

| Layer | Mechanism |
|-------|-----------|
| Pure boundaries (`Store.Logic`, `Store.Config`, `Gams.Outcome`, `FeeSplit`, `VolumePath.Decode`) | **`Either String` / `Either <NamedError>`**, resolved with `either fail pure` at **startup**. The `Rig.Manifest` idiom |
| `Web3` actions | Leave as-is. `fail` with a message that names the cause, the resolved values, and what was *not* sent — the `CheatSwap.Rpc` guard idiom |
| Store consistency | **`withTransaction`**, not exception handling |
| The loop | **`try @SomeException` exactly once, at the iteration boundary.** The only broad catch in the new code |

### `ExceptT` is REJECTED — with the reason

`ExceptT e Web3` cannot help, because it does not catch what actually flies. `fail` throws an
`IOException` and `remote` throws a `JsonRpcException`; neither becomes a `Left` in an `ExceptT`
stack. The result is a type that **advertises** total error capture and delivers none — strictly
worse than plain `IO` plus a documented handler, because it converts a known, documented hazard
into a false guarantee. That is precisely the advertised-but-dead defect class this suite already
carries a standing guard against (`every_advertised_override_is_honoured`).

### Why the store stays consistent

`try @SomeException` is at the iteration boundary, and every write in an iteration is inside one
`withTransaction`. So:

- Exception before the transaction ⇒ nothing written, watermark unmoved, block re-processed.
- Exception inside it ⇒ rolled back, watermark unmoved, block re-processed.
- Re-processing a block whose solve had completed hits the content key and elides the re-solve;
  the log row is deduped by `UNIQUE (tx_hash, log_index)`.

**Every partial failure converges to "the block is processed again," and that is always safe.**

`try @IOException` would be a bug here — `JsonRpcException` is not an `IOException`. Note the suite
already makes this narrower choice in `guarded` (`offchain/test/Main.hs:385-390`); the loop must not
copy it.

---

## Publication

### The consumer contract

`test/models/mev_tax_model_one/fixtures/volume_path.json` does **not exist in this worktree** —
`find test -path "*models*"` returns nothing. The precedent that does exist is
`test/gamsDiff/fixtures/*.json`, read by `test/gamsDiff/PricingKernelPlank.diff.t.sol:50,63` via
`vm.readFile` + `vm.parseJsonUintArray`. Same shape, same ownership question.

### The ownership rule: the publisher owns ONE path

- `Loop/Publish.hs` exports one constant (`fixture_path`) and one function. It never enumerates,
  creates, or removes anything else under `test/`.
- The path is overridable via `VOLUME_PATH_FIXTURE`, **registered in `advertised_overrides`** —
  otherwise a forge-side falsification aimed at the fixture is vacuous, three times measured.
- **The loop never creates the directory.** A missing
  `test/models/mev_tax_model_one/fixtures/` is a loud failure naming the path and the owning
  workstream. Creating a directory in another track's tree is how a typo becomes a
  successfully-published-to-nowhere fixture. (`outside_repo`,
  `offchain/test/Main.hs:5061-5071`, is the same principle enforced in the other direction.)

### Partial writes are already impossible — reuse, don't reinvent

`Driver.Capture.write_json_atomically` (`offchain/lib/Driver/Capture.hs:356-360`) writes a
**sibling** temp file then `renameFile`s. Its haddock (lines 336–355) documents why a direct
`encodeFile` is unsafe (it truncates, then streams a lazily-built ByteString, so a bottom partway
through leaves the destination truncated) and why the temp file must be a sibling (so the rename
cannot cross a filesystem and silently degrade to a copy).

**But it goes through aeson, and the fixture must be the prover's bytes.** So:

```haskell
-- ADD to offchain/lib/Driver/Capture.hs
write_bytes_atomically :: FilePath -> ByteString -> IO ()
write_bytes_atomically path bytes = do
  let tmp = path ++ ".tmp"
  BS.writeFile tmp bytes `onException` ignoring_errors (removeFile tmp)
  renameFile tmp path

-- REDEFINE, preserving the existing onException semantics
write_json_atomically :: ToJSON a => FilePath -> a -> IO ()
write_json_atomically path = write_bytes_atomically path . BSL.toStrict . encode
```

One atomic-write primitive, one owner, in the module that already documents why it exists — and
the fixture is the prover's bytes, not aeson's re-rendering of them. (That distinction is not
stylistic; see Anti-Pattern 1.)

The temp sibling lands momentarily inside the other track's directory. That is required for rename
atomicity. Name it `.volume_path.json.tmp` and add `test/models/**/fixtures/.*.tmp` to
`.gitignore`; state plainly that this is the one extra path the publisher touches.

---

## Anti-Patterns

### Anti-Pattern 1: Storing the model output as `jsonb` — DESTROYS the milestone's headline guarantee

**What the brief says:** *"JSONB schema for keyed model outputs"* and *"re-solving an existing key
must reproduce it byte-for-byte."*

**Why it's wrong: those two requirements are incompatible.** MEASURED on Postgres 18 against the
actual `VOLUME_PATH.md` §3 output shape:

| column type | round-trips byte-identically? |
|---|---|
| `bytea` | **true** |
| `json` | **true** |
| `jsonb` | **false** |

The `jsonb` round trip reordered every key (`sqrtPriceX96, liquidity, txlVolumeRate, …` →
`dQM, dQx, nEvents, phiMpips, phiXpips, liquidity, …`), and `sha256` over the two differed
(`4075758e…` vs `dd8a3e26…`). Confirmed by the official docs: *"jsonb does not preserve white
space, does not preserve the order of object keys, and does not keep duplicate object keys"* plus
number reformatting via `numeric`.

**And it is not only Postgres.** MEASURED with aeson at GHC 9.10.3 — `decode` then `encode`
reorders keys **and reformats numbers**: `0.00318353` became `3.18353e-3`. So routing the prover's
JSON through `Data.Aeson.Value` **anywhere** destroys byte identity. That rules out `jsonb`
columns, `postgresql-simple`'s `ToField Value` (which is `toField . JSON.encode`,
`ToField.hs:314-315`), and the existing `write_json_atomically` on the publication path.

**Do this instead — two columns, and the digest is over the raw one:**

```sql
create table model_run (
  key        bytea primary key,   -- H(seven inputs || gamsVer || conoptVer)
  raw        bytea not null,      -- THE ARTIFACT. Byte-exact. The oracle.
  doc        jsonb not null,      -- derived, for querying/indexing. NEVER authoritative.
  model      text  not null,
  gams_ver   text  not null,
  conopt_ver text  not null,
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);
```

`Store.Logic.verify_bytes` compares `raw`. `Store.Key` digests `raw`. `doc` exists so a human can
`select doc->>'deltaRealized'`, and a check must assert it is derived from `raw` — never the
reverse.

**Rejected alternative:** a `json` (not `jsonb`) column alone. It does preserve bytes, but gives up
GIN indexing and containment operators, and is fragile — any tool that casts to `jsonb`
re-normalizes silently.

### Anti-Pattern 2: `ExceptT` over `Web3`

Covered above. It advertises a guarantee the runtime does not provide. Use `Either` at pure
boundaries and one `try @SomeException` at the loop boundary.

### Anti-Pattern 3: Skipping a check when the DB is absent

Forbidden by `sc3_load_succeeds`'s stated rule and by the milestone brief's own warning. Absent
subject ⇒ FAIL, naming the resolved path and the command that produces it.

### Anti-Pattern 4: `Latest` anywhere in the loop

On a single-writer local anvil, `Latest` returns byte-identical results to a pinned read
(`VolOrder/Rpc.hs:200-204`), so the defect is invisible in every recorded value and only appears
under a lagging replica or a second writer. Pin every read, and record the pin.

### Anti-Pattern 5: Gating GAMS on log text

`VOLUME_PATH.md` §4 forbids it and the measurement above shows exit codes are faithful at
`action=ce`. The only supplement permitted is **absence of the output file**, which is not log
text.

### Anti-Pattern 6: The loop creating directories in `test/`

One owned path, never `createDirectoryIfMissing` in another workstream's tree.

### Anti-Pattern 7: A queue between the chain and the solver

Use the persisted watermark. A queue makes lag invisible, unbounded, and lost on crash.

### Anti-Pattern 8: Re-deriving the seven inputs in two places

`Gams.Args.render_overrides` and `Store.Key.store_key` must consume the **same**
`VolumePath.Types.ShockInputs` value. A key computed over a different rendering than the one handed
to the prover is a cache that answers the wrong question — and would be invisible, because both
sides would be self-consistent.

---

## Scaling Considerations

Reframed for this system — user counts are not the axis.

| Load | Adjustment |
|------|------------|
| A few shocks/hour (expected) | Single-connection `postgresql-simple`, single-threaded loop, no pool. |
| Solve slower than block production | Already handled: the watermark records the lag. Add a `store_lag_blocks` readout and a loud warning above a threshold before adding concurrency. |
| Store grows past interactive query speed | Index `(model, created_at)` and add a GIN index on `doc`. `raw` is never searched, only fetched by key. |
| Multiple models (`<model>/<key>` layout) | Already in the schema via the `model` column; no structural change. |
| Multiple concurrent loops | **Do not.** Two loops sharing a watermark is a distributed-lock problem this milestone does not need. If forced: `select … for update` on the watermark row. |

**First bottleneck:** the CONOPT solve, at seconds per uncached shock. The content key is the fix
and it is already in the design.
**Second bottleneck:** publishing on every iteration. Only if it becomes measurable, skip the
rename when the bytes are unchanged — but measure first; a rename is microseconds.

---

## Integration Points

### External services

| Service | Integration | Gotchas |
|---------|-------------|---------|
| Postgres | `postgresql-simple` 0.7.0.1 via `Store.Postgres` only | `jsonb` normalizes — Anti-Pattern 1. **MEASURED:** compiles clean against GHC 9.10.3 / base 4.20.2.0 with `withTransaction`, `begin`/`rollback`, `ToField Value` and `bytea` all type-checking. Its declared bound is `base >=4.12 && <4.22`; tested-with tops out at GHC 9.10.2 vs this repo's 9.10.3 — one patch ahead, and it built here. |
| GAMS 54.1 | `readProcessWithExitCode` via `Gams.Invoke` | Exit `0/2/3` measured for ok/compile-error/abort at `action=ce`. Exit 0 + no output file is still an abort. Toolchain version feeds the key, so a GAMS upgrade correctly invalidates the cache. |
| Anvil | `hs-web3` polling via `VolumePath.Rpc` | No `eth_subscribe` on this stack. Blocked on the upstream `next` event. |
| Docker | `docker run --rm postgres:18-alpine` in the capture script only | Present on this machine. Never invoked from `cabal test`. |

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Loop` ↔ `Store` | `Store.Class` record | The seam that keeps the suite DB-free |
| `Loop` ↔ `Gams` | `(ExitCode, Maybe ByteString)` → pure `classify` | Never log text |
| `Loop` ↔ `FeeSplit` | Pure call, **before** GAMS | "Infeasibility is a refusal we explain, not an exit code we interpret" |
| `Loop` ↔ forge test | One file, atomic rename, raw bytes | The only write into another track's tree |
| `Loop` ↔ `Rig.Manifest` | `load_rig` at startup, `either fail pure` | Existing; no change |
| New code ↔ `Driver.Capture` | `write_bytes_atomically` | The one modified existing module |

---

## Build Order

### Dependency facts that reshape the phase graph

1. **Phase 5 (FeeSplit) has zero dependencies.** Pure math, base only. Startable immediately.
2. **Phase 2 needs the GAMS/CONOPT versions** (they are in the key) — a hidden 2→3 edge. **Broken**
   by having `Store.Key` take version *strings* as arguments; `Gams/Version.hs` becomes an
   independent leaf.
3. **`VolumePath/Types.hs` is needed by phases 2 and 3** but is pure data from `VOLUME_PATH.md` §2.
   Not blocked.
4. **Phase 4 splits.** The selector (`0xd3827b0b`) and signature
   (`next(address,uint160,int24,uint24,uint24)`) are known **now**, so `VolumePath/Decode.hs` is
   buildable and testable against **synthetic logs** — which the suite already does for E1
   (`.cabal:193`, "the Phase 21 event re-pin builds synthetic logs"). Only `VolumePath/Rpc.hs` is
   genuinely blocked on the upstream emitting the event.

### Waves

| Wave | Work | Parallel? | Blocked? |
|------|------|-----------|----------|
| **1** | **5** FeeSplit (pure, zero deps) · **1** PG foundation + `VolumePath/Types.hs` + `Gams/Version.hs` · **4a** `VolumePath/Decode.hs` vs synthetic logs | All three fully parallel | No |
| **2** | **2** keyed store (needs 1) · **3** GAMS invocation (needs `VolumePath/Types`, `Gams/Version`) | 2 and 3 parallel | No |
| **3** | **2+3 integration:** the store↔GAMS round trip incl. the byte-reproduction law, with a hand-supplied shock | — | **No** |
| **4** | **4b** `VolumePath/Rpc.hs` | — | **YES** — upstream `next` event |
| **5** | **6** loop + publication (needs 2, 3, 4b, 5) | — | Inherits 4b's block |

### The sequencing point that matters most

**The byte-reproduction guarantee — the milestone's headline falsifiable claim — is provable at the
end of wave 3, with no chain and no upstream.** The shock is seven values; they can be supplied by
hand. Do **not** sequence that proof behind phase 4. If the upstream block persists, waves 1–3 still
deliver the store, the prover integration, the determinism check, and the fee splitter as a
complete, verified subsystem.

### Suggested phase order for the roadmap

```
Phase 1  →  Postgres foundation, VolumePath.Types, Gams.Version     [unblocked]
Phase 5  →  Fee splitter                            [unblocked, fully parallel with 1]
Phase 4a →  VolumePath.Decode vs synthetic logs     [unblocked, parallel with 1]
Phase 2  →  The keyed store + Store.Laws + conformance capture      [needs 1]
Phase 3  →  GAMS invocation layer                   [needs 1; parallel with 2]
   ── byte-reproduction proven here, chain-free ──
Phase 4b →  Anvil read layer                        [BLOCKED on upstream `next`]
Phase 6  →  Resident loop + fixture publication     [needs all]
```

---

## Open Questions for `/gsd:plan-phase`

1. **Digest function.** `web3-crypto`'s `keccak256` is already a dependency and used by the suite;
   `sha256` would need `cryptonite`/`crypton`. Recommend keccak256 — no new package. Not yet
   confirmed against any external consumer's expectation.
2. **Migration runner.** Recommend `Store/Schema.hs` as an ordered list of pure `(version, sql)`
   values applied in one transaction against a `schema_version` table (~40 lines, no new
   dependency, and the list becomes a pure value the suite can assert over: ordering, no gaps, no
   edits to applied versions). `postgresql-migration` 0.2.1.8 is cached but **unverified** — I did
   not build or read it.
3. **`nEvents`** is listed as an input in `VOLUME_PATH.md` §2 and as an open ruling in §6
   (fixture: 8). It must be in the key. Confirm the production value before the first row lands, or
   accept that changing it invalidates the whole store.
4. **Pinned Postgres image tag.** Measured against `postgres:18-alpine`; the server version is part
   of the conformance evidence and should be recorded in `store-conformance.json`.
5. **Publication on cache hit** — recommended above (a cache hit is still a run), but it is a
   product decision, not a technical one.

---

## Sources

**Primary — this repository (HIGH confidence, read directly):**
- `.planning/PROJECT.md` (v6.0 milestone) · `cfmm-replicationPlank-rpc-api.cabal`
- `offchain/lib/Rig/Manifest.hs` · `offchain/lib/Driver/Capture.hs` · `offchain/lib/Driver/Seed.hs`
- `offchain/lib/VolOrder/Rpc.hs` · `offchain/lib/CheatSwap/Rpc.hs` · `offchain/app/Main.hs`
- `offchain/test/Main.hs` (`Check`:379, `sc3_load_succeeds`:729, `advertised_overrides`:3562,
  `swept_artifacts`:5019, `sentinel_falsification_harness`:5477, `core_checks`:5684)
- `.github/workflows/develop-gate.yml:130-155` · `Makefile` (`compile-gams`, `payoff-fixtures`)
- `test/gamsDiff/PricingKernelPlank.diff.t.sol` · `.gitignore:57-58`

**Binding reference (HIGH):**
- `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/VOLUME_PATH.md` §§1–6

**Dependency sources, read directly (HIGH):**
- `web3-provider-1.1.0.0` `Network/Web3/Provider.hs:43-44, 84-93` · `web3-ethereum-1.1.0.1`
  `Network/Ethereum/Api/Eth.hs` · `jsonrpc-tinyclient-1.1.0.0` `TinyClient.hs:157-161, 182-217`
- `postgresql-simple-0.7.0.1` `Transaction.hs:114-195`, `ToField.hs:314-323`,
  `FromField.hs:576-588`

**Measured on this machine (HIGH — reproducible):**
- GAMS 54.1 `action=ce` exit codes: `0` clean / `2` compile error / `3` `abort$`
- Postgres 18 `bytea` vs `json` vs `jsonb` byte-fidelity on the real `volume_path.json` shape;
  `sha256` divergence
- aeson `decode`→`encode` at GHC 9.10.3: key reorder + `0.00318353` → `3.18353e-3`
- `postgresql-simple` builds clean against GHC 9.10.3 / base 4.20.2.0
- Toolchain present: GHC 9.10.3, cabal 3.16.1.0, `psql`/`pg_config` 18.4 + `libpq-fe.h`, docker,
  gams 54.1. **Absent: `initdb`, `pg_ctl`, `postgres` server binaries.**

**External (MEDIUM — official docs):**
- PostgreSQL `datatype-json` — jsonb normalization
- Hackage `postgresql-simple` 0.7.0.1 (2025-08-02) · Hackage `tmp-postgres` 1.34.1.0 (2019-12-29)

---
*Architecture research for: v6.0 Model Output Store + VolumePath Bridge (rpc_api workstream)*
*Researched: 2026-08-16*
