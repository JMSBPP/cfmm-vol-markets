# StochasticPriceGen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `StochasticPriceGen.*` library that simulates a discrete GBM/CEV tick
trajectory via Euler-Maruyama and sequentially drives the existing `PriceSetter.Rpc.
write_price` over it, wired into `Main.hs` alongside `create_order`/`write_price`.

**Architecture:** Four new library modules built bottom-up
(`offchain/lib/StochasticPriceGen/{Types,Simulate,Report,Rpc}.hs`), mirroring the
established `VolOrder.*`/`PriceSetter.*` pattern (pure decode/simulate separated from thin
IO reporting, a bare reusable `Web3` action plus an `_and_report` IO wrapper). The whole
tick path is generated as pure(-ish) data via `mwc-random` before any RPC call, then
folded sequentially through `write_price` inside one `runWeb3'` session — no concurrency,
no multicall (both are inapplicable/incorrect for this operation, see the spec).

**Tech Stack:** Haskell (GHC 9.10.3, `Haskell2010`), Cabal 3.12, `mwc-random` (new
dependency — RNG/normal-distribution sampling), reusing the existing `hs-web3` stack.

## Global Constraints

- Package: `cfmm-replicationPlank-rpc-api`, `base ^>=4.20.2.0`, `cabal-version: 3.12`,
  `default-language: Haskell2010`. Toolchain: GHC 9.10.3.
- Every stanza uses `import: warnings` (`-Wall`) — **zero warnings** required after every
  build check.
- **Every Euler-Maruyama step must validate the resulting price is positive and finite
  before it can reach `P^β` or `log(P)` in a later step** — Haskell's `(**)` and `log`
  both silently produce `NaN` on a non-positive input, and `round(NaN)` does not throw,
  it returns implementation-defined garbage. This is a hard correctness requirement, not
  a nice-to-have (see spec decision 5).
- No tick clamping — an out-of-range simulated tick must be allowed to fail loudly via
  the underlying `write_price`/`packSlot0For` revert, not silently distorted (spec
  decision 6).
- No concurrency/multicall for the writes — `run_price_gen` must call `write_price`
  strictly sequentially (spec decision 4).
- Reproducibility testing must use **two independent `System.Random.MWC.create` calls**
  (fresh `Gen`s), never two draws threaded through one shared `Gen` (spec, Testing section).
- Spec: `docs/superpowers/specs/2026-07-19-stochastic-price-gen-design.md` (two-step
  reviewed: Reality Checker + Model QA Specialist; this plan implements the post-review
  version, including the domain guard, the corrected citation framing, and the
  `run_price_gen`/`run_price_gen_and_report` two-tier split).
- Current `PriceSetter.Rpc.write_price` signature (consumed as-is, unchanged):
  `write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)`.

---

### Task 1: `StochasticPriceGen.Types` — the domain types

**Files:**
- Create: `offchain/lib/StochasticPriceGen/Types.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`; this module has no dependencies beyond `base`)

**Interfaces:**
- Produces: `data ProcessType = GBM { mu :: Double, sigma :: Double } | CEV { mu ::
  Double, delta :: Double, beta :: Double }` and `data StochasticPriceGen =
  StochasticPriceGen { process :: ProcessType, size :: Int, initial_tick :: Integer, dt
  :: Double }`, both fully exported. Task 2 (`Simulate`) and Task 5 (`Sample.hs`) both
  construct/pattern-match these directly.

`mu` appearing as a field in both `GBM` and `CEV` is valid Haskell2010 (same field name
across multiple constructors of one datatype is allowed when the field type matches in
both, which it does here — `Double` in both) — no language extension needed.

- [ ] **Step 1: Create `StochasticPriceGen.Types`**

```haskell
module StochasticPriceGen.Types
  ( ProcessType (..)
  , StochasticPriceGen (..)
  ) where

data ProcessType
  = GBM
      { mu    :: Double
      , sigma :: Double
      }
  | CEV
      { mu    :: Double
      , delta :: Double
      , beta  :: Double
      }
  deriving (Eq, Show)

data StochasticPriceGen = StochasticPriceGen
  { process      :: ProcessType
  , size         :: Int
  , initial_tick :: Integer
  , dt           :: Double
  }
  deriving (Eq, Show)
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
                    , PriceSetter.Rpc
                    , StochasticPriceGen.Types
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task1-build.log
grep -i warning /tmp/spg-task1-build.log || echo "no warnings"
```

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/StochasticPriceGen/Types.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticPriceGen.Types (ProcessType, StochasticPriceGen)"
```

---

### Task 2: `StochasticPriceGen.Simulate` — Euler-Maruyama path generation

**Files:**
- Create: `offchain/lib/StochasticPriceGen/Simulate.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `build-depends` gains
  `mwc-random` — new; `exposed-modules` gains the module)

