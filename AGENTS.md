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
  `develop`: environment approval → `forge` + `plank` jobs on a self-hosted runner. It — not a
  local run of the commands above — is what decides whether work is good (see Contributing).

## Contributing / workflow

**Phases start INLINE, in the current tree.** Do not create a git worktree per phase, feature
or fix — work in the checkout you are already in. (An earlier rule here required a dedicated
worktree per unit of work; it was retired after Phase 1.1.) Tracking issues on `develop` are a
separate matter and still apply.

`d2p-finance/*` are the canonical/upstream repos; `JMSBPP/*` are the develop forks. **All
changes land on the `JMSBPP` fork and reach `d2p-finance` ONLY via pull request
(fork → upstream).** Never push directly to a `d2p-finance` canonical repo.

**CI is the validation gate, not your local machine.** Do NOT establish that work is correct by
compiling or running the suite locally. Push the branch and read the GitHub Actions
`develop-gate` result — the push is accepted only if `develop-gate` passes. Never report work
as verified on the basis of a local build.

## Docs

- Foundry — https://book.getfoundry.sh
- Plank / protocol spec — the `spec/` submodule (`d2p-finance/cfmm-vol-markets-spec`)
