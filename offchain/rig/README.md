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
cabal run cfmm-replicationPlank-rpc-api
```

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

What it still does not prove is the stochastic-driver acceptance bar: `cabal run` is a demo, not
the DRIV-01/DRIV-02 run. Its price writes go to the `PriceSetterPoolManager`, not to the
`DynamicFeeHook` pool, and it does not exercise the cheat-swap path that makes the hook write a
timepoint per step — `deploy-rig.sh`'s probe swap is currently the only thing on the rig that
does.

## The two files

| file | committed? | written by | read by |
|---|---|---|---|
| `offchain/rig/rig-pins.json` | YES | `offchain/rig/generate-pins.sh` (from the imported `src/interfaces/**/*.plk`) | `Rig.Manifest`, the pin tests |
| `offchain/rig/rig-manifest.json` | NO (gitignored) | `offchain/rig/deploy-rig.sh` (from `broadcast/**/run-latest.json`) | `Rig.Manifest`, the drivers |

`generate-pins.sh` is not part of the sequence above because its output is committed. Re-run it
when an interface file changes; it is idempotent, so a run that changes nothing leaves
`git diff` clean.

## Rules

- No address, selector or topic0 is ever typed. Selectors and topic0s are computed from the
  signature strings in the interface files; addresses come from foundry's broadcast records.
- `RIG_PINS` / `RIG_MANIFEST` override the default paths.
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

`verify-rig.sh` probes both routers' `manager()` against the manifest's `PoolManager`. A router
constructed against the *other* live manager has bytecode and passes a liveness probe; only the
binding check sees it.

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
