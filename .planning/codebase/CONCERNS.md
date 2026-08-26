# Codebase Concerns

**Analysis Date:** 2026-06-27

---

## 1. No Commit History — Zero Audit Trail

**Issue:** The repository has no commits. Every file in git status is either `AM` (added-then-modified in index), `A` (newly staged), or `??` (untracked). There is no prior history to understand design decisions, intent, or regression baselines.

**Files:** entire repo root
**Impact:** No way to bisect regressions, no record of what changed or why, no stable reference point for reviewers. When the first real commit lands, the entire codebase will appear in a single diff.
**Fix approach:** Make an initial commit of the current state before further work, even if much of it is stub/WIP. Start using conventional commits or at minimum descriptive messages from this point forward.

---

## 2. Implementation Completeness: Most `.plk` Files Are Stubs or Syntax Errors

The vast majority of the Plank source tree is placeholder code that will not compile. Categorized by severity:

**Completely empty modules:**

- `src/MarketType.plk` — 2 lines of whitespace. No declarations of any kind.
- `src/DynamicCFMM.plk` — `init {}` and `run {}` are both empty. The `INIT_STATE` struct is declared but never stored or returned.
- `src/ldf/GeometricDistribution.plk` — 34 lines. Has 5 selector branches in `run {}` but every branch body is empty. Deployed by the LDF test but does nothing.

**Syntax errors that will fail to parse/compile:**

- `src/interfaces/IMarketDynamicsLens.plk` lines 3 and 5: `const SELECTOR_GET_STATE_PARTITION_DELTA =;` and `const SELECTOR_GET_BASE_TICK =;` — missing right-hand side values. These are not valid Plank syntax.
- `src/types/VolatilityTermStructure.plk` lines 12–14: struct field declarations missing type annotations (`priceElasticity:` with no type). Line 19: `const read = fn(_volStructState:VolatilityTermStructure)` — truncated signature with no return type and no body.
- `src/types/Numerics.plk` line 11: `fn (_min: u256, _max: u265, _step: u256)` — typo `u265` instead of `u256`. The `NumberFormat` function body also only handles the `NATURAL` key; all other keys fall through returning nothing.

**Logic / language errors in otherwise-working files:**

- `src/ReferenceMarket.plk` line 75: `uint256 _tickSpacing = @evm_sload(SLOT_TICK_SPACING);` — uses Solidity type syntax (`uint256`) instead of Plank syntax (`u256`). This will likely fail compilation.
- `src/ReferenceMarket.plk` line 76: `let minTick = @evm_sdiv(_tickLower, _tickSpacing) *% _tickSpacing;` — result is never stored or returned. Dead variable. The comment at line 74 says "We set the tickMin to be the tick lower" but the actual `SLOT_TICK_LOWER` is stored from `_tickLower`, not `minTick`.
- `src/lib/SwapAmtGen.plk` line 36: `let timeIndex = timeDecay();` — shadows the function parameter `timeIndex` passed in from the call site. The parameter is silently ignored; every call reads from storage regardless.
- `src/interfaces/IMarketDynamics.plk` — 3 lines, only defines `SELECTOR_INIT_VOL_TERM_STRUCTURE`. No function implementations. The interface is not used anywhere in `src/`.

**Undefined storage slots:**

- `src/MarketState.plk` defines `SLOT_VOLATILITY_TERM_STRUCTURE`, `SLOT_CURRENT_TICK`, and `SLOT_MARKET_LIQUIDITY`, but `src/ReferenceMarket.plk` uses `SLOT_LIQUIDITY`, `SLOT_TICK_SPACING`, `SLOT_TICK_LOWER`, and `SLOT_TICK_UPPER` — none of which are declared anywhere in the repo. These must be implicit or resolved via the `v3::` import, but the dependency is undocumented.

**Fix approach:** Before any new feature work, do a compilation pass (`make build-pool`, `make build-random`, `make build-cash`) and address all parse/compile failures. Mark stub files with `// STUB: not implemented` to distinguish intentional placeholders from errors.

---

## 3. Plank Language Risk: Custom Toolchain, Early Version, No Standard Tooling

