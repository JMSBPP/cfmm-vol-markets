# Requirements: Milestone v6.0 — Model Output Store + VolumePath Bridge

**Defined:** 2026-08-16
**Core Value:** A target contingent payoff can flow end-to-end — payoff → GAMS solves optimal
parameters → parameters encoded → Plank CFMM simulates — with the two tracks agreeing on one
authoritative type/parameter kernel.
**Source:** GitHub issue #25. Authoritative contract: `model/mev_tax_model_one/VOLUME_PATH.md`.
**Research:** `.planning/research/SUMMARY.md` (2026-08-16).

---

## v6.0 Requirements

### Byte Integrity (BYTE)

The milestone's headline guarantee is that a re-solve reproduces bytes. Everything here
exists because three separate layers were measured silently altering them.

- [ ] **BYTE-01**: The prover's output is stored as `bytea` and returned byte-identical to
      what GAMS emitted — verified against a recorded sha256, not against a parsed document.
- [ ] **BYTE-02**: A `jsonb` projection exists for querying and is **derived** from the
      bytes; no check ever compares `jsonb` to `jsonb` to establish byte identity.
- [ ] **BYTE-03**: The prover's bytes never pass through `Data.Aeson.Value` on the storage
      or publication path (measured: `decode→encode` mutates 4 fields at GHC 9.10.3).
- [ ] **BYTE-04**: `dQx`/`dQM` are decoded as `Integer`, never `Double` (measured: `Double`
      loses 32 wei on the first element, which would execute the wrong swap amounts).
- [ ] **BYTE-05**: A stored artifact round-trips byte-identically through the database — a
      test that fails if any layer normalizes, including `ByteString` sent as text rather
      than via the `Binary` newtype.

### Key Identity (KEY)

