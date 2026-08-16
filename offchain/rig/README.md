# The Phase 20 rig

One command stands up the full V2 contract set on a local anvil, makes the hook's pool
SWAPPABLE, and writes the manifest the Haskell drivers read at startup.

Nothing in this directory requires you to know anything beyond this file.

## Clean-machine sequence

Run these in order, from the repository root. Every step must exit 0 before the next.

```bash
npm ci --ignore-scripts          # node_modules is a HARD forge dependency

# the recursion guard is REQUIRED on a clean machine -- see "The submodule guard" below
git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive

forge build                      # must exit 0 before anything else

offchain/rig/check-upstream.sh   # the artifacts are imported from origin/develop
offchain/rig/verify-import.sh    # SC-1: imported files match the recorded ref
offchain/rig/deploy-rig.sh       # SC-2/SC-5: owns anvil; writes offchain/rig/rig-manifest.json
offchain/rig/verify-rig.sh       # SC-2: every contract answers a live read

cabal build --enable-tests -j all && cabal test  # SC-3/SC-4: manifest loads; pins recompute

# the DRIVER. RIG_SEED is optional: unset, a seed is DRAWN and printed.
RIG_SEED=123456789 cabal run cfmm-replicationPlank-rpc-api
```

The last step is the run itself, not a smoke test. It drives both price mechanisms and all three
order shapes against the standing rig and writes `offchain/rig/driver-run-capture.json` —
committed — carrying the five-step cheat-swap path with its E3 per step, and the `orders` block
(single, mixed, zero-arrival). That artifact is what `cabal test`'s `driv01_*` and `driv02_*`
checks assert against, which is how the suite stays chain-independent while still asserting facts
that only a chain can produce.

`RIG_SEED` is a single decimal `Word32`. A malformed value FAILS LOUDLY rather than falling back
to a drawn one — a silent fallback would produce a run the operator believes is a replay and is
not, and the artifact would record the drawn value, so nothing downstream could tell.

`--enable-tests` is not decoration. Dropping it leaves the test component unconfigured, so the
build exits 0 against a test suite that would not compile — MEASURED four separate times in
Phase 21. Do not "simplify" the flag away.

`offchain/rig/deploy-rig.sh --stop` kills the anvil the rig owns.

### The sixth deploy script

`deploy-rig.sh` runs six `forge script`s. The first five are the Phase-20 set and all take
`--broadcast --ffi --via-ir`. The sixth is different and deliberately so:

```bash
env POOL_MANAGER=$PM HOOK=$HOOK TOKEN0=$CURRENCY0 TOKEN1=$CURRENCY1 \
  forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig \
    --rpc-url local --broadcast --via-ir
```

No `--ffi` (it is pure Solidity, unlike the Plank deploys), `--tc` to name the target, and all
four env vars come from the fourth script's printed manifest. `deploy-rig.sh` supplies them; you
never type this yourself.

It makes the pool swappable: it deploys the two canonical v4-core routers (`PoolSwapTest`,
`PoolModifyLiquidityTest` — vendored, nothing authored), funds and approves the deployer
**towards the routers** (settlement is `CurrencySettler.settle` → `transferFrom` pulled *by the
router*, so the PoolManager is never approved), mints ONE full-range position at
±887260 with L = 1e21, and runs a probe swap.

**What the probe proves.** Until this script runs, `DynamicFeeHook`'s pool has zero liquidity and
there is no unlock-callback router anywhere on chain, so a swap from an EOA is impossible and the
hook can never write a timepoint. The probe swap enters `DynamicFeeHook.beforeSwap`, and both the
script and `deploy-rig.sh` assert that the hook's `lastTimepointTimestamp` STRICTLY ADVANCED. A
passing run is therefore evidence that timepoints self-write, not a claim that they do. You will
see the line

```
  probe swap wrote a timepoint: 1700000003 -> 1700000010
```

**Do not mint additional ranges on this rig.** The drivers cheat `slot0`, so ticks are never
crossed; a second position would introduce an initialized tick boundary and leave `pool.liquidity`
stale relative to a cheated tick. One full-range position keeps active liquidity uniform over the
whole usable range.

### Capturing the batch return

```bash
offchain/rig/capture-batch-return.sh   # writes offchain/rig/batch-return-capture.json
```

