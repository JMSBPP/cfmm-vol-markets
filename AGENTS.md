# cfmm-vol-markets — agent guide

The on-chain protocol core for typed volatility markets. The build is **Foundry + the
Plank toolchain** — there is no Hardhat step (the Hardhat sample scaffold was removed).

## Project layout

```
src/              Plank (*.plk) + Solidity (*.sol) protocol sources
test/             Foundry tests (*.t.sol)
foundry-scripts/  Foundry scripts (forge script)
lib/              submodule dependencies (forge-std, panoptic-v2-core, plank-monorepo, …)
spec/ offchain/ refs/   canonical-repo submodules (see README "Repository split")
notes/            binding spec docs (DATA_CONTRACT.md, UNITS_AND_SCALES.md)
.planning/        GSD planning tree
```

## Working in this project

- **Build/test:** `make plank-toolchain` (build the Plank compiler from the pinned
  `lib/plank-monorepo`), `make compile-plank` (compile Plank entrypoints), and
  `forge test --via-ir --offline` (Foundry suite). `npm ci --ignore-scripts` is required —
  it installs the `@cryptoalgebra/*` Solidity sources that `remappings.txt` maps into
  `node_modules/` (a hard forge dependency, not a Hardhat/JS runtime).
- **The `notes/` docs are binding spec** (`DATA_CONTRACT.md`, `UNITS_AND_SCALES.md`) and are
  cited from `src/*.plk` comments — treat their notation as authoritative.
- **`develop-gate`** (`.github/workflows/develop-gate.yml`) is the sole required check on
  `develop`: environment approval → `forge` + `plank` jobs on a self-hosted runner.

## Contributing / workflow

`d2p-finance/*` are the canonical/upstream repos; `JMSBPP/*` are the develop forks. **All
changes land on the `JMSBPP` fork and reach `d2p-finance` ONLY via pull request
(fork → upstream).** Never push directly to a `d2p-finance` canonical repo.

## Docs

- Foundry — https://book.getfoundry.sh
- Plank / protocol spec — the `spec/` submodule (`d2p-finance/cfmm-vol-markets-spec`)
