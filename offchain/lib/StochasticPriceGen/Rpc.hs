-- |
-- TWO price drivers live here, and they are not alternatives.
--
-- 'run_price_gen' folds 'PriceSetter.Rpc.write_price' over a simulated tick path. It drives
-- @PriceSetterHook@'s OWN pool, which sits on a second, liquidity-free @PoolManager@ (manifest key
-- @PriceSetterPoolManager@) that @DynamicFeeHook@ does not read. It writes slot0 and emits nothing.
-- Roadmap SC-1 requires that flow to stay available and UNCHANGED, so it is untouched here — the
-- driver below was ADDED BESIDE it, never in place of it, and @Main@ still calls both.
--
-- 'run_cheat_swap_path' is DRIV-01. It folds 'CheatSwap.Rpc.cheat_and_swap' over the same kind of
-- simulated path, aimed at the @DynamicFeeHook@ pool on the REAL @PoolManager@, advancing the chain
-- clock by a fixed stride each step. @beforeSwap@ reads the pre-swap (i.e. cheated) tick and writes
-- the timepoint itself, so every step produces an E3 carrying the tick the driver submitted, with
-- no offchain @writeTimepoint@ call anywhere.
--
-- 22-04 measured why the distinction matters and is not stylistic: the identical sequence aimed at
-- @PriceSetterPoolManager@ came back at status 1 with one E3 and one E5 carrying the WRONG tick. A
-- driver pointed at the wrong manager does not fail — it lies.
module StochasticPriceGen.Rpc
  ( run_price_gen
  , run_price_gen_and_report
  , run_cheat_swap_path
  ) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.IORef (IORef, modifyIORef', readIORef)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')
import System.Random.MWC (GenIO)

import CheatSwap.Rpc
  ( CheatSwapClock (AdvanceTo)
  , CheatSwapStep (..)
  , CheatSwapTarget
  , chain_head_timestamp
  , cheat_and_swap
  )
import PriceSetter.Rpc (write_price)
import RealizedVol.Decode (TimepointWritten (..))
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

-- ---------------------------------------------------------------------------------------------
-- DRIV-01
-- ---------------------------------------------------------------------------------------------

-- | Drive a whole stochastic price path through the cheat-swap pattern, one E3 per step.
--
-- == THE SCHEDULE
--
-- @t_0 = chain_head + stride@, read ONCE at the start, then @t_k = t_0 + k*stride@. Monotonic by
-- construction, which is what keeps the G1 same-second hazard out of a healthy run: the write guard
-- is one timepoint per distinct @uint32@ TIMESTAMP (@RealizedVolatilityStateLib.plk:114@ compares
-- @lastTimepointTimestamp@ to @now@ for EQUALITY, with no block number anywhere), so a stride of
-- zero would silently drop every step after the first.
--
-- The head is read once rather than per step ON PURPOSE. Re-reading it would make each step's
-- timestamp depend on how long the previous transaction took, which is wall-clock noise; a fixed
-- arithmetic schedule replays in SHAPE (@t_k - t_0 = k*stride@) even though @t_0@ itself is
-- chain-dependent and does not replay across rigs. 'CheatSwap.Rpc.cheat_and_swap''s guard (b) still
-- re-reads the head every step, so a schedule that fell behind the chain is caught there.
--
-- == THE IORef, AND WHY IT IS NOT A RETURN VALUE
--
-- Each step is appended to @steps_ref@ IMMEDIATELY, before the next one runs. 22-CONTEXT's G2 is
-- the reason this driver aborts on the first bad step rather than completing and reporting: once a
-- bad timestamp lands, the oracle's window math is silently wrong for every subsequent step, so a
-- complete-and-report-all run would produce evidence that LOOKS fine and is not. But a @fail@ inside
-- 'Web3' surfaces as an UNCAUGHT 'IOException' (documented in 'PriceSetter.Rpc' and
-- 'StochasticOrderGen.Rpc'), and it can fire MID-FOLD after earlier transactions have already
-- mined. A return value is lost on that path; an 'IORef' the caller already holds is not. @Main@
-- flushes it from a 'Control.Exception.finally' handler.
--
-- == THE PER-STEP ASSERTIONS
--
-- They are repeated here rather than left to 'cheat_and_swap' because that function DELIBERATELY
-- tolerates @e3_count == 0@ — 22-04's G1 measurement needs that case observable, and a function
-- that refused it would make the phase's cheapest falsifiable clock check unmeasurable. A driver
-- has the opposite obligation: a step with no E3 is a lost timepoint and the run's evidence is
-- already corrupt.
run_cheat_swap_path
  :: CheatSwapTarget
  -> StochasticPriceGen
  -> Integer                 -- ^ stride, in seconds. Must be >= 1: see the schedule note above.
  -> IORef [CheatSwapStep]
  -> GenIO
  -> Web3 [CheatSwapStep]