Requires a standing rig — it reads the manager address out of `rig-manifest.json` and calls the
live contract, so run it after `deploy-rig.sh` and `verify-rig.sh`. It sends no transaction:
`create_orders` returns its array, so four plain `eth_call`s produce the whole capture and nothing
on chain changes.

It writes `offchain/rig/batch-return-capture.json`, which IS committed: real
`(bool, uint256)[]` returndata for four cases (`N0_empty`, `N1_success`, `N2_success_then_fail`,
`N1_dirty_vega`), each with the calldata that produced it, plus `chainId`, `manager` and
`blockNumber`. It exists so `cabal test` can assert against bytes that actually came off a chain
while itself staying chain-independent.

Re-running is reproducible: `jq -S 'del(.generatedAt, .blockNumber)'` over two runs against the
same rig is byte-identical. Note that one run takes well under a second, so two back-to-back runs
can share a `generatedAt` — delete the artifact first if you want the regeneration to be visible.

### Why `npm ci` is step one

`foundry.toml` remaps `@cryptoalgebra/...` into `node_modules/`, several tracked `.sol` files
import it, and `node_modules/` is gitignored. Without this step `forge build` — and therefore
every `forge script` the rig runs — dies with
`Source "node_modules/..." not found` before it ever touches the chain.

### The submodule guard

`lib/panoptic-v2-core` declares a nested `lib/panoptic-helper` submodule that is not reachable,
and a plain `git submodule update --init --recursive` will try to clone it and fail. The
`-c submodule.lib/panoptic-helper.update=none` flag skips exactly that one submodule; you should
see `Skipping submodule 'lib/panoptic-v2-core/lib/panoptic-helper'` in the output. Nothing the
rig builds needs it.

If you have run the plain command before and it worked, that is a machine-local artifact: the
skip ends up recorded in `lib/panoptic-v2-core/.git/config`, which no clean checkout has. Use the
flag; it is a no-op when the skip is already configured.

### What each step needs

| step | needs |
|---|---|
| `check-upstream.sh` | network access to `origin`, and `jq`. Exits 2 if the upstream merge has not landed. |
| `verify-import.sh` | `sha256sum`; recomputes digests, so it works even if the ref object has been gc'd |
| `deploy-rig.sh` | `anvil`, `forge`, `cast`, `jq`, and either `lsof` or `fuser` to clear a stale listener on 8545 |
| `verify-rig.sh` | `cast`, `jq`, and a running rig |
| `cabal test` | `cast` on PATH always. A running rig only for the manifest-consuming checks — see below. |

**The `cabal test` row, precisely.** Phase 21 MEASURED the suite chain-independent: rig stopped,
`pgrep anvil` empty, `cast block-number` erroring, `cabal test` still exit 0. It opens no socket
(`grep -cE 'cast call|HttpProvider|8545' offchain/test/Main.hs` is 0) and consumes committed,
provenance-bearing artifacts instead. Two things are still needed, for two different reasons:

- **`cast` on PATH** — `sc4_cast_agreement` shells out to `cast sig` / `cast keccak` to recompute
  the pins with a second, independent implementation. No chain is involved.
- **a rig that has been stood up at least once** — `rig-manifest.json` is gitignored, so
  `sc3_load_succeeds`, `sc3_corrupted_manifest_fails` and `rpin05_capture_is_present_and_fresh`
  have no file to read on a fresh checkout. They FAIL rather than skip, naming
  `deploy-rig.sh`. The rig does not have to still be *running*; the file has to exist.

`RIG_MANIFEST=<path>` points the suite at a different manifest, which is how the nine-contract
requirement is falsified.

### What the last step does and does not prove

`cabal run` exercises the whole path — it loads the manifest, sends transactions, writes prices,
runs both generators and reports. Every address it uses comes from the rig.

It DOES place vol orders, as of Phase 21. Re-measured against this rig at plan 22-03: the demo
order mines with receipt **status success**, an `ORDER_CREATED` log carrying
`target_vega 1000000000000000000`, `price WRITTEN`, `path WRITTEN (5 observations)`, and the
batch reporting **7 succeeded, 0 failed (of 7)** with every order id read back. This section used
to say the order reverted; that was the V1 three-argument `create_order` encoder meeting a V2
four-argument module, and Phase 21 re-pinned both the encoder and the event decoder, which is
what fixed it.