**Interfaces:**
- Consumes: `ProcessType(..)`, `StochasticPriceGen(..)` (Task 1).
- Produces: `simulate_path :: GenIO -> StochasticPriceGen -> IO [Integer]`. Task 4
  (`Rpc`) calls this. `GenIO` comes from the `mwc-random` package
  (`System.Random.MWC.GenIO`).

This is the module with the review-mandated domain guard: every simulated step is
checked for positivity/finiteness **before** it can be fed into the next step's `P^β` or
into the tick-conversion `log(P)` — a non-positive or non-finite step fails immediately
with a clear, distinguishable error rather than silently producing `NaN` that
`round` would turn into misleading garbage.

- [ ] **Step 1: Create `StochasticPriceGen.Simulate`**

```haskell
module StochasticPriceGen.Simulate
  ( simulate_path
  ) where

import System.Random.MWC (GenIO)
import System.Random.MWC.Distributions (standard)

import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))

simulate_path :: GenIO -> StochasticPriceGen -> IO [Integer]
simulate_path gen config = do
  prices <- generate_prices gen config (tick_to_price (initial_tick config))
  pure (map price_to_tick prices)

generate_prices :: GenIO -> StochasticPriceGen -> Double -> IO [Double]
generate_prices gen config = go (size config)
  where
    go 0 _ = pure []
    go n p_current = do
      p_next <- euler_step gen config p_current
      rest <- go (n - 1) p_next
      pure (p_next : rest)

-- Domain guard: p_next is validated positive and finite here, before it is ever
-- used as p_current in the next step's P^beta (drift_diffusion) or fed into
-- price_to_tick's log(P) -- Haskell's (**) and log both silently produce NaN on a
-- non-positive input, and round(NaN) does not throw, it returns implementation-defined
-- garbage. Failing loudly here, at the exact step that went wrong, is the whole point.
euler_step :: GenIO -> StochasticPriceGen -> Double -> IO Double
euler_step gen config p_current = do
  z <- standard gen
  let (drift, diffusion) = drift_diffusion (process config) p_current
      step_dt = dt config
      p_next = p_current + drift * step_dt + diffusion * sqrt step_dt * z
  if p_next > 0 && not (isNaN p_next) && not (isInfinite p_next)
    then pure p_next
    else fail ("simulated price went non-positive or non-finite: " ++ show p_next)

drift_diffusion :: ProcessType -> Double -> (Double, Double)
drift_diffusion (GBM m s) p = (m * p, s * p)
drift_diffusion (CEV m d b) p = (m * p, d * (p ** b))

tick_to_price :: Integer -> Double
tick_to_price t = 1.0001 ** fromIntegral t

price_to_tick :: Double -> Integer
price_to_tick p = round (log p / log 1.0001)
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
                    , PriceSetter.Rpc
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate

    -- Other library packages from which modules are imported.
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      web3-provider,
                      memory-hexstring,
                      process,
                      bytestring,
                      time,
                      jsonrpc-tinyclient,
                      aeson,
                      mwc-random
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task2-build.log
grep -i warning /tmp/spg-task2-build.log || echo "no warnings"
```

Expected: build succeeds (may take longer than prior tasks while `mwc-random` and its
transitive deps — `vector`, `primitive`, `math-functions`, etc. — resolve/download for
the first time), zero warnings.

- [ ] **Step 4: Smoke-test `simulate_path` in `cabal repl` — determinism, size, finiteness**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
import StochasticPriceGen.Simulate (simulate_path)
import StochasticPriceGen.Types (ProcessType(..), StochasticPriceGen(..))
import System.Random.MWC (create)