**Issue:** Plank (`lib/plank-monorepo`, `lib/plank-foundry-deployer`) is a non-standard, research-oriented EVM language maintained by a small team. Version in use is `v0.1.1` (compiler at `~/.plank/bin/plank`); the monorepo submodule is at `v0.0.1-alpha.2-38-gc6f969f`.

- The compiler is installed via a curl-bash script (`curl -L install.plankevm.org | bash && plankup`) with no lockfile or pinned binary hash. Any developer who installs a different version of `plank` will get different bytecode.
- `ffi = true` in `foundry.toml` enables arbitrary subprocess execution. Forge tests invoke the system `plank` binary by shelling out via `PlankDeployer.plankDeployFFI()`. A missing or version-mismatched binary silently produces wrong results or crashes.
- Tests select backend `'sona'` (`test/LiquidityDensityFunctionPlankTest.t.sol` line 16; `test/Utils.t.sol` line 141), while the `PlankDeployer` defaults to `'sir-debug'`. These are different code generation backends with potentially different semantics; no documentation exists within the repo explaining which is correct for production use.
- `lib/plank-foundry-deployer` is pinned to `heads/main` (floating HEAD, no release tag). `lib/plankified-univ3` is also at `heads/main`. Both can change silently on `git submodule update`.
- LSP/editor support: `lib/plank-monorepo/plank-vscode/` and `lib/plank-monorepo/plank-zed/` exist but are bundled as submodule content, not published extensions. Tree-sitter grammar at `lib/plank-monorepo/plank-tree-sitter/` is available but not integrated into CI.

**Files:** `lib/plank-monorepo/`, `lib/plank-foundry-deployer/src/PlankDeployer.sol`, `foundry.toml`, `Makefile`
**Impact:** Non-reproducible builds, hard onboarding for new contributors, no guarantee of compiler correctness at early alpha version, potential for silent bytecode divergence between developer machines.
**Fix approach:** Pin the `plank` binary version in a `.plank-version` file or via `plankup` pin mechanism. Document the exact install steps in a project-level README. Consider adding a CI step that checks `plank --version` against the required version.

---

## 4. Plank<->GAMS Integration Gap: The Core Research Goal Does Not Exist Yet

**Issue:** The stated goal of this repo is to build adaptive feedback controllers that map GAMS-derived parameter bounds and behavioral theorems back to Plank CFMM contracts. This integration layer does not exist in any form.

- The GAMS files were vendored into `model/` from the external `experiments/gams/` sibling. They are not yet referenced by any file in `src/`, `test/`, or `script/`, and have no shared data format with the Plank side.
- The central GAMS module, `PayoffModule.gms`, is 2 lines: `$include primitives.gms` and a blank line. It is the stub for the entire payoff-replication logic.
- `dynamic/InitState.gms` is 6 lines of parameter initializations with no optimization model or constraint structure.
- `TradingRegion.gms` and `LiquidityKernel.gms` define GAMS equations and parameter grids but produce no output artifacts (no CSV, no JSON, no ABI-compatible encoding) that the Plank side can consume.
- The parameter mapping problem is unresolved: `VolatilityTermStructure` (in `src/types/VolatilityTermStructure.plk`) requires `priceElasticity` (xi in `TradingRegion.gms`), `statePartitionDelta` (iota in `LiquidityKernel.gms`), and `baseTick`. These names exist in both worlds but the mapping from GAMS floating-point scalars to Plank `u256` fixed-point values (WAD/Q64.96) is undefined. The `primitives.gms` file encodes `unity = 1e18` and `precision = 1e12` suggesting awareness of EVM fixed-point, but there is no serialization code.
- There is no described mechanism (script, bridge contract, oracle, off-chain relay) for conveying GAMS optimization outputs to the on-chain Plank contracts.

