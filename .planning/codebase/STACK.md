# Technology Stack

**Analysis Date:** 2026-06-27

## Languages

**Primary:**
- **Plank** (`.plk`) - Custom EVM-targeting language used for all protocol business logic.
  All smart contracts under `src/` are written in Plank (`.plk` extension). Plank's only
  numeric primitive is `u256`; signed integers (`int24` ticks, etc.) are represented as
  two's-complement values inside `u256` and operated on via EVM signed-arithmetic builtins
  (`@evm_sdiv`, `@evm_slt`, etc.). Plank has explicit `init {}` and `run {}` blocks that
  map directly to EVM constructor and runtime bytecode sections. `@evm_*` and `@malloc_uninit`
  are compiler intrinsics, not library calls.

- **Solidity** (`^0.8.0` / `^0.8.13`) - Used exclusively for test harnesses and the
  Foundry-facing deployer glue. No production protocol logic lives in Solidity files under
  `src/`. Key Solidity files in this project:
  - `src/Counter.sol` - scaffold placeholder
  - `test/Utils.t.sol` - base test contract (inherits `PlankDeployer`)
  - `test/LiquidityDensityFunctionPlankTest.t.sol` - LDF fuzz tests
  - `script/Counter.s.sol` - unused deploy scaffold

**Compiler Implementation Language:**
- **Rust** (edition 2024, rustc 1.93.1) - The Plank compiler (`plankc`) is a Cargo
  workspace inside `lib/plank-monorepo/plankc/`. Not used for any on-chain code.

**Secondary / Research:**
- **GAMS** (General Algebraic Modeling System) - Used in the sibling companion at
  `/home/jmsbpp/cfmms-playground/experiments/gams/` for mathematical modeling of CFMM
  payoff structures. Not compiled into or called from this Foundry project.

## Runtime

**Environment:**
- EVM (Ethereum Virtual Machine) — compile target for both Plank and Solidity artifacts.
  EVM version: **cancun** (set in `lib/plank-foundry-deployer/foundry.toml`; this flows
  through to the `--evm-version` flag passed to `plank build`).

**Rust Runtime (compiler only):**
- rustc 1.93.1 / cargo 1.93.1

## Package Manager

**Solidity / Foundry:**
- **Foundry** (forge 1.5.1-stable, commit b0a9dd9c) — dependency management via git
  submodules (no npm/yarn for Solidity deps in this project root).
- Lockfile: `foundry.lock` — pins exact commits/tags for all submodules.

**Rust (compiler):**
- Cargo — workspace defined in `lib/plank-monorepo/plankc/Cargo.toml`.
- Lockfile: `lib/plank-monorepo/plankc/Cargo.lock`.

## Frameworks

**Core Testing:**
- **Foundry / Forge** v1.5.1-stable — test runner, fuzzer, fork-testing, FFI bridge.
  All `.t.sol` test files use `forge-std`'s `Test` base contract.
- Fuzz configuration: `runs = 10`, `fail_on_revert = false` (see `foundry.toml`).

**Plank Toolchain:**
- **plank** CLI v0.1.1 — installed at `~/.plank/bin/plank`.
  Installed via `plankup` (install script: `curl -L install.plankevm.org | bash && plankup`).
  Standard library at `~/.plank/stdlib/` (mirrors `lib/plank-monorepo/std/`).
- **plank build** — compiles a `.plk` file to EVM initcode (raw bytes), printed to stdout.
  Used with `--backend sona` (Sonatina optimizing backend) or `--backend sir` (debug).
  Optimization flag `-O csud` (SCCP + copy-prop + unused-elim + defrag).

**Plank-to-Foundry Bridge:**
- `lib/plank-foundry-deployer/src/PlankDeployer.sol` — abstract Solidity base contract.
  Exposes `plankBuildFFI(path, opts)` (returns raw initcode bytes via `vm.ffi`) and
  `plankDeployFFI(path, opts)` (compiles + deploys in one call using `CREATE`).
  Requires `ffi = true` in `foundry.toml`.
- `lib/plank-foundry-deployer/src/mini-vm.sol` — minimal `vmFFI` helper used by the deployer.

## Plank Compiler Architecture

The compiler pipeline (all code in `lib/plank-monorepo/plankc/`):

```
Source (.plk)
  → Lexer/Parser  (frontend/parser)      — error-resilient CST + AST wrappers
  → HIR Gen       (frontend/hir)         — untyped high-level IR
  → Evaluator     (frontend/hir-eval)    — comptime eval, monomorphize, type-check
  → MIR Lower     (frontend/mir-lower)   — flatten structs, build CFG, basic blocks
  → SIR           (sir/)                 — Sensei IR: EVM-specific low-level IR
      ├── debug backend (sir-debug)      — fast codegen, no optimization
      └── sona backend  (frontend/mir-lower-sona) — via Sonatina (sonatina-codegen,
                                                     sonatina-ir, sonatina-triple from
                                                     fe-lang/sonatina@5987a72)
  → EVM initcode  (raw bytes, stdout)
```

Backends selected via `--backend sir` (default) or `--backend sona` (used in all
Makefile targets and test `setUp()` calls for this project).

## Key Dependencies

**Critical (git submodules, pinned in `foundry.lock`):**

