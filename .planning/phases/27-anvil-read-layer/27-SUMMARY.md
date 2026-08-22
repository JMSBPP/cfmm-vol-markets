---
phase: 27-anvil-read-layer
kind: phase-summary
status: complete-with-one-blocked-requirement
subsystem: chain
tags: [chain-02, chain-03, chain-05, chain-06, chain-07, block-pinning, endpoint-resolver, fixture-identity, chain-01-blocked]
plans: 3
requirements_shipped: [CHAIN-02, CHAIN-03, CHAIN-05, CHAIN-06, CHAIN-07]
requirements_blocked: [CHAIN-01]
requirements_elsewhere: [CHAIN-04]
completed: 2026-08-22
---

# Phase 27 — The Anvil Read Layer: phase summary

Six of the seven CHAIN requirements are retired and the seventh is **BLOCKED BY NAME with its
dependency stated**. The endpoint is resolved once in two languages and the producer binds the same
reading of it; every pool read is pinned to a block the type cannot omit and cannot express the
moving head; an absent, zero or unparseable answer is a refusal that names its field; and the
published fixture says which pool, at which height, on which chain — with the reason its height is
a string OBSERVED rather than asserted.

`cabal test` went **194/194 → 205/205**, exit 0, zero warnings, and it still opens no socket — now
asserted by a **third** structural grep beside the DB-free and GAMS-free ones.

---

## Requirement disposition

| | State | Where |
|---|---|---|
| **CHAIN-01** | ⛔ **BLOCKED — externally, and named below** | — |
| **CHAIN-02** | ✅ Complete | 27-02 |
| **CHAIN-03** | ✅ Complete | 27-02 |
| **CHAIN-04** | ✅ Complete (before this phase) | 26-02 |
| **CHAIN-05** | ✅ Complete | 27-03 |
| **CHAIN-06** | ✅ Complete, **and its text corrected at close** | 27-01 |
| **CHAIN-07** | ✅ Complete | 27-01 |

CHAIN-02 and CHAIN-03 were carried into this phase marked *Blocked*. **They were never blocked**,
and the row said so before the work started: a pinned read needs a POOL, and `deploy-rig.sh` has
stood one up since 22-03. Only CHAIN-01 depends on the upstream emitter. That "Blocked" was
inherited from CHAIN-01's row rather than measured, and it is the kind of inheritance that costs a
phase.

---

## CHAIN-01 — BLOCKED, by name, with the dependency stated

**Dependency: the plank / mev-migrate workstream. Issue #26 — `SELECTOR_NEXT 0xd3827b0b`.**

**There is no deploy script for the Shock writer.** `foundry-scripts/mev_tax_model_one/` holds only
`DeployAlgebraFactory.s.sol`, and the event is emitted from a forge **test**
(`AlgebraIntegralMevTaxModelOneShocks.t.sol`), not from a deployed contract another process can
drive. A mined `Shock` log therefore requires that workstream to run the emitter against an anvil
endpoint. **Not this workstream's to build**, and it was not built here.

**What would discharge it:** one driver that emits a single `Shock` in a MINED transaction on the
resolved endpoint. Nothing more.

**Everything on this side is ready and was shipped without it:**

- `Chain.Shock` decodes the event — CHAIN-04, 12 checks, a 21-member synthetic corpus including
  the negative fixtures a real log has to be told apart from.
- `Chain.Read` pins the reads to its block, and the pin is a `newtype` with one constructor.
- `Chain.Endpoint` resolves the endpoint the driver would be pointed at, and `deploy-rig.sh` binds
  the same reading of it and asserts the chain id before any broadcast.
- CHAIN-05's fixture already carries the identity slot the decoded pool goes into. The pool in it
  today is SYNTHETIC and is labelled as such in the check's own haddock; the day a `Shock` is mined,
  the value changes and the shape does not.

### CHAIN-01's stale wording, corrected in `REQUIREMENTS.md`

The requirement said *"The **`next`** event is decoded…"*.
`next(address,uint160,int24,uint24,uint24)` is a **FUNCTION SELECTOR** (`0xd3827b0b`) on
`AlgebraIntegralShocksWriterInterface.plk` — **never an event.** 26-02 established this against the
merged source and demoted it to a NEGATIVE fixture: a log whose topic0 is that selector left-padded
into a word is exactly the thing the decoder must refuse, and the corpus contains one.

The event is `Shock(address indexed pool, int24, uint24, uint24)`, topic0
`0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`, verified equal to
`cast keccak` of that signature rather than transcribed.

Same defect class as FEE-01's "exactly", corrected in 26-04. **The correction is to the wording; the
status stays BLOCKED.**

### CHAIN-06's "nine sites", corrected in `REQUIREMENTS.md`

Carried from 27-01 and 27-02 and discharged here. The sentence read *"Nine sites, one rule"* and the
count was **wrong three ways**:

