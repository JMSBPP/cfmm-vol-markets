# `loop` — the resident VolumePath bridge: operator's manual

**Location:** `offchain/LOOP.md` — next to the code it describes (`docs/` is gitignored on this branch).
**Milestone:** v6.0 (rpc_api workstream), Phases 23–28. **Status:** every component built and
verified; the in-process composition proven chain-free; the live end-to-end run **has never
executed** and says so (see §7).

## What it is

A headless daemon. Per block it: polls the chain for `Shock` events from a **persisted**
watermark → reads the pool **pinned to the event's block** → splits the fee → content-keys the
shock → elides or solves it through GAMS/CONOPT → records **every** event in a Postgres ledger →
publishes `volume_path.json` **atomically** into the `mev_tax_model_one` test tree. One iteration
function; the mode only decides whether it is re-entered.

## 1. Invocation

```
cabal build --enable-tests -j all      # --enable-tests is load-bearing (Phase 21, measured 4x)
cabal run -v0 loop                     # resident: poll the head every LOOP_POLL_MS, forever
cabal run -v0 loop -- --once           # drain: process watermark+1 .. head, publish, exit 0
cabal run -v0 loop -- --help
```

## 2. Environment

One resolver per variable (`Loop.Config`, `Chain.Endpoint`, `Store.Config`, `Gams.Config`).
A malformed value is **refused with a named exit**, never silently defaulted.

| Variable | Default | Notes |
|---|---|---|
| `ETH_RPC_URL` | `http://127.0.0.1:8545` | The one endpoint authority. `offchain/rig/endpoint.sh` states the same default for the shell scripts; the suite asserts the two byte-equal. |
| `PGSTORE_DSN` | *(empty — the loop will not start)* | **Required.** Store + ledger. The loop runs migrations `001`–`004` itself at startup. |
| `FIXTURE_DIR` | `test/models/mev_tax_model_one/fixtures` (repo-relative; issue #25's contract) | Publication directory. The loop **never creates it** (LOOP-04). |
| `LOOP_POLL_MS` | `1000` | Positive integer only. |
| `GAMS_BIN` | `gams` (on `PATH`) | Prover binary. |
| `GAMS_MODEL` | see `Gams.Config` | The `.gms` model path. |

The prover child receives a **whitelisted** environment (`Gams.Env`): `GAMS*`, `GDX*`,
`CONOPT*`, `LC_NUMERIC`, `LANG` are stripped and controlled so locale can never re-render numbers.

## 3. Standing up what it needs

`offchain/rig/README.md`'s clean-machine sequence, from the repo root, each step exit 0:

```bash
npm ci --ignore-scripts
git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive
forge build
offchain/rig/check-upstream.sh && offchain/rig/verify-import.sh
offchain/rig/deploy-rig.sh        # owns anvil; asserts `cast chain-id` BEFORE the first broadcast
offchain/rig/verify-rig.sh
```

Plus a Postgres at `PGSTORE_DSN` (the conformance capture uses `postgres:18-alpine` via docker)
and a GAMS 54.1 / CONOPT 4.39 toolchain. `offchain/rig/deploy-rig.sh --stop` kills the rig's anvil.

## 4. Startup, in order — each failure is a named exit code

1. Resolve `GAMS_BIN` / `GAMS_MODEL` → **43** `precondition_prover_paths`
2. `detect_toolchain` — a version-only hermetic probe, no production solve → **41**
   `precondition_toolchain`. The identity is pinned for the process lifetime; a later run that
   reports a different toolchain is **adopted and logged** (user ruling, 28-CONTEXT), never a halt.
3. Resolve the endpoint → **42** `precondition_endpoint`
4. The fixture directory must exist (absent vs. a file in its place are distinguished) → **40**
   `precondition_fixture_dir`
5. Connect, run migrations, open the ledger → **44** `precondition_ledger`
6. Read the watermark (genesis if none) and begin.

## 5. Per block: one JSON line on stdout

```json
{"block":N,"events":k,"published":true,"fixture":"<path>",
 "outcomes":[{"tx":"0x…","logIndex":i,"outcome":"elided|stored|not_persisted|inadmissible","keyPrefix":"…"}]}
```

- **Every** event gets a ledger row (`loop_event`, unique on `(tx_hash, log_index)`), whatever
  its outcome. The watermark (`loop_watermark`, single row) advances **in the same transaction**
  as the block's rows — through event-free blocks too.
- Two distinct events with identical shocks → one `model_run` row, two ledger rows. The same
  event replayed → one ledger row, no second solve. (Note: the content key, not the ledger, is
  what elides the solve — measured in 28-01.)
- A cache hit **still publishes**, stamped with the event's block.
- The fixture carries Phase 27's identity fields — `pool`, `blockNumber` as a **string**
  (2^53+1 through a JSON number comes back 2^53; measured), `chainId` — around the solver's
  byte-exact artifact, written temp-sibling-then-`rename(2)`. A fixture below the shape floor
  (parses, `length dQx == nEvents`, minimum size) is **refused**, not published.

## 6. Exit codes — `Loop.Config.exit_table` is the single source

| Code | Name | Watermark |
|---|---|---|
| 0 | clean / drained | — |
| 30 | `halt_unsolvable` — admissible shock, CONOPT infeasible | **not** advanced past the block |
| 31 | `halt_rpc_exhausted` | not advanced (bounded retry not yet implemented — tracked) |
| 32 | `halt_db` | not advanced |
| 33 | `halt_solver_exception` | not advanced |
| 34 | `halt_block_exception` — an exception escaped a stage | not advanced; the block is re-processed on restart under the same content key |
| 40–44 | the preconditions in §4 | never started |

An **inadmissible** shock (fee-split / ellipse refusal — refused before the solver is ever
reached) is *not* a halt: ledger row, advance, continue. SIGINT is honoured only at a block
boundary — block N lands fully, block N+1 never starts.

## 7. Evidence, and what cannot run today

- `cabal test` — 232 checks, chain-, DB- and GAMS-free (~9 min; the ten-second torn-read race
  harness, re-run by the sentinel sweep, is the cost). Every LOOP requirement is proven there
  against synthetic logs, `Store.Memory`, a stub solver and a temp `FIXTURE_DIR`, with each
  firing input observed red.
- The real solver mated once: the spike (`e0b3600`) ran split → key → decide → GAMS → store on a
  *constructed* shock and reproduced `offchain/rig/volume-path-golden.json` byte-for-byte.
- `offchain/rig/capture-loop.sh` — the live end-to-end capture. **It has never run**, and refuses
  by name:
  - **CHAIN-01 / issue #26** — no deployable `Shock` emitter exists; the event is emitted from
    inside a forge test, not a contract another process can drive. One driver emitting a single
    `Shock` in a *mined* transaction discharges it.
  - **LOOP-04 / issues #24, #25** — `test/models/mev_tax_model_one/fixtures/` does not exist on
    any branch, and the loop will not create it.
  The suite asserts the capture artifact's **absence** as a verdict whose message says what to do
  the day it appears.

## 8. What this loop is not

The output is a **JSON fixture** the Solidity test parses and replays. Nothing ABI-encodes the
GAMS result or sends it back on-chain; that would be a new capability composed from the v5.0
`cast calldata` + `sendTransaction` machinery, and it needs a receiving contract named first.
