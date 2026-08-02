{-# LANGUAGE OverloadedStrings #-}

-- |
-- The capture tool that discharges Phase 22's highest-severity finding BY MEASUREMENT.
--
-- == WHAT IS BEING PROVEN, AND WHY A CAPTURE TOOL RATHER THAN A TEST
--
-- @PriceSetterHookScript@ binds @PriceSetterHook@ to a pool on a SECOND @PoolManager@ (manifest key
-- @PriceSetterPoolManager@), while @DynamicFeeHook@ — the contract that actually writes timepoints
-- — is bound to a pool on a different one. Cheating slot0 on the first and swapping the second
-- records the UN-cheated tick, permanently, and it fails SILENTLY: E3 still fires, the receipt is
-- status 1, the timepoint clock still advances. There is no error to notice.
--
-- 'CheatSwap.Types' fixes that by composing the word from the TARGET pool's own @extsload@. Every
-- component of that fix was verified in isolation and NOTHING had been executed end to end. This
-- program is the end-to-end execution, and its output is the evidence:
--
--   * measurement A cheats the RIGHT manager and must produce an E3 carrying tick 5000;
--   * measurement B is IDENTICAL except that it cheats @PriceSetterPoolManager@ — the exact defect,
--     run on purpose — and records what actually comes back.
--
-- It is a capture TOOL, in the same family as @capture-batch-return.sh@, and not part of the demo
-- driver: plan 22-05 rewires @offchain\/app\/Main.hs@ substantially, and an environment-flag branch
-- there would collide with it. The committed artifact is what @cabal test@ then asserts over,
-- offline, so the suite stays chain-independent.
--
-- == THE PROVENANCE FIELD THAT PHASE 21's F4 ASKED FOR
--
-- @generatedFrom@ is written UNCONDITIONALLY. Phase 21's F4 measured that
-- @rpin05_capture_is_present_and_fresh@ cannot see a MODULE change, because it asserts @chainId@
-- and @manager@ only and @manager@ is a @CREATE@ address — identical across three from-scratch
-- deploys. @generatedFrom@ (the imported source-of-truth ref) can see it. @blockNumber@ is
-- deliberately NOT recorded: 21-02 measured three from-scratch deploys landing at heights 9, 11 and
-- 10, so asserting it would redden the suite after any redeploy.
module Main (main) where

import Control.Exception (SomeException, displayException, try)
import Control.Monad (unless)
import Data.Aeson (Value, encodeFile, object, toJSON, (.=))
import Data.Bits (shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, toBytes)
import Data.Char (intToDigit, isSpace)
import Data.List (dropWhileEnd)
import qualified Data.Text as T

import Network.Ethereum.Api.Types (Quantity, unQuantity)
import Network.Web3.Provider (Provider (HttpProvider), Web3, Web3Error, runWeb3')
import System.Process (readProcess)

import CheatSwap.Rpc
  ( CheatSwapClock (AdvanceTo, ForceTimestamp, LeaveClockAlone)
  , CheatSwapStep (..)
  , CheatSwapTarget (..)
  , chain_head_timestamp
  , cheat_and_swap
  )
import RealizedVol.Decode (FeeApplied (..), TimepointWritten (..))
import Rig.Manifest
  ( Rig (..)
  , RigAccounts (..)
  , RigAddresses (..)
  , RigPool (..)
  , contract_address
  , load_rig
  , pin_topic0
  , resolve_account
  , resolve_contract
  )

-- ---------------------------------------------------------------------------------------------
-- Constants of the measurement
-- ---------------------------------------------------------------------------------------------

output_path :: FilePath
output_path = "offchain/rig/cheat-swap-proof.json"

import_ref_path :: FilePath
import_ref_path = "offchain/rig/import-ref.txt"

provider :: Provider
provider = HttpProvider "http://127.0.0.1:8545"

-- | Measurement A's cheated tick.
--
-- 5000 is chosen so that observing it PROVES the cheat landed, rather than merely correlating with
-- it. The pool initialised at tick 0; a 1e6-wei exact-input swap against @L = 1e21@ cannot move the
-- price anywhere near tick 5000; and 5000 is comfortably inside the G4 domain. So an E3 carrying
-- 5000 has exactly one possible origin — a slot0 write that the hook actually read.
tick_right_pool :: Integer
tick_right_pool = 5000

-- | Measurement B's cheated tick, deliberately DIFFERENT from A's so the two cannot be confused.
tick_wrong_pool :: Integer
tick_wrong_pool = 7000

-- | Measurement C's three ticks. They all DIFFER so that if an E3 unexpectedly appears its value
-- says which of the writes produced it.
tick_same_second_1, tick_same_second_2, tick_same_second_3 :: Integer
tick_same_second_1 = 5100
tick_same_second_2 = 5200
tick_same_second_3 = 5300

-- | The inclusive G4 floor: @minUsableTick(20) + 1@. One below this and 'check_cheat_tick' rejects.
tick_extreme_floor :: Integer
tick_extreme_floor = -887259

-- | Seconds between steps. Strictly positive is a CORRECTNESS requirement, not a preference: the
-- write guard is one timepoint per distinct @uint32@ timestamp.
stride :: Integer
stride = 12

-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  rig <- load_rig
  generated_at <- required_env_free_timestamp
  generated_from <- trim <$> readFile import_ref_path

  let addrs = rig_addrs rig
      pool  = rig_pool addrs
      must what = either (error . ((what ++ ": ") ++)) id

      pool_manager_addr    = must "PoolManager"            (resolve_contract rig "PoolManager")
      price_setter_pm_addr = must "PriceSetterPoolManager" (resolve_contract rig "PriceSetterPoolManager")

      base = CheatSwapTarget
        { cst_cheat_manager = pool_manager_addr
        , cst_pool_manager  = pool_manager_addr
        , cst_price_hook    = must "PriceSetterHook" (resolve_contract rig "PriceSetterHook")
        , cst_fee_hook      = must "DynamicFeeHook"  (resolve_contract rig "DynamicFeeHook")
        , cst_swap_router   = must "PoolSwapTest"    (resolve_contract rig "PoolSwapTest")
        , cst_deployer      = must "deployer"        (resolve_account  rig "deployer")
        , cst_pool_id       = read (T.unpack (rig_pool_id pool))
        , cst_currency0     = T.unpack (rig_currency0 pool)
        , cst_currency1     = T.unpack (rig_currency1 pool)
        , cst_tick_spacing  = rig_tick_spacing pool
        , cst_topic_e3      = must "TimepointWritten" (pin_topic0 rig "TimepointWritten")
        , cst_topic_e5      = must "FeeApplied"       (pin_topic0 rig "FeeApplied")
        }

      -- IDENTICAL to `base` in every respect except WHERE the storage write lands. That is the
      -- whole experiment: hold everything constant, move one address, observe the silence.
      wrong_pool = base { cst_cheat_manager = price_setter_pm_addr }

  -- Run in GROUPS, each caught on its own, so a failure in one measurement cannot erase the
  -- others. The same-second pair shares a group because it must land back to back; the extreme
  -- tick has its own because research flags its outcome as an UNMEASURED analytical argument and
  -- a revert there is a result to record, not a crash to propagate.
  group_ab <- attempt_group "A/B" (run_right_and_wrong base wrong_pool)
  group_c  <- attempt_group "C"   (run_same_second base)
  group_d  <- attempt_group "D"   (run_extreme_tick base)
  let measurements = group_ab ++ group_c ++ group_d

  let rig_block = object
        [ "poolManager"            .= manifest_contract rig "PoolManager"
        , "priceSetterPoolManager" .= manifest_contract rig "PriceSetterPoolManager"
        , "dynamicFeeHook"         .= manifest_contract rig "DynamicFeeHook"
        , "priceSetterHook"        .= manifest_contract rig "PriceSetterHook"
        , "swapRouter"             .= manifest_contract rig "PoolSwapTest"
        , "poolId"                 .= rig_pool_id pool
        , "tickSpacing"            .= rig_tick_spacing pool
        , "deployer"               .= rig_deployer (rig_accounts addrs)
        ]

  encodeFile output_path $ object
    [ "generatedAt"   .= generated_at
    , "chainId"       .= rig_chain_id addrs
    , "generatedFrom" .= generated_from
    , "_provenance"   .= provenance_note
    , "rig"           .= rig_block
    , "measurements"  .= map measurement_json measurements
    ]

  putStrLn ("wrote " ++ output_path ++ "  (" ++ show (length measurements) ++ " measurements)")
  mapM_ (putStrLn . summarise) measurements

-- ---------------------------------------------------------------------------------------------
-- The measurements
-- ---------------------------------------------------------------------------------------------

-- | One measurement's outcome. A measurement that FAILED is still a measurement, and recording it
-- is the whole point: research flags the near-floor swap as an unmeasured analytical argument, and
-- \"it reverted\" is an answer to that question while \"the capture crashed\" is not.
data Measured = Measured
  { m_name    :: String
  , m_outcome :: Either String (CheatSwapStep, Integer)  -- ^ failure text, or step + head ts after
  }

-- | One guarded step: read the head, advance by the stride, swap, then read the head BACK.
--
-- The head is re-read every time rather than tracked, and the PREVIOUS step's timestamp handed to
-- guard (c) is the observed head rather than a remembered number — so the guard is checked against
-- what the chain actually did, not against what this program believes it did.
guarded_step :: CheatSwapTarget -> Integer -> Web3 (CheatSwapStep, Integer)
guarded_step target tick = do
  previous <- chain_head_timestamp
  step     <- cheat_and_swap target (AdvanceTo previous (previous + stride)) tick
  after    <- chain_head_timestamp
  pure (step, after)

-- | A and B. Identical in every respect except WHERE the storage write lands.
run_right_and_wrong :: CheatSwapTarget -> CheatSwapTarget -> Web3 [(String, (CheatSwapStep, Integer))]
run_right_and_wrong right_pool wrong_pool = do
  a <- guarded_step right_pool tick_right_pool
  b <- guarded_step wrong_pool tick_wrong_pool
  pure [("cheat_to_5000_then_swap", a), ("cheat_wrong_pool_then_swap", b)]

-- | C — the G1 same-second no-op, the hazard that WILL bite a driver loop.
--
-- Three steps, because the FIRST attempt at this measurement was refuted and the refutation is
-- worth keeping on chain:
--
--   1. advance the clock normally — the control. Expect an E3.
--   2. 'ForceTimestamp' at step 1's OWN timestamp. @RealizedVolatilityStateLib.plk:114@ is
--      @if vol_state.lastTimepointTimestamp == now { return false; }@ — an EQUALITY test on the
--      @uint32@ timestamp, no block number anywhere — so this is expected at status 1 with an E5
--      and NO E3. That makes @count(E5) - count(E3)@ a direct on-chain measurement of how many
--      steps the guard ate, and both counts come free in the same receipt.
--   3. 'LeaveClockAlone' — do not touch the clock at all. This was the ORIGINAL step 2 and it did
--      NOT collide: it was measured landing at @T + 1@ with a healthy E3. Kept as a recorded
--      measurement so nobody re-derives the wrong mechanism from the wrong premise.
--
-- The ticks all differ so that an unexpected E3 says by its VALUE which write produced it.
run_same_second :: CheatSwapTarget -> Web3 [(String, (CheatSwapStep, Integer))]
run_same_second target = do
  s1@(step1, _) <- guarded_step target tick_same_second_1
  s2 <- cheat_and_swap target (ForceTimestamp (cs_timestamp step1)) tick_same_second_2
  after2 <- chain_head_timestamp
  s3 <- cheat_and_swap target LeaveClockAlone tick_same_second_3
  after3 <- chain_head_timestamp
  pure [ ("same_second_repeat_step1", s1)
       , ("same_second_repeat_step2", (s2, after2))
       , ("clock_untouched_repeat_step3", (s3, after3))
       ]

-- | D — one step at the inclusive G4 floor.
--
-- Research PREDICTS no revert on the price bound (@getSqrtPriceAtTick(-887259) = 4297706459@, about
-- 2.5e6 units above the fixed @sqrtPriceLimitX96@) but a swap that DEGENERATES to @amount1 ~ 0@
-- because the position holds essentially no token1 down there, with E3 still firing because
-- @beforeSwap@ runs before any swap math. That prediction is explicitly flagged as UNMEASURED in
-- @CheatSwap.Encoding@'s haddock. Whatever happens here is the answer.
run_extreme_tick :: CheatSwapTarget -> Web3 [(String, (CheatSwapStep, Integer))]
run_extreme_tick target = do
  d <- guarded_step target tick_extreme_floor
  pure [("extreme_tick_near_floor", d)]

-- | Run one group, catching BOTH the @Left@ that @runWeb3'@ returns for an RPC error and the
-- uncaught 'IOException' that a @fail@ inside 'Web3' becomes — a documented characteristic of this
-- codebase's Web3 usage, not a hypothetical.
attempt_group :: String -> Web3 [(String, (CheatSwapStep, Integer))] -> IO [Measured]
attempt_group label action = do
  raw <- try (runWeb3' provider action)
  case raw :: Either SomeException (Either Web3Error [(String, (CheatSwapStep, Integer))]) of
    Right (Right results) -> pure [Measured n (Right r) | (n, r) <- results]
    Right (Left err) -> do
      putStrLn ("  group " ++ label ++ " RPC error: " ++ show err)
      pure [Measured (group_placeholder label) (Left (show err))]
    Left exc -> do
      putStrLn ("  group " ++ label ++ " FAILED: " ++ displayException exc)
      pure [Measured (group_placeholder label) (Left (displayException exc))]

-- | The name a failed group records. Named per group so a failure is still identifiable in the
-- artifact, and so the check that counts measurements reddens rather than silently shrinking.
group_placeholder :: String -> String
group_placeholder "A/B" = "cheat_to_5000_then_swap"
group_placeholder "C"   = "same_second_repeat_step1"
group_placeholder "D"   = "extreme_tick_near_floor"
group_placeholder other = other

-- ---------------------------------------------------------------------------------------------
-- Serialisation
--
-- Every field that can exceed 2^53 is emitted as a DECIMAL STRING, never as a JSON number. A
-- 256-bit slot0 word written as a number is silently rounded by any consumer backed by a double —
-- jq included — and a rounded word still looks like a word. The pre-computed @..._high184@ fields
-- exist so the bit-184 composition is checkable with plain string equality, i.e. from the artifact
-- ALONE and without shift arithmetic; the full words are recorded beside them so the derivation is
-- re-checkable rather than trusted.
-- ---------------------------------------------------------------------------------------------

measurement_json :: Measured -> Value
measurement_json m = case m_outcome m of
  -- A measurement that did not complete records status 0 and the verbatim reason. Recording it is
  -- what makes "it reverted" an answer rather than a missing row.
  Left why -> object
    [ "name"          .= m_name m
    , "status"        .= (0 :: Integer)
    , "revert_reason" .= why
    , "e3_count"      .= (0 :: Integer)
    , "e5_count"      .= (0 :: Integer)
    ]
  Right (step, head_after) -> object
    [ "name"                 .= m_name m
    , "tick"                 .= cs_tick step
    , "ts"                   .= cs_timestamp step
    , "head_ts_after"        .= head_after
    , "state_slot"           .= hex_of (cs_state_slot step)
    , "word_before"          .= decimal (cs_word_before step)
    , "word_written"         .= decimal (cs_word_written step)
    , "word_before_high184"  .= decimal (cs_word_before step `shiftR` 184)
    , "word_written_high184" .= decimal (cs_word_written step `shiftR` 184)
    , "swap_calldata_bytes"  .= BS.length (toBytes (cs_swap_calldata step))
    , "tx_hash"              .= hex_of (cs_tx_hash step)
    , "status"               .= fmap quantity (cs_status step)
    , "e3_count"             .= cs_e3_count step
    , "e5_count"             .= cs_e5_count step
    , "e3"                   .= fmap e3_json (cs_e3 step)
    , "e5"                   .= fmap e5_json (cs_e5 step)
    ]

e3_json :: TimepointWritten -> Value
e3_json e = object
  [ "timestamp"            .= tw_timestamp e
  , "tick"                 .= tw_tick e
  , "volatilityCumulative" .= decimal (tw_vol_cum e)
  , "averageTick"          .= tw_avg_tick e
  , "tickCumulative"       .= decimal (tw_tick_cum e)
  ]

e5_json :: FeeApplied -> Value
e5_json e = object
  [ "sigma" .= decimal (fa_sigma e)
  , "fee"   .= fa_fee e
  ]

decimal :: Integer -> Value
decimal = toJSON . show

quantity :: Quantity -> Integer
quantity = unQuantity

provenance_note :: String
provenance_note =
  "Every value below was produced by offchain/app/CheatSwapProof.hs against the live rig stood up"
    ++ " by offchain/rig/deploy-rig.sh. Nothing here was transcribed. Measurement B is the phase's"
    ++ " blocker EXECUTED ON PURPOSE: it is identical to measurement A except that the slot0 write"
    ++ " is aimed at PriceSetterPoolManager, the manager DynamicFeeHook does not read. Its receipt"
    ++ " is expected to look perfectly healthy -- status 1, one E3, one E5 -- while carrying a tick"
    ++ " that is not the cheated one. blockNumber is deliberately absent: three from-scratch"
    ++ " deploys were measured at heights 9, 11 and 10, so it is not a provenance field."

summarise :: Measured -> String
summarise m = case m_outcome m of
  Left why -> "  " ++ m_name m ++ "  DID NOT COMPLETE: " ++ takeWhile (/= '\n') why
  Right (step, head_after) ->
    "  " ++ m_name m
      ++ "  tick=" ++ show (cs_tick step)
      ++ "  ts=" ++ show (cs_timestamp step)
      ++ "  headAfter=" ++ show head_after
      ++ "  status=" ++ show (fmap quantity (cs_status step))
      ++ "  e3=" ++ show (cs_e3_count step)
      ++ "  e5=" ++ show (cs_e5_count step)
      ++ "  e3.tick=" ++ maybe "-" (show . tw_tick) (cs_e3 step)

-- ---------------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------------

manifest_contract :: Rig -> T.Text -> T.Text
manifest_contract rig name =
  either (error . (("cheat-swap-proof: " ++ T.unpack name ++ " -- ") ++)) id
         (contract_address rig name)

-- | @0x@-prefixed lowercase hex, rendered from the bytes so the shape is this program's decision.
hex_of :: HexString -> String
hex_of = ("0x" ++) . concatMap byte . BS.unpack . toBytes
  where
    byte b = [nibble (b `shiftR` 4), nibble (b .&. 0x0f)]
    nibble = intToDigit . fromIntegral

-- | The capture timestamp, taken from @date@ rather than from a new @time@ dependency — the same
-- move @capture-batch-return.sh@ makes, kept here so the executable is runnable on its own.
required_env_free_timestamp :: IO String
required_env_free_timestamp = do
  raw <- trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""
  unless (length raw == 20) $
    error ("cheat-swap-proof: date produced " ++ show raw ++ ", not an ISO-8601 UTC stamp")
  pure raw

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