**As of Phase 22 it IS the DRIV-01/DRIV-02 run**, not a demo beside it. This section used to say
the opposite — that `cabal run` only wrote prices to the `PriceSetterPoolManager` and never
exercised the cheat-swap path, leaving `deploy-rig.sh`'s probe swap as the only thing on the rig
that made the hook write a timepoint. Plans 22-05 and 22-06 changed that. The one command now also
runs:

- **DRIV-01** — `run_cheat_swap_path`, five consecutive cheat → clock → swap steps on a
  `t_k = t_0 + k*stride` schedule, each producing exactly one `TimepointWritten` carrying the tick
  AND the timestamp the driver submitted.
- **DRIV-02** — the single order with its E1 and a receipt-block-pinned readback, a MIXED batch
  carrying one contract-rejected tuple, and a zero-arrival empty batch.

The legacy `write_price` / `PriceSetterHook` flow is still there and still runs, on its own second
manager, exactly as roadmap SC-1 requires — it was ADDED BESIDE by, never replaced.

Two limits worth keeping straight. `cabal run` needs a standing rig and writes to the chain, so it
is not part of `cabal test`; and it does not re-derive the pins or verify the import, which is why
`check-upstream.sh` and `verify-import.sh` come earlier in the sequence rather than being folded
into it.

### Replaying a run

`RIG_SEED=<the seed the run printed>` against a **fresh** rig reproduces the tick path, the drawn
`targetVega`s and the minted order ids. A fresh rig starts at `orderCount = 0`, so the ids replay
too.

```bash
S=123456789
offchain/rig/deploy-rig.sh && RIG_SEED=$S cabal run cfmm-replicationPlank-rpc-api
cp offchain/rig/driver-run-capture.json /tmp/replay-a.json
offchain/rig/deploy-rig.sh && RIG_SEED=$S cabal run cfmm-replicationPlank-rpc-api   # FRESH rig
cp offchain/rig/driver-run-capture.json /tmp/replay-b.json

PROJ='{ticks: [.steps[].tick], e3: [.steps[].e3.tick], ids: [.orders.mixed.readbacks[].id]}'
jq -S "$PROJ" /tmp/replay-a.json > /tmp/ra.json
jq -S "$PROJ" /tmp/replay-b.json > /tmp/rb.json
diff -u /tmp/ra.json /tmp/rb.json     # EMPTY
sha256sum /tmp/ra.json /tmp/rb.json   # equal
jq -r '.seed.t0' /tmp/replay-a.json /tmp/replay-b.json   # DIFFERENT — see below
```

**What it does NOT reproduce, stated rather than hidden: absolute timestamps.** `t_0` is read from
the CHAIN HEAD at driver start (`t_0 = head + stride`), and anvil's `--timestamp` fixes the origin
and not the rate, so two runs minutes apart start from different heads. Measured at plan 22-06:
two same-seed runs against fresh rigs gave `t0 = 1700000027` and `t0 = 1700000026` while the
projection above was byte-identical at
`03c8515e582fd7d38731aa420b2dcbb17287099c0c79afe00893c50d745c27b9`. That the two `t0`s DIFFER is
not a defect — it is what proves the second run actually re-ran rather than the comparison reading
one file twice. What replays is the tick path, the E3 series, the drawn values, the ids, and the
schedule's SHAPE (`t_k - t_0 = k*stride`).

**Do not project `.orders.mixed.submitted[].targetVega` and call it a seed check.** Those three
values are `sample_mixed_batch`, fixed DATA rather than a draw, so they are identical under every
seed and can never falsify anything. Measured: a `RIG_SEED=123456790` run moved the ticks
(`237,-556,-1000,-1344,-1191` → `289,-222,-331,-919,-169`) and the ids (`[6,7]` → `[5,6]`) and
left that field untouched.

**The seed is consumed SEQUENTIALLY** by `run_price_gen`, then `run_cheat_swap_path`, then
`run_order_gen`. Changing the price path's `size` therefore changes the ORDERS too. That is
deterministic and replayable, but it means the three drivers are not independently seeded.

## The evidence artifacts

