# Requirements: Milestone v6.0 — Model Output Store + VolumePath Bridge

**Defined:** 2026-08-16
**Core Value:** A target contingent payoff can flow end-to-end — payoff → GAMS solves optimal
parameters → parameters encoded → Plank CFMM simulates — with the two tracks agreeing on one
authoritative type/parameter kernel.
**Source:** GitHub issue #25. Authoritative contract: `model/mev_tax_model_one/VOLUME_PATH.md`.
**Research:** `.planning/research/SUMMARY.md` (2026-08-16).

### Lean4 + Math track (CTX-*)

**Added 2026-08-02 at the Phase-12 close-out.** Phases 8–12 mint their requirement ids as `CTX-*`
tags at planning time, declared in `ROADMAP.md` and in each phase's `CONTEXT.md`. Until now none of
them were declared here, so `requirements mark-complete` was a no-op for every phase in that track.
**Declared for Phases 12, 12.1, 13 and 14; Phases 8–11 remain undeclared (known gap, inherited not resolved).** Phases 8–11's CTX-* ids remain declared solely in
`ROADMAP.md` — recorded rather than silently back-filled, because adopting the full table belongs to
the roadmapper, not to a phase close-out. These are **not** v1 plumbing requirements and are not
counted in the v1 coverage totals below.