| | Measured at 27-01 |
|---|---|
| By the pattern the sentence itself implies | **TEN** — the tenth is `offchain/spec/types.md`, prose inside the grep's blast radius |
| Counting `offchain/rig/verify-rig.sh` | **ELEVEN** — fourteen `cast` calls against a live rig, reached through foundry's `--rpc-url local` ALIAS, so it named neither token and **no pattern built from those two tokens could ever have found it** |
| Times the rule was actually implemented | **ZERO** — the only occurrence of the variable under `offchain/` was a *comment* saying the deploy scripts scrub it |

A count in prose is not the durable form. What replaces it is `Chain.Endpoint.endpoint_sites`, a
manifest checked in BOTH directions against the tree — **18 entries** today, verified on disk at
this close.

---

## What each plan shipped

### 27-01 — one endpoint rule, producer included (CHAIN-06, CHAIN-07)

`Chain.Endpoint` and `offchain/rig/endpoint.sh`: the resolver stated once per language, with the two
statements of the default asserted **byte-equal**, because `bash` cannot import a Haskell module and
a duplication a check compares is a checked agreement. All eleven sites rewired; `deploy-rig.sh`
binds anvil's `--host`/`--port` and every deploy endpoint to one reading of one variable and asserts
`cast chain-id` **before** the first broadcast. Four checks, **194 → 198**, eleven firings observed.

The plan's own census pattern would have reported the fix as a regression (10 before the rewiring,
**8 after**, because five consumers stop naming either token the moment they name the resolver), and
one check MEASURED GREEN against a deliberately unguarded resolver because `setEnv k ""` routes an
empty value to `unsetEnv` — it was driving the unset path twice while reporting on the empty one.

### 27-02 — the pinned read layer (CHAIN-02, CHAIN-03)