let gbm_config = StochasticPriceGen { process = GBM { mu = 0.0, sigma = 0.05 }, size = 5, initial_tick = 60, dt = 1.0 }
gen1 <- create
path1 <- simulate_path gen1 gbm_config
gen2 <- create
path2 <- simulate_path gen2 gbm_config
print path1
print (path1 == path2)
:quit
EOF
```

Expected: `path1` prints a list of exactly 5 `Integer`s (no error), and `path1 == path2`
prints `True` — confirms two **independent** `create` calls (fresh `Gen`s, not one shared
`Gen` reused) reproduce identically, per the Global Constraints reproducibility
requirement. If this errors instead of printing a path, the domain guard fired on these
parameters — try a smaller `sigma` (e.g. `0.02`) and re-run; this specific
mu=0/sigma=0.05/dt=1.0 combination is expected to be safe, but empirical confirmation
matters more than the expectation.

- [ ] **Step 5: Adversarial test — deliberately trigger the domain guard**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
import StochasticPriceGen.Simulate (simulate_path)
import StochasticPriceGen.Types (ProcessType(..), StochasticPriceGen(..))
import System.Random.MWC (create)

let aggressive_config = StochasticPriceGen { process = GBM { mu = 0.0, sigma = 5.0 }, size = 30, initial_tick = 0, dt = 1.0 }
gen <- create
simulate_path gen aggressive_config
:quit
EOF
```

Expected: this should fail with a `user error (simulated price went non-positive or
non-finite: ...)` message from the domain guard (a large `sigma = 5.0` against a
`tick_to_price 0 = 1.0` starting price, over 30 steps with a fixed seed, gives repeated
large-swing opportunities). If it does NOT fail (prints a 30-element list instead),
increase `sigma` further (e.g. `10.0`) or `size` (e.g. `100`) and re-run until it does —
the goal is to positively confirm the guard fires with a clear message, not a silent
`NaN`/garbage-`Integer` result. Record the exact parameters that triggered it in the
commit message for Step 6.

- [ ] **Step 6: Commit**

```bash
git add offchain/lib/StochasticPriceGen/Simulate.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticPriceGen.Simulate (Euler-Maruyama path generation)"
```

---

### Task 3: `StochasticPriceGen.Report` — thin IO formatting

**Files:**
- Create: `offchain/lib/StochasticPriceGen/Report.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`)

**Interfaces:**
- Produces: `report_path_write :: [(Address, HexString, HexString)] -> IO ()`. Task 4's
  `run_price_gen_and_report` calls this.

Prints the **whole** written sequence **once**, after the run completes — not
interleaved per-step reporting during the fold, matching every other `Report` module in
this codebase (`VolOrder.Report`, `PriceSetter.Report` both report once after their
`Web3` action finishes, not live).

- [ ] **Step 1: Create `StochasticPriceGen.Report`**

```haskell
module StochasticPriceGen.Report
  ( report_path_write
  ) where

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

report_path_write :: [(Address, HexString, HexString)] -> IO ()
report_path_write written = do
  putStrLn ("path    WRITTEN (" ++ show (length written) ++ " observations)")
  mapM_ report_step (zip [1 :: Int ..] written)

report_step :: (Int, (Address, HexString, HexString)) -> IO ()
report_step (step_number, (pool_manager, slot, value)) = do
  putStrLn ("  step " ++ show step_number)
  putStrLn ("    poolManager " ++ show pool_manager)
  putStrLn ("    slot        " ++ show slot)
  putStrLn ("    value       " ++ show value)
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
                    , PriceSetter.Rpc
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task3-build.log
grep -i warning /tmp/spg-task3-build.log || echo "no warnings"
```

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/StochasticPriceGen/Report.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticPriceGen.Report IO formatting"
```

---

### Task 4: `StochasticPriceGen.Rpc` — orchestration

**Files:**
- Create: `offchain/lib/StochasticPriceGen/Rpc.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`; `web3-provider` for `runWeb3'`/`Provider` is already present from the
  `write_price` work, `mwc-random` for `GenIO` already added in Task 2)

**Interfaces:**
- Consumes: `simulate_path` (Task 2), `report_path_write` (Task 3),
  `StochasticPriceGen` (Task 1), `PriceSetter.Rpc.write_price :: Address -> Integer ->
  Web3 (Address, HexString, HexString)` (already built, unchanged).
- Produces: `run_price_gen :: Address -> StochasticPriceGen -> GenIO -> Web3 [(Address,
  HexString, HexString)]` (no printing — reusable); `run_price_gen_and_report :: Address
  -> StochasticPriceGen -> GenIO -> IO ()`. Task 5's `Main.hs` calls the bare
  `run_price_gen`.

`run_price_gen` pre-generates the whole tick path via `simulate_path` (`liftIO`'d into
the `Web3` action — zero RPC cost, pure(-ish) computation), then uses `mapM` to fold
`write_price hook` sequentially over the list — `mapM` in the `Web3` monad executes
left-to-right, threading state, which is exactly the strict sequential fold the design
requires (never concurrent).

- [ ] **Step 1: Create `StochasticPriceGen.Rpc`**