**Files:** `model/PayoffModule.gms`, `model/dynamic/InitState.gms`, `src/types/VolatilityTermStructure.plk`, `src/interfaces/IMarketDynamics.plk`, `src/interfaces/IMarketDynamicsLens.plk`
**Impact:** The bridge between the mathematical model (GAMS) and the on-chain implementation (Plank) is the entire research contribution. It is currently a zero-line gap. All downstream phases depend on first defining this interface.
**Fix approach:** Define a concrete data exchange format (e.g., JSON parameter file, Solidity ABI-encoded calldata, or a foundry script that reads GAMS `.lst` output). Add the GAMS directory as a tracked git submodule or symlink. Define the fixed-point encoding for each GAMS scalar before writing any Plank type implementations.

---

## 5. Test Coverage: Most Tests Are Empty Shells

**Issue:** The test suite has two files totalling 264 lines but almost no actual assertions.

- `test/LiquidityDensityFunctionPlankTest.t.sol`: 6 test functions declared. Five of them (`test_query_cumulativeAmounts`, `test_inverseCumulativeAmount0`, `test_inverseCumulativeAmount1`, `test_boundary_static_invalidWhenOutOfBounds`, `test_boundary_dynamic_boundedWhenDecoding`) have completely empty bodies — `external virtual { }`. The sixth (`test_liquidityDensity_sumUpToOne`) sets up bounds but has no assertions; it passes trivially.
- `test/Utils.t.sol::test__swapAmountsCorrect`: calls `bound(deltaBlock, ...)` but discards the return value (the result is not assigned). Then calls `_selectTestFork()`. No assertions. This test always passes and verifies nothing.
- `test/Utils.t.sol::test_differentValuesTimeDimension`: has assertions about binomial values being 0 or 1 and alternating, but relies on `@evm_difficulty()` / `block.prevrandao` parity flipping — extremely brittle under EIP-4399 post-merge behavior, and the alternation is forced by `vm.prevrandao(prevDifficulty ^ 1)` which is a mock rather than a real entropy source.
- The `_pingBinomial()` function calls `RAND_GEN.call(abi.encodeWithSignature("ping()"))` but `BinomialProxy.plk` exposes selector `0x5c36b186` with no documented ABI. There is no check that the call succeeded before decoding; a failed call silently returns zero-bytes decoded as 0.
- Fuzz config: `runs = 10` in `foundry.toml`. This is far too low to provide mathematical confidence for financial arithmetic. Industry standard for DeFi is 10,000+.

**Files:** `test/LiquidityDensityFunctionPlankTest.t.sol`, `test/Utils.t.sol`, `foundry.toml`
**Impact:** The test suite provides no verified mathematical guarantees. All critical LDF properties (normalization, monotonicity, inverse functions) are tested with zero assertions.
**Fix approach:** Raise fuzz runs to at minimum 1,000 before any merge. Implement test bodies for all 5 empty LDF tests using the inherited `LiquidityDensityFunctionTest` assertions. Add return value check to `_pingBinomial`. Replace `fail_on_revert = false` with `true` unless there is a specific reason to swallow reverts.

---

## 6. Dependency Sprawl and Version Mismatches

**Issue:** The repo has 8 tracked git submodules and 4 additional untracked library directories under `lib/`.

**Tracked submodules (from `.gitmodules`):**
- `lib/forge-std` — `+` prefix in `git submodule status` means it is at commit `620536fa` which differs from what `.gitmodules` records. Tag `v1.16.1`.
- `lib/bunni-v2` — `+` prefix, at `000f79a3`, differs from recorded; tag `v1.2.1`.
- `lib/plank-monorepo` — `+` prefix, differs from recorded; at `v0.0.1-alpha.2-38`.
- `lib/protocol` (Centrifuge) — `+` prefix, differs from recorded.
- `lib/v3-core` — `+` prefix, differs from recorded.
- `lib/plankified-univ3` — `heads/main` (floating, no tag).
- `lib/plank-foundry-deployer` — `heads/main` (floating, no tag).
- `lib/panoptic-v2-core` — pinned to a named tag `2025-12-c4mr-freeze-107`.

**Untracked (not in `.gitmodules`, present on disk only):**
- `lib/mochi-yield/` — present locally, not committed or tracked.
- `lib/shizo/` — present locally, not committed or tracked.
- `lib/unistrata/` — present locally, not committed or tracked.
- `lib/v4-core/` — present locally, not committed or tracked.