`BlockRef` is a `newtype` with ONE constructor, so the moving-head tag is not avoided — it is
**inexpressible**; every read takes it positionally; five refusals name their field DELIMITED
(`liquidity` is a strict prefix of v4's real `liquidityNet`). Three offline checks, a third
structural grep, and an out-of-band capture in which a read pinned at block 13 returns tick −1 while
the unpinned read returns the tick 5000 the state change wrote. **198 → 203**, 21 firings observed.

Two corrections came out of it. The naming arm's decoy was hand-spelled and the mutation that drops
the delimiters MEASURED **201/201, exit 0, NOT CAUGHT** — the decoy kept its own quotes while the
producer lost them, so the two strings could never collide. And `anvil_setStorageAt` **does not
create a block**: it writes into the state OF THE CURRENT HEAD, which made a working pin look
exactly like CHAIN-02's defect until it was driven with `cast` independently.

### 27-03 — fixture identity, and the phase close (CHAIN-05)

`FixtureIdentity` and `render_fixture_identity` in `Chain.Read`, publishing the three fields issue
#29's returned contract names, plus two checks. **203 → 205.** Detail in `27-03-SUMMARY.md`.

---

## Measured totals at phase close

| | Value | How |
|---|---|---|
| `cabal build --enable-tests -j all` | exit **0**, **0** warnings | run at close |
| `cabal test` | exit **0**, **205/205**, **0** FAIL lines | run at close |
| Suite at phase start | 194/194 | 26-04's close |
| Delta across the phase | **+11** (4 + 5 + 2) | |
| Wall, full suite | **3 m 15 s** baseline reading this session | `time cabal test` |
| `purge_file_floor` | **72**, zero slack | `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f \| wc -l` → **72** |
| `credential_scan_floor` | **83**, zero slack | same `find` plus `-o -name '*.json'` → **83** |
| Census under `offchain/` | hs **57**, sh **12**, json **11**, sql **3** | RUN at close |
| `endpoint_sites` | **18** entries | counted on disk at close |
| Structural greps at 0 | **three** — DB-free, GAMS-free, chain-free, each with a positive control | in-suite |
| Territory | **empty** | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` |

Both floors are **unchanged from 27-02** and both were re-measured by RUNNING `find` rather than by
reasoning that nothing was added: 27-03 creates no file, and the prediction and the measurement were
both taken.

### The three structural greps

| Grep | Asserts | Positive control |
|---|---|---|
| DB-free | the suite reaches no database | seeded bait |
| GAMS-free | the suite spawns no solver | seeded bait |
| **chain-free** (new at 27-02) | **`cabal test` opens no socket** | a seeded copy of the subject |

The chain-free grep's two tokens are **not equally load-bearing**, and that was measured rather than
assumed: the JSON-RPC method module IS a test dependency, so importing it compiles and only the scan
stops it; the provider module is NOT, so that import does not build at all and its firing input had
to be a comment. One guards a state reachable in one line of Haskell, the other one reachable in one
line of `.cabal`.

---

## Carried forward into phase 28

### From the end-to-end spike (`.planning/SPIKE-end-to-end.md`) — three seams that did not mate

**S1 — a `KeyIdentity` can only be obtained from a COMPLETED RUN.** `Store.Key.key_identity` needs a
`ToolchainIdentity`, whose only producer in this package is the `Produced` arm of
`Gams.Run.run_prover`; but `Store.Cache.decide` needs the identity BEFORE the first solve. There is
no `detect_toolchain` anywhere. The spike paid a **bootstrap solve whose only product is the
identity**. Phase 28's loop either bootstraps with a throwaway solve or the library gains a
detection function. **Decide this before phase 28 plans its loop — it changes the loop's startup
shape.**

**S2 — `Gams.Invoke.invoke_shock` does not fit the `Store.Solver` seam.** Its type is
`EnvChoice -> Shock -> IO (Either InvokeError ProverOutcome)` and the seam wants
`Shock -> IO ProverOutcome`, and **`Gams.Run.AbortReason` has no constructor for a resolution
failure**, so an `InvokeError` arriving inside a solver has nowhere truthful to go — it must throw
or be mapped to a lie. A shape mismatch rather than a defect, but **the composition function you
would reach for first is the wrong one**, and phase 28 will reach for it.

**S3 — `Store.Cache.Decision` drops `CapturedStreams`.** `NotPersisted` carries only the reason and
the exit code, and the abort LINE NUMBER — the discriminator 26-PROVER-SWEEP measured, **109 =
ellipse refusal vs 171/173 = CONOPT infeasible** — lives only in `volume_path.log`, inside a run
directory `Gams.Run` deletes on every exit path. So a caller of `decide` cannot tell an inadmissible
shock from an unsolvable one, and those two call for **opposite** responses: inadmissible means fix
the shock, infeasible means the fixture cannot answer this one. This touches CHAIN-03's spirit
directly — a refusal that does not say which refusal it is.

### From this phase's own plans

- **`anvil_setStorageAt` writes into the head's state.** This binds anything else constructing a
  historical divergence on this rig, and it is why `write_landed_above_b` exists. Nobody has checked
  whether `capture-cheat-swap-proof.sh`'s reasoning depends on the opposite anywhere.
- **`chain-read-conformance.json` is NOT in the sentinel sweep**, and it has an override, so the
  sweep *could* reach it. Declared in `unswept_artifacts` with its reason. Folding it in means
  enumerating its leaves against six sentinels and writing an `absorbed_by_design` entry for every
  pair no check objects to.
- **Both live captures need a FRESH rig and neither is idempotent.** `capture-chain-read.sh` refuses
  loudly on a second run rather than recording a fake divergence. Anything wanting both in one
  sitting must sequence them and redeploy between.
- **`offchain/rig/README.md`'s chain-independence grep carries the `cast call` / `cast calldata`
  prefix bug.** Harmless today; the executable form in `chain_reaching_terms` no longer has it.
- **`foundry.toml:59` still defines the endpoint alias.** Nothing in the rig uses it, but it is a
  third statement of the default that this workstream cannot edit and no check can reach.
- **`endpoint.sh` is not exercised by `cabal test`** — it is bash, and its behaviour is recorded
  from a direct eight-input run. Putting it under the gate is a Tier decision nobody has made.
- **`roadmap update-plan-progress 27` records `4/3` plans**, because it counts `*-SUMMARY.md` in the
  phase directory and this phase keeps its phase-level summary there — which the plan required.
  Corrected by hand at close; it will need correcting again after any re-run. `STATE.md`'s
  frontmatter was verified INTACT after that command, so the 24-03 warning still applies only to the
  three `state` subcommands.
- **`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock` are untracked and pre-date this
  phase.** Somebody ran a `stack` init in this worktree. They should be tracked or ignored
  deliberately rather than left in `git status` forever.

---

## The pattern this phase kept meeting

Every plan in phase 27 found the same defect at a different depth: **an assertion passing because
its subject was absent.**

| Plan | The instance |
|---|---|
| 27-01 | a rule driven at the UNSET environment twice while reporting on the EMPTY one, because `setEnv k ""` routes to `unsetEnv` |
| 27-02 | a decoy that kept its own quotes while the producer lost them, so the collision the arm exists to observe could not happen — **201/201, exit 0, NOT CAUGHT** |
| 27-03 | a precision witness that, placed at or below the ceiling, would have made every arm agree against a value that cannot fail |

In each case the answer was the same: **drive the subject at the awkward argument and assert the
subject can fail before asserting that it did not.** 27-03 wrote that guard first and then removed
it on purpose, to find out whether it was load-bearing — it was, though not alone (see
`27-03-SUMMARY.md`).

---

## Commits

| Plan | SHA | Subject |
|---|---|---|
| — | `d0e148d` | plan the Anvil read layer — 3 plans, measured before written |
| 27-01 | `e067e31` | the one endpoint rule, in two languages and a manifest |
| 27-01 | `4bf504b` | every site resolves, and the census that found the eleventh |
| 27-01 | `36bc427` | the producer binds it, and the chainId is asserted before any send |
| 27-01 | `235342c` | complete the one-endpoint-rule plan |
| 27-02 | `596ed38` | a read that cannot be made without saying which block |
| 27-02 | `10a3231` | three guards, and the decoy that had to be built by the thing it tests |
| 27-02 | `28e7ffa` | the divergence, constructed — and the cheat that landed in the block it was read at |
| 27-02 | `8910c7c` | complete the pinned-read-layer plan |
| 27-03 | `306b587` | the fixture says which pool, and the string is a measurement not a preference |