```haskell
module StochasticPriceGen.Rpc
  ( run_price_gen
  , run_price_gen_and_report
  ) where

import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')
import System.Random.MWC (GenIO)

import PriceSetter.Rpc (write_price)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Simulate (simulate_path)
import StochasticPriceGen.Types (StochasticPriceGen)

run_price_gen
  :: Address -> StochasticPriceGen -> GenIO -> Web3 [(Address, HexString, HexString)]
run_price_gen hook config gen = do
  ticks <- liftIO (simulate_path gen config)
  mapM (write_price hook) ticks

run_price_gen_and_report :: Address -> StochasticPriceGen -> GenIO -> IO ()
run_price_gen_and_report hook config gen = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (run_price_gen hook config gen)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right written    -> report_path_write written
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
                    , PriceSetter.Rpc
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
                    , StochasticPriceGen.Rpc
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task4-build.log
grep -i warning /tmp/spg-task4-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. At this point the full library (all `VolOrder.*`,
`PriceSetter.*`, and `StochasticPriceGen.*` modules) builds; the executable still runs
the old `Main.hs`.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/StochasticPriceGen/Rpc.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticPriceGen.Rpc orchestration"
```

---

### Task 5: Wire up `Sample.hs`, `Main.hs`, and the executable stanza

**Files:**
- Modify: `offchain/app/Sample.hs` (add `sample_price_gen`)
- Modify: `offchain/app/Main.hs` (extend the composition)
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (executable `build-depends` gains
  `mwc-random`)

**Interfaces:**
- Consumes: `run_price_gen` (Task 4), `report_path_write` (Task 3), `ProcessType(..)`/
  `StochasticPriceGen(..)` (Task 1), plus the existing `create_order`, `write_price`,
  `report_receipt`, `report_price_write`.
- Produces: nothing further downstream — Task 6 verifies this task's output live.

`sample_price_gen`'s parameters are deliberately sane (small `sigma`, `dt = 1.0`) so an
ordinary `cabal run` doesn't trip the Task 2 domain guard — `initial_tick = 60` matches
`sample_tick` (the value the preceding `write_price` demo call already sets on-chain),
so the simulated path continues from where the demo left the pool.

- [ ] **Step 1: Update `offchain/app/Sample.hs`**

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_price_gen
  , sample_tick
  ) where

import Data.Solidity.Prim.Address (Address)

import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))
import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

price_setter_hook :: Address
price_setter_hook = "0x78f77B581417489BABC51CC63091db140962B000"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }

-- Nonzero and a multiple of the deployed pool's tickSpacing (60), so the demo
-- visibly moves state away from PriceSetterHookScript's initial tick = 0.
sample_tick :: Integer
sample_tick = 60

-- Small sigma relative to dt = 1.0 -- deliberately unlikely to trip
-- StochasticPriceGen.Simulate's domain guard on an ordinary demo run.
-- initial_tick matches sample_tick so the simulated path continues from where
-- the preceding write_price demo call leaves the pool.
sample_price_gen :: StochasticPriceGen
sample_price_gen =
  StochasticPriceGen
    { process      = GBM { mu = 0.0, sigma = 0.05 }
    , size         = 5
    , initial_tick = 60
    , dt           = 1.0
    }
```

- [ ] **Step 2: Replace `offchain/app/Main.hs` entirely**

```haskell
module Main where

import System.Random.MWC (createSystemRandom)

import Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_price_gen
  , sample_tick
  )