**Usage reality:** Only `bunni-v2` and `plank-foundry-deployer` are actually imported in `src/` or `test/`. `panoptic-v2-core`, `protocol`, `plankified-univ3` (as a Plank dep, not a Solidity import), `forge-std`, `v3-core`, `mochi-yield`, `shizo`, `unistrata`, `v4-core` contribute no direct imports to the project's own source files. The `remappings.txt` file has 44 entries covering deep transitive paths into `panoptic-v2-core`'s own submodules, adding build surface area for paths that are not exercised.

**Files:** `.gitmodules`, `remappings.txt`, `lib/`
**Impact:** The `+` prefix on 5 submodules means `git submodule update` would silently change versions. Untracked libs are invisible to collaborators. 44 remappings for unused dependencies increase `forge build` time and create false import targets.
**Fix approach:** Run `git submodule update --init` and then `git add lib/<name>` to pin each submodule to its current commit. Remove or comment out remappings for libraries not yet imported. Add untracked libs to `.gitmodules` or remove them from `lib/`.

---

## 7. CI Pipeline: Broken by Design

**Issue:** The CI workflow at `.github/workflows/test.yml` will fail or produce misleading results in several ways.

- It sets `FOUNDRY_PROFILE: ci` but `foundry.toml` has no `[profile.ci]` section. Foundry will silently fall back to `[profile.default]`, meaning CI uses the same 10-fuzz-run config as local dev.
- It runs `forge test -vvv` but has no `API_KEY` secret configured. Any test that calls `_bootstrapChain()` will attempt `vm.createSelectFork(vm.rpcUrl("mainnet"))`, fail, and fall back to local chain — the `console2.log("Unable to fork mainnet")` branch. This means CI never tests the forked path.
- `forge fmt --check` will fail if `.plk` files are passed to it; Forge does not format Plank files. Whether this step passes depends on whether Foundry ignores unknown extensions.
- `forge build --sizes` will not compile `.plk` files (only Solidity). The Plank FFI compilation only happens at test time via `plankDeployFFI`. If the system `plank` binary is not installed on the CI runner, all Plank-based tests will revert silently (FFI failure returns empty bytes which `_deploy` interprets as a zero-address, causing a revert).
- Workflow uses `actions/checkout@v5` which does not exist as of the knowledge cutoff; the latest stable is `v4`. This will cause the CI job to fail to find the action.

**Files:** `.github/workflows/test.yml`, `foundry.toml`
**Impact:** CI provides no real confidence. Fork tests are silently skipped. Plank compilation is never verified in CI.
**Fix approach:** Add `[profile.ci]` to `foundry.toml` with appropriate fuzz runs. Add the `API_KEY` as a GitHub Actions secret and inject it as `API_KEY: ${{ secrets.ALCHEMY_API_KEY }}` in the env block. Add a CI step to install the plank toolchain before running tests. Fix the checkout action version to `v4`.

---

## 8. Randomness / Entropy Source: Fragile and Non-Standard

**Issue:** `src/lib/BinomialProxy.plk` uses `@evm_difficulty()` to read `block.prevrandao` as a source of randomness, producing a 1-bit "binomial" sample by checking the parity of the value.

- Post-merge EIP-4399 renamed `DIFFICULTY` to `PREVRANDAO`. The opcode returns the beacon chain RANDAO value, which is manipulable by the block proposer within a slot. This is not cryptographically secure randomness.
- The "binomial" distribution produces only 0 or 1 based on a single bit of `prevrandao`, which is not a binomial distribution and has no calibrated probability parameter.
- The test in `Utils.t.sol::test_differentValuesTimeDimension` forces alternation by calling `vm.prevrandao(prevDifficulty ^ 1)`. This tests the mock infrastructure, not the actual randomness source.
- `SwapAmtGen.plk` uses a deterministic formula `19e18 + 2 * KERNEL^(timeIndex^4 * decay)` as the "proxy" for a Poisson-Lognormal swap flow process. The formula is documented in `notes/STOCHASTIC_MODEL.md` as a deterministic approximation, but the exponentiation chain (`@evm_exp(timeIndex,4)` then `@evm_mul` with `SLOT_TIME_DECAY`) is likely to overflow `u256` for any non-trivial `timeIndex` value given `KERNEL = 1e14` and `INIT_TIME_DECAY = -10000e18`.

