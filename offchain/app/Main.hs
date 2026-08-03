{-# LANGUAGE OverloadedStrings #-}

-- |
-- The demo driver. One @cabal run@ exercises BOTH price mechanisms and the order generator against
-- the live rig, and leaves a committed, replayable record of the DRIV-01 run behind.
--
-- == THE ORDER OF THE THREE THINGS THAT HAPPEN BEFORE ANY RPC
--
--   1. @load_rig@ — every address and every topic0 below comes from the manifest and the pin file.
--      A missing, stale or malformed manifest stops the program HERE rather than after a
--      transaction has gone to an address that used to be right.
--   2. @resolve_seed@ — and the seed is PRINTED immediately, before the run, so a crashed run still
--      tells the operator how to replay it. Until 22-05 this line was mwc-random's system-entropy
--      constructor: unseeded, unrecorded, and therefore unreplayable. That name is deliberately not
--      written out here, because the acceptance criterion for this file is a grep that must find
--      zero occurrences of it — a historical note that quoted it would defeat the check whose whole
--      job is to notice the call coming back.
--   3. the capture 'IORef's — created before the Web3 action so the exception handler can reach
--      them.
--
-- == THE TWO PRICE MECHANISMS, BOTH KEPT
--
-- @write_price@ + @run_price_gen@ drive @PriceSetterHook@'s own pool on the SECOND, liquidity-free
-- @PoolManager@. They write slot0 and emit nothing, which is precisely why they could never have
-- satisfied DRIV-01 on their own — and roadmap SC-1 requires them to stay available and unchanged,
-- so @run_cheat_swap_path@ was added BESIDE them, not in place of them.
--
-- == FLUSH ON FAILURE
--
-- A @fail@ inside 'Network.Web3.Provider.Web3' surfaces as an UNCAUGHT 'IOException', not as
-- @runWeb3'@'s 'Left', and it can fire MID-FOLD after earlier steps have already mined.
-- 22-CONTEXT's G2 is why this driver aborts on the first bad step instead of completing: once a bad
-- timestamp lands, the oracle's window math is silently wrong for everything after it, so a
-- complete-and-report-all run would produce evidence that LOOKS fine and is not. Aborting is only
-- useful if the partial run survives, so the whole @runWeb3'@ is wrapped in 'finally' over the
-- steps 'IORef'.
--
-- The handler must never throw: a failed flush that masked the original error would turn a
-- diagnosable failure into a mystery. It catches everything and prints the path.
module Main where

import Control.Exception (SomeException, displayException, finally, try)
import Control.Monad.IO.Class (liftIO)
import Data.Bits (shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.Char (intToDigit, isSpace)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Data.List (dropWhileEnd)
import Data.Maybe (listToMaybe)
import qualified Data.Text as T
import Data.Word (Word32)
import System.Process (readProcess)

import Sample
  ( sample_mixed_batch
  , sample_order
  , sample_order_gen
  , sample_price_gen
  , sample_stride
  , sample_tick
  )
import Data.ByteArray.HexString (HexString, toBytes)
import Data.Solidity.Prim.Address (Address, toHexString)
import Network.Ethereum.Api.Types
  ( Change
  , DefaultBlock (BlockWithNumber, Latest)
  , TxReceipt (..)
  , unQuantity
  )
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import CheatSwap.Rpc (CheatSwapStep (..), CheatSwapTarget (..))
import Driver.Capture
  ( DriverRig (..)
  , DriverRun (..)
  , DriverSeed (..)
  , E1Record (..)
  , E3Record (..)
  , E5Record (..)
  , LegacyWritePrice (..)
  , MixedBatch (..)
  , MixedReadback (..)
  , OrderFields (..)
  , OrdersRecord (..)
  , SingleOrder (..)
  , StepRecord
  , ZeroArrival (..)
  , capture_path
  , no_orders
  , step_record
  , write_capture
  )
import Driver.Seed (gen_from_seed, resolve_seed, seed_env_var)
import PriceSetter.Report (report_price_write)
import PriceSetter.Rpc (write_price)
import RealizedVol.Decode (FeeApplied (..), TimepointWritten (..))
import Rig.Manifest
  ( Rig (..)
  , RigAccounts (..)
  , RigAddresses (..)
  , RigPool (..)
  , contract_address
  , hex_to_integer
  , load_rig
  , pin_topic0
  , resolve_account
  , resolve_contract
  )
import StochasticOrderGen.Report (report_batch_result)
import StochasticOrderGen.Rpc (chunk, max_batch, run_order_gen)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Rpc (run_cheat_swap_path, run_price_gen)
import StochasticPriceGen.Types (StochasticPriceGen (size))
import VolOrder.Decode
  ( OrderCreatedEvent (..)
  , decode_create_orders_result
  , unpack_vol_order_storage
  )
import VolOrder.Report (decode_e1_from, report_receipt)
import VolOrder.Rpc
  ( PackedReadback (..)
  , create_order
  , create_orders
  , preview_create_orders
  , read_order_count
  , read_order_packed_traced
  )
import VolOrder.Types (VolOrder (..))

main :: IO ()
main = do
  -- The rig is loaded FIRST -- before the RNG, before the provider, before any RPC call.
  --
  -- Every address this driver touches and the topic0s it decodes with are read here, from
  -- offchain/rig/rig-manifest.json (written by offchain/rig/deploy-rig.sh) and
  -- offchain/rig/rig-pins.json (generated by offchain/rig/generate-pins.sh). There is no
  -- literal, no default and no fallback anywhere below: a missing, stale or malformed manifest
  -- stops the program HERE, naming the resolved path and the command that produces it, rather
  -- than sending a transaction to an address that used to be right.
  rig <- load_rig
  let addrs = rig_addrs rig
      pool  = rig_pool addrs

  sender   <- either fail pure (resolve_account  rig "sender")
  deployer <- either fail pure (resolve_account  rig "deployer")
  manager  <- either fail pure (resolve_contract rig "VolOrderManagerMod")
  psh      <- either fail pure (resolve_contract rig "PriceSetterHook")
  pm       <- either fail pure (resolve_contract rig "PoolManager")
  fee_hook <- either fail pure (resolve_contract rig "DynamicFeeHook")
  router   <- either fail pure (resolve_contract rig "PoolSwapTest")
  topic_e1 <- either fail pure (pin_topic0       rig "VolOrderCreated")
  topic_e3 <- either fail pure (pin_topic0       rig "TimepointWritten")
  topic_e5 <- either fail pure (pin_topic0       rig "FeeApplied")
  -- The poolId is resolved HERE, with the other ten, and not with `read` inside the CheatSwapTarget
  -- below. `read` is partial AND lazy, so a malformed poolId throws from wherever the field is
  -- first forced -- inside the Web3 fold, after transactions have mined -- which is precisely the
  -- "bottom thrown from wherever the value is first forced" Rig.Manifest's header exists to
  -- prevent. It also reads DECIMAL without a 0x prefix, so an unprefixed all-digit poolId would
  -- parse silently as a different, valid-looking slot rather than fail at all.
  pool_id  <- either fail pure (hex_to_integer   "pool.poolId" (rig_pool_id pool))

  -- The seed is resolved and PRINTED before anything is sent. A run that dies at step 3 still
  -- leaves the operator a line they can paste straight back in to reproduce it exactly.
  (seed, seed_note) <- resolve_seed
  putStrLn (seed_env_var ++ "=" ++ show seed)
  putStrLn ("  " ++ seed_note)
  gen <- gen_from_seed seed

  -- The cheat manager and the read manager are the SAME address, always. CheatSwapTarget splits
  -- them only so 22-04 could aim a measurement at the wrong one and observe the silence.
  let target = CheatSwapTarget
        { cst_cheat_manager = pm
        , cst_pool_manager  = pm
        , cst_price_hook    = psh
        , cst_fee_hook      = fee_hook
        , cst_swap_router   = router
        , cst_deployer      = deployer
        , cst_pool_id       = pool_id
        , cst_currency0     = T.unpack (rig_currency0 pool)
        , cst_currency1     = T.unpack (rig_currency1 pool)
        , cst_tick_spacing  = rig_tick_spacing pool
        , cst_topic_e3      = topic_e3
        , cst_topic_e5      = topic_e5
        }

  steps_ref  <- newIORef []
  legacy_ref <- newIORef Nothing
  done_ref   <- newIORef False
  orders_ref <- newIORef no_orders

  capture <- capture_path

  result <-
    flip finally (flush rig seed steps_ref legacy_ref done_ref orders_ref capture) $
      runWeb3'
        (HttpProvider "http://127.0.0.1:8545")
        (do receipt <- create_order sender manager sample_order

            -- DRIV-02 / SC-2: the single order's E1 and its receipt-block-pinned readback,
            -- captured from the receipt that was already here rather than from a second send.
            single <- capture_single topic_e1 manager sample_order receipt
            liftIO (modifyIORef' orders_ref (\o -> o { or_single = Just single }))

            -- The LEGACY flow, unchanged and still first-class (roadmap SC-1).
            written <- write_price psh sample_tick
            liftIO (writeIORef legacy_ref (Just (legacy_record sample_tick written)))
            path_written <- run_price_gen psh sample_price_gen gen

            -- DRIV-01: the stochastic price path, one E3 per step.
            steps <- run_cheat_swap_path target sample_price_gen sample_stride steps_ref gen

            -- The DRIV-01 path is complete HERE. Anything that fails after this point is an
            -- order-side failure and must not mark the price-path evidence partial. DRIV-02 gets
            -- its own flag (or_complete) rather than borrowing this one.
            liftIO (writeIORef done_ref True)

            batch_results <- run_order_gen sender manager sample_order_gen gen

            -- DRIV-02 / SC-3 and SC-4. Both come AFTER run_order_gen on purpose: `gen` is consumed
            -- sequentially by run_price_gen, run_cheat_swap_path and run_order_gen, so anything
            -- inserted before the generator would shift the draws it makes and change the orders a
            -- replay of the same seed produces. Neither of these two draws from `gen` at all --
            -- sample_mixed_batch is DATA and the empty batch has nothing to draw for -- so the
            -- order stream is left exactly where 22-05 found it.
            mixed <- capture_mixed sender manager sample_mixed_batch
            liftIO (modifyIORef' orders_ref (\o -> o { or_mixed = Just mixed }))

            n0 <- capture_zero_arrival sender manager
            liftIO (modifyIORef' orders_ref (\o -> o { or_n0 = Just n0 }))

            liftIO (modifyIORef' orders_ref (\o -> o { or_complete = True }))
            pure (receipt, written, path_written, steps, batch_results, mixed, n0))

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right (receipt, written, path_written, steps, batch_results, mixed, n0) -> do
      report_receipt topic_e1 manager receipt
      report_price_write written
      report_path_write path_written
      mapM_ (putStrLn . summarise_step) (zip [0 :: Int ..] steps)
      mapM_ report_batch_result batch_results
      putStrLn (summarise_mixed mixed)
      putStrLn (summarise_n0 n0)
      putStrLn ("wrote " ++ capture ++ "  (" ++ show (length steps) ++ " steps, 3 order shapes)")

-- ---------------------------------------------------------------------------------------------
-- DRIV-02: the three order shapes, captured live
--
-- The generator produces NONE of these three on its own, which is why they are here rather than in
-- StochasticOrderGen:
--
--   * SINGLE      -- run_order_gen only ever calls the BATCH entrypoint, so no create_order receipt
--                    and no E1-with-readback pair comes out of it.
--   * MIXED       -- every shape the generator builds is valid, so no batch it sends is ever mixed.
--   * ZERO ARRIVAL -- a Poisson draw of 0 gives `chunk max_batch [] == []`, i.e. zero chunks, zero
--                    eth_calls and zero transactions. The generator sends NOTHING, so the empty-batch
--                    return contract is never exercised on that path at all.
-- ---------------------------------------------------------------------------------------------

-- | SC-2. One @create_order@ receipt in, one recorded exercise out.
--
-- The readback is pinned to the RECEIPT's block, never @Latest@: on anything but a single-writer
-- local node @Latest@ can be a lagging replica or a later tip, and either one makes the readback
-- describe a different chain state from the one the transaction landed in. The block height is
-- recorded so a check can see the pinning rather than take it on trust.
capture_single :: Integer -> Address -> VolOrder -> TxReceipt -> Web3 SingleOrder
capture_single topic_e1 manager submitted receipt = do
  let block = BlockWithNumber (receiptBlockNumber receipt)
      e1s   = decode_e1s topic_e1 manager (receiptLogs receipt)
  -- ONE binding, used as the query argument and recorded FROM THE QUERY ITSELF.
  --
  -- @so_readback_id@ is 'prb_queried_id' — the argument decoded back out of the calldata this call
  -- sent — and NOT @fmap orderId (listToMaybe e1s)@, which is what it was until this was fixed. In
  -- the @(e : _)@ branch @listToMaybe e1s@ IS @Just e@, so the recorded id was literally the
  -- expression already handed to the readback and the offline check evaluated @orderId e ==
  -- orderId e@ for every input. MEASURED on this rig: a driver whose readback queried the constant
  -- @1@ (an id that holds an identical sample order, so the content comparison still matched) while
  -- the E1 announced id @8@ produced a capture that passed 89/89. With the id threaded out of the
  -- call the same mutant reddens driv02_single_order_live, because the recorded id follows the
  -- QUERY and the E1's id follows the chain.
  readback <-
    case e1s of
      (e : _) -> Just <$> read_order_packed_traced manager block (orderId e)
      []      -> pure Nothing
  pure SingleOrder
    { so_submitted      = order_fields submitted
    , so_tx_hash        = hex_of (receiptTransactionHash receipt)
    , so_status         = fmap unQuantity (receiptStatus receipt)
    , so_e1_count       = length e1s
    , so_e1             = fmap e1_record (listToMaybe e1s)
    , so_readback       = fmap (order_fields . unpack_vol_order_storage . prb_word) readback
    , so_readback_id    = fmap prb_queried_id readback
    , so_readback_block = Just (unQuantity (receiptBlockNumber receipt))
    }

-- | SC-3. A batch with at least one contract-rejected tuple, sent live.
--
-- @create_orders@ already enforces the whole contract internally — the preview decodes and its
-- length matches the batch, the receipt is status 1, @orderCount()@ read AT THE RECEIPT'S BLOCK
-- moved by exactly the number of previewed successes, and every minted id reads back
-- content-matched. None of that is re-implemented here; this function RECORDS the numbers so an
-- offline check can assert them without a chain.
--
-- KNOWN LIMIT, recorded rather than papered over (Phase 21 follow-up #5, PARTIALLY ADDRESSED):
-- @verify_mined_order@ compares the 4-field 'VolOrder' record, and @unpack_vol_order_storage@
-- discards tickSpacing at bits 104..127 and anything at >= 248 BEFORE that comparison. The
-- readbacks below inherit exactly that blind spot.
capture_mixed :: Address -> Address -> [VolOrder] -> Web3 MixedBatch
capture_mixed sender manager batch = do
  before <- read_order_count manager Latest
  (receipt, preview) <- create_orders sender manager batch
  let block     = BlockWithNumber (receiptBlockNumber receipt)
      successes = [o | (o, (True, _)) <- zip batch preview]
      -- Ids are 1-based and sequential: the module mints id = orderCount + 1 and then advances the
      -- count to it, so this batch minted exactly [before+1 .. before+successes]. The PREVIEW's
      -- absolute ids are deliberately not used -- they are read before the send and any other
      -- writer landing in between shifts the base.
      minted_ids = take (length successes) [before + 1 ..]
  after <- read_order_count manager block
  -- Same rule as the single order's: @mr_id@ is the id THIS CALL asked for, decoded back out of its
  -- own calldata, not the loop variable written down a second time beside it.
  readbacks <- mapM (fmap mixed_readback . read_order_packed_traced manager block) minted_ids
  pure MixedBatch
    { mb_submitted    = map order_fields batch
    , mb_preview      = preview
    , mb_count_before = before
    , mb_count_after  = after
    , mb_tx_hash      = hex_of (receiptTransactionHash receipt)
    , mb_status       = fmap unQuantity (receiptStatus receipt)
    , mb_readbacks    = readbacks
    }

-- | SC-4, in BOTH of its readings.
--
-- The PREVIEW half first, and it has to be first: a mined transaction carries no returndata at all,
-- so the "exactly 64 bytes" fact is observable through @preview_create_orders@ and through nothing
-- else. The TRANSACTION half follows, to show the empty batch also mines cleanly and moves
-- @orderCount@ by zero. The GENERATOR half is @length (chunk max_batch [])@, taken from the real
-- function so it cannot drift into a stale comment.
capture_zero_arrival :: Address -> Address -> Web3 ZeroArrival
capture_zero_arrival sender manager = do
  preview_raw <- preview_create_orders manager []
  decoded <- either fail pure (decode_create_orders_result preview_raw)
  before <- read_order_count manager Latest
  (receipt, _) <- create_orders sender manager []
  after <- read_order_count manager (BlockWithNumber (receiptBlockNumber receipt))
  pure ZeroArrival
    { zr_preview_hex              = hex_of preview_raw
    , zr_preview_byte_length      = BS.length (toBytes preview_raw)
    , zr_decoded_length           = length decoded
    , zr_tx_hash                  = hex_of (receiptTransactionHash receipt)
    , zr_status                   = fmap unQuantity (receiptStatus receipt)
    , zr_count_before             = before
    , zr_count_after              = after
    , zr_generator_chunks_at_zero = length (chunk max_batch ([] :: [VolOrder]))
    }

-- The emitting-address filter is MANDATORY here, exactly as it is on the E3/E5 path in
-- CheatSwap.Rpc, and for the same reason: topic0 identifies an EVENT SIGNATURE and not an emitter.
-- A receipt may carry logs from any contract the call touched, and a topic0-only match would report
-- one of them as a VolOrderCreated with an orderId read out of whatever its second topic was -- and
-- then read that id back out of the MANAGER's storage, content-matching some unrelated order or
-- getting getOrderPacked's 0 sentinel. The predicate lives in VolOrder.Report so this call site and
-- report_receipt cannot drift apart.
decode_e1s :: Integer -> Address -> [Change] -> [OrderCreatedEvent]
decode_e1s topic_e1 emitter logs = [e | Just e <- map (decode_e1_from topic_e1 emitter) logs]

mixed_readback :: PackedReadback -> MixedReadback
mixed_readback r =
  MixedReadback
    { mr_id     = prb_queried_id r
    , mr_fields = order_fields (unpack_vol_order_storage (prb_word r))
    }

order_fields :: VolOrder -> OrderFields
order_fields o =
  OrderFields
    { of_strike      = unQuantity (vol_target o)
    , of_width       = unQuantity (range_width o)
    , of_skew        = unQuantity (skew o)
    , of_target_vega = unQuantity (target_vega o)
    }

e1_record :: OrderCreatedEvent -> E1Record
e1_record e =
  E1Record
    { e1r_order_id    = orderId e
    , e1r_strike      = orderStrike e
    , e1r_width       = orderRangeWidth e
    , e1r_skew        = orderSkew e
    , e1r_target_vega = orderTargetVega e
    }

-- ---------------------------------------------------------------------------------------------
-- The flush
-- ---------------------------------------------------------------------------------------------

-- | Build and write the run record from whatever the fold managed to record.
--
-- Runs on BOTH paths. On the happy path @done_ref@ is 'True' and the artifact is complete; on the
-- exception path it is 'False', @dr_steps@ is short of @dr_configured_size@, and @dr_complete@ says
-- so — which is what lets an offline check refuse to treat a partial run as evidence.
--
-- @t0@ is the FIRST recorded step's own submitted timestamp, which is @chain_head + stride@ by
-- construction. It is 'Nothing' when nothing mined, because a run with no origin has none to record
-- and inventing one would make the artifact lie.
flush
  :: Rig
  -> Word32
  -> IORef [CheatSwapStep]
  -> IORef (Maybe LegacyWritePrice)
  -> IORef Bool
  -> IORef OrdersRecord
  -> FilePath
  -> IO ()
flush rig seed steps_ref legacy_ref done_ref orders_ref path = do
  outcome <- try $ do
    steps  <- readIORef steps_ref
    legacy <- readIORef legacy_ref
    done   <- readIORef done_ref
    orders <- readIORef orders_ref
    stamp  <- iso_timestamp

    let addrs = rig_addrs rig
        pool  = rig_pool addrs
        run = DriverRun
          { dr_generated_at    = stamp
          , dr_chain_id        = rig_chain_id addrs
          , dr_generated_from  = T.unpack (rig_generated_from addrs)
          , dr_complete        = done
          , dr_configured_size = size sample_price_gen
          , dr_rig = DriverRig
              { drg_pool_manager      = manifest_contract rig "PoolManager"
              , drg_dynamic_fee_hook  = manifest_contract rig "DynamicFeeHook"
              , drg_price_setter_hook = manifest_contract rig "PriceSetterHook"
              , drg_swap_router       = manifest_contract rig "PoolSwapTest"
              , drg_vol_order_manager = manifest_contract rig "VolOrderManagerMod"
              , drg_pool_id           = T.unpack (rig_pool_id pool)
              , drg_tick_spacing      = rig_tick_spacing pool
              , drg_deployer          = T.unpack (rig_deployer (rig_accounts addrs))
              , drg_sender            = T.unpack (rig_sender   (rig_accounts addrs))
              }
          , dr_seed = DriverSeed
              { ds_rng    = seed
              , ds_t0     = case steps of
                              (first_step : _) -> Just (cs_timestamp first_step)
                              []               -> Nothing
              , ds_stride = sample_stride
              }
          , dr_steps              = zipWith to_step [0 ..] steps
          , dr_legacy_write_price = legacy
            -- Whatever the order side managed to record. A run that died between the mixed batch
            -- and the zero-arrival call still leaves the mixed batch here, with or_complete false.
          , dr_orders             = orders
          }
    write_capture path run

  case outcome :: Either SomeException () of
    Right () -> pure ()
    Left err ->
      -- Deliberately swallowed. If the flush itself fails, the ORIGINAL error is the one worth
      -- propagating; re-raising here would replace a diagnosable failure with a mystery.
      putStrLn ("WARNING: could not write the driver capture to " ++ path ++ ": "
                 ++ displayException err)

to_step :: Int -> CheatSwapStep -> StepRecord
to_step k step =
  step_record
    k
    (cs_tick step)
    (cs_timestamp step)
    (Just (hex_of (cs_tx_hash step)))
    (fmap unQuantity (cs_status step))
    (Just (cs_e3_count step))
    (Just (cs_e5_count step))
    (fmap e3_record (cs_e3 step))
    (fmap e5_record (cs_e5 step))

e3_record :: TimepointWritten -> E3Record
e3_record e =
  E3Record
    { e3r_timestamp = tw_timestamp e
    , e3r_tick      = tw_tick e
    , e3r_vol_cum   = tw_vol_cum e
    , e3r_avg_tick  = tw_avg_tick e
    , e3r_tick_cum  = tw_tick_cum e
    }

e5_record :: FeeApplied -> E5Record
e5_record e = E5Record { e5r_sigma = fa_sigma e, e5r_fee = fa_fee e }

-- | What @write_price@ returned, as the artifact records it. Its @poolManager@ is the OTHER
-- manager, and pinning that is the point: it is why this flow is ADDED BESIDE the driver rather
-- than being the driver.
legacy_record :: Integer -> (Address, HexString, HexString) -> LegacyWritePrice
legacy_record tick (pool_manager, slot, value) =
  LegacyWritePrice
    { lwp_tick         = tick
    , lwp_pool_manager = address_hex pool_manager
    , lwp_slot         = hex_of slot
    , lwp_value        = hex_of value
    }

address_hex :: Address -> String
address_hex = hex_of . toHexString

-- ---------------------------------------------------------------------------------------------
-- Reporting and small helpers
-- ---------------------------------------------------------------------------------------------

summarise_step :: (Int, CheatSwapStep) -> String
summarise_step (k, step) =
  "  step " ++ show k
    ++ "  tick=" ++ show (cs_tick step)
    ++ "  ts=" ++ show (cs_timestamp step)
    ++ "  status=" ++ show (fmap unQuantity (cs_status step))
    ++ "  e3=" ++ show (cs_e3_count step)
    ++ "  e5=" ++ show (cs_e5_count step)
    ++ "  e3.tick=" ++ maybe "-" (show . tw_tick) (cs_e3 step)

summarise_mixed :: MixedBatch -> String
summarise_mixed m =
  "  mixed batch  submitted=" ++ show (length (mb_submitted m))
    ++ "  preview=" ++ show (map fst (mb_preview m))
    ++ "  orderCount " ++ show (mb_count_before m) ++ " -> " ++ show (mb_count_after m)
    ++ "  readbacks=" ++ show (length (mb_readbacks m))
    ++ "  status=" ++ show (mb_status m)

summarise_n0 :: ZeroArrival -> String
summarise_n0 z =
  "  zero arrival  preview=" ++ show (zr_preview_byte_length z) ++ " bytes"
    ++ "  decoded=" ++ show (zr_decoded_length z)
    ++ "  orderCount " ++ show (zr_count_before z) ++ " -> " ++ show (zr_count_after z)
    ++ "  status=" ++ show (zr_status z)
    ++ "  generator chunks at N=0: " ++ show (zr_generator_chunks_at_zero z)

manifest_contract :: Rig -> T.Text -> String
manifest_contract rig name =
  either (error . (("driver capture: " ++ T.unpack name ++ " -- ") ++)) T.unpack
         (contract_address rig name)

-- | @0x@-prefixed lowercase hex, rendered from the bytes so the shape is this program's decision
-- and so nothing here is a source literal the offchain purge could match.
hex_of :: HexString -> String
hex_of = ("0x" ++) . concatMap byte . BS.unpack . toBytes
  where
    byte b = [nibble (b `shiftR` 4), nibble (b .&. 0x0f)]
    nibble = intToDigit . fromIntegral

-- | The capture timestamp, from @date@ rather than a new @time@ dependency -- the same move
-- @capture-batch-return.sh@ and @CheatSwapProof.hs@ both make.
iso_timestamp :: IO String
iso_timestamp = trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