| file | committed? | written by | read by |
|---|---|---|---|
| `offchain/rig/rig-pins.json` | YES | `offchain/rig/generate-pins.sh` (from the imported `src/interfaces/**/*.plk`) | `Rig.Manifest`, the pin tests |
| `offchain/rig/rig-manifest.json` | NO (gitignored) | `offchain/rig/deploy-rig.sh` (from `broadcast/**/run-latest.json`) | `Rig.Manifest`, the drivers |
| `offchain/rig/batch-return-capture.json` | YES | `offchain/rig/capture-batch-return.sh` | `cabal test`'s `rpin05_*` checks |
| `offchain/rig/cheat-swap-proof.json` | YES | `offchain/rig/capture-cheat-swap-proof.sh` (`cheat-swap-proof` executable) | `cabal test`'s `driv01_cheat_swap_proof_*`, `driv01_cheated_tick_reaches_e3`, `driv01_wrong_pool_is_silent`, `driv01_same_second_is_a_silent_noop`, `driv01_extreme_tick_is_survivable` |
| `offchain/rig/driver-run-capture.json` | YES | `cabal run cfmm-replicationPlank-rpc-api` | `cabal test`'s `driv01_run_capture_*`, `driv01_e3_per_step_matches_submitted`, `driv01_no_same_second_noop`, `driv01_legacy_write_price_still_ran`, and all four `driv02_*` checks |

`RIG_CHEAT_SWAP_PROOF` and `DRIVER_CAPTURE` override the last two paths. They differ in SCOPE and
deliberately so: `RIG_CHEAT_SWAP_PROOF` redirects the CHECKS only (the capture tool always writes
the committed path), while `DRIVER_CAPTURE` redirects the WRITER as well — there the driver IS the
capture tool, so a mutant run has to be aimable at a temp path or the only available falsification
would be damaging the evidence it guards.

`generate-pins.sh` is not part of the sequence above because its output is committed. Re-run it
when an interface file changes; it is idempotent, so a run that changes nothing leaves
`git diff` clean. It writes to `rig-pins.json.tmp` and renames, and refuses to emit below a
floor of 30 selectors / 5 topics — a `const` syntax drift used to parse zero pins, exit 0, and
replace the tracked file with empty maps.

### Regenerating a committed artifact

**Never regenerate with `generator ... > committed-file`.** The shell creates and truncates the
redirect target *before* the generator starts, so a generator that fails to compile has already
destroyed the evidence, and `jq .` on empty stdin exits 0 writing nothing — so the pipeline
reports success over a zero-byte artifact. Measured on `peer-haskell-bytes.json`: 3120 bytes → 0,
with nothing to restore from but git.

Write beside the target and rename:

```bash
cabal build lib:cfmm-replicationPlank-rpc-api
OUT=offchain/rig/peer-haskell-bytes.json
cabal exec -- runghc --ghc-arg=-package --ghc-arg=cfmm-replicationPlank-rpc-api \
  offchain/rig/gen-peer-bytes.hs > "$OUT.raw" \
  && jq . "$OUT.raw" > "$OUT.tmp" \
  && mv "$OUT.tmp" "$OUT" && rm -f "$OUT.raw"
```

The `--ghc-arg=-package` pair is required on ghc 9.10.3 — without it `runghc` reports
`Could not load module VolOrder.Decode ... member of the hidden package`, and the
`runghc -package X file.hs` and `runghc -- -package X file.hs` spellings both die with
`Not in scope: main`.

## Rules

- No address, selector or topic0 is ever typed. Selectors and topic0s are computed from the
  signature strings in the interface files; addresses come from foundry's broadcast records.
- `RIG_PINS` / `RIG_MANIFEST` override the default paths. This holds for READERS **and for the
  WRITER** — an override honoured on one side of a producer/consumer pair is how a falsification
  comes to be aimed at nothing. `RIG_MANIFEST` is honoured by `deploy-rig.sh` (writer),
  `verify-rig.sh`, `capture-cheat-swap-proof.sh`, `capture-batch-return.sh` and `Rig.Manifest`;
  `RIG_PINS` by `generate-pins.sh` (writer), `check-upstream.sh` and `Rig.Manifest`. Both were
  dead on their writer until it was measured (`90765c1`, and this commit).
- A missing or malformed file is a loud startup failure, never a default. The message names the
  resolved path and the command that produces the file.
- `src/`, `foundry-scripts/`, `test/`, `Makefile`, `foundry.toml` belong to other tracks:
  this rig RUNS them, it never edits them.
- The rig holds exactly ONE liquidity position, the full-range one `InitSwappableRig` mints.
  Adding a second range breaks the cheat-swap invariant silently.