run_cheat_swap_path target config stride steps_ref gen = do
  when (stride < 1) $
    fail ("run_cheat_swap_path: stride " ++ show stride ++ " is not at least 1 second. The write"
           ++ " guard is one timepoint per distinct uint32 timestamp, so a zero or negative stride"
           ++ " silently drops every step after the first: status 1, an E5 and a fee each time,"
           ++ " and no E3. Nothing was sent.")

  ticks <- liftIO (simulate_path gen config)
  head_ts <- chain_head_timestamp
  let t0 = head_ts + stride
      schedule = [(k, tick, t0 + k * stride) | (k, tick) <- zip [0 ..] ticks]

  mapM (one_step target steps_ref) schedule

-- | One step: submit, assert what came back, and record it before returning.
--
-- The value handed to guard (c) is the timestamp the LAST RECORDED STEP actually submitted, read
-- back out of @steps_ref@ — not a number recomputed from this step's own @t_k@. That distinction is
-- the whole guard. @AdvanceTo (t_k - stride) t_k@ looked like it carried the previous step's
-- timestamp and did not: with @t_k = t0 + k*stride@ the two agree only because the schedule is
-- already monotonic, so the predicate reduced to @stride <= 0@, which 'run_cheat_swap_path' rejects
-- before the fold starts. Reading the record instead makes the guard carry information the schedule
-- does not: a shuffled schedule, a replayed step, or a second driver appending to the same 'IORef'
-- all move the recorded value away from @t_k - stride@.
one_step
  :: CheatSwapTarget -> IORef [CheatSwapStep]
  -> (Integer, Integer, Integer)
  -> Web3 CheatSwapStep
one_step target steps_ref (k, tick, t_k) = do
  previous_submitted <- liftIO (last_submitted_timestamp <$> readIORef steps_ref)
  step <- cheat_and_swap target (AdvanceTo previous_submitted t_k) tick
  -- Appended BEFORE the assertions below, so a step that mined and then failed its assertion is
  -- still in the artifact. That is the step a reader most needs to see.
  liftIO (modifyIORef' steps_ref (++ [step]))

  when (cs_e3_count step /= 1) $
    fail ("run_cheat_swap_path: step " ++ show k ++ " (tick " ++ show tick ++ ", timestamp "
           ++ show t_k ++ ", tx " ++ show (cs_tx_hash step) ++ ") produced "
           ++ show (cs_e3_count step) ++ " E3 logs and " ++ show (cs_e5_count step)
           ++ " E5 logs, expected exactly 1 E3."
           ++ " E3 is the ground truth of what landed, never the swap count: a swap that wrote no"
           ++ " timepoint still returns status 1, still emits E5 and still serves a fee."
           ++ " cs_e5_count > cs_e3_count means the G1 same-second guard ATE a write, i.e. this"
           ++ " step's timestamp collided with an already-recorded second."
           ++ " The run is aborted here because the oracle's window math is silently wrong for"
           ++ " every step after a lost or mis-clocked one; the partial artifact is flushed.")

  case cs_e3 step of
    Nothing ->
      fail ("run_cheat_swap_path: step " ++ show k ++ " reported an E3 count of "
             ++ show (cs_e3_count step) ++ " but carried no decoded E3 (tx "
             ++ show (cs_tx_hash step) ++ "). The count and the payload come from the same"
             ++ " mapMaybe, so this means the decoder rejected a log the counter accepted.")
    Just e3 -> do
      when (tw_tick e3 /= tick) $
        fail ("run_cheat_swap_path: step " ++ show k ++ " SUBMITTED tick " ++ show tick
               ++ " but the hook RECORDED tick " ++ show (tw_tick e3) ++ " (tx "
               ++ show (cs_tx_hash step) ++ ", timestamp submitted " ++ show t_k
               ++ ", recorded " ++ show (tw_timestamp e3) ++ ")."
               ++ " 22-04 measured this exact receipt shape -- status 1, one E3, one E5 -- coming"
               ++ " back with the wrong tick when the slot0 write was aimed at the OTHER"
               ++ " PoolManager. Check that the cheat manager is .contracts.PoolManager.")
      when (tw_timestamp e3 /= t_k) $
        fail ("run_cheat_swap_path: step " ++ show k ++ " SUBMITTED timestamp " ++ show t_k
               ++ " but the hook RECORDED timestamp " ++ show (tw_timestamp e3) ++ " (tx "
               ++ show (cs_tx_hash step) ++ ", tick submitted " ++ show tick
               ++ ", recorded " ++ show (tw_tick e3) ++ ")."
               ++ " The hook stamps its own clock, so a disagreement means the block did not carry"
               ++ " the timestamp evm_setNextBlockTimestamp was given -- which makes the whole"
               ++ " series' sigma^2 window arithmetic unattributable.")
      pure step

-- | The timestamp the last recorded step SUBMITTED, or 'Nothing' when nothing has been recorded.
--
-- 'Nothing' is not a lenient default: on the first step of a run the driver has genuinely claimed
-- no timestamp yet, and any number invented for that position would be derived from the step being
-- checked. Guard (b) — the chain-head comparison inside 'cheat_and_swap' — covers step 0 on its own.
last_submitted_timestamp :: [CheatSwapStep] -> Maybe Integer
last_submitted_timestamp [] = Nothing
last_submitted_timestamp xs = Just (cs_timestamp (last xs))