import Network.Web3.Provider (Provider (HttpProvider), runWeb3')
import PriceSetter.Report (report_price_write)
import PriceSetter.Rpc (write_price)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Rpc (run_price_gen)
import VolOrder.Report (report_receipt)
import VolOrder.Rpc (create_order)

main :: IO ()
main = do
  -- Created before entering the Web3 action (main is already IO, so no liftIO
  -- is needed here) -- run_price_gen below just takes the resulting GenIO value.
  gen <- createSystemRandom

  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (do receipt <- create_order account order_manager sample_order
          written <- write_price price_setter_hook sample_tick
          path_written <- run_price_gen price_setter_hook sample_price_gen gen
          pure (receipt, written, path_written))

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right (receipt, written, path_written) -> do
      report_receipt receipt
      report_price_write written
      report_path_write path_written
```

- [ ] **Step 3: Update the cabal executable stanza**

`Main.hs` now directly imports `System.Random.MWC (createSystemRandom)`, so the
executable needs `mwc-random` directly:

```cabal
executable cfmm-replicationPlank-rpc-api
    import:           warnings
    main-is:          Main.hs
    other-modules:    Sample
    build-depends:
        base ^>=4.20.2.0,
        cfmm-replicationPlank-rpc-api,
        web3-solidity,
        web3-provider,
        mwc-random
    hs-source-dirs:   offchain/app
    default-language: Haskell2010
```

- [ ] **Step 4: Build the whole package and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task5-build.log
grep -i warning /tmp/spg-task5-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings.

- [ ] **Step 5: Commit**

```bash
git add offchain/app/Sample.hs offchain/app/Main.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: wire StochasticPriceGen into Main.hs"
```

---

### Task 6: End-to-end verification

**Files:** none (verification only).

**Interfaces:** none.

`Main.hs` uses `createSystemRandom` (real entropy) for a realistic demo — its output is
**not** reproducible run-to-run, so it cannot be directly compared against a separately
computed `simulate_path` result. The live-sequence-match check therefore uses
`cabal repl` with **fixed-seed (`create`) `Gen`s** on both sides (predicted path vs.
actually-written path), not a comparison against `cabal run`'s own non-deterministic
output. `cabal run`'s job in this task is only to confirm the fully-wired demo completes
without crashing and prints a plausible summary.

- [ ] **Step 1: Confirm the anvil node and deployed rig from the `write_price` work are
      still live** (reuse them; do not redeploy unless this fails)

```bash
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x78f77B581417489BABC51CC63091db140962B000","latest"]}'
```

Expected: an `anvil/...` result, and a non-`"0x"` `result` for the hook's code. If either
fails, redeploy fresh in the fixed order documented in the `write_price` plan
(`docs/superpowers/plans/2026-07-18-write-price-implementation.md`, Task 5): first
`foundry-scripts/VolOrderManager.s.sol`, then `foundry-scripts/PriceSetterHook.s.sol`,
both `--broadcast --ffi --via-ir`, and confirm the hook lands at the same
`0x78f77B581417489BABC51CC63091db140962B000` address before continuing (if it lands at a
different address, `Sample.hs`'s `price_setter_hook` value is now stale and this task
cannot proceed until that's reconciled — treat as a blocker, do not silently substitute
the new address into a temporary test without updating `Sample.hs`).

- [ ] **Step 2: Fixed-seed comparison — predicted path vs. actually-written path**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import Data.Solidity.Prim.Address (Address)
import StochasticPriceGen.Rpc (run_price_gen)
import StochasticPriceGen.Simulate (simulate_path)
import StochasticPriceGen.Types (ProcessType(..), StochasticPriceGen(..))
import Network.Web3.Provider (Provider(HttpProvider), runWeb3')
import System.Random.MWC (create)

let hook = "0x78f77B581417489BABC51CC63091db140962B000" :: Address
let config = StochasticPriceGen { process = GBM { mu = 0.0, sigma = 0.05 }, size = 5, initial_tick = 60, dt = 1.0 }

predict_gen <- create
predicted <- simulate_path predict_gen config

write_gen <- create
result <- runWeb3' (HttpProvider "http://127.0.0.1:8545") (run_price_gen hook config write_gen)

print predicted
print result
:quit
EOF
```

Expected: `predicted` prints a 5-element `Integer` list (the same list Task 2's Step 4
would produce for this config, since it's the same fixed seed and parameters). `result`
prints `Right [...]` with exactly 5 `(Address, HexString, HexString)` triples — confirms
`run_price_gen` actually executed against the live rig successfully. Manually verify the
final on-chain tick matches `predicted`'s last element:

```bash
cast call 0x78f77B581417489BABC51CC63091db140962B000 "readTick()(int24)" \
  --rpc-url http://127.0.0.1:8545
```

Expected: matches the last `Integer` in `predicted`'s printed list.

- [ ] **Step 3: Confirm the fully-wired demo runs end-to-end without crashing**

```bash
cabal run -v0 exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/spg-task6-run.log
```

Expected: the `create_order` receipt block, the `write_price` block (`price   WRITTEN`),
and a new `path    WRITTEN (5 observations)` block with 5 numbered steps, each showing
`poolManager`/`slot`/`value` — no `rpc error:` line. Since this run uses
`createSystemRandom` (real entropy), its specific tick values will differ from Step 2's
fixed-seed run — that's expected and not a discrepancy to chase; only Step 2's
fixed-seed comparison is a byte-for-byte check.

```bash
grep -c "path    WRITTEN" /tmp/spg-task6-run.log
grep -c "rpc error:" /tmp/spg-task6-run.log
```

Expected: first command prints `1`, second prints `0`.

No commit for this task — verification only. If any step fails, fix the implementation
in the relevant earlier task and re-run this task from Step 2.