- [ ] **KEY-01**: A shock's key is `H(canonical inputs ‖ GAMS version ‖ CONOPT version ‖
      model source digest ‖ solver options digest)`.
- [ ] **KEY-02**: One renderer produces both the `execve` argv and the hash preimage, so the
      key cannot describe an invocation other than the one that ran.
- [ ] **KEY-03**: Inputs are normalized once at the edge (`28e18` → `28000000000000000000`)
      and never re-rendered between uses.
- [ ] **KEY-04**: The preimage is **framed** — field boundaries are unambiguous, so no two
      distinct input tuples can produce the same preimage.
- [ ] **KEY-05**: The pips denominator is part of the preimage, so a future change to it
      cannot silently reinterpret existing keys.
- [ ] **KEY-06**: A missing or unparseable input is an error before hashing — never a
      default that silently becomes part of a key.
- [ ] **KEY-07**: Rows carry a `key_scheme` inside the unique constraint, so a future key
      formula change orphans rows rather than corrupting them.

### Store (STORE)

- [ ] **STORE-01**: An identical shock returns the stored artifact **without invoking the
      solver**.
- [ ] **STORE-02**: Re-solving an existing key and getting different bytes is reported as a
      determinism failure with a non-zero exit.
- [ ] **STORE-03**: On a determinism failure the original is kept and the divergent bytes are
      **quarantined**, not discarded — a mismatch becomes evidence.
- [ ] **STORE-04**: Verification is on demand, not on every cache hit (always-verify defeats
      the elision the store exists for; Nix shipped it and removed it as broken).
- [ ] **STORE-05**: A run can be pinned so retention never removes it.
- [ ] **STORE-06**: Reset is a separate, explicit operation that cannot run as a side effect
      of a solve or publish.
- [ ] **STORE-07**: An append-only run log records `(timestamp, key, event tx, block)` — the
      chronology a content key cannot carry.
- [ ] **STORE-08**: A partial or failed run never becomes a cache entry.

### Database Foundation (DB)

- [ ] **DB-01**: Schema and migrations are applied by an explicit command whose failure —
      including a checksum mismatch — exits non-zero (`postgresql-migration` returns the
      error and still exits 0).
- [ ] **DB-02**: Connection configuration is resolved from the environment with no hardcoded
      credentials, consistent with the existing override convention.
- [ ] **DB-03**: `cabal test` passes with **no database present**, and the tests that cover
      store behaviour still discriminate — they must not skip, pass vacuously, or read
      nothing and report clean.
- [ ] **DB-04**: A Postgres instance can be provisioned for local and CI runs via Docker.

### Solver Invocation (GAMS)

- [ ] **GAMS-01**: The prover is invoked as a subprocess whose success is decided by the
      **exit code**, never by log text.
- [ ] **GAMS-02**: A run that exits 0 without producing the artifact is a failure (GAMS exit
      0 means "GAMS ran", not "the model solved").
- [ ] **GAMS-03**: The GAMS and CONOPT versions are detected and fed into the key; detection
      that finds nothing **fails loudly** rather than yielding an empty string.
- [ ] **GAMS-04**: CONOPT version detection reads the true solver version (`C O N O P T
      version 4.39.0`) and not the adjacent GAMS-side link version or the `.so` filename.
- [ ] **GAMS-05**: A hung solve is bounded by a timeout that terminates the child process.
- [ ] **GAMS-06**: The invocation environment is controlled, so ambient variables cannot
      change what the solver computes.

### Fee Split (FEE)

- [ ] **FEE-01**: Given a pool fee `f` and a target `δ*`, the splitter produces (φ_X, φ_M)
      satisfying `(1−φ_X)(1−φ_M) = 1−f` exactly.
- [ ] **FEE-02**: The pair satisfies the admissibility condition `δ* ≥ 2ρ/(1+ρ²)` where
      `ρ = φ_M/φ_X`, checked **before** the solver is invoked.
- [ ] **FEE-03**: An infeasible request is refused with the reason and the boundary value,
      rather than being discovered as a solver exit code.
- [ ] **FEE-04**: The choice of ρ within the admissible band is reproducible from a recorded
      seed.

### Chain Reads (CHAIN)

- [ ] **CHAIN-01**: The `next` event is decoded from a mined transaction's logs into the
      shock it carries.
- [ ] **CHAIN-02**: Pool price, liquidity and fee are read **pinned to a single block**, not
      at `latest`.
- [ ] **CHAIN-03**: A read that returns an absent, zero or unparseable value is an error, not
      a value that flows into a key.
- [ ] **CHAIN-04**: Decoding is exercised against synthetic logs, so it is testable before
      the upstream event exists and without a chain.

### Loop and Publication (LOOP)

- [ ] **LOOP-01**: The loop discovers new `next` events by polling from a persisted watermark
      (`eth_subscribe` is unavailable and the client is request/response).
- [ ] **LOOP-02**: Seeing the same event twice does not duplicate work or corrupt the store.
- [ ] **LOOP-03**: The newest run is published to the fixture path the forge test reads, by
      atomic rename — a consumer can never observe a partial file.
- [ ] **LOOP-04**: Publication writes exactly one file into the other workstream's tree and
      nothing else.
- [ ] **LOOP-05**: A crash or interrupt mid-cycle leaves the store and the published fixture
      consistent.

---

## Deferred (v7.0+)

| Requirement | Why deferred |
|---|---|
| Numeric-aware diff of divergent artifacts | Byte inequality plus both digests suffices until a mismatch actually happens |
| Garbage collection of unpinned entries | Artifacts are low-KB; its reachability predicate depends on pinning and the run log landing first |
| Single-flight concurrent solves | Assumes one loop; revisit if the loop becomes concurrent |
| A second store tenant (another model) | Layout is model-agnostic from the start; building a second tenant before a second model exists is speculative |

## Out of Scope

| Feature | Reason |
|---|---|
| Changing `VOLUME_PATH.md`'s emitted JSON shape | `model/` is the GAMS workstream's territory; the §3 shape is their contract |
| Implementing `SELECTOR_NEXT`'s event emission | Plank workstream (issue #26) |
| Fixing the test's `shock(...)` signature mismatch | Belongs with issue #26, which owns the alignment |
| Asserting the rig's computed payload (`e5.fee`, σ, accumulators) | Filed as issue #19; different concern from this store |
| `ExceptT` error plumbing over `Web3` | `runWeb3'`'s `Left` is unreachable; it would advertise a guarantee the runtime does not provide |

## Traceability

Filled during roadmap creation.

| Requirement | Phase | Status |
|---|---|---|
| (pending roadmap) | — | Pending |

**Coverage:** 39 v6.0 requirements defined; mapping pending.

---
*Requirements defined: 2026-08-16*