## The nine contracts

`deploy-rig.sh` runs six deploy scripts and records nine contracts under `contracts` in the
manifest:

| contract | what it is for |
|---|---|
| `VolOrderManagerMod` | the vol-order registry the order driver writes to |
| `RealizedVolatilityMod` | the module-global vol oracle, seeded at `initTs` |
| `DynamicFeeMod` | the fee configuration the hook reads |
| `DynamicFeeHook` | the v4 hook: `beforeSwap` writes the timepoint and overrides the fee |
| `PoolManager` | the v4 manager the hook's pool lives in |
| `PriceSetterHook` | the tick-experiment hook `write_price` drives |
| `PriceSetterPoolManager` | that hook's OWN second manager — a distinct contract, not a copy |
| `PoolSwapTest` | v4-core's unlock-callback swap router. Without it no EOA can swap, so `beforeSwap` can never fire. |
| `PoolModifyLiquidityTest` | v4-core's unlock-callback liquidity router; mints the one full-range position |

All nine are mandatory — a manifest missing one is a broken rig, and `Rig.Manifest` refuses to
load it rather than handing a driver a zero address. The two routers are mandatory for a reason
worth stating: their absence means the `InitSwappableRig` step did not run, which means a
zero-liquidity pool where no timepoint can ever be written — and that fault is invisible to every
other check, because the remaining seven deployments are all live and all answer.

`verify-rig.sh` asserts the `contracts` key set is EXACTLY these nine before it probes anything.
That gate is not decoration: the probe loop walks `.contracts | keys[]`, so a key deleted from the
manifest used to delete its own probe and the run ended `SC-2 OK: 7 contracts live`. Measured
against a copy with both `PriceSetter*` keys removed, before the gate existed: **exit 0**.

`verify-rig.sh` probes both routers' `manager()` against the manifest's `PoolManager`. A router
constructed against the *other* live manager has bytecode and passes a liveness probe; only the
binding check sees it. `PriceSetterHook` and `PriceSetterPoolManager` get the same treatment:
`PriceSetterHook.poolManager()` must equal the manifest's `PriceSetterPoolManager`, its
`slot0Slot()` must be nonzero (`beforeInitialize` writes it and `afterInitialize` proves it against
what `Pool.initialize` stored, so zero means the hook is deployed and bound to nothing), and the
second manager must return a nonzero `extsload(slot0Slot)` — the two halves of one pool, checked
against each other rather than each against itself.

The manifest also carries `accounts` (`deployer`, `sender`), `pool`
(`poolId`, `currency0`, `currency1`, `tickSpacing`), `seed` (`initTs`, `initTick`), `chainId`,
`generatedAt` and `generatedFrom` (the upstream sha the artifacts were imported from).

## Why the rig owns the clock

`deploy-rig.sh` starts anvil as `anvil --silent --timestamp "$INIT_TS"`, so the chain's genesis
timestamp is the same `1700000000` that seeds `RealizedVolatilityMod`. Without it there are two
unrelated clocks: the module-global series anchored at 1.7e9 and `DynamicFeeHook`'s own buffer
seeded at `uint32(block.timestamp)` — wall clock, ~1.78e9. A driver computing `INIT_TS + k*stride`
against a wall-clock chain would be asking for timestamps years in the past, which anvil rejects.

Two things this does NOT do, both measured:

- **It fixes the origin, not the rate.** anvil's clock still advances with wall time from the
  anchor (13 s of real time → block timestamp `1700000013` on anvil 1.5.1), and
  `InitSwappableRig` warps a further +5 s of its own. Read the chain head; never assume it
  equals `INIT_TS`. `cast block --rpc-url local 0 --field timestamp` is the genesis value,
  not the current one.
- **It does not make the timepoint guard a block guard.** The hook writes at most one timepoint
  per distinct `uint32` TIMESTAMP — blocks are irrelevant, and anvil mines several blocks per
  second. Two swaps inside one wall-second silently no-op the second write: no `TimepointWritten`
  event, while the receipt is still `status 1` and the fee is still served. A driver that does
  not advance the clock loses writes invisibly. `TimepointWritten` is the ground truth of what
  landed, never the swap count.

## Reproducibility

`deploy-rig.sh` kills the previous anvil and starts a fresh chain, so every run is from scratch.
Two runs produce a byte-identical manifest once the timestamp is excluded:

