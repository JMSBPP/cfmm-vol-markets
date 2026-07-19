# Design: `StochasticPriceGen` — a simulated price-path generator driving `write_price`

**Date:** 2026-07-19
**Topic:** A new `StochasticPriceGen.*` library that generates a discrete tick trajectory
under GBM or CEV dynamics and imposes it on the deployed `PriceSetterHook` rig by
sequentially driving `PriceSetter.Rpc.write_price`.
**Scope track:** rpc_api offchain (Haskell) only. Does not touch `PriceSetterHook.sol`,
any other Solidity, or the deploy scripts — consumes `write_price` as a frozen,
already-built interface.
**Status:** design drafted via interactive brainstorming; pending two-step review
(Reality Checker + a specialist — see the open question this raises, addressed below)
before being treated as ready to plan/implement.

## Motivation

`write_price` (built earlier this session) imposes a single tick on the `PriceSetterHook`
rig per call. The natural next step for the tick-experiment rig this hook exists for (per
`PriceSetterHook.sol`'s own doc comment: "off-chain process imposes a stochastic process
on the pool's tick") is to actually generate and impose a *simulated trajectory* — a
sequence of ticks following a real stochastic process — rather than one arbitrary point at
a time.

## Ground truth (verified, not assumed)

- **The requested "CES" process does not exist as a named stochastic process** and has no
  precedent in this repo as a price-path model (`src/exp/CESLongPayoff.plk` uses "CES" for
  an unrelated CFMM *payoff formula*, `π = (P·Δᴵ − Δᴼ)²`). During brainstorming this was
  corrected to **CEV (Constant Elasticity of Variance)**, grounded in a real, directly
  relevant paper: Maymin, "Option Pricing on Automated Market Maker Tokens" (arXiv
  2603.29763, 2026-03-31). **Theorem 1** of that paper: for a constant-weighted-product AMM
  with diffusive net flow `dF = μ_F dt + σ_F dW`, the marginal token price satisfies the
  CEV stochastic differential equation
  ```
  dP = μ(P) dt + δ·P^w·dW(t)
  ```
  where `w` is the pool's numeraire weight (the CEV exponent `β = w`) and `δ` is derived
  from pool depth and flow volatility. For a standard constant-product pool (`w = 1/2`,
  matching `PriceSetterHook`'s deployed rig), `σ_ret(P) = δ/√P` — volatility rises as price
  falls (the "leverage effect"). The paper empirically rejects the GBM null in favor of CEV
  across 90 real AMM pools (median variance elasticity −0.86, p < 0.0001). GBM is CEV's
  degenerate case; the two are NOT parameterizations of the same enum-of-configs by
  accident — they're a genuinely nested family, which this design's shared-step-function
  architecture (below) reflects directly.
  **Scope note — this design does NOT implement the paper's `μ(P)` (equation 13)
  verbatim.** That formula is derived specifically from AMM net-flow dynamics
  (`μ_F`, `σ_F`, pool depth `K`) — a different modeling exercise (deriving CEV *from* AMM
  flow assumptions) than "simulate a CEV price path given chosen parameters." This design
  uses the standard/generic textbook CEV drift-diffusion form (Cox 1975's original
  formulation): `dP = μ·P·dt + δ·P^β·dW` — simple proportional drift `μP`, not the paper's
  AMM-flow-derived `μ(P)`. The paper is cited for *why* CEV (not GBM) is the
  theoretically and empirically appropriate process family for AMM token prices, and for
  the exponent identification `β = w = 1/2` for a constant-product pool — not as a literal
  transcription of its Theorem 1 drift term.
- **`write_price` is not a transaction and there is nothing to batch or optimize at the
  transaction-type/multicall level.** A hook cannot write `PoolManager` storage via
  `sendTransaction` — this is an EVM contract-isolation primitive, not an implementation
  gap (see the brainstorming transcript for the full explanation, confirmed by the user).
  `write_price` does three `eth_call`s plus one `anvil_setStorageAt` node-storage cheat,
  which only exists on local dev nodes (Anvil/Hardhat) and can never become a real-chain
  operation. The actual throughput concern this design addresses is therefore **local
  RPC call-rate against one anvil process**, not blockchain transaction throughput —
  confirmed and reframed with the user before any further design work.
- **`mwc-random` (Hackage/Stackage, resolves against this project's `lts-24.49`/GHC 9.10.3
  snapshot, confirmed via `cabal info` and `stackage.org` lookups)** is the RNG library.
  Verified exact API from the real `mwc-random-0.15.3.0` source:
  - `System.Random.MWC.Distributions.standard :: StatefulGen g m => g -> m Double` —
    standard-normal (mean 0, variance 1) draw. This is what drives each `Z_n` in the
    Euler-Maruyama step.
  - `System.Random.MWC.createSystemRandom :: IO GenIO` — system-entropy-seeded generator,
    for the real demo/production path.
  - `System.Random.MWC.create :: PrimMonad m => m (Gen (PrimState m))` — **fixed default
    seed**, for reproducible test runs (confirmed non-deprecated).
  - **Correction from an earlier draft of this design:** `withSystemRandom` was initially
    proposed for Gen creation but is **deprecated** in `mwc-random-0.15.3.0` (its own
    Haddock: "Use `withSystemRandomST` or `createSystemSeed` or `createSystemRandom`
    instead"). This design uses `createSystemRandom` instead.
  - `GenIO = Gen (PrimState IO)` (type alias) — the `IO`-specialized generator type used
    throughout this design's `IO`-based simulation.
- **Current `PriceSetter.Rpc.write_price` signature** (unchanged, consumed as-is):
  `write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)`.

## Decisions (from brainstorming)

1. **`size` means one path, N steps** — not N independent realizations. `size :: Int` is
   the number of sequential tick observations in a single simulated trajectory.
2. **Both GBM and CEV use Euler-Maruyama discretization**, not exact sampling. CEV's exact
   transition law exists (Cox's noncentral-χ² construction, which is what the paper's own
   closed-form option pricing uses) but needs a noncentral-χ² sampler not available in
   mainstream Haskell RNG libraries — deferred as unnecessary complexity for this feature.
3. **GBM and CEV share one Euler-Maruyama step function**, since GBM is CEV's degenerate
   case: `P_{n+1} = P_n + μ(P_n)·dt + diffusion(P_n)·√dt·Z_n`, where `ProcessType`
   supplies `(μ, diffusion)` — GBM: `μ(P) = μ·P`, `diffusion(P) = σ·P`; CEV: `μ(P)` per
   Theorem 1 above, `diffusion(P) = δ·P^β`. This avoids duplicating the stepping loop.
4. **No multicall, no concurrency for the writes** — each write imposes the next point of
   one continuous trajectory onto the same slot, so writes are strictly sequential by
   construction; concurrent writes would race and produce a nonsensical path. The real
   optimization is **decoupling path generation from RPC execution**: the whole tick path
   is generated as pure(-ish, RNG-state-threaded) data first — zero RPC cost — then driven
   sequentially through `write_price` inside one `runWeb3'` session. This separates "is the
   randomness right" from "is the RPC sequencing right," and makes the one real bottleneck
   (N sequential local RPC round-trips) explicit rather than hidden inside interleaved
   generate-then-write logic.
5. **No tick clamping.** A simulated path can in principle drift outside Uniswap's valid
   tick range (`[MIN_TICK, MAX_TICK] = [-887272, 887272]`), which would make the
   underlying `packSlot0For` call revert. This design does **not** clamp or silently
   distort out-of-range ticks — a path that drifts out of range surfaces as a real
   failure (inheriting `write_price`'s existing failure characteristics, see Error
   handling below), rather than being papered over.
6. **New namespace `StochasticPriceGen.*`**, not folded into `PriceSetter.*` — this is a
   distinct concern (path simulation + orchestration) built *on top of* `write_price`,
   not a peer RPC primitive. Exposed from the same library stanza as `VolOrder.*`/
   `PriceSetter.*`.

## Module breakdown

Four new library modules under `offchain/lib/StochasticPriceGen/`:

- **`StochasticPriceGen.Types`** — the domain types:
  ```haskell
  data ProcessType
    = GBM { mu :: Double, sigma :: Double }
    | CEV { mu :: Double, delta :: Double, beta :: Double }

  data StochasticPriceGen = StochasticPriceGen
    { process      :: ProcessType
    , size          :: Int
    , initial_tick :: Integer
    , dt            :: Double
    }
  ```
  Params live on each `ProcessType` constructor (not a separate shared record) since GBM
  and CEV genuinely have different parameter sets. `dt` is the Euler-Maruyama step size —
  defaults to `1.0` (one unit of simulated time per observation) at the call site, not
  hardcoded in the type. **Exports:** both types fully (`ProcessType(..)`,
  `StochasticPriceGen(..)`).
- **`StochasticPriceGen.Simulate`** — the pure(-ish) math:
  `simulate_path :: GenIO -> StochasticPriceGen -> IO [Integer]`. Internally: one shared
  Euler-Maruyama step (decision 3 above) produces a `[Double]` price path of length
  `size`, seeded at `P_0 = 1.0001 ^ initial_tick` (the standard Uniswap tick→price
  formula, inverted to convert the caller-supplied starting tick into the starting price
  the SDE simulates in); each simulated price then converts back to the nearest tick via
  `tick = round(log(P) / log(1.0001))` — no `tickSpacing` snapping, since
  `packSlot0For` itself doesn't require tick-spacing alignment (only real swap-routing/LP
  logic elsewhere in Uniswap does). **Exports:** `simulate_path`.
- **`StochasticPriceGen.Report`** — thin IO: prints the generated path summary (process
  type/params, size, first/last tick) and per-step progress as `write_price` drives
  through it. **Exports:** a `report_path_write` function taking the list of written
  triples (mirroring `PriceSetter.Report`'s shape).
- **`StochasticPriceGen.Rpc`** — orchestration:
  `run_price_gen :: Address -> StochasticPriceGen -> GenIO -> Web3 [(Address, HexString,
  HexString)]`. Pre-generates the full tick path via `Simulate.simulate_path` (`liftIO`'d
  into the `Web3` action), then folds `PriceSetter.Rpc.write_price hook` sequentially over
  it, returning all N written triples. No printing — reusable, matches `write_price`'s
  and `create_order`'s established shape. **Exports:** `run_price_gen`.

## Data flow

`StochasticPriceGen` config (from `Sample.hs` or a caller) → `Simulate.simulate_path`
(Euler-Maruyama loop over `mwc-random` draws, price→tick conversion) → `[Integer]` (N
ticks, fully generated before any RPC call) → `Rpc.run_price_gen` folds `write_price`
over that list inside the caller's `runWeb3'` session → `Report` prints progress/summary.

## Error handling

If any `write_price` call in the fold fails, the whole sequence aborts — correct, since
continuing to write subsequent path points after a failure would impose a broken/
inconsistent trajectory. This inherits `write_price`'s already-documented failure
characteristics (the `runWeb3'`-`try`-vs-`MonadFail` uncaught-exception gap noted in
`PriceSetter.Rpc.hs`) rather than duplicating or hiding them — `run_price_gen` does not
add its own error-handling layer beyond letting `Web3`'s monadic short-circuit do its job.

## `Main.hs` / `Sample.hs` integration

`Sample.hs` gains `sample_price_gen :: StochasticPriceGen` with modest parameters (e.g.
`size = 5`) — bounded enough to stay a fast demo alongside the existing `create_order`/
`write_price` calls, not a stress test. `Main.hs`'s composition extends to create the
`GenIO` (via `createSystemRandom`, `liftIO`'d) and call `run_price_gen`, reporting the
result alongside the existing receipt/write reports, inside the same single `runWeb3'`
session already established.

## Cabal changes

`library` stanza: `exposed-modules` gains `StochasticPriceGen.Types`,
`StochasticPriceGen.Simulate`, `StochasticPriceGen.Report`, `StochasticPriceGen.Rpc`.
`build-depends` gains `mwc-random` (its transitive deps — `vector`, `primitive`, etc. —
resolve automatically; not listed explicitly, matching how this project has never listed
transitive deps for its other libraries).

## Testing / verification

No unit-test framework exists in this project (consistent with `VolOrder`/`PriceSetter`).
Verification plan:
1. `cabal build` clean, zero `-Wall` warnings.
2. A `cabal repl` smoke test of `simulate_path` using `System.Random.MWC.create`'s fixed
   default seed (reproducible across runs) for both `GBM` and `CEV` `ProcessType`s,
   confirming: the output has exactly `size` elements, all values are finite (no
   NaN/Infinity from a badly-parameterized `P^β` for extreme `P`), and the path is
   deterministic given the fixed seed (two runs with `create` produce identical output).
3. A live end-to-end run at a small `size` (5–10) against the deployed rig: confirm the
   sequence of ticks actually written via `run_price_gen` matches `simulate_path`'s pure
   output for the same seed/parameters exactly, and that the final on-chain tick (via
   `cast call ... readTick()`) matches the path's last element.

## Out of scope (explicit)

- No exact noncentral-χ² CEV sampling (Euler-Maruyama only, decision 2).
- No tick clamping (decision 5) — out-of-range paths fail loudly.
- No multicall/concurrency for the writes (decision 4) — writes are inherently sequential.
- No changes to `PriceSetterHook.sol`, `write_price`, or any other already-built code —
  this design only adds a new consumer on top.
- No "N independent realizations" mode — single-path-per-run only (decision 1); revisit
  if a future need for Monte Carlo-style multi-path generation arises.

## Success criteria (what must be TRUE)

1. `offchain/lib/StochasticPriceGen/{Types,Simulate,Report,Rpc}.hs` exist with the exports
   described above.
2. `simulate_path` is deterministic given a fixed-seed `Gen` (verified via `create`, not
   `createSystemRandom`) — two calls with the same seed and `StochasticPriceGen` config
   produce identical `[Integer]` output.
3. `GBM` and `CEV` share one Euler-Maruyama step implementation, not two duplicated loops.
4. `run_price_gen` never calls `write_price` concurrently — the fold is strictly
   sequential.
5. An out-of-range simulated tick is not clamped — it surfaces as a real failure when
   `write_price`/`packSlot0For` reverts.
6. `cabal build` succeeds cleanly (no warnings) with the cabal diff described above.
7. A live run's written tick sequence matches `simulate_path`'s pure output exactly for
   the same seed/parameters, and the final on-chain tick matches the path's last element.