**Files:** `src/lib/BinomialProxy.plk`, `src/lib/SwapAmtGen.plk`, `test/Utils.t.sol`
**Impact:** The stochastic simulation layer (which drives swap flow for replication testing) is either trivially manipulable or prone to arithmetic overflow. Results from simulations using this module cannot be trusted as representative of real market dynamics.
**Fix approach:** For on-chain entropy, use Chainlink VRF or commit-reveal schemes. For simulation purposes in tests, consider using Foundry's `vm.randomUint()` or a seeded PRNG. Verify the `SwapAmtGen` formula for overflow at expected `timeIndex` ranges before use.

---

## 9. Scaffold Code Not Removed

**Issue:** `src/Counter.sol` and `script/Counter.s.sol` are the default Foundry project scaffold files with no connection to CFMM research.

**Files:** `src/Counter.sol`, `script/Counter.s.sol`
**Impact:** Noise in the codebase. `forge build --sizes` in CI includes `Counter` in output. `forge fmt --check` will format it. The deploy script points to a `Counter` contract deployment which has no research purpose.
**Fix approach:** Delete both files.

---

## 10. `refs/` Directory: Unrelated Web App Committed in Repo

**Issue:** `refs/` contains a complete Next.js web application (with `node_modules/`, `pnpm-lock.yaml`, `tsconfig.json`, `babel/`, `components/`, `pages/`, etc.). Based on structure, this appears to be the Plank playground IDE or a similar reference implementation. It is 7MB+ of content tracked in the repo root with no explanation.

**Files:** `refs/` (entire directory)
**Impact:** Inflates repo size, confuses scope, `node_modules/` in a Solidity/Plank research repo is unexpected. Git submodule status lists this as a directory of files, not as a submodule.
**Fix approach:** Either move to a separate repo, or add a `refs/README.md` explaining its purpose and add `refs/node_modules/` to `.gitignore`.

---

## 11. README Is Default Foundry Template

**Issue:** `README.md` contains only the boilerplate Foundry README describing `forge`, `cast`, `anvil`, and `chisel`. There is no project description, research context, setup instructions, or architecture overview.

**Files:** `README.md`
**Impact:** New contributors (or future-self) have no entry point into the project's goals, the Plank/GAMS duality, or the setup required to run anything.
**Fix approach:** Replace with project-specific content covering research goals, the two-track architecture (Plank + GAMS), prerequisites (`plank v0.1.1`, GAMS 54+, Foundry), and how to run tests.

---

## 12. Missing Critical Features (Blocking Research Progress)

**Area: Controller Logic**
- Problem: No adaptive feedback controller exists anywhere in the codebase. `DynamicCFMM.plk` is the intended home (based on its name) but has empty `init` and `run` blocks. There is no fee-rate adaptation logic, no LDF parameter update mechanism, and no hook integration point.
- Blocks: The entire stated research goal.

**Area: LDF Parameter Encoding**
- Problem: `GeometricDistribution.plk` has the 5 recognized selectors wired but all branches are empty. The `alpha` parameter (used in the test bounds `MIN_ALPHA = 1e3`, `MAX_ALPHA = 12e8`) has no encoding, storage, or computation logic.
- Blocks: LDF tests cannot pass even if test bodies are filled in.

**Area: VolatilityTermStructure Storage/Read**
- Problem: `VolatilityTermStructure.plk` defines the type but the struct fields have no types and the `read` function has no body. `ReferenceMarket.plk` stores a raw `@evm_calldataload(0)` into the constructor call without wrapping it in this type.
- Blocks: Any controller logic that reads or writes the volatility term structure.

**Area: GAMS-to-Plank Parameter Bridge**
- Problem: Defined in detail under Concern 4 above. No bridge exists.
- Blocks: Closed-loop parameter adaptation.

---

*Concerns audit: 2026-06-27*