```bash
offchain/rig/deploy-rig.sh && jq -S 'del(.generatedAt)' offchain/rig/rig-manifest.json > /tmp/run1.json
offchain/rig/deploy-rig.sh && jq -S 'del(.generatedAt)' offchain/rig/rig-manifest.json > /tmp/run2.json
diff -u /tmp/run1.json /tmp/run2.json    # empty
sha256sum /tmp/run1.json /tmp/run2.json  # equal
```

`generatedAt` differs between the two, which is what shows the second run actually regenerated the
file rather than the comparison reading one file twice.

**Re-measured at plan 22-03**, after `--timestamp` and the sixth deploy script were added — the
property is not inherited across a change to the lifecycle. `diff -u` empty; normalised sha256

```
e0f01eb5fc3545f7d1a7066a95a42c62c271aa333bf955fd6359d286abfeec44
```

on both runs, with `generatedAt` `2026-08-02T16:35:12Z` vs `2026-08-02T16:35:21Z`. Both router
addresses and `pool.poolId` are stable across from-scratch runs.

Nothing in the rig reads the wall clock for anything else. The TWAP seed is a fixed literal inside
`deploy-rig.sh`: a clock-derived seed would still pass the manifest diff above — the seed is not a
manifest field — while silently making the rig's on-chain STATE irreproducible.

---

## `volume-path-golden.json` — the real GAMS artifact, and where its digest is NOT

`offchain/rig/volume-path-golden.json` is **606 bytes** of real solver output. It is the only
corpus that can exercise BYTE-02 at all: the adversarial corpus catches *transport* corruption — a
byte the wire cannot carry — while `jsonb`'s key reorder is a function of the key names and lengths
and a number re-render is a function of the actual numeric literals, so a shape-dependent
normalization needs the real shape. A synthetic fixture cannot substitute.

| | |
|---|---|
| **Source** | `cfmm-gams`, `model/mev_tax_model_one/volume_path.json` |
| **Toolchain** | GAMS 54.1 / CONOPT 4.39.0 |
| **Copied in** | 2026-08-16, at plan 23-04 |
| **Reproducibility** | MEASURED byte-identical at two independent paths, two runs of the same model |
| **Last four bytes** | `5d 0a 7d 0a` — `"]\n}\n"`, trailing newline PRESENT |

**The sha256 is deliberately NOT written here.** It is pinned in Haskell source, at
`offchain/lib/Store/Types.hs`'s `volume_path_golden_sha256`, and the length beside it at
`volume_path_golden_bytes_len`. A digest recorded next to the thing it digests is a tautology —
regenerate the bytes and regenerate the digest and the comparison still passes — and this
repository has already shipped that defect once. The pin lives in a different file, maintained by
different hands, so that a silent replacement of these bytes reddens rather than agreeing with
itself. It is also written **bare**, with no `0x` prefix, because `sc3_literal_purge` greps for
prefixed 64-hex and a prefixed pin would fail the suite on sight.

**The bytes are copied, not read across worktrees.** Reading `cfmm-gams` from this tree at capture
time is the Phase-28 ownership problem arriving early: this workstream would silently depend on
another checkout's working state, and a capture taken on a machine without that worktree would
have no subject at all.

## `capture-store-conformance.sh` — the one script here that needs a database

Everything else under `offchain/rig/` needs a chain. This one needs Postgres, and it is the only
place in Phase 23 that does: `cabal test` opens no socket, by construction rather than by a branch.

```bash
bash offchain/rig/capture-store-conformance.sh     # docker required; nothing else
```

It provisions its own container on a **non-default host port**, creates a **per-run database**,
runs the capture, gates on VALUES in the result, and tears the container down on every exit path
including a SIGINT. `CFMM_REQUIRE_DB` lives here and nowhere else: in `cabal test` that variable
fails *open* — a workflow whose `env:` block drifts silently returns to skip-mode and is green —
whereas here its failure mode is *no artifact at all*, and a stale artifact is caught by the
computed freshness oracle rather than by nobody.

The artifact it writes, `offchain/rig/store-conformance.json`, is **committed**, so a fresh
checkout can assert over real database evidence while staying database-independent. On any failure
the previous artifact is put back from a saved copy — a capture that fails must not leave the
operator with a bad artifact and no good one.