- [x] **CTX-CURVDOC**: the curvature specification (Capponi–Jia arXiv:2103.08842v4 §5.1 — Lemma 3, Propositions 5 and 6) transcribed into `VOLATILITY_INSTRUMENTS.md` as blocks E0–E8 over a one-dimensional curvature index, under HEAVY USER APPROVAL and a notation gate — ✓ **SATISFIED** (12-01)
- [x] **CTX-CAPTRANS**: the anchor's curvature layer machine-checked — both Lemma-3 antitonicities, both branch points, branch agreements and continuity — ✓ **SATISFIED** (12-03: `arbLossRatio_strictAntiOn`, `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff`, the branch-agreement lemmas)
- [x] **CTX-INTERIOR**: the interior optimum established, **with no first-order condition** — ✓ **SATISFIED** (12-03: `kphiStar_eq_kphiI`, `kphiStar_mem_Ioo_iff`, `lpExcess_isMaxOn` from the two one-sided strict monotonicities, `lpPayoff_isMaxOn`, `liquidity_freeze_minimal`, `depositEfficiency_isMaxOn`)
- [x] **CTX-ETABRIDGE**: the `κ_φ ↔ η` bridge and the closed-form controller — ✓ **SATISFIED** (12-03: `curvIndex` and its bijection lemmas, `curvIndex_etaStar` as an EQUALITY, the four strict comparative statics, the η-side transport, and T28'a `priceEta_eq_p_eta_half` / `priceEta_eq_P_half`). **NOTE:** the η-identity's FACTOR-SHARE half (T28'b / E8(6)) is OPEN, so the user's η-identity decision is **PARTIALLY discharged**; the requirement as scoped is satisfied, the decision is not closed
- [x] **CTX-DEGEN**: **SATISFIED AS NARROWED** — per the user's binding ruling of 2026-07-31 there is **no literal de-degeneration of the `Θ_φ` program** and none was attempted: `mevMulti` contains no η, no `κ_φ` and no `ϱ_I`, so nothing in the curvature layer moves the Phase-11 objective, and the Phase-11 degeneracy stands exactly where Phase 11 left it. What shipped is the interior optimum in the separate Capponi-anchored model, the η-bridge transport, and the Phase-11 contrast as an honest scope statement (12-03: `eta_no_common_argmax`, `etaStar_coupled_to_fee_corner`). Full de-degeneration needs one objective carrying both a demand-elastic investor and `λ_ARB`; that object exists in neither model and is **OPEN**
- [x] **CTX-REVIEW**: the two-reviewer gate (Reality Checker + a fitted specialist, run blind and in parallel) on every pre-submission spec artifact — ✓ **SATISFIED** (12-01: 3 BLOCKER + 9 MAJOR resolved; 12-02: 2 BLOCKER + 1 MAJOR + 11 MINOR resolved, one BLOCKER being a false sentence in the already-approved, byte-pinned document)
- [x] **CTX-TRACE**: the auditable record — traceability rows with statuses taken from the fidelity record and nowhere else, every named identifier verified to exist, every OPEN item labelled OPEN, plus the doc back-annotation and the plank answer — ✓ **SATISFIED** (12-04)

**Phase 13 (added 2026-08-03).** Four PARALLEL tracks; per-track detail and gates in
`.planning/phases/13-phi-convention-and-kristensen/TRACKS.md`.

- [ ] **CTX-PHIDOC**: the Capponi `F` → `φ` transition closed without false statements — the CES lock, the Angeris canonical form, and the curvature verdict machine-checked, with the doc's notation corrected to match. ◐ **IN FLIGHT** — `PhiCES`/`CanonicalCurve`/`CurvatureTwo` landed axiom-clean and the rename set applied (`601e7ba`, `758e964`, `634ded6`); OPEN: embedding test `232c8ee4` (Aristotle API 500), the E4 optimum redo on the ε axis, the stale `eta-notation-gate.sh`
- [ ] **CTX-IVLEVEL**: Kristensen's implied-volatility LEVEL integrated into the framework — the σ_IV extraction with anchors, the VOL/AMT ↔ `u` relation stated as a provable lemma, and `r_fix` declared as the new parameter it is. ◐ **RESEARCH DONE, GATED** — the user's `2·√` hypothesis REFUTED as a CES specialization (both factors Gaussian); headline is that constant-`AMT_tick` holds exactly iff `ξ = ξ⋆`. Blocked on two rulings: signed-vs-magnitude `ΔQ` (**BLOCKER** — live defect in an already-inserted block) and whether `W` depends on σ

- [ ] **CTX-GREEKS**: the Greeks layer formalized — the `D_p`/`Γ` ladder displays, the θ split, the `Δθ_fee/Δσ` statics and above all the **G4 deficit lemmas** landed axiom-clean, with the structural-deficit result (`(β,γ)`'s column is zero on every shape row, so the free `(β,γ)` provably cannot close the underspecification) PROVED rather than asserted; G2 excluded while E8(6) is open; t-semantics carried into the Lean signatures. ○ **NOT STARTED, NOT BUNDLEABLE** — gated on PR-CARRY (per-event vs time-integrated: decides *what* gets proved) and PR-THETA (the exponent-sign FLAG). The Bunni-v2 LDF port is a declared FUTURE MILESTONE, out of scope
- [ ] **CTX-DEFORDER**: the document's opening re-ordered into the user's specified definitional sequence — formal definition of `θ`, then the streamia assignment, then a named assignment for the time-integrated streamia — with `π^σ` promoted to a numbered DEFINITION and `α₁,α₂ → c₁,c₂`. ⊘ **BLOCKED ON HEAVY USER APPROVAL** — restructures the block every later section depends on

**Phase 15.1 / 15.2 (added 2026-08-10).** Sequenced pair; 15.2 is gated on 15.1.

- [ ] **CTX-ELL**: the trading curve's liquidity established as a **dimensionally consistent, local** object — the intrinsic liquidity `ℓ_(χ,ε)` of Risk–Tung–Wang §2.1 obtained in CLOSED FORM for our family, with the geometric-mean and constant-product limits recovered, degree-1 homogeneity proved, the ρ→1⁻ pole (linear member = infinite depth) stated, and the state-constancy question SETTLED (`ℓ/√(xy)` constant iff ρ=0, so off Cobb–Douglas the liquidity is a field, not a constant). Consequence to be recorded in the document: **Rule 5's `χ ← 1/2` is a CHOICE, not a silent dimensional precondition** — every `L̄`-denominated statement currently depends on it for type validity. ◐ IN FLIGHT (Aristotle `9786b137`)
- [ ] **CTX-HALFKERNEL**: the **half-kernel reduction** proved — the constant-product pool carrying `L ← ℓ_(χ,ε)` reproduces a general member's marginal price and first-order price impact, so every quantity factoring through `(p, dp/dQ_X)` (`𝒟_p[π]`, `Γ`, LVR, the per-strike amounts) is computable on the `(sqrtPriceX96, per-tick L)` machinery on-chain protocols instantiate. The two limits must be stated, not buried: the match is local and second-order (pins `Γ`, not `d²p/dQ_X²`), and a local match is not a global value match. ◐ IN FLIGHT (Aristotle `9786b137`, targets L7a/L7b)
- [ ] **CTX-LDF**: the pinned geometric weight profile replaced by a parametrized liquidity density `ℓ_LDF(θ_LDF; i_K)` with `Σ ℓ_LDF = 1`, closing G4's ladder deficit (`dim θ_LDF ≥ ι − 2`). ○ NOT STARTED — **gated on CTX-ELL**: 15.1 supplies the geometric object an LDF parametrizes.
---

## v6.0 Requirements

### Byte Integrity (BYTE)

The milestone's headline guarantee is that a re-solve reproduces bytes. Everything here
exists because three separate layers were measured silently altering them.

- [x] **BYTE-01**: The prover's output is stored as `bytea` and returned byte-identical to
      what GAMS emitted — verified against a recorded sha256, not against a parsed document.
- [x] **BYTE-02**: A `jsonb` projection exists for querying and is **derived** from the
      bytes; no check ever compares `jsonb` to `jsonb` to establish byte identity.
- [x] **BYTE-03**: The prover's bytes never pass through `Data.Aeson.Value` on the storage
      or publication path (measured: `decode→encode` mutates 4 fields at GHC 9.10.3).
- [x] **BYTE-04**: `dQx`/`dQM` are decoded as `Integer`, never `Double` (measured: `Double`
      loses 32 wei on the first element, which would execute the wrong swap amounts).
- [x] **BYTE-05**: A stored artifact round-trips byte-identically through the database — a
      test that fails if any layer normalizes, including `ByteString` sent as text rather
      than via the `Binary` newtype.

### Key Identity (KEY)

- [x] **KEY-01**: A shock's key is `H(canonical inputs ‖ GAMS version ‖ CONOPT version ‖
      model source digest ‖ solver options digest)`.
- [x] **KEY-02**: One renderer produces both the `execve` argv and the hash preimage, so the
      key cannot describe an invocation other than the one that ran.
- [x] **KEY-03**: Inputs are normalized once at the edge (`28e18` → `28000000000000000000`)
      and never re-rendered between uses.
- [x] **KEY-04**: The preimage is **framed** — field boundaries are unambiguous, so no two
      distinct input tuples can produce the same preimage.
- [x] **KEY-05**: The pips denominator is part of the preimage, so a future change to it
      cannot silently reinterpret existing keys.
- [x] **KEY-06**: A missing or unparseable input is an error before hashing — never a
      default that silently becomes part of a key.
- [x] **KEY-07**: Rows carry a `key_scheme` inside the unique constraint, so a future key
      formula change orphans rows rather than corrupting them.

### Store (STORE)

> **SCOPE CUT 2026-08-17 — user ruling.** v6.0 is the `volume_path` **bridge**, not a
> content-addressed store with research-grade guarantees. Five of these eight requirements are
> **DEFERRED to a later milestone**, not dropped: they remain true things we want, but they are not
> what makes the loop work, and building them was costing more than the bridge itself. The
> deferred set is what plan 25-05 existed for and what most of 25-07/25-08's capture blocks served.
>
> Rationale of record: the verification apparatus had grown larger than the code it verified
> (11,206 test lines against 9,844 library lines), and the trigger-hardening work the phase-25
> database review called for amounts to defending an append-only log against a **superuser on a
> local development Postgres**. That is not this milestone's threat model.

**IN SCOPE for v6.0 — the bridge:**

- [x] **STORE-01**: An identical shock returns the stored artifact **without invoking the
      solver**. *(The critical one — this is the whole point of the store.)*
- [x] **STORE-06**: Reset is a separate, explicit operation that cannot run as a side effect
      of a solve or publish.
- [x] **STORE-08**: A partial or failed run never becomes a cache entry. *(Cache correctness:
      without it, one crashed solve poisons every later run of the same shock.)*

**DEFERRED — revisit after the loop runs end to end:**

- [~] **STORE-02** *(deferred)*: Re-solving an existing key and getting different bytes is reported
      as a determinism failure with a non-zero exit. **Why deferred:** this turns `VOLUME_PATH.md`
      §3's determinism guarantee into a standing falsifiable check — a genuinely valuable research
      property, and one the bridge does not need in order to produce a fixture. It also generates
      the re-solve driver, the quarantine path, and STORE-04.
- [~] **STORE-03** *(deferred)*: On a determinism failure the original is kept and the divergent
      bytes are **quarantined**. **Why deferred:** serves STORE-02 only; nothing consumes a
      quarantine row in the bridge.
- [~] **STORE-04** *(deferred)*: Verification on demand rather than on every cache hit. **Why
      deferred:** serves STORE-02 only. Note the underlying hazard stays recorded — always-verify
      defeats the elision the store exists for, which is why Nix shipped it and removed it.
- [~] **STORE-05** *(deferred)*: A run can be pinned so retention never removes it. **Why
      deferred:** there is no retention sweep in the bridge yet, so pinning has nothing to survive.
- [~] **STORE-07** *(deferred)*: An append-only run log records `(timestamp, key, event tx, block)`.
      **Why deferred:** two of its four fields (`event tx`, `block`) are blocked upstream on Phase 27
      regardless, so it could only ever have closed as PARTIAL in v6.0 — and the append-only
      enforcement it implies is the trigger-hardening work described above.
      **PARTIAL BY CONSTRUCTION at 28-01, AND STILL DEFERRED at the Phase 28 close.** Migration
      `004_loop_ledger.sql` creates `loop_event`, which carries three of the four fields (`key`,
      `tx_hash`+`log_index`, `block`) plus `observed_at`, unique on `(tx_hash, log_index)`, with
      every outcome recorded — `elided`, `stored`, `not_persisted`, `inadmissible`. **What is
      ABSENT is exactly the append-only ENFORCEMENT: there is no trigger, and nothing in this
      repository forbids an `update` or a `delete` on a `loop_event` row.** Nothing issues one
      either — `insert_event_sql` ends `on conflict … do nothing`, first-writer-wins, and the
      memory reference implementation applies the same rule — but "nobody does it" is a fact about
      today's callers and "the server refuses it" is a fact about the schema, and STORE-07 asks for
      the second. The gap is stated in migration `004`'s own header so it is a recorded decision
      rather than something a later reader infers from the absence of a trigger. **A row saying
      STORE-07 is closed because a table exists would be the assertion-without-an-implementing-task
      shape this milestone keeps finding.** The trigger hardening stays deferred with STORE-02..05.

### Database Foundation (DB)

- [x] **DB-01**: Schema and migrations are applied by an explicit command whose failure —
      including a checksum mismatch — exits non-zero (`postgresql-migration` returns the
      error and still exits 0).
- [x] **DB-02**: Connection configuration is resolved from the environment with no hardcoded
      credentials, consistent with the existing override convention.
- [x] **DB-03**: `cabal test` passes with **no database present**, and the tests that cover
      store behaviour still discriminate — they must not skip, pass vacuously, or read
      nothing and report clean.
- [x] **DB-04**: A Postgres instance can be provisioned for local and CI runs via Docker.

### Solver Invocation (GAMS)

- [x] **GAMS-01**: The prover is invoked as a subprocess whose success is decided by the
      **exit code**, never by log text.
- [x] **GAMS-02**: A run that exits 0 without producing the artifact is a failure (GAMS exit
      0 means "GAMS ran", not "the model solved").
- [x] **GAMS-03**: The GAMS and CONOPT versions are detected and fed into the key; detection
      that finds nothing **fails loudly** rather than yielding an empty string.
- [x] **GAMS-04**: CONOPT version detection reads the true solver version (`C O N O P T
      version 4.39.0`) and not the adjacent GAMS-side link version or the `.so` filename.
- [x] **GAMS-05**: A hung solve is bounded by a timeout that terminates the child process.
- [x] **GAMS-06**: The invocation environment is controlled, so ambient variables cannot
      change what the solver computes.

### Fee Split (FEE)

- [x] **FEE-01**: Given a pool fee `f` and a target `δ*`, the splitter produces (φ_X, φ_M)
      whose COMPOSED fee `1−(1−φ_X)(1−φ_M)` reproduces `f` under a **rounding rule pinned in
      writing** (ROADMAP SC-1). Exactness is a DIVISOR problem over the integer pip grid, not a
      rounding problem: `(10⁶−φ_X)(10⁶−φ_M) = 10⁶(10⁶−f)` has a solution only when
      `10⁶ ∣ φ_X·φ_M`, which holds for **4.935 %** of `f ∈ [1, 20000]` — 987 of 20000, recomputed
      2026-08-17 by full factorisation — and for **NONE** of the canonical tiers 100 / 500 / 3000 /
      10000 pips (`exact_pairs_for` is empty at all four; `f = 6497` admits exactly two pairs,
      `(500, 6000)` and its mirror). The splitter therefore rounds the partner leg to NEAREST
      (ties up), records the exact realized fee and the exact residual as first-class fields, marks
      whether the pair is exact, and REFUSES when `|residual| ≥ 1` pip. Nearest rounding bounds the
      residual by `(10⁶−φ_X)/2`, so the one-pip alarm has **2x** headroom, not the 10³ a
      band-minimum reading suggests (MEASURED worst-in-band: 0.4997 pip at `f = 3000`). The
      DERIVED pips — not `f` — are what reach GAMS and the key.
- [x] **FEE-02**: The pair satisfies the prover's own admissibility test, transcribed from
      `volume_path.gms:100-108` and checked **before** the solver is invoked:
      `ellTest = (φ̄² + Δφ²)δ*² − (φ_X+φ_M)·φ̄·δ* + φ_X·φ_M ≤ 0`, where **φ̄ is the COMPOSED fee**
      `1−(1−φ_X)(1−φ_M)` and **Δφ is the FULL gap** `φ_M−φ_X`. Evaluated in exact integer
      arithmetic over pips — never `Double`, never `Rational`. NOTE: an earlier reading of φ̄ as
      the arithmetic mean and Δφ as the ellipse SEMI-axis is WRONG — it yields a bound exactly
      2× too large and falsely refuses ~82,700 pips of admissible δ* at the fixture fees.
- [x] **FEE-03**: An infeasible request is refused with the reason and the boundary value,
      rather than being discovered as a solver exit code.
- [x] **FEE-04**: The choice of ρ within the admissible band is reproducible from a recorded
      seed.

### Chain Reads (CHAIN)

- [ ] **CHAIN-01**: The `Shock` event is decoded from a mined transaction's logs into the
      shock it carries. **TEXT CORRECTED AT PHASE 27 CLOSE (27-03).** It read *"the `next`
      event"*, and `next(address,uint160,int24,uint24,uint24)` is a FUNCTION SELECTOR
      (`0xd3827b0b`) on `AlgebraIntegralShocksWriterInterface.plk` — **never an event.** 26-02
      established this against the merged source and demoted it to a NEGATIVE fixture: a log whose
      topic0 is that selector left-padded is exactly the thing a decoder must refuse. The event is
      `Shock(address indexed pool, int24, uint24, uint24)`, topic0
      `0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`, verified equal to
      `cast keccak` of that signature. Same defect class as FEE-01's "exactly", corrected in 26-04.
      **Still OPEN and BLOCKED** — the correction is to the wording, not to the status.
- [x] **CHAIN-02**: Pool price, liquidity and fee are read **pinned to a single block**, not
      at `latest`.
- [x] **CHAIN-03**: A read that returns an absent, zero or unparseable value is an error, not
      a value that flows into a key.
- [x] **CHAIN-04**: Decoding is exercised against synthetic logs, so it is testable before
      the upstream event exists and without a chain.
- [x] **CHAIN-05**: The published fixture records the pool identity it was solved for — `pool`
      (string address), `blockNumber` (**string**, because it can exceed the 53-bit double-exact
      ceiling) and `chainId` — so the consuming test can ATTACH rather than construct. `token0`/
      `token1` are deliberately NOT recorded: the test reads them from the pool on-chain, keeping
      the pool the single source of truth.
- [x] **CHAIN-06**: Every endpoint consumer resolves `ETH_RPC_URL` if set, else
      `http://127.0.0.1:8545` — the four `*/Rpc.hs` providers, `app/Main.hs`,
      `app/CheatSwapProof.hs`, `deploy-rig.sh` and both `capture-*.sh`. One rule.
      **TEXT CORRECTED AT PHASE 27 CLOSE (27-03): this sentence ended "Nine sites, one rule", and
      the count was wrong three ways.** MEASURED at 27-01: **TEN** by the pattern the sentence
      itself implies — the tenth is `offchain/spec/types.md`, prose inside the grep's blast radius;
      **ELEVEN** counting `offchain/rig/verify-rig.sh`, which makes fourteen `cast` calls against a
      live rig but reached it through foundry's `--rpc-url local` ALIAS, so it named neither token
      and **no pattern built from those two tokens could ever have found it**; and the rule was
      implemented **ZERO** times, not nine — the only occurrence of the variable under `offchain/`
      was a comment. A count in prose is not the durable form: what replaces it is
      `Chain.Endpoint.endpoint_sites`, a manifest checked in BOTH directions against the tree,
      holding **18** entries as of 27-02.
- [x] **CHAIN-07**: The PRODUCER binds the same endpoint as the consumers — `deploy-rig.sh`
      derives anvil's `--host`/`--port` AND the deploy `--rpc-url` from one `ETH_RPC_URL`, and
      asserts `chainid` before any `--broadcast`. A consumer-only resolver does NOT retire the
      desync: `ETH_RPC_URL=…:9545` would otherwise start anvil on 8545 while the test attaches to
      9545, which is the exact divergence issue #29 was opened to prevent.

### Loop and Publication (LOOP)

> **THE FIVE LOOP REQUIREMENTS ARE MARKED COMPLETE FOR THEIR CHAIN-FREE HALVES ONLY, AND THE OTHER
> HALF IS BLOCKED BY NAME.** Every proof below is driven against synthetic logs, `Store.Memory`,
> `new_memory_ledger` and a stub `Solver`, because `cabal test` is chain-free, database-free and
> solver-free by three structural greps with positive controls. That is enough for the requirements
> AS WRITTEN — they are about the watermark, the ledger, the atomic write and the shutdown, and none
> of those needs a chain — and it is **not** the live end-to-end run. The live run is
> `offchain/rig/capture-loop.sh`, which is written, gated exactly as Phase 27 gated its two
> captures, and **HAS NEVER BEEN RUN**: CHAIN-01 is BLOCKED on the plank / mev-migrate workstream,
> **GitHub issue #26**, `SELECTOR_NEXT 0xd3827b0b` — the `Shock` event is emitted from a forge
> TEST, not from a deployable contract another process can drive, and
> `foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol`. **What would
> discharge it: one driver emitting a single `Shock` in a MINED transaction on the resolved
> endpoint. Nothing more, and it is not this workstream's to build.** A second prerequisite is also
> OUTSTANDING: `test/models/mev_tax_model_one/fixtures/` is absent from this worktree AND from
> `origin/develop` (MEASURED at 28-04, both directions, `git ls-tree -r --name-only origin/develop |
> grep -c` = 0 and `find test -path "*mev_tax_model_one*"` empty), owned by the `#24` track and
> requested on issue **#25**. The chain-free proofs and the end-to-end run must not be reported as
> one thing.

- [x] **LOOP-01**: The loop discovers new `next` events by polling from a persisted watermark
      (`eth_subscribe` is unavailable and the client is request/response). *(28-02. Chain-free half
      complete; the live poll is blocked — see the note above.)*
- [x] **LOOP-02**: Seeing the same event twice does not duplicate work or corrupt the store.
      *(28-01 for both directions against the reference implementations, 28-05 for both directions
      over the LOOP itself.)*
- [x] **LOOP-03**: The newest run is published to the fixture path the forge test reads, by
      atomic rename — a consumer can never observe a partial file. *(28-03.)*
- [x] **LOOP-04**: Publication writes exactly one file into the other workstream's tree and
      nothing else. *(28-04, against temporary directories: the real tree is on neither branch.)*
- [x] **LOOP-05**: A crash or interrupt mid-cycle leaves the store and the published fixture
      consistent. *(28-05.)*

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

Filled during roadmap creation (2026-08-16).

| Requirement | Phase | Status |
|---|---|---|
| BYTE-01 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Evidence complete (23-04), assertion owed** — all SEVEN corpus members round-trip byte-identically through the `Binary` path against a real PG 18.4 (`binary_out_sha256 == in_sha256`, seven for seven), and the real 606-byte artifact round-trips to `e7b14f38…07d0d884`, the digest pinned in Haskell source. Recorded in `offchain/rig/store-conformance.json`. What is still owed is a CHECK that reads it — 23-05. Prior verdict: **Partial (23-03)** — the `bytea` columns exist (`model_run.raw`, `model_run.key`, `byte_corpus.raw`) and EVERY parameter reaching one goes through `Binary`: six sites, inspected individually in the summary, including the two in `WHERE` clauses that the plan's "every bytea WRITE parameter" wording did not cover but that are exposed to the identical wart. Reads are deliberately unwrapped — `FromField ByteString` special-cases the `bytea` OID, so the wart is write-only. Byte-exactness itself is UNOBSERVED: the corpus round-trip through a real server is 23-04. |
| BYTE-02 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Evidence complete (23-04), assertion owed** — the exhibit exists and has a LIVE subject: on the real 606-byte shape `doc_text_sha256` is `b50a14b4…a87a16e4` and `raw_out_sha256` is `e7b14f38…07d0d884`, so the `jsonb` round-trip FAILS the sha256 comparison the requirement asks for. The digest comes from `convert_to(doc::text,'UTF8')` — the server's own rendering — never from a json library. 23-05 asserts it, and must redden if the two ever become EQUAL, because equal digests mean the exhibit lost its subject. Prior verdict: **Partial (23-03)** — the "a jsonb projection EXISTS" clause is now SATISFIED and its "derived from the bytes" half is STRUCTURAL: `doc` is written by `convert_from(?, 'UTF8')::jsonb` from the SAME parameter as `raw`, in ONE statement, with the artifact passed twice — there is no second source it could come from and no Haskell code constructs it. Still owed: the exhibit of a `jsonb` round-trip FAILING a sha256 comparison on the real 606-byte shape (23-04). Prior verdict, still standing: **Partial (23-01)** — the "no check compares jsonb to jsonb" clause is DISCHARGED at compile time and OBSERVED firing (`[GHC-39999] No instance for 'Eq DerivedDoc'`, plus `[GHC-01928]` on a converter). The "a jsonb projection EXISTS" clause needs the schema (23-03) and the failing-comparison exhibit (23-04). |
| BYTE-03 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Effectively closed at 23-03, formally signed off with the phase** — `aeson_is_absent_from_the_storage_path` is GREEN over SEVEN files that all exist (`Store/Schema.hs` was added to the list at 23-03 after the self-check found it unlisted for two commits), zero aeson tokens in each, and its scan branch was OBSERVED firing against the REAL `Store/Postgres.hs` rather than against a stub. Prior verdict: **Partial (23-02)** — both guards exist and both were OBSERVED. `aeson_round_trip_mutations_are_re_measured` is GREEN and re-measures three mutations at aeson 2.2.5.0 as pinned VALUES (`0.00318353 -> 3.18353e-3`, `2.8e19 -> 28000000000000000000`, and a key reorder), so a subject that vanished would redden. `aeson_is_absent_from_the_storage_path` is DELIBERATELY RED: it names all six `offchain/lib/Store/*.hs` with no exemptions, and `Store/Postgres.hs` does not exist until 23-03. Its positive control was OBSERVED firing (pattern mutated to match nothing) and its scan branch was OBSERVED catching a seeded aeson import. Complete when 23-03 lands the file and the check goes green — MEASURED with a clean stub: 96/96. |
| BYTE-04 | Phase 24 | Complete |
| BYTE-05 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Evidence complete (23-04), assertion owed, and STRONGER than planned** — driven through a real server, THREE members corrupt SILENTLY on the bare path (`nul` 1→0, `octal-escape` 6→3, `double-backslash` 4→3) and two raise `SqlError`; the plan expected two silent and three loud. **`nul` was retagged from `ServerRejects` to `SilentlyCorrupted` on measurement**: `ToField ByteString` is `Escape`, libpq's escaper takes a C STRING, and a C string ends at its first NUL, so the parameter reaching Postgres is empty — 1 byte in, 0 out, no error. A total truncation is a worse silent corruption than 6→3 and had been filed under the loud behaviour that proves the least. `crlf` and `trailing-newline` round-trip CORRECTLY through the broken path and must never be cited as evidence. Prior verdict: **Pending — NOT satisfied by 23-01.** The requirement is a round-trip *through the database*; 23-01 provisioned and contacted no database. What 23-01 landed is its PRECONDITION: the 7-member corpus with measured behaviour tags, including the `SilentlyCorrupted` `a\101b` that SC-1's own five members cannot produce. Lands at 23-04. **23-02 added the corpus SET lock** (`adversarial_corpus_has_a_silently_corrupted_member`, GREEN), and MEASURED that the behaviour-tag set the plan prescribed does NOT discriminate deleting `octal-escape` — `double-backslash` carries the same tag, so all three classes survive the deletion. The member-NAME set, asserted in both directions, is what caught it. |
| KEY-01 | Phase 25 | **Asserted (25-01)** — `no_key_identity_carries_an_absolute_model_source_path` is GREEN over the eight-component tagged preimage, whose components are the scheme, the model name, the rendered shock, the fixed options, the pip denominator, the GAMS version, the CONOPT version and the model-source (name, digest) pairs. **MEASURED DEVIATION from the plan:** an ordinary absolute path is NOT refused — `Store.Key.relativise` basenames first, so `/var/lib/cfmm-replication/models/volume_path.gms` becomes `volume_path.gms` and only a path with no file name at all is a `Left`. The check therefore asserts BOTH halves: the relativised identity carries only the file name AND the directory string is absent from the preimage bytes, and a path that cannot be basenamed is refused naming the ORIGINAL path. The solver-binary digest is deliberately NOT a component (24-RESEARCH M13: machine-specific across boxes at identical versions) — a decision of record, non-destructive because `KeyScheme` is component one. |
| KEY-02 | Phase 25 | **Asserted (25-01)** — `the_preimage_excludes_every_per_run_token` is GREEN, positive arm first: all seven `render_argv` tokens and both `fixed_model_options` are present in the preimage in their FRAMED form, so the absences below are true of something. Then the six tokens `Gams.Run` adds and the request does not — the timeout wrapper's `-k` flag, the kill delay, the budget, the timeout binary, the absolute solver path and the per-run `curdir=` option — are absent. That last one is the one that matters: the per-run directory is a different path on every invocation by design, and a preimage carrying it reconstructs the argv perfectly while giving a cache hit rate of exactly zero with nothing red anywhere. Absence is asserted on the framed form, so the numeric tokens are a claim about a component and not about which digits happen to occur inside a digest. OBSERVED reddening: seeding a legitimately-present token (`lo=2`) into the forbidden list took the check to `FAIL`, 155/157. |
| KEY-03 | Phase 25 | **Asserted (25-01)** — `edge_normalization_is_single_pass` is GREEN: `28e18` and `28000000000000000000` parse to one value at the edge and produce one `ContentKey`. Two arms keep that from being green about nothing — a DIFFERENT shock value must key differently (a key function returning a constant satisfies the equality on its own), and the key must be 32 bytes (`Store.Key.digest_bytes` DROPS a non-hex byte rather than substituting a zero, so a damaged digest comes out short instead of plausible). The argv-layer twin `argv_rendering_is_canonical_and_total` already settles the same pair upstream of any row. |
| KEY-04 | Phase 25 | **Asserted (25-01)** — `framing_separates_what_concatenation_conflates` is GREEN on `[("a","bcd"),("e","f")]` against `[("ab","cd"),("e","f")]`. The FIRST arm asserts the two lists are byte-identical concatenated bare (`abcdef` both ways) — without it the check would pass with the framer deleted, which is exactly what a pair built from fixed-length digests would do. The second asserts `frames` separates them; the third carries it to `key_preimage`, so the claim is about the real preimage and not only about the helper. 25-RESEARCH M1 measured 30 collisions in 343 bare-concatenated shock tuples, and `source_frames` frames a source's name and its digest SEPARATELY for the same reason one level down. |
| KEY-05 | Phase 25 | **Asserted (25-01)** — `the_pips_denominator_is_in_the_preimage` is GREEN: `ki_pips_denom` at `pips_denominator` and at `pips_denominator + 1` give different preimage bytes, so a change to the denominator ORPHANS rows rather than reinterpreting them in place. The constant is IMPORTED from `Store.Key` and never transcribed into the suite — a transcribed copy keeps agreeing with itself after the library moves, which is the failure this asserts against. The check also pins that `key_identity` is where the constant enters an identity. |
| KEY-06 | Phase 25 | **Asserted (25-01)** — `key_identity_refuses_an_absent_conopt_version` is GREEN: `ti_conopt_version = Nothing` is `Left ConoptVersionAbsent`, never an empty string and never a placeholder. Phase 24 built a version type that cannot be constructed empty and then wrapped it in a `Maybe`; `Nothing` reaching the preimage is that hole one constructor up, and rows written under an emptied version component are indistinguishable from good ones afterwards because the emptied component IS the evidence. The fixture asserts `ti_conopt_version` is actually `Nothing` before testing, and a refusal for any OTHER reason is a failure. The range half is inherited structurally: `key_preimage` calls `render_argv` and REFUSES BEFORE HASHING for all eight of its value refusals. |
| KEY-07 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Evidence complete (23-04), assertion owed** — `live_identity_constraint_columns` has now been RUN, against a real catalogue, and reports exactly `["model","key_scheme","key"]`. That is the half 23-03 could not reach: a DDL file that was never applied and a catalogue that drifted are different failures, and this one says the file WAS applied. Both KEY-07 laws also pass against real SQL. Prior verdict: **Partial (23-03)** — the constraint now names all THREE columns in the DDL (`constraint model_run_identity unique (model, key_scheme, key)`) AND in Haskell (`Store.Schema.identity_constraint_columns`), asserted as two subjects because they drift; the FILE half was OBSERVED reddening when `key_scheme` was dropped from the DDL with the constant left alone. `live_identity_constraint_columns` exists and reads the catalogue with `with ordinality` but has NEVER BEEN RUN — the live half is 23-04's capture and 23-05's assertion. Prior verdict: **Partial (23-02)** — the orphaning property is now an EXECUTING law rather than a comment: `law_key_scheme_orphans_rather_than_matching` and `law_same_key_under_a_new_scheme_inserts` run against `Store.Memory` inside `cabal test` with no socket, and BOTH were OBSERVED firing against a store keyed on `(model, key)` alone. The requirement's own subject — `key_scheme` inside a Postgres UNIQUE CONSTRAINT — is schema, and lands at 23-03; the live-catalogue assertion lands at 23-04. |
| STORE-01 | Phase 25 | **COMPLETE (25-02)** — `an_identical_shock_elides_the_solve` and `a_miss_invokes_the_solver_exactly_once` are GREEN. `Store.Cache.decide` looks the key up BEFORE the solver is reachable; the solver is entered only from the branch where the lookup returned `Nothing`. BOTH instruments are read and neither is sufficient alone: the returned bytes are the STORED artifact B and not the solver's B′ (a counter alone passes for a solver that ran and was ignored, which costs a full solve per request while every byte claim stays true), AND the test solver's own invocation counter is 0 (a value alone passes for a solver that ran and happened to agree, which is what a correct solver DOES on a repeat shock). B ≠ B′ is asserted first, without which both claims hold of a cache that elides nothing. The miss side adds three arms that make the pair a cache rather than two facts: the second identical request elides, the counter is still 1, and the store holds ONE entry — a key carrying a per-run value writes under a key no lookup recomputes, and every assertion above it stays green. OBSERVED reddening, throwaway: `decide` solving before the lookup gave `FAIL … the solver was invoked 1 times on a shock whose key was already stored` (156/159) with the VALUE arm still green; `decide` returning the solver's bytes on a hit gave `FAIL … expected Elided with the STORED bytes` (156/159). **SCOPE GAP, recorded (reviewer M3):** nothing in this repository builds a production `Solver` from `Gams.Run.run_prover`, so this is proven at the seam and not end to end. That adapter is the bridge phase's. |
| STORE-02 | — | **Deferred to a later milestone** (scope cut 2026-08-17) |
| STORE-03 | — | **Deferred to a later milestone** (scope cut 2026-08-17) |
| STORE-04 | — | **Deferred to a later milestone** (scope cut 2026-08-17) |
| STORE-05 | — | **Deferred to a later milestone** (scope cut 2026-08-17) |
| STORE-06 | Phase 25 | **COMPLETE (25-03)** — discharged by a TYPE and a SOURCE SCAN, in that order. `Store.Class.store_reset :: ResetScope -> IO ()` means there is no `store_reset store` that type-checks: a caller has to name, at the call site and in the source, which part of the store it means to empty, so the operation cannot be written down by accident. `reset_empties_the_store_and_is_scoped` seeds TWO entries under DIFFERENT keys (asserted different — first-writer-wins would make identical triples one entry, and a store removing a single row would satisfy everything below), asserts both PRESENT before the emptying (absence is the pass condition, and a seed that never landed satisfies it — the keyed put RAISES on a non-json artifact), then asserts both absent after `reset ModelRunOnly`, then asserts a seeded BLOB **survives** — which is what stops `ResetScope` being decoration, since the blob table holds the adversarial corpus BYTE-05 rests on. `no_solve_path_names_the_reset_entry_point` reads `offchain/lib/Store/Cache.hs` and asserts the case-folded token `reset` does not occur in it; it asserts FIRST that the file exists and that it names `decide`, `store_put` and `store_lookup` — fields of the same record reached through the same `Store (..)` import — so the absence is a fact about one identifier rather than about a scan reading nothing. **RENAMED from the plan's `reset_is_unreachable_from_a_solve_or_a_publish` on measurement:** there is no publish path in this tree (`grep -rn 'publish\|Publish' offchain/lib offchain/app --include=*.hs` returns nothing) and the field is NOT unreachable — it is in scope wherever `Store (..)` is imported, and a typeclass would have the identical property. **STORE-05 is deferred, so neither implementation carries a `pinned` predicate and neither carries a `where not pinned` clause**: a filter that never excludes anything reads, to a later auditor, exactly like a retention policy being honoured. `Store.Postgres.store_reset` (`delete from model_run`, via `execute_`) is NOT exercised by any check — `cabal test` is server-free by construction (DB-03) and the in-suite subject is `Store.Memory`. It takes no parameters, so it carries neither the DB-B2 `Binary` hazard nor a DB-M4 placeholder to transpose, but "it compiles" is the whole of the evidence and the module haddock says so. |
| STORE-07 | — | **Deferred to a later milestone** (scope cut 2026-08-17). **PARTIAL BY CONSTRUCTION at 28-01, and it is NOT closed by it.** Migration `004_loop_ledger.sql` creates `loop_event`, which carries three of STORE-07's four fields (`key`, `tx_hash`+`log_index`, `block`) plus `observed_at`, unique on the event position, with every outcome recorded — `elided`, `stored`, `not_persisted`, `inadmissible`. What it does NOT carry is the APPEND-ONLY ENFORCEMENT the requirement implies: nothing in this repository updates or deletes a `loop_event` row, and there is no trigger that says so. That gap is stated in the migration's own header so it is a recorded decision rather than something a later reader infers from the absence of a trigger. The trigger hardening stays deferred with STORE-02..05. |
| STORE-08 | Phase 25 | **COMPLETE (25-02)** — `an_aborted_run_produces_no_cache_entry` is GREEN over three abort shapes, each driven against a FRESH `Store.Memory`: a non-zero exit (`ExitVerdict (classify_exit (ExitFailure 3))`), the budget expiring (code 124 — the timeout WRAPPER's code, which `gams_code_domain` deliberately excludes from GAMS's own domain, so it is a distinct shape and not a re-spelling), and exit 0 with no artifact (`NoArtifact` — MEASURED with the real binary, `action=c` is exactly that). The verdicts are computed by the library's own taxonomy rather than transcribed, so a constructor renamed in `Gams.Exit` does not keep agreeing with a copy in the suite. **A `Produced` POSITIVE CONTROL is ordered FIRST inside the same check** and must leave `entries == 1` AND be findable under the triple `decide` computed — absence is the pass condition here, which is the shape that passes vacuously most often, and a store that never worked satisfies "the store is empty" for all three variants and every variant anyone adds later. Both instruments, not one: the count catches a put that landed under some OTHER key, which is what a per-run value inside the key produces and which a lookup under the computed key reports as a clean absence. `decide` returns `NotPersisted why code` and writes nothing — an entry for an aborted run serves the ABSENCE of a solve to every later request for that shock, permanently and silently, while the store's reads all look healthy. |
| DB-01 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Evidence complete (23-04), assertion owed** — all four server-requiring clauses are now VALUES in the committed artifact: a corrupted checksum makes the runner exit **1** (`checksum_drift_exit`, from a real subprocess; the library's own in-process result is `MigrationError` with the process still alive, recorded as `checksum_drift_exit_without_guard 0`); two runs from a database created moments ago succeed and the second applies **0**; and a second migrator, while the first holds `pg_advisory_lock(872304)`, gets **`f`** and applies **0** — then, after release, gets **`t`** and applies **1** of a directory carrying a third migration, which is the positive control without which "applied 0" is satisfied by a migrator that could never apply anything. NOTE for 23-05: the drift stderr is `migration FAILED: 001_model_run.sql` — a FILENAME — so nothing may assert on that text. Prior verdict: **Partial (23-03)** — `run_migrations_or_exit` exists, holds `pg_advisory_lock(872304)` (which `postgresql-migration` 0.2.1.8 does NOT provide — zero `advisory` hits, re-grepped) and calls `exitFailure` on `MigrationError` (which the library does NOT do — it exits 0). The manifest is ordered, gapless and locked as a SET in both directions over the directory's WHOLE contents, with two arms OBSERVED firing. But every DB-01 clause that matters is an observation against a SERVER — exit code 1 on drift, the second migrator applying 0, two runs from an empty database — and NONE was made: this plan contacted no database. 23-04. |
| DB-02 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Partial (23-01)** — `PGSTORE_DSN`/`STORE_CONFORMANCE` resolve via `lookupEnv` in the `Rig.Manifest` idiom with **zero** credential literals (grep-verified, prose included). Not complete until both are registered in `advertised_overrides` and OBSERVED honoured (23-05); this repo has measured three advertised-and-dead overrides. |
| DB-03 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Partial (23-02) — and the "passes" half is RED BY DESIGN right now.** The "still discriminate" half is DELIVERED and measured: `store_laws_run_against_the_memory_store` really executes all seven store laws against a fresh `Store.Memory` per law, and every law was OBSERVED firing against a named wrong store. "No database present" is satisfied STRUCTURALLY — `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` = 0, so no socket and no branch to misconfigure. But `cabal test` does NOT currently pass (2 red: `aeson_is_absent_from_the_storage_path` and, consequently, `sentinel_falsification_harness`), so the requirement as written is NOT met until 23-03. |
| DB-04 | Phase 23 | **CLOSED (23-05) — phase verified 9/9, 111/111 checks, suite DB-free.** Prior: **Partial (23-04)** — `offchain/rig/capture-store-conformance.sh` provisions Postgres via Docker for local runs: `postgres:18-alpine` on host port **55433** (deliberately NOT 5432 — another project's Postgres is bound to `0.0.0.0:5432` on this machine, so the default would let a foreign database silently satisfy the connection), a per-run database, a bounded readiness poll, and teardown on every exit path including SIGINT. Cold run **4–8 s**. The artifact records BOTH sides of the pin: `image_tag` (`postgres:18-alpine`, what was asked for) and `server_version` (`18.4`, what replied). Still owed: the CI half of "local and CI" — that is the CI track's coordination item, not this workstream's, and no `.github/` file was touched. No check compares the two recorded fields yet (23-05). |
| GAMS-01 | Phase 24 | Complete |
| GAMS-02 | Phase 24 | Complete |
| GAMS-03 | Phase 24 | Complete |
| GAMS-04 | Phase 24 | Complete |
| GAMS-05 | Phase 24 | Complete |
| GAMS-06 | Phase 24 | Complete |
| FEE-01 | Phase 26 | Complete |
| FEE-02 | Phase 26 | Complete |
| FEE-03 | Phase 26 | Complete |
| FEE-04 | Phase 26 | Complete |
| CHAIN-01 | Phase 27 | **BLOCKED, and named as such at phase close (27-03).** Dependency: the plank / mev-migrate workstream, issue #26 — `SELECTOR_NEXT 0xd3827b0b`. There is no deploy script for the Shock writer (`foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol`) and the event is emitted from a forge **test**, not from a deployable contract another process can drive. **Not this workstream's to build.** What would discharge it: one driver that emits a single `Shock` in a MINED transaction on the resolved endpoint. Everything on this side is ready — `Chain.Shock` decodes it (CHAIN-04, 12 checks, 21-member corpus) and `Chain.Read` pins the reads to its block. |
| CHAIN-02 | Phase 27 | Complete (27-02) — **and it was never blocked.** 27-CONTEXT measured that only CHAIN-01 depends on the upstream `next` emitter; a pinned read needs a POOL, and `deploy-rig.sh` has stood one up since 22-03. The "Blocked" this row carried was inherited from CHAIN-01's row, not measured. Evidence: `offchain/rig/chain-read-conformance.json`, in which a read pinned at block 13 returns tick −1 while the unpinned read returns the tick 5000 the state change wrote. |
| CHAIN-03 | Phase 27 | Complete (27-02) — same correction as CHAIN-02: never blocked. The rule is a PURE total function of the field, where the read was made and what the transport handed back, so it is driven at arguments no chain will produce on demand (a truncated word, a non-hex character, an absent answer). Twelve refusals across five diagnoses and four acceptances; every refusal names its field DELIMITED, because `liquidity` is a strict prefix of v4's real `liquidityNet`. |
| CHAIN-04 | Phase 26 | Complete |
| CHAIN-05 | Phase 27 | Complete (27-03) — the fixture publishes `pool` (string address), `blockNumber` (**string**) and `chainId` (number), exactly the contract issue #29 handed back at plank `f713089`. `token0`/`token1` deliberately absent: the consuming test reads them from the pool. The string choice is OBSERVED, not asserted — `9007199254740993` through a JSON number decoded into the 53-bit carrier comes back `9007199254740992`, short by exactly 1 and equal to BYTE-04's own image of that integer. **The pool is SYNTHETIC** (`decode_shock` of a corpus member), because CHAIN-01's emitter is blocked; the height and chain id are `block_b` and `chainId` out of the committed capture. |
| CHAIN-06 | Phase 27 | Complete (27-01) — **but its text says "Nine sites" and that is wrong three ways.** MEASURED: TEN by its own pattern (`offchain/spec/types.md` is the tenth); ELEVEN counting `offchain/rig/verify-rig.sh`, which reached the chain through foundry's `--rpc-url local` alias and so named neither token, making it invisible to any pattern built from them; and the rule was implemented ZERO times, not nine. **Correct this text at phase close**, with CHAIN-01's stale `next`-event wording. |
| CHAIN-07 | Phase 27 | Complete (27-01) — `deploy-rig.sh` binds anvil's `--host`/`--port` and every `--rpc-url` to one reading of `ETH_RPC_URL`, and asserts `cast chain-id` before the first `--broadcast`. The alias could NOT be the mechanism: `foundry.toml:59` pins it to the default and is outside this workstream's territory. |
| LOOP-01 | Phase 28 | **Complete (28-02) — and the "Blocked" attribution was INHERITED, not measured**, the third time on this branch after CHAIN-02/03. The watermark is a ROW IN THE STORE (`loop_watermark`, migration 004), not an `IORef` and not a file, and `run_loop` re-reads it from the ledger on every pass. The restart is PROVEN the only way it can be: `a_restart_resumes_at_the_watermark_and_skips_nothing` drains a head of 5, then -- WITH NO LOOP RUNNING -- adds events at blocks 6 and 7 and raises the head to 8, then builds a SECOND `Env` over the SAME store and ledger and asserts the down-time rows landed, the watermark reads 8, and the EARLY events did not gain a second row (which is what tells resuming apart from starting over). The down-time events are asserted to EXIST in the source first. FIRING INPUT OBSERVED: `next_range` starting from the head when a watermark is present reddens at *"Row counts [0,0] for the events at blocks [6,7]"*. Ranges are CLOSED `[b, b]`, asserted on the CALLS the iteration made (`[(0,0),(1,1),(2,2),(3,3),(4,4)]`), and a quiet block still advances the watermark. **WHAT IS NOT COVERED:** the LIVE path. `eth_getLogs` against a real node is exercised only by `offchain/app/LoopMain.hs`, which stops at the chain-surface precondition because the rig manifest names no emitter -- CHAIN-01, issue #26. The requirement is about the WATERMARK and the RESUME, and neither needs a chain; a Tier-C capture of the live poll belongs with the plan that has one. |
| LOOP-02 | Phase 28 | **In progress (28-01) — and the "Blocked" attribution was INHERITED, not measured.** Both of LOOP-02's directions are now asserted CHAIN-FREE, against `Store.Memory` + `new_memory_ledger` + a counting stub solver: `the_same_event_twice_produces_one_row_and_no_second_solve` (one row, one solve, one store entry, with the first pass asserted to have happened BEFORE any absence is read) and `two_distinct_events_with_one_shock_make_one_entry_and_two_rows` (two rows, ONE entry, ONE solve, tokens `stored` then `elided`). Neither needs an emitter — the requirement is about the ledger and the key, not about the chain — which is the same correction 27 made for CHAIN-02/03, whose Blocked status came from CHAIN-01's row rather than from a measurement. **CLOSED AT 28-05, OVER THE LOOP.** 28-01's two directions were asserted against the reference implementations through a pipeline the SUITE composed; the requirement is stated over `Loop.Run`, and both directions are now asserted there. Replay: the stage battery's re-run arm drives `run_loop` a second time over the SAME block on the SAME ledger and the row count stays at exactly one, with the row's `(event, block, key)` unchanged — the same event twice, one row, no re-keying. Distinct-events-one-shock: `a_cache_hit_publishes_at_the_events_own_block` already stages exactly that subject (two positions at DIFFERENT heights whose `split_for` answers agree, FOUND by search rather than written down, and CONFIRMED through the full `split_for` the loop itself calls), and it now reads BOTH instruments — `[1, 1]` ledger rows and `1` store entry, through a counting store — because neither is sufficient alone: the entry count catches a ledger keyed on the content key, the row counts catch a store keyed on the event position. The arms were added to that check rather than to a new one, so the suite total did not move for a property its instruments already had staged. **MEASURED FINDING (28-01 M1):** dropping the `ledger_seen` guard does NOT cost a second solve — the content key still elides it — so the ledger guard and the content key are not two spellings of one mechanism, and what the guard buys is the pipeline doing NOTHING on a replay. **WHAT IS NOT PROVEN:** the live path; CHAIN-01, issue #26. |
| LOOP-03 | Phase 28 | **Complete (28-03) — and the "Blocked" attribution was INHERITED, not measured**, the fourth time on this branch after CHAIN-02/03 and LOOP-01. The headline is MEASURED on both arms by the SAME reader against the SAME two documents of DIFFERENT lengths, with the harness parameterised by the WRITER so the arms differ in exactly one expression: `publish_fixture` gave **142,623 publications / 204,555 completed reads / 0 unparseable** over ten seconds, and the same harness with no temp file and no rename gave **6,079 / 1,333,592 / 1,240,687 — 93.0% torn**. Both checks order the "did the race actually run" arm (floor 100 on both counters) FIRST. Every read is classified by this repository's own `Store.Json.is_json_value` PLUS a `decode_artifact` of the artifact under the identity, because a tear between two documents of different lengths can leave valid JSON that is not a valid artifact. The shape floor refuses on six named shapes and ADMITS the committed golden, with `fixture_min_bytes < volume_path_golden_bytes_len` asserted BEFORE anything is driven. The splice is TEXTUAL and byte-identity is asserted against the golden itself, never against a re-serialisation. A cache HIT publishes, stamped with the EVENT's block, with the artifact bytes byte-identical to the first publication's. FIVE FIRING INPUTS OBSERVED, all baselines `sha256sum -c` clean; M1 left the control GREEN, M3 also reddened three structural guards, M5 six. **WHAT IS NOT COVERED:** LOOP-04's before/after tree diff and the missing-directory PRECONDITION text belong to 28-04; the LIVE publication path is `offchain/app/LoopMain.hs`, which stops at the chain-surface precondition (CHAIN-01, issue #26). The requirement is about the ATOMIC WRITE and the SHAPE, and neither needs a chain. |
| LOOP-04 | Phase 28 | **Complete (28-04) for its chain-free half; the LIVE half is BLOCKED, on the `#24` track landing the directory (issue #25) — and the "Blocked" this row used to carry was INHERITED, not measured**, the fifth time on this branch after CHAIN-02/03, LOOP-01 and LOOP-03. "Exactly one file" is settled by a BEFORE/AFTER TREE DIFF over a directory seeded with two decoys plus one in the PARENT, not by reading `Loop.Publish`: `added = ["volume_path.json"]`, `removed = []`, the decoys' BYTES unchanged (read back, not merely their names), no `*.tmp` surviving, and the parent gaining only `fixtures/volume_path.json` — across TWO publications of different bytes (264 and 296), because a temp sibling that survives the first write is invisible until the second collides with it. The "before-set is non-empty" arm is ordered FIRST. The missing-directory refusal is `Loop.Publish.publish_precondition`, carrying the RESOLVED path, the owning workstream (`mev_tax_model_one`, issues **#24 AND #25**), the refusal to create it and the repair in ONE sentence; `LoopMain` calls it at STARTUP, before the first poll, exiting **40** — a loop that discovered this on its first EVENT has already advanced a watermark past blocks it could not publish for. Nothing in the module can make a directory and the property is STRUCTURAL: the `System.Directory` import list carries the two questions and no maker. `Loop.Config.default_fixture_path` is pinned BYTE-EQUAL to the consumer's own `VOLUME_PATH_JSON` read live out of `origin/develop` through `git show`, with the extraction asserted to have found exactly ONE non-empty literal FIRST. FIRING INPUTS OBSERVED: M2 (the precondition creates the directory and still refuses) reddened the after-state arm ALONE; M3 (one character out of `default_fixture_dir`) was caught by TWO checks with different diagnoses; M4 (`mkdir -p` the real directory) reddened the worktree arm. **WHAT IS NOT PROVEN:** every publication above happens into a TEMPORARY directory, because `test/models/mev_tax_model_one/fixtures/` is on neither tree. `the_fixtures_directory_is_recorded_absent_from_both_trees` is the standing record and it goes RED the day the `#24` track lands the directory — at which point LOOP-04 must be re-stated against the real tree and that check RETIRED rather than weakened. |
| LOOP-05 | Phase 28 | **Complete (28-05) for its chain-free half; the LIVE half is BLOCKED on CHAIN-01 / issue #26.** THE WORD IS *EACH*, and the battery is what says so: `an_exception_at_each_stage_leaves_the_watermark_unadvanced` drives `run_loop` — not `process_block`, because four of the seven stages are components the iteration does not wrap and driving it directly would measure the wrong composition — over SEVEN stages broken from OUTSIDE the function (`source_logs`, `ledger_seen`, `source_reads`, `solver_run`, `env_read_identity`, the publish write, `ledger_commit_block`). Its PREMISE arm is ordered first: a clean pass over the same block must leave one row, one store entry and a watermark, or every "nothing was written" arm is satisfied by a pipeline that writes nothing ever. `an_interrupt_is_observed_only_at_a_block_boundary` sets the flag from inside `source_logs` WHILE IT SERVES BLOCK 2 — the earliest moment inside that block's work — over a block carrying TWO events, and asserts both of block 2's rows AND its watermark landed, block 3 was never entered, and `run_loop` returned `Right ()`. `the_published_fixture_survives_an_interrupted_iteration` breaks the stage AFTER publication, so bytes reach disk and the iteration is then abandoned, and asserts the document parses as JSON AND as an artifact, carries the ten golden fields and issue #29's three identity fields, leaves no `*.tmp`, and is byte-identical to the run the LAST COMPLETED block's ledger row is keyed to — looked up under that row's OWN key, never one the check recomputed. FIRING INPUTS OBSERVED: hoisting the commit ahead of the event loop → **228/231**, caught by TWO checks with different diagnoses (*"STAGE seen: THE WATERMARK READS Just 0 … must be UNCHANGED at Nothing"* and *"the watermark reads Just 29, expected Just 5"*); reading the flag between EVENTS → **229/231**, *"Row counts by block: [(1,1),(2,0),(2,0),(3,0)]"*; leaving the temp sibling behind → **228/231**, caught by this check AND 28-04's tree diff. **TWO THINGS ARE MEASURED RATHER THAN ASSUMED AND BOTH ARE RECORDED AS DISPOSITIONS IN THE BATTERY'S OWN DATA:** the PUBLISH stage does NOT abandon the block (28-03 wrapped the write in `try` deliberately — a full disk is not a reason to stop processing the chain), and the store legitimately HOLDS an entry for the three stages that throw after the solve, because `decide` writes it and that write is content-keyed. What is uniform, and what the requirement asks, is that a clean pass over the same block reproduces the row under the SAME content key. **WHAT IS NOT PROVEN:** no real `SIGINT` was ever delivered. The handler is `offchain/app/LoopMain.hs`'s (`installHandler sigINT`/`sigTERM`, `Catch`, writing one `IORef Bool` and doing nothing else) and it is reachable only from the executable, which stops at the chain-surface precondition — CHAIN-01, issue #26. What the suite drives is the FLAG, which is the half the loop owns. |

**Coverage:** 46 v6.0 requirements defined; **46/46 mapped** to exactly one phase each — no
orphans, no duplicates.

**Count correction (2026-08-16):** this file previously stated *"39 v6.0 requirements defined"*
in both the header and here. The actual checkbox count is **43** — BYTE 5, KEY 7, STORE 8, DB 4,
GAMS 6, FEE 4, CHAIN 4, LOOP 5. The figure is corrected rather than reconciled by dropping four
requirements; no requirement was added or removed at roadmap time.

| Phase | Requirements | Count | Blocked? |
|---|---|---|---|
| 23 — Postgres Foundation & the Byte-Exact Schema | DB-01..04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07 | 9 | No |
| 24 — GAMS Invocation & Toolchain Identity | GAMS-01..06, BYTE-04 | 7 | No |
| 25 — The Content Key & Keyed Store | KEY-01..06, STORE-01, STORE-06, STORE-08 | 9 | No |
| 26 — Shock Assembly (Fee Split & Event Decode) | FEE-01..04, CHAIN-04 | 5 | No |
| 27 — Anvil Read Layer | CHAIN-01, CHAIN-02, CHAIN-03 | 3 | **Yes** — plank worktree must emit `Shock` in a mined transaction (issue #26). Only CHAIN-01 was ever blocked; CHAIN-02/03 shipped at 27-02. |
| 28 — Resident Loop & Fixture Publication | LOOP-01..05 | 5 | **5/5 chain-free; the LIVE half of all five is blocked.** Two distinct blocks, both external: issue **#26** (no deployable `Shock` emitter, CHAIN-01) and issues **#24/#25** (the publication directory is on neither tree). Neither is this workstream's to build. `offchain/rig/capture-loop.sh` is the run that would discharge the first half of it, written and gated and UNRUN. |

**Two ordering corrections applied at roadmap time**, both from research, both changing which
phase a requirement lands in relative to the six approved in brainstorm:

1. **GAMS-03/GAMS-04 precede STORE-01.** The key contains the GAMS and CONOPT versions
   (KEY-01), so version detection is a *prerequisite* of the store's first production write, not
   a later phase. The GAMS phase therefore sits at position 2, ahead of the store.
2. **BYTE-01/02/05 and KEY-07 land in the earliest schema phase (23), not with the store.**
   They are schema decisions — `bytea` authoritative, `jsonb` derived, the `Binary` newtype, and
   `key_scheme` inside the unique constraint — that every later phase consumes and each is
   expensive to retrofit.

Additionally, **CHAIN-04 is mapped to Phase 26, not to the (blocked) Anvil phase**: decoding is
exercised against synthetic logs, so it is buildable with no chain and no upstream. Only
CHAIN-01/02/03 are blocked.

---
*Requirements defined: 2026-08-16 · Traceability filled: 2026-08-16*

---

## Merged from origin/develop on 2026-08-23 (other tracks' conflicting segments, kept verbatim)

Resolution rule: `.planning/` is shared by several tracks with disjoint phase ranges. The rpc_api v6.0 state is kept as the live frontmatter/position; every develop-side segment that conflicted is preserved below unedited so no other track's record is lost.

### develop segment 1 of 1

|-------------|-------|--------|
| REPO-01 | Phase 1 | Pending |
| REPO-02 | Phase 1 | Pending |
| REPO-03 | Phase 1 | Pending |
| REPO-04 | Phase 1 | Complete |
| REPO-05 | Phase 1 | Complete |
| GAMS-01 | Phase 2 | ✓ Complete (pre-done — vendored to model/) |
| KERN-01 | Phase 2 | Pending |
| KERN-02 | Phase 2 | Pending |
| KERN-03 | Phase 2 | Pending |
| TOOL-01 | Phase 2 | Pending |
| TOOL-02 | Phase 2 | Pending |
| MAP-01 | Phase 3 | Pending |
| MAP-02 | Phase 3 | Pending |
| MAP-03 | Phase 3 | Pending |
| MAP-04 | Phase 3 | Pending |
| MAP-05 | Phase 3 | Pending |
| MAP-06 | Phase 3 | Pending |
| REF-01 | Phase 3 | Pending |
| REF-02 | Phase 3 | Pending |
| PLNK-01 | Phase 4 | Pending |
| PLNK-02 | Phase 4 | Pending |
| PLNK-03 | Phase 4 | Pending |
| PLNK-04 | Phase 4 | Pending |
| GAMS-02 | Phase 5 | Pending |
| BRDG-01 | Phase 6 | Pending |
| BRDG-02 | Phase 6 | Pending |
| BRDG-03 | Phase 6 | Pending |
| BRDG-04 | Phase 6 | Pending |
| PIPE-01 | Phase 7 | Pending |
| PIPE-02 | Phase 7 | Pending |
| CTX-CURVDOC | Phase 12 | ✓ Complete |
| CTX-CAPTRANS | Phase 12 | ✓ Complete |
| CTX-INTERIOR | Phase 12 | ✓ Complete |
| CTX-ETABRIDGE | Phase 12 | ✓ Complete |
| CTX-DEGEN | Phase 12 | ✓ Complete **AS NARROWED** (user ruling 2026-07-31 — no literal de-degeneration of the `Θ_φ` program) |
| CTX-REVIEW | Phase 12 | ✓ Complete |
| CTX-TRACE | Phase 12 | ✓ Complete |
| CTX-PHIDOC | Phase 13 | ◐ In flight |
| CTX-IVLEVEL | Phase 14 | ◐ Research done, gated |
| CTX-GREEKS | Phase 15 | ○ Not started, gated |
| CTX-DEFORDER | Phase 12.1 | ⊘ Blocked (approval + θ FLAG) |

> **Status glyphs:** `✓` complete · `◐` in flight or partially discharged · `⊘` blocked, nothing may start. Phase-12 rows use word statuses with a prose qualifier; both conventions are in force.

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30 ✓
- Unmapped: 0
- Lean4 + Math track: 11 `CTX-*` ids declared — 7 Phase-12 complete, 4 open (CTX-PHIDOC, CTX-IVLEVEL, CTX-GREEKS, CTX-DEFORDER); the `T_ITM/T` occupancy work is a spike with no id (Phases 8–11's `CTX-*` ids are declared in `ROADMAP.md` only — a known, recorded gap)

---
*Requirements defined: 2026-06-27*
*Last updated: 2026-08-03 — traceability populated against plumbing-first 7-phase roadmap (30/30 mapped)*
| VDIFF-01 | Phase 8 | Complete |
| VDIFF-03 | Phase 8 | Complete |
| VDIFF-02 | Phase 9 | Complete |
| VDIFF-04 | Phase 9 | Complete |
| VDIFF-05 | Phase 10 | Pending |
| VDIFF-06 | Phase 10 | Pending |
| VDIFF-07 | Phase 11 | Pending |
| VDIFF-08 | Phase 11 | Pending |
| RISK-01 | Phase 12 | Complete |
| RISK-02 | Phase 12 | Complete |
| VLIB-01 | Phase 13 | Complete |
| VLIB-02 | Phase 13 | Complete |
| VLIB-03 | Phase 13 | Complete |
| VLIB-04 | Phase 13 | Complete |
| VMOD-01 | Phase 14 | Complete |
| VMOD-02 | Phase 14 | Complete |
| VMOD-03 | Phase 14 | Complete |
| VMOD-04 | Phase 14 | Complete |
| VMOD-05 | Phase 14 | Complete |
| VVER-01 | Phase 15 | Complete |
| VVER-02 | Phase 15 | Complete |
| VORD-02 | Phase 16 | Complete |
| VORD-01 | Phase 17 | Complete |
| VORD-03 | Phase 17 | Complete |
| VORD-04 | Phase 17 | Complete |
| VORD-05 | Phase 17 | Complete |
| MCAL-01 | Phase 18a | Complete |
| MCAL-02 | Phase 18a | Complete |
| MCAL-03 | Phase 18a | Complete |
| MCAL-04 | Phase 18a | Complete |
| MCAL-05 | Phase 18b | Complete |
| MCAL-06 | Phase 18a (+ 18b) | Complete |
| MVER-01 | Phase 19 | Complete |
| MVER-02 | Phase 19 | Complete |
| MVER-03 | Phase 19 | Complete |
| MVER-04 | Phase 19 | Complete |
| RIG-01 | Phase 20 | Complete |
| RPIN-01 | Phase 21 | Complete |
| RPIN-02 | Phase 21 | Complete |
| RPIN-03 | Phase 21 | Complete |
| RPIN-04 | Phase 21 | Complete |
| RPIN-05 | Phase 21 | Complete |
| RPIN-06 | Phase 21 | Complete |
| VEGA-01 | Phase 21 | Complete |
| DRIV-01 | Phase 22 | Complete |
| DRIV-02 | Phase 22 | Complete |

