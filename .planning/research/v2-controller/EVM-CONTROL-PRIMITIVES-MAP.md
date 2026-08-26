# EVM-CONTROL-PRIMITIVES-MAP — On-chain (Plank) building blocks for a matrix feedback controller

**Generated:** 2026-06-28 · **Mode:** READ-ONLY inventory. No code modified.
**Audience:** designer of the closed-loop adaptive controller (`CTRL-01`/`CTRL-02`, v2).
**Conventions:** paths are absolute; `file:line` where load-bearing. Status tags:
`IMPLEMENTED` / `PARTIAL` / `STUB` / `PARSE-ERROR` / `unknown`.

Companion docs in this dir: `PROJECT-MAP.md` (project + pipeline), `LEAN-MAP.md`
(formalization). This doc covers **on-chain numeric primitives and EVM/Plank
feasibility for matrix/state-space feedback math** only.

> **Worktree note:** the latest Plank work lives on `feat/plank`
> (`/home/jmsbpp/cfmms-playground/cfmm-wt/plank`, HEAD `490b706`). This
> `evm-controller` worktree's `src/` is a *stale mirror* (no `DynamicCFMM.plk`).
> All Plank citations below are against the `cfmm-wt/plank` tree unless noted;
> `DynamicCFMM.plk` only exists in the **main checkout**
> `/home/jmsbpp/cfmms-playground/cfmm-replicationPlank/src/DynamicCFMM.plk`.

---

## 1. Controller-relevant `.plk` source inventory (current state)

