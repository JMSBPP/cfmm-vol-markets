# Design: `StochasticPriceGen` — a simulated price-path generator driving `write_price`

**Date:** 2026-07-19
**Topic:** A new `StochasticPriceGen.*` library that generates a discrete tick trajectory
under GBM or CEV dynamics and imposes it on the deployed `PriceSetterHook` rig by
sequentially driving `PriceSetter.Rpc.write_price`.
**Scope track:** rpc_api offchain (Haskell) only. Does not touch `PriceSetterHook.sol`,
any other Solidity, or the deploy scripts — consumes `write_price` as a frozen,
already-built interface.
**Status:** two-step reviewed (Reality Checker + Model QA Specialist). One BLOCKER folded
in (Decision 3 self-contradicted the Scope note on what CEV's drift actually is), five
MAJORs folded in (an unguarded Euler-Maruyama step can silently NaN-cascade into a
misleading "tick out of range" failure; "90 real AMM pools" overstated the paper's actual
90-Bittensor-subnet sample; the GBM-nesting framing conflated the paper's own K→∞
mechanism with the generic Cox-1975 β=1 mechanism this design actually uses; the no-clamp
decision didn't state which of `write_price`'s two failure modes applies, or that earlier
writes in a failed fold already landed on-chain even though the return value is lost),
plus MEDIUM/MINOR fixes to the reproducibility claim and the `Report`/`Rpc` module
boundary. No reviewer flagged a BLOCKER on the core architecture (module breakdown, CEV
citation validity, or the Haskell library API claims — all independently verified against
real sources).

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
  in a cross-sectional test across **90 Bittensor subnets specifically** (median variance
  elasticity −0.86, IQR [−0.98, −0.71], p < 0.0001) — not "90 real AMM pools" generally;
  an earlier draft of this spec overstated the sample's generality, corrected here.
  **This design does NOT implement the paper's `μ(P)` (equation 13) verbatim** — that
  formula is derived specifically from AMM net-flow dynamics (`μ_F`, `σ_F`, pool depth
  `K`), a different modeling exercise (deriving CEV *from* AMM flow assumptions) than
  "simulate a CEV price path given chosen parameters." This design instead uses the
  standard/generic textbook CEV drift-diffusion form (Cox 1975's original formulation):
  `dP = μ·P·dt + δ·P^β·dW` — simple proportional drift `μP`, not the paper's
  AMM-flow-derived `μ(P)`. The paper is cited for *why* CEV (not GBM) is the
  theoretically and empirically appropriate process family for AMM token prices, and for
  the exponent identification `β = w = 1/2` for a constant-product pool — not as a literal
  transcription of its Theorem 1 drift term.
  **On "GBM is CEV's degenerate case" — two distinct nesting mechanisms, not one.** The
  paper's own model nests Black–Scholes as the limit of *infinite pool depth*
  (`K → ∞`) with the exponent `β = w` held fixed at the pool's weight — setting `β = 1` in
  the paper's own model would instead mean `w = 1`, a degenerate one-sided pool, which is
  a different and unrelated statement. The nesting this design actually relies on is the
  separate, standard fact about the **generic Cox (1975) CEV family** it implements
  (`dP = μP dt + δP^β dW`): setting `β = 1` there makes the diffusion term `δP`, which is
  exactly GBM's `σP` with `δ = σ`, and the drift `μP` is already GBM's drift independent of
  `β`. This generic-family nesting is what justifies decision 3's shared step function
  below — it is unrelated to the paper's own `K → ∞` nesting, and this design does not
  claim the paper's nesting mechanism applies here.
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
3. **GBM and CEV share one Euler-Maruyama step function**, since GBM is the generic
   Cox-1975 CEV family's degenerate case at `β = 1` (see the Ground truth note above —
   this is a different nesting fact than the paper's own `K → ∞` nesting):
   `P_{n+1} = P_n + μ(P_n)·dt + diffusion(P_n)·√dt·Z_n`, where `ProcessType` supplies
   `(μ, diffusion)` — GBM: `μ(P) = μ·P`, `diffusion(P) = σ·P`; CEV: `μ(P) = μ·P` (the
   same simple proportional drift as GBM — CEV and GBM differ only in the diffusion
   term here, not the drift; this design does **not** use the paper's AMM-flow-derived
   `μ(P)`, per the Ground truth Scope note above), `diffusion(P) = δ·P^β`. This avoids
   duplicating the stepping loop.
4. **No multicall, no concurrency for the writes** — each write imposes the next point of
   one continuous trajectory onto the same slot, so writes are strictly sequential by
   construction; concurrent writes would race and produce a nonsensical path. The real
   optimization is **decoupling path generation from RPC execution**: the whole tick path
   is generated as pure(-ish, RNG-state-threaded) data first — zero RPC cost — then driven
   sequentially through `write_price` inside one `runWeb3'` session. This separates "is the
   randomness right" from "is the RPC sequencing right," and makes the one real bottleneck
   (N sequential local RPC round-trips) explicit rather than hidden inside interleaved
   generate-then-write logic.
5. **Explicit domain guard on every Euler-Maruyama step (added in review — the original
   draft had none).** Verified empirically: Haskell's `(**)` returns `NaN` for a negative
   base with a fractional exponent (`(-5.0) ** 0.5 = NaN`), which the CEV diffusion term
   `P^β` hits directly the first time a step overshoots to a non-positive price; `log` of
   a non-positive value is likewise `NaN`, which the tick-conversion formula (below) hits
   too. Critically, `round(NaN)` does **not** throw — it silently returns a nonsensical,
   implementation-defined huge `Integer`. Left unguarded, this huge garbage value usually
   (not guaranteed) happens to fall outside the valid tick range and gets caught by
   decision 6's out-of-range check below — but with a misleading failure signature ("tick
   out of range") that hides the real cause (an unguarded non-positive price step) from
   whoever is debugging it. **Fix:** `simulate_path` checks `P_n > 0` (and finite) after
   computing each step, *before* computing `P^β` or `log(P)` for that step, and fails
   immediately with a clear, distinguishable error (e.g. `"simulated price went
   non-positive at step N"`) if violated — rather than let it silently cascade into a
   confusing downstream symptom.
6. **No tick clamping**, and an explicit statement of what actually happens when a path
   goes out of range (added in review — the original draft cited `write_price`'s "existing
   failure characteristics" without saying which one applies). A simulated path can in
   principle drift outside Uniswap's valid tick range (`[MIN_TICK, MAX_TICK] =
   [-887272, 887272]`), which makes the underlying `packSlot0For` `eth_call` revert
   on-chain. This design does **not** clamp or silently distort such a tick — it lets the
   revert propagate. What that propagation actually looks like is **not fully known**:
   `PriceSetter.Rpc.hs`'s own code comment documents one *empirically observed* failure
   mode (a decode failure on empty `eth_call` data escapes `runWeb3'`'s `Left` handling
   entirely as an uncaught `IOException`, via `Web3`'s `MonadFail` instance) but an
   on-chain revert from `packSlot0For` itself goes through the same `remote`-based
   `eth_call` mechanism and has never been empirically tested — it may surface as a clean
   `Left` or may also escape uncaught; this design does not resolve that uncertainty, it
   only declines to paper over it with clamping. Practically: because `write_price` calls
   are sequential and non-atomic (decision 4), any writes that succeeded *before* a
   mid-path failure **did land on-chain** even though `run_price_gen`'s in-process return
   value is lost when the whole `Web3` action aborts — a caller that needs to know how far
   a failed run actually got must check on-chain state directly (e.g. `readTick()`), not
   rely on `run_price_gen`'s return value.
7. **New namespace `StochasticPriceGen.*`**, not folded into `PriceSetter.*` — this is a
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
  Euler-Maruyama step (decision 3 above) with the domain guard from decision 5 above
  produces a `[Double]` price path of length `size`, seeded at `P_0 = 1.0001 ^
  initial_tick` (a synthetic-price convention *inverting* the tick-conversion formula
  below — not literally Uniswap's own `TickMath`, which uses `floor`, not `round`; see
  the next line); each simulated price then converts to the nearest tick via `tick =
  round(log(P) / log(1.0001))` — deliberately `round` rather than `floor`, since there is
  no true on-chain tick for a synthetic price and nearest is the more faithful mapping
  for this generator's purpose — no `tickSpacing` snapping, since `packSlot0For` itself
  doesn't require tick-spacing alignment (only real swap-routing/LP logic elsewhere in
  Uniswap does). **Exports:** `simulate_path`.
- **`StochasticPriceGen.Report`** — thin IO: prints the generated path summary (process
  type/params, size, first/last tick) and the full sequence of written triples, **once,
  after the whole run completes** — not interleaved per-step reporting during the fold
  (matching every other `Report` module in this codebase, which all report once after
  their `Web3` action finishes, not live). **Exports:** a `report_path_write` function
  taking the list of written triples (mirroring `PriceSetter.Report`'s shape).
- **`StochasticPriceGen.Rpc`** — orchestration, mirroring the `write_price`/
  `write_price_and_report` two-tier split already established in `PriceSetter.Rpc`:
  - `run_price_gen :: Address -> StochasticPriceGen -> GenIO -> Web3 [(Address, HexString,
    HexString)]` — pre-generates the full tick path via `Simulate.simulate_path`
    (`liftIO`'d into the `Web3` action), then folds `PriceSetter.Rpc.write_price hook`
    sequentially over it, returning all N written triples. No printing — reusable.
  - `run_price_gen_and_report :: Address -> StochasticPriceGen -> GenIO -> IO ()` — the
    thin `IO` wrapper: runs `run_price_gen` via `runWeb3'`, prints the `Web3Error` on
    `Left` or calls `Report.report_path_write` on `Right`. This, not the bare
    `run_price_gen`, is what a caller wanting console output uses (matching
    `write_price_and_report`'s role).
  - **Exports:** `run_price_gen`, `run_price_gen_and_report`.

## Data flow

`StochasticPriceGen` config (from `Sample.hs` or a caller) → `Simulate.simulate_path`
(Euler-Maruyama loop over `mwc-random` draws, price→tick conversion) → `[Integer]` (N
ticks, fully generated before any RPC call) → `Rpc.run_price_gen` folds `write_price`
over that list inside the caller's `runWeb3'` session → `Report` prints the summary once
the whole run completes (see Module breakdown above — not interleaved per-step).

## Error handling

If any `write_price` call in the fold fails, the whole sequence aborts — correct, since
continuing to write subsequent path points after a failure would impose a broken/
inconsistent trajectory. See decision 6 above for the full, honest treatment of what this
actually means: which failure mode applies is not fully known (only one of `write_price`'s
two failure paths has ever been empirically observed), and a failed run's earlier
successful writes did land on-chain even though the in-process return value is lost.
`run_price_gen` does not add its own error-handling layer beyond letting `Web3`'s
monadic short-circuit do its job — it does not duplicate or attempt to paper over
`write_price`'s existing, only-partially-understood failure characteristics.

## `Main.hs` / `Sample.hs` integration

`Sample.hs` gains `sample_price_gen :: StochasticPriceGen` with modest, deliberately sane
parameters (e.g. `size = 5`, modest `sigma`/`delta` relative to `dt = 1.0` — see the
Testing/verification parameter-scaling caveat) — bounded enough to stay a fast demo
alongside the existing `create_order`/`write_price` calls, not a stress test, and
deliberately unlikely to trip the decision-5 domain guard on an ordinary `cabal run`.
`Main.hs`'s composition extends to create the `GenIO` (via `createSystemRandom`,
`liftIO`'d) and call the bare `run_price_gen` (not `run_price_gen_and_report` — `Main.hs`
already reports once via the single shared `Left`/`Right` match at the end, matching how
it already calls bare `create_order`/`write_price` rather than their `_and_report`
wrappers), reporting the result alongside the existing receipt/write reports, inside the
same single `runWeb3'` session already established.

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
2. A `cabal repl` smoke test of `simulate_path` using **two independent calls to
   `System.Random.MWC.create`** (its fixed default seed) for both `GBM` and `CEV`
   `ProcessType`s — two separate `Gen`s, not two draws threaded through one shared `Gen`,
   since a shared/reused `Gen` continues its RNG stream and would *not* reproduce,
   falsifying the determinism claim for the wrong reason. Confirms: the output has
   exactly `size` elements, all values are finite, and both independent `create`-seeded
   runs produce identical `[Integer]` output.
3. **An adversarial parameterization test targeting the decision-5 domain guard
   specifically** (added in review — the original plan had no test that would have caught
   the NaN-cascade issue): deliberately choose a `CEV`/`GBM` parameterization likely to
   drive the price non-positive within `size` steps (e.g. a low `initial_tick`, large
   `sigma`/`delta`, and a `dt` large enough to produce big single-step swings), and
   confirm `simulate_path` fails with the clear "simulated price went non-positive"
   error from decision 5 — not a silent `NaN`/garbage-`Integer` path, not an unrelated
   "tick out of range" symptom.
4. A live end-to-end run at a small `size` (5–10), with a *sane* parameterization (see the
   `dt`/parameter-scaling caveat below), against the deployed rig: confirm the sequence of
   ticks actually written via `run_price_gen` matches `simulate_path`'s pure output for
   the same seed/parameters exactly, and that the final on-chain tick (via `cast call ...
   readTick()`) matches the path's last element.

**Parameter-scaling caveat (added in review):** `dt` defaults to `1.0` with no built-in
guidance on scaling `mu`/`sigma`/`delta` relative to it. Nothing prevents a caller from
choosing volatility-looking magnitudes that produce large single-step swings compounding
over `size` steps, materially raising the odds of hitting decision 5's domain guard even
for "reasonable-looking" parameters. This design does not add a hard constraint on
parameter ranges (that would be arbitrary and project-specific), but any implementation
should pick and document a demonstrably sane default `sample_price_gen` in `Sample.hs`
(small `size`, modest `sigma`/`delta` relative to `dt = 1.0`) rather than assume any
plausible-looking numbers are safe.

## Out of scope (explicit)

- No exact noncentral-χ² CEV sampling (Euler-Maruyama only, decision 2).
- No tick clamping (decision 6) — out-of-range paths fail loudly, with the caveat that
  which of `write_price`'s failure modes applies is not fully known (decision 6).
- No multicall/concurrency for the writes (decision 4) — writes are inherently sequential.
- No changes to `PriceSetterHook.sol`, `write_price`, or any other already-built code —
  this design only adds a new consumer on top.
- No "N independent realizations" mode — single-path-per-run only (decision 1); revisit
  if a future need for Monte Carlo-style multi-path generation arises.
- No hard-enforced parameter-range constraints (see the parameter-scaling caveat above) —
  a sane default is a documentation/implementation responsibility, not a type-level one.

## Success criteria (what must be TRUE)

1. `offchain/lib/StochasticPriceGen/{Types,Simulate,Report,Rpc}.hs` exist with the exports
   described above, including `run_price_gen_and_report`.
2. `simulate_path` is deterministic given a fixed seed — **two independent calls to
   `System.Random.MWC.create`** (not two draws from one shared `Gen`) with the same
   `StochasticPriceGen` config produce identical `[Integer]` output.
3. `GBM` and `CEV` share one Euler-Maruyama step implementation, not two duplicated loops,
   and that step includes the decision-5 domain guard (non-positive/non-finite price
   fails clearly, before it can reach `P^β` or `log(P)`).
4. `run_price_gen` never calls `write_price` concurrently — the fold is strictly
   sequential.
5. An out-of-range simulated tick is not clamped — it surfaces as a real failure when
   `write_price`/`packSlot0For` reverts (decision 6).
6. `cabal build` succeeds cleanly (no warnings) with the cabal diff described above.
7. A live run's written tick sequence matches `simulate_path`'s pure output exactly for
   the same seed/parameters, and the final on-chain tick matches the path's last element.
8. The adversarial domain-guard test (Testing/verification step 3) actually triggers the
   clear non-positive-price error, not a NaN/garbage-tick/misleading-range-error symptom.