| Submodule | Tag / Rev | Purpose |
|-----------|-----------|---------|
| `lib/forge-std` | v1.16.1 | Foundry test utilities (`Test`, `console2`, `vm`) |
| `lib/plank-monorepo` | v0.1.1 | Plank compiler, std library, tooling |
| `lib/plank-foundry-deployer` | rev 24fe42f | Solidity FFI bridge for Plank build+deploy |
| `lib/plankified-univ3` | rev 9a89319 | Uniswap V3 math ported to Plank (used as `--dep v3=lib/plankified-univ3/plank/lib/`) |
| `lib/bunni-v2` | v1.2.1 | Bunni v2 protocol (LDF interfaces, test base) |
| `lib/panoptic-v2-core` | rev 5555b32 | Panoptic v2 (brings v3-core, v3-periphery, solady, clones-with-immutable-args) |
| `lib/v3-core` | branch 0.8 | Uniswap V3 core (Solidity 0.8 branch) |
| `lib/protocol` | v3.2.0 | Centrifuge protocol (multi-chain structured products) |
| `lib/unistrata` | untracked | Unistrata Uniswap v4 hook + Reactive Network |
| `lib/shizo` | untracked | Schizō ILBondHook (Uniswap v4 + Reactive Network) |
| `lib/mochi-yield` | untracked | Mochi Yield fixed-income Uniswap v4 hook |
| `lib/v4-core` | untracked | Uniswap V4 core (PoolManager) |

**Solidity utility libraries (transitive, remapped):**
- `solady` — via `lib/panoptic-v2-core/lib/solady/src/` (remapped as `solady/`)
- `openzeppelin-contracts` — via `lib/v4-core/lib/openzeppelin-contracts/` (remapped as `openzeppelin-contracts/`, `@openzeppelin/`)
- `permit2` — via `lib/bunni-v2/lib/permit2/`
- `solmate` — via `lib/v4-core/lib/solmate/`
- `clones-with-immutable-args` — via `lib/panoptic-v2-core/lib/clones-with-immutable-args/src/`
- `reactive-lib` — via `lib/shizo/lib/reactive-lib/` (Reactive Network base contracts)

**Rust crates (Plank compiler, key dependencies):**
- `logos` 0.16 — lexer
- `chumsky` 0.11 — parser combinators
- `alloy-primitives` 1.1.2 — EVM primitive types
- `sonatina-codegen`, `sonatina-ir`, `sonatina-triple` — Sonatina EVM backend (from `fe-lang/sonatina@5987a72`)
- `bumpalo`, `allocator-api2` — arena allocator (O(1) allocation model enforced throughout)

## Configuration

**Foundry (`foundry.toml`):**
```toml
[profile.default]
src    = "src"
out    = "out"
test   = "test"
libs   = ["lib"]
ffi    = true          # REQUIRED: enables vm.ffi() for Plank compilation

[fuzz]
runs           = 10
fail_on_revert = false

[rpc_endpoints]
mainnet = "https://eth-mainnet.g.alchemy.com/v2/${API_KEY}"
```

**Environment (`.env` — do not commit values):**
- `API_KEY` — Alchemy API key for Ethereum mainnet RPC (used in fork tests via `vm.createSelectFork(vm.rpcUrl("mainnet"))`)

**Remappings (`remappings.txt`):**
Full remapping table at `remappings.txt`. Key entries for this project's own code:
- `plank-foundry-deployer/` → `lib/plank-foundry-deployer/src/`
- `plankified-univ3/` → `lib/plankified-univ3/contracts/`
- `forge-std/` → `lib/forge-std/src/`
- `bunni-v2/` → `lib/bunni-v2/`
- `v4-core/` → `lib/v4-core/src/`
- `panoptic-v2-core/` → `lib/panoptic-v2-core/`

**Makefile (`Makefile`):**
Three build targets that invoke the `plank` CLI directly:
- `build-random` — compiles `src/lib/BinomialProxy.plk` with `--backend sona`
- `build-cash` — compiles `src/lib/SwapAmtGen.plk` with `--backend sona`
- `build-pool` — compiles `src/ReferenceMarket.plk` with `--backend sona`
All targets pass `--dep v3=lib/plankified-univ3/plank/lib/` for V3 math.

**Plank module system (`--dep` flag):**
Plank uses named dependency namespaces. Current project uses:
- `v3` → `lib/plankified-univ3/plank/lib/` (V3 math, `util.plk`, etc.)
- `std` → provided automatically from `~/.plank/stdlib/`
Import syntax: `import v3::util::{revert_empty, return_u256};`

## Platform Requirements

**Development:**
- Foundry (forge 1.5.1+) — `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Plank v0.1.1 — `curl -L install.plankevm.org | bash && plankup`
- Rust 1.93+ / Cargo (only needed to build the Plank compiler from source; not required when using the pre-built binary)
- `ffi = true` must be set in `foundry.toml` (already set)
- Alchemy API key in `.env` as `API_KEY` for fork tests (tests fall back to local chain if fork fails)

**CI (`.github/workflows/test.yml`):**
- Runs on `ubuntu-latest`
- Steps: checkout (recursive submodules) → install Foundry via `foundry-rs/foundry-toolchain@v1` → `forge fmt --check` → `forge build --sizes` → `forge test -vvv`
- Does NOT install the Plank compiler in CI (Plank FFI calls will fail unless `plank` is added to the CI PATH)

**Production:**
- Target: EVM chains compatible with the **cancun** hardfork
- No deployment scripts present yet (`script/Counter.s.sol` is a scaffold placeholder)

---

*Stack analysis: 2026-06-27*