| File | Status | What it is / what's there |
|------|--------|----------------------------|
| `src/DynamicCFMM.plk` (main checkout only) | **PARSE-ERROR / STUB** | Intended controller home. Does **not compile**. 29 lines: an `import v3::`, a comment block with the init state `(di=20, i=100, i_l=-120, i_u=120, L(i)=1e18, Y=100e18)`, a `return_runtime` fn, an unused `INIT_STATE` struct (`tickSpacing,tick,tickLower,tickUpper,cashStock : u256`), and empty `init {}` / `run {}`. No xi/iota, no control law, no hook. |
| `src/MarketState.plk` | **STUB (consts only)** | 4 storage-slot constants: `SLOT_VOLATILITY_TERM_STRUCTURE` (keccak), `SLOT_CURRENT_TICK=7`, `SLOT_MARKET_LIQUIDITY=10`. No code, no init/run. A namespaced storage layout sketch. |
| `src/MarketType.plk` | **EMPTY** | 2 bytes, blank. |
| `src/ReferenceMarket.plk` | **IMPLEMENTED (compiles)** | The working on-chain market state contract. Flat storage `SLOT_LIQUIDITY..SLOT_TICK_UPPER (0..4)`; ABI dispatcher with 5 view selectors (liquidity/tickSpacing/currentTick/tickLower/tickUpper) and 5 setters (`setPoolLiquidity 0x08a68255`, `setTickSpacing 0x0693ca3b` w/ int24 sign-extend, `setCurrentTick 0x8f3f8c52`, `setTickLower 0x04211dd1` snaps to spacing via `@evm_sdiv`, `setTickUpper 0x37969917`). **This is the read/write surface a controller would target.** Probed: compiles, 825 bytes hex. |
| `src/types/VolatilityTermStructure.plk` | **PARSE-ERROR / STUB** | Type-constructor sketch `VolatilityTermStructure(priceElasticity, statePartitionDelta, baseTick : BoundedValue)`; struct body has empty field types; trailing `const read = fn(...)` is unterminated. Will not parse. These 3 fields (price elasticity, partition delta, base tick) are the candidate controller parameter vector. |
| `src/types/Numerics.plk` | **PARTIAL / PARSE-RISK** | Number-format machinery: keccak keys `NATURAL/RATIONAL/Q64_96/Q128_128`; `NumberGroupSpec{min,max,step}`; `NumberFormat(key)` (only `NATURAL` branch filled, no return on miss); `BoundedValue(numberFormat,lowerBound,upperBound)` returns `struct{value:u256}`. Has a typo `_max: u265`. Intent: typed bounded fixed-point scalars (saturation metadata) — **not** wired to arithmetic. |
| `src/lib/TickUtils.plk` | **IMPLEMENTED** | V4 `TickMath` port. `Tick = u256` (two's-complement int24); `MIN_TICK=-887272`, `MAX_TICK=887272`; `minUsableTick/maxUsableTick(tickSpacing)` via `@evm_sdiv … *% tickSpacing`. Excellent doc on the signed-in-u256 contract. |
| `src/lib/SwapAmtGen.plk` | **IMPLEMENTED (compiles)** | Deterministic swap-size generator = the η-proxy `Δy(t)=19e18 + 2·KERNEL^(timeIndex⁴·η)` (see NOTES.md). Storage `SLOT_TIME_DECAY`, init `INIT_TIME_DECAY=-10000e18`; getters/setters + `swapAmount` using `@evm_exp/@evm_add/@evm_mul`. WAD bounds 19e18/21e18, `KERNEL=1e14`, `UNITY=1e18`. **A worked example of a time-driven on-chain dynamic law** — closest existing analogue to a controller update. |
| `src/lib/BinomialProxy.plk` | **IMPLEMENTED (compiles)** | RNG proxy: `gen_rand(seed)` returns parity bit; `run` pulls `@evm_difficulty()` (prevrandao) as entropy. The ±1 trade-direction draw. |
| `src/ldf/GeometricDistribution.plk` | **STUB** | 5 empty selector branches (`0x612800c5…`), falls through to `revert_empty()`. Liquidity-density-function placeholder. |
| `src/exp/CESLongPayoff.plk` | **IMPLEMENTED (compiles)** | Stateless CES ½-kernel trader payoff `(P·Δ^I − Δ^O)²` reusing v3 `sqrt_price_math` + `mulDiv`. Probed: compiles, 2041 bytes hex. **Reference for how to compose v3 fixed-point math into a new computation in Plank.** |
| `src/interfaces/IMarketDynamics.plk` | **STUB** | Single const `SELECTOR_INIT_VOL_TERM_STRUCTURE=0xd9c112ef` (`initVolTerm(uint256,uint256,uint256)`). |
| `src/interfaces/IMarketDynamicsLens.plk` | **PARSE-ERROR** | Two selector consts with **empty RHS** (`const SELECTOR_GET_STATE_PARTITION_DELTA =;`). Won't parse. |

**Compile reality (probed with `plank build … --backend sona`):** `ReferenceMarket`,
`CESLongPayoff`, `SwapAmtGen`, `BinomialProxy`, `GeometricDistribution` compile
(artifacts in `cfmm-wt/plank/build/plank/*.hex`). `DynamicCFMM` **fails** — see
`build/plank/src_DynamicCFMM.hex.err`:
```
error: unexpected `const`  --> DynamicCFMM.plk:10:1
error: entry point must end with explicit terminator  (init {} / run {})
```
Root causes: a `const` after `import v3::` with no body between, and `init/run`
must end in a `never` terminator (`@evm_stop()` / `@evm_revert(...)`).

---

## 2. V4 `beforeSwap` hook integration point

**There is no implemented hook anywhere** — no `.plk` and no `.sol` contains
`beforeSwap`/`IHooks`/`BeforeSwapDelta`. The integration is a *design sketch only*.

- **Sketch (authoritative intent):** `cfmm-wt/plank/NOTES.md` —
  ```
  ControllerEntryPoint.sol :: IHook.sol {
      addr plkWrapper;
      beforeSwap() {
         LibCall.callContract(plkWrapper, msg.amount,
             abi.encodeWithSignature(IHooks.beforeSwap))
      }
  }
  ```
  i.e. a thin Solidity hook delegates the controller math to a **deployed Plank
  contract** (`plkWrapper`) via a raw call. This matches the project stance:
  "Solidity/Foundry is thin glue; controller computed entirely in Plank"
  (`PROJECT-MAP.md §1`).

- **Canonical V4 signature available** (in a *nested* copy, see §5 dangling-remap
  caveat) — `cfmm-wt/plank/lib/bunni-v2/lib/v4-core/src/interfaces/IHooks.sol:103`:
  ```solidity
  function beforeSwap(
      address sender,
      PoolKey calldata key,
      IPoolManager.SwapParams calldata params,
      bytes calldata hookData
  ) external returns (bytes4, BeforeSwapDelta, uint24);
  ```
  Return triple lets a hook (a) ack via selector, (b) return a `BeforeSwapDelta`
  to shift in/out amounts, and (c) **override the LP fee** (dynamic-fee pools, bit
  `0x400000`, ≤ 1e6). `BeforeSwapDelta.sol` is alongside.

- **Data available at hook time** for the controller to read:
  `params` (`zeroForOne`, `amountSpecified` int256, `sqrtPriceLimitX96`), `key`
  (pool id, fee, tickSpacing, hooks), plus anything the controller `sload`s from
  its own state or from `ReferenceMarket` (currentTick/liquidity/bounds, §1).
  **What it could write:** the dynamic-fee override (the natural actuator for an
  on-chain feedback law) and/or `BeforeSwapDelta`; or `sstore` updated `xi/iota`
  / vol-term-structure params for the next swap.

- **Deploy path for the Plank side:** `lib/plank-foundry-deployer`
  (remap `plank-foundry-deployer/`), `plankDeployFFI` — compiles `.plk` via FFI
  and deploys; this is how `plkWrapper` would be instantiated in tests/scripts
  (`PROJECT-MAP.md §1`).

- **Uniswap math available to the hook** = the entire `plankified-univ3` lib (§3).
  Note this is **V3-derived** math (`getSqrtRatioAtTick`, `computeSwapStep`,
  `sqrt_price_math`), adequate for single-position sqrt-price/tick reasoning; V4
  pool-manager mechanics themselves are not ported to Plank.

---

## 3. Fixed-point / numeric primitive catalog (Plank)

**Language substrate (critical):** Plank's only numeric type is **`u256`**
(`bool` exists). There are **no native signed, fixed-width, or float types**;
`int24`/`int128`/`int256` are two's-complement values *in* a `u256`, and signed
ops are explicit EVM builtins. (`TickUtils.plk:5-12` documents this.)

**Operators (from `lib/plank-monorepo/std/core_ops.plk` + usage):**
- Wrapping (no overflow check): `+%`, `-%`, `*%`.
- Checked (revert on overflow/underflow): `+`, `-`, `*` (see `checked_add/sub/mul`).
- Division: `</` (checked div-down, used throughout `full_math`/`sqrt_price_math`);
  raw `@evm_div`, `@evm_mod`, `@evm_mulmod`. **No `/` infix for u256 division —
  use `</` or builtins.**
- Bitwise/shift: `&` `|` `^` `~` `<<` `>>`.
- Signed builtins: `@evm_sdiv`, `@evm_smod`, `@evm_slt`, `@evm_sgt`, `@evm_sar`,
  and `-x` (two's-complement negate). Unsigned compare via `<,>,<=,>=,==`.

**Fixed-point scales present:**
- **WAD (1e18):** used as literals (`UNITY=1e18`, bounds 19e18/21e18 in
  `SwapAmtGen.plk:4-11`). No dedicated WAD mul/div lib — done by hand via `mulDiv`.
- **Q64.96 / `sqrtPriceX96`:** `fixed_point_96.plk` → `RESOLUTION=96`, `Q96=1<<96`.
  Full sqrt-price suite in `sqrt_price_math.plk`
  (`getNextSqrtPriceFromAmount0RoundingUp`, `…Amount1RoundingDown`,
  `getAmount0/1DeltaUnsigned`, signed `getAmount0/1Delta`).
- **Q128.128:** key constant in `Numerics.plk`; intermediate scale inside
  `tick_math` (not a typed surface).

**Core math libs** (`cfmm-wt/plank/lib/plankified-univ3/plank/lib/math/`):
| Primitive | Location | Notes |
|-----------|----------|-------|
| `mulDiv(a,b,denom)` / `mulDivRoundingUp` | `full_math.plk:6,58` | Full 512-bit-precision Remco-Bloemen mulDiv. **The workhorse for any fixed-point linear combination.** Reverts on `denom==0` / overflow. |
| `divRoundingUp(x,y)` | `unsafe_math.plk:3` | ceil division. |
| `getSqrtRatioAtTick` / `getTickAtSqrtRatio` | `tick_math.plk:17,60` | tick↔sqrtPrice (the on-chain `exp`/`log` analogues, base 1.0001). |
| `computeSwapStep` | `swap_math.plk` | full single-tick swap step (in/out/fee). |
| `mostSignificantBit` | `bit_math.plk:5` | MSB (used by log/sqrt). |
| `addDelta(x,y)` | `liquidity_math.plk:7` | signed-delta add to uint128 w/ overflow check. |
| `toUint160/toInt128/toInt256` | `safe_cast.plk` | range-checked casts (saturation guards). |
| `min/max/ceil32` | `std/math.plk:1,9,17` | unsigned scalar min/max. |

**Std helpers for state-space work:** `std/mem.plk` (`unsafe_mem_write`, `@mload/@mstore/@mcopy`, `@malloc_uninit/@malloc_zeroed`), `std/type.plk` (`sizeof`, `@field_*`, `@get_field/@set_field`, struct reflection), `std/abi*.plk`, `std/storage.plk`, `std/constructor.plk::return_runtime`.

**What's MISSING for linear algebra (none of these exist anywhere):**
- No vector/matrix type, no `mat·vec` / `mat·mat` multiply.
- No small-matrix inverse / linear solve (no 2×2/3×3 determinant, no Gaussian
  elim, no LU). `sympy`/GAMS do this off-chain; nothing on-chain.
- No **signed fixed-point mul/div** helper (must hand-roll: branch on sign with
  `@evm_slt`, operate on magnitudes via `mulDiv`, re-apply sign). This is the
  single biggest gap for `K·x` gain math with signed states.
- No **saturation/clamp** primitive (only revert-on-overflow casts + `min/max`
  on unsigned). A `clamp(x,lo,hi)` and signed-saturating add must be written.
- No `exp`/`ln`/general `pow` on WAD (only tick-basis 1.0001 via `tick_math`,
  and raw integer `@evm_exp`). No PRBMath/solady-style transcendental lib in Plank.
- No dot-product / accumulator helper; `@evm_mulmod`-based 512-bit accumulation
  would be hand-rolled.

---

## 4. Feasibility & gas for matrix/state-space feedback on EVM (Plank)

**Verdict:** a *small, fixed-dimension, signed-fixed-point* linear update
(`x_{k+1}=A·x_k + B·u_k`, output `u_k = −K·x_k`) is **feasible** in Plank with
hand-written helpers. Heavier linear algebra (online inverse/solve, eigen) is
**not** advisable on-chain.

- **Realistic dimension:** state `n ≤ 3–4`, input/output `m ≤ 2`. The candidate
  state is already small — the 3 `VolatilityTermStructure` params
  (priceElasticity, statePartitionDelta, baseTick) or the (tick, liquidity,
  cashStock) market state. **Matrices `A,B,K` should be compile-time constants**
  (precomputed off-chain in GAMS/sympy), not solved on-chain. An `n×n` update is
  `n²` `mulDiv` + `n²` signed adds per step — for `n=3` that's ~9 `mulDiv`
  (each `mulDiv` ≈ a few hundred gas of EVM mul/mulmod/div) → low thousands of
  gas, trivially affordable inside `beforeSwap`.
- **Representation:** store the state vector as `n` `sstore` slots (signed in
  u256). Gains as constants in code. No dynamic arrays needed → no memory-layout
  risk. `std/type.plk` struct reflection can index a fixed struct as a vector.

**Numerical pitfalls (concrete):**
- **Signedness:** states/gains are signed; `mulDiv` is unsigned. Every product
  `K_ij · x_j` needs explicit sign handling (magnitude via `mulDiv`, sign via
  XOR of operand signs). Forgetting this silently corrupts via two's-complement
  wrap. This is the #1 correctness hazard.
- **Fixed-point scale discipline:** pick ONE scale (WAD recommended for
  controller params; Q96 only where touching sqrt-price). Each `A·x` term is
  `mulDiv(a_ij, x_j, WAD)` to keep scale; a missing `/WAD` blows the scale up by
  1e18 per multiply.
- **Overflow:** `*%` wraps silently; `*` reverts. For a controller you generally
  want **saturation, not revert** (a hook that reverts blocks the swap → DoS).
  So clamp before it can overflow rather than relying on checked `*`. Note
  `CESLongPayoff.plk:42` already documents a real `*%` overflow at ~2^192 — the
  same trap applies to accumulators.
- **Truncation/precision:** integer `</` and `mulDiv` round toward zero; repeated
  feedback steps accumulate bias. Keep intermediate scale high (Q96/Q128) and
  downcast once, mirroring `tick_math`'s Q128.128→Q96 final shift.
- **Division by controller-derived denominators:** `mulDiv` reverts on `denom==0`.
  Any gain/normalizer that can reach 0 must be guarded *before* the call, else the
  swap reverts.
- **Determinism vs. entropy:** if the law consumes `BinomialProxy`/prevrandao,
  it's miner-influenceable — keep stochastic inputs out of the feedback gain
  itself; use them only for the *simulated* order flow, not the control law.

**Bottom line:** treat the EVM as an *evaluator of a precompiled constant-gain
linear controller*, not a solver. Off-chain (GAMS/sympy) designs `A,B,K`; Plank
evaluates `K·x` + saturating state update inside `beforeSwap`. That is well within
EVM gas and Plank's primitive set, *given* two new hand-written helpers:
**signed-fixed-point `mulDiv`** and **signed saturating add/clamp**.

---

## 5. Plank toolchain / build facts (for iterating)

- **Compiler:** `plank v0.1.1` at `/home/jmsbpp/.plank/bin/plank` (managed via
  `plankup`). Source: `lib/plank-monorepo/plankc/`. Backend: **`sona`**.
- **Build invocation (per `Makefile`):**
  ```
  plank build <entry.plk> --dep v3=lib/plankified-univ3/plank/lib/ --backend sona
  ```
  Only **entrypoints** (files with an `init {}` block) compile; pure
  lib/type/interface `.plk` have no `init` and are pulled in via imports.
  `make compile-plank` auto-discovers entrypoints (`grep '^\s*init\s*{'`),
  writes `build/plank/<name>.hex` on success / `<name>.hex.err` on failure.
- **Namespaces:** `v3::…` → remapped by `--dep v3=…/plankified-univ3/plank/lib/`;
  `std::…` → resolved from `lib/plank-monorepo/std/` (built into the toolchain's
  dep resolution). `import v3::math::full_math::{mulDiv}` style.
- **Entrypoint rule (the DynamicCFMM trap):** `init {}` and `run {}` must end in a
  terminating `never` expression (`@evm_stop()`, `@evm_revert(...)`,
  `@evm_invalid()`). Empty `init {}`/`run {}` is a compile error.
- **Foundry side:** `foundry.toml` — `ffi = true` (needed for Plank FFI deploy),
  `fs_permissions` read on `test/gamsDiff/fixtures`, fuzz `runs=10`,
  `fail_on_revert=false`. Tests run **`--via-ir`** (see Makefile `test-utils`,
  `test-pricing-kernel-diff`).
- **Fork tests / RPC:** `[rpc_endpoints] mainnet = …/v2/${API_KEY}` — fork runs
  need `API_KEY` env set. The project's documented test invocation pattern is
  `--via-ir --offline` with `API_KEY` exported (per task brief; offline avoids
  re-fetching deps).
- **Submodule hazard (panoptic):** the develop-gate strips non-closure submodule
  gitlinks so `forge` won't hang recursing into `panoptic-helper`
  (evm-controller log `0dc3045`, `2e96f57`, `9ff9d2a`; MEMORY "Develop gate
  live"). Init submodules **panoptic-safe** — do not recurse panoptic-helper.
- **Dangling remap caveat:** `remappings.txt` maps `v4-core/=lib/v4-core/src/`
  but **`lib/v4-core/` does not exist** at top level — the only V4 sources are
  *nested* under `lib/bunni-v2/lib/v4-core/…`. Any Solidity hook that
  `import "v4-core/..."` will not resolve until that submodule is populated or the
  remap is repointed. (`unknown` whether this is intentional dead remap or pending.)
- **Deploy:** `lib/plank-foundry-deployer` `plankDeployFFI` (remap
  `plank-foundry-deployer/`) compiles+deploys `.plk` from Foundry via FFI.

---

## 6. Unknowns / explicitly not verified

- Exact semantics of Plank `</` vs `*` vs `*%` beyond observed usage + `core_ops`
  (no language spec read; inferred from `std/core_ops.plk`).
- Whether `@evm_difficulty`/`@evm_exp`/`@evm_add` (used in `SwapAmtGen`,
  `BinomialProxy`) are the full builtin set — only the union actually *used* in
  `plankified-univ3` + `std` was enumerated.
- Whether the `v4-core` remap dead-link is intentional (no V4 hook work has begun).
- No gas was actually measured; §4 figures are order-of-magnitude EVM estimates,
  not benchmarked.
- `DynamicCFMM.plk` exists only in the **main checkout**, not in this worktree or
  the `plank` worktree's `src/` — its canonical location for the controller work
  is `unknown` (likely to be (re)created on `feat/evm-controller`).
