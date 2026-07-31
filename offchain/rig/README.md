# The Phase 20 rig

One command stands up the full V2 contract set on a local anvil and writes the manifest the
Haskell drivers read at startup.

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

cabal build -j all && cabal test # SC-3/SC-4: manifest loads; every pin recomputes
cabal run cfmm-replicationPlank-rpc-api
```

`offchain/rig/deploy-rig.sh --stop` kills the anvil the rig owns.

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
| `cabal test` | `cast` on PATH, and a running rig — it does NOT skip when the rig is down, it fails |

### What the last step does and does not prove

`cabal run` exercises the whole path — it loads the manifest, sends transactions, writes prices,
runs both generators and reports. Every address it uses comes from the rig.

It does NOT yet place a vol order. The driver's encoder still builds the retired three-argument
`create_order` call, while the deployed V2 module dispatches the four-argument one, so that first
transaction comes back `status reverted` and the batch reports its orders skipped. That is a known
gap in the driver, not a fault in the rig: `verify-rig.sh` reads the same contract live, and the
pinned V2 signature is in `rig-pins.json` already. Re-pinning the encoder and the event decoder
against it is the next phase's work.

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

## The seven contracts

`deploy-rig.sh` runs five deploy scripts and records seven contracts under `contracts` in the
manifest: `VolOrderManagerMod`, `RealizedVolatilityMod`, `DynamicFeeMod`, `DynamicFeeHook`,
`PoolManager`, `PriceSetterHook`, `PriceSetterPoolManager`. All seven are mandatory — a manifest
missing one is a broken rig, and `Rig.Manifest` refuses to load it rather than handing a driver a
zero address.

The manifest also carries `accounts` (`deployer`, `sender`), `pool`
(`poolId`, `currency0`, `currency1`, `tickSpacing`), `seed` (`initTs`, `initTick`), `chainId`,
`generatedAt` and `generatedFrom` (the upstream sha the artifacts were imported from).

## Reproducibility

`deploy-rig.sh` kills the previous anvil and starts a fresh chain, so every run is from scratch.
Two runs produce a byte-identical manifest once the timestamp is excluded:

```bash
offchain/rig/deploy-rig.sh && jq -S 'del(.generatedAt)' offchain/rig/rig-manifest.json > /tmp/run1.json
offchain/rig/deploy-rig.sh && jq -S 'del(.generatedAt)' offchain/rig/rig-manifest.json > /tmp/run2.json
diff -u /tmp/run1.json /tmp/run2.json    # empty
```

`generatedAt` differs between the two, which is what shows the second run actually regenerated the
file rather than the comparison reading one file twice.

Nothing in the rig reads the wall clock for anything else. The TWAP seed is a fixed literal inside
`deploy-rig.sh`: a clock-derived seed would still pass the manifest diff above — the seed is not a
manifest field — while silently making the rig's on-chain STATE irreproducible.
