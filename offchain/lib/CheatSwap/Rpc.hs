{-# LANGUAGE OverloadedStrings #-}

-- | The composed per-step sequence of the cheat-swap pattern: write the target pool's slot0, set
-- the next block's clock ABSOLUTELY, send a dust swap through the router, and read the hook's own
-- E3\/E5 back out of the receipt.
--
-- == WHAT THIS MODULE IS FOR
--
-- @DynamicFeeHook.beforeSwap@ reads the PRE-swap tick out of @PoolManager@ storage and hands it to
-- @rv_write_timepoint@. So a swap that changes nothing about the price still records whatever tick
-- slot0 held when it entered — which makes \"cheat slot0, then swap\" a complete price driver with
-- no offchain @writeTimepoint@ call anywhere, exactly as 22-CONTEXT's locked decision requires.
--
-- 'CheatSwap.Types' already holds the pure half (slot derivation, the bit-184 composition, the G4
-- domain guard) and 'CheatSwap.Encoding' the calldata half. This module is the only place the two
-- meet a chain.
--
-- == THE FOUR CLIENT-SIDE GUARDS, AND WHY THEY ARE NOT DEFENSIVE
--
-- Every guard below fires before anything MUTATES chain state. Reads (@eth_call@, the head
-- timestamp) are not sends; the ordering that is load-bearing is that no storage write and no
-- transaction happens until all four have passed.
--
-- They matter because three of the four failure modes they catch are SILENT on chain:
--
--   * (a) G4 — a cheat tick outside the rig's single full-range position desyncs liquidity
--     accounting. Cheat moves never CROSS a tick, so nothing reverts and nothing is emitted.
--   * (b)\/(c) G2 — the Algebra-ported oracle assumes a non-decreasing @uint32@ clock and does not
--     check it. A backwards or non-advancing timestamp corrupts the window math with no revert, no
--     event and no symptom. 22-CONTEXT states it plainly: we own clock monotonicity, and these
--     client-side guards are THE ONLY SIGNAL THAT EXISTS. (The node rejects a strictly backwards
--     @setNextBlockTimestamp@ with @-32602@, but that fires at SEND time, says nothing about the
--     caller's own sequence, and does not fire at all for the equal-timestamp case.)
--   * (d) a @NotBound@ revert on @PriceSetterHook.readSlot0@ returns @0x@, which
--     'VolOrder.Decode.hex_to_integer' reads as @0@ — a well-formed word describing a zero price.
--     'PriceSetter.Rpc' documents the same shape one layer over: a @fail@ inside 'Web3' surfaces as
--     an UNCAUGHT 'IOException', not a 'Left', so the message has to name the cause itself.
--
-- == WHY THE ABSOLUTE SETTER AND NOT @evm_increaseTime@
--
-- MEASURED on this machine (22-RESEARCH section 5, anvil 1.5.1): @evm_increaseTime@ returned
-- @-85682546@ — a WALL-CLOCK-relative offset, not an offset from the chain head, because anvil's
-- @--timestamp@ fixes the ORIGIN and not the RATE. @InitSwappableRig.s.sol@ itself reaches that
-- cheatcode through a low-level @address(vm).call@ precisely because its return value fails the
-- typed cheatcode's decode. A relative lever whose base is the wall clock cannot produce a
-- replayable @INIT_TS + k*stride@ path. The absolute setter used below was measured to return
-- @null@ and to give the NEXT mined block exactly the requested timestamp, and it composes with a
-- preceding storage write without mining (height 5 -> 5).
--
-- == THE SENDER RULE
--
-- Swaps go from 'cst_deployer', ALWAYS. @InitSwappableRig._fund@ minted and approved from
-- @vm.addr(deployerKey())@ = anvil index 0 only. The rig's other account (index 1) has no balance
-- and no allowance, so a swap from it dies inside @CurrencySettler.settle -> transferFrom@ with an
-- unhelpful message; it exists for ORDER creation, which needs neither. The two are one line apart
-- in the manifest, which is exactly why the rule is written here rather than left to the call site.
module CheatSwap.Rpc
  ( -- * The step record
    CheatSwapStep (..)
  , CheatSwapTarget (..)
  , CheatSwapClock (..)
    -- * The composed sequence
  , cheat_and_swap
    -- * Node cheats and chain reads
  , anvil_set_storage_at
  , evm_set_next_block_timestamp
  , chain_head_timestamp
  ) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value)
import Data.Bits (shiftL, shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.Char (intToDigit)
import Data.Maybe (listToMaybe, mapMaybe)
import Data.String (fromString)

import Data.ByteArray.HexString (HexString, toBytes)
import Data.Solidity.Prim.Address (Address, toHexString)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types
  ( Call (..)
  , Change (..)
  , DefaultBlock (Latest)
  , Quantity
  , TxReceipt (..)
  , blockTimestamp
  , unQuantity
  )
import Network.JsonRpc.TinyClient (remote)
import Network.Web3.Provider (Web3)

import CheatSwap.Encoding (encode_extsload, encode_swap, hex32)
import CheatSwap.Types (check_cheat_tick, compose_slot0, pool_state_slot)
import PriceSetter.Encoding (encode_pack_slot0_for)
import RealizedVol.Decode
  ( FeeApplied
  , TimepointWritten
  , decode_fee_applied
  , decode_timepoint_written
  )
import VolOrder.Decode (hex_to_integer)
import VolOrder.Rpc (wait_for_receipt)

-- ---------------------------------------------------------------------------------------------
-- Node cheats and chain reads
-- ---------------------------------------------------------------------------------------------

-- | Write one 32-byte word into one contract's storage. Same shape and same style as
-- @PriceSetter.Rpc@'s, and deliberately NOT shared with it: this one is aimed at a manager the
-- @PriceSetterHook@ flow never touches.
anvil_set_storage_at :: Address -> HexString -> HexString -> Web3 Value
anvil_set_storage_at = remote "anvil_setStorageAt"

-- | Set the ABSOLUTE timestamp the next mined block will carry. See the module haddock for the
-- measurement that rules out the relative alternative; the name of that alternative is
-- @evm_increaseTime@ and it appears in this file only in prose.
evm_set_next_block_timestamp :: Integer -> Web3 Value
evm_set_next_block_timestamp = remote "evm_setNextBlockTimestamp"

-- | The timestamp of the current chain head.
--
-- Read every step rather than tracked, because anvil's @--timestamp@ anchors the ORIGIN only and
-- the clock keeps advancing with wall time between calls: 22-03 measured the head at @1700000027@
-- after a deploy whose genesis was @1700000000@. A driver that assumed @INIT_TS + k*stride@ without
-- reading the head would ask the node for timestamps in the past.
chain_head_timestamp :: Web3 Integer
chain_head_timestamp = do
  height <- GlobalState.blockNumber
  found  <- GlobalState.getBlockByNumber height
  case found of
    Just blk -> pure (unQuantity (blockTimestamp blk))
    Nothing  ->
      fail ("cheat_and_swap: eth_getBlockByNumber returned nothing for the head at height "
             ++ show (unQuantity height)
             ++ ". Without the head timestamp the clock guards cannot run, and the clock guards"
             ++ " are the ONLY signal that exists for a non-advancing timestamp (G2 is not"
             ++ " guarded on chain). Refusing to send.")

-- ---------------------------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------------------------

-- | Everything about the rig one step needs. Every field is supplied by the caller from
-- @rig-manifest.json@ and @rig-pins.json@; this module reads no file and holds no address.
--
-- == WHY 'cst_cheat_manager' IS SEPARATE FROM 'cst_pool_manager'
--
-- It is NOT a general-purpose knob and no production caller should ever set the two differently —
-- every real step passes the same address twice.
--
-- It exists so the phase's blocker can be DEMONSTRATED rather than argued. @PriceSetterHookScript@
-- stands up a SECOND @PoolManager@ (manifest key @PriceSetterPoolManager@) and binds
-- @PriceSetterHook@ to a pool there, while @DynamicFeeHook@ lives on a different one. Cheating the
-- wrong manager and swapping the right one records the UN-cheated tick permanently and fails
-- silently — E3 still fires, the receipt is status 1, only the tick value is wrong. Splitting the
-- field lets a measurement aim the write at the wrong manager with everything else held identical,
-- so the silence is observed instead of asserted.
data CheatSwapTarget = CheatSwapTarget
  { cst_cheat_manager :: Address   -- ^ WHICH manager's storage gets written
  , cst_pool_manager  :: Address   -- ^ whose @extsload@ supplies the high bits
  , cst_price_hook    :: Address   -- ^ @packSlot0For@ oracle (its LOW 184 bits only)
  , cst_fee_hook      :: Address   -- ^ the E3\/E5 emitter to filter logs on
  , cst_swap_router   :: Address   -- ^ @PoolSwapTest@
  , cst_deployer      :: Address   -- ^ the ONLY funded and router-approved account
  , cst_pool_id       :: Integer
  , cst_currency0     :: String
  , cst_currency1     :: String
  , cst_tick_spacing  :: Integer   -- ^ from @.pool.tickSpacing@ — never a constant
  , cst_topic_e3      :: Integer
  , cst_topic_e5      :: Integer
  } deriving (Eq, Show)

-- | What a step does to the chain clock.
--
-- 'AdvanceTo' is the production constructor and the only one a driver loop may use. It carries the
-- PREVIOUS step's timestamp as well as this step's, because guard (c) is about the caller's own
-- sequence and no chain read can supply it: a head timestamp tells you where the chain is, not
-- where the driver has already claimed to be.
--
-- The other two constructors both SKIP both clock guards and exist only so the G1 hazard can be
-- measured. Neither may appear in a driver loop.
--
-- 'ForceTimestamp' sets the absolute timestamp anyway, guards bypassed. It is how a same-second
-- collision is CONSTRUCTED: @RealizedVolatilityStateLib.plk:114@ is
-- @if vol_state.lastTimepointTimestamp == now { return false; }@ — an equality test on the @uint32@
-- timestamp with no block number anywhere — so a second swap on an already-recorded second serves
-- E5 and the fee at status 1 while emitting NO E3. MEASURED here: anvil ACCEPTS a next-block
-- timestamp EQUAL to the previous block's (it returns @null@) and rejects only a strictly lower one
-- (@-32602 \"Timestamp error: N is lower than previous block's timestamp\"@). That asymmetry is
-- what makes the collision constructible at all.
--
-- 'LeaveClockAlone' skips the setter entirely. It does NOT produce a collision, and that is itself
-- a measured fact rather than an assumption: after an explicit absolute set, the next unset block
-- came back at @T + 1@, not @T@. A driver that merely FORGOT to advance the clock would therefore
-- drift one second per step instead of hitting G1 — the hazard is real, but it is not reached by
-- omission on this node, and the constructor is kept so that stays recorded.
data CheatSwapClock
  = AdvanceTo Integer Integer   -- ^ previous step's timestamp, then this step's absolute timestamp
  | ForceTimestamp Integer      -- ^ MEASUREMENT ONLY: set this timestamp, guards bypassed (G1)
  | LeaveClockAlone             -- ^ MEASUREMENT ONLY: do not touch the clock at all
  deriving (Eq, Show)

-- | One executed step, as a VALUE. 22-CONTEXT asks the price write to produce the swap artifact
-- rather than perform it as a side effect; recording the whole step this way is what lets a capture
-- tool commit the evidence without re-deriving anything.
data CheatSwapStep = CheatSwapStep
  { cs_tick          :: Integer
  , cs_timestamp     :: Integer          -- ^ requested for 'AdvanceTo'; the observed head otherwise
  , cs_state_slot    :: HexString        -- ^ @keccak(poolId || 6)@
  , cs_word_before   :: Integer          -- ^ @extsload@ of the TARGET pool, before the write
  , cs_word_written  :: Integer          -- ^ the composed word
  , cs_swap_router   :: Address
  , cs_swap_calldata :: HexString        -- ^ the offchain-generated swap artifact
  , cs_tx_hash       :: HexString
  , cs_status        :: Maybe Quantity
  , cs_e3            :: Maybe TimepointWritten
  , cs_e5            :: Maybe FeeApplied
  , cs_e3_count      :: Int
  , cs_e5_count      :: Int
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The sequence
-- ---------------------------------------------------------------------------------------------

-- | Cheat the target pool's slot0 to @tick@, set the clock, swap, and read the hook's events back.
--
-- Returns the step record even when NO E3 was emitted. That is deliberate: the G1 measurement needs
-- a zero E3 count to be observable, and a function that failed on it would make the phase's
-- cheapest falsifiable clock check unmeasurable. The only on-chain outcome this refuses is a
-- reverted receipt.
cheat_and_swap :: CheatSwapTarget -> CheatSwapClock -> Integer -> Web3 CheatSwapStep
cheat_and_swap target clock tick = do
  -- GUARD (a) — G4. Before any RPC at all.
  case check_cheat_tick tick of
    Right _  -> pure ()
    Left why ->
      fail ("cheat_and_swap: " ++ why
             ++ " Nothing was sent. The rig holds exactly ONE full-range position and minting a"
             ++ " second range would break the same invariant from the other side.")

  head_ts <- chain_head_timestamp

  ts <- case clock of
    LeaveClockAlone      -> pure head_ts
    ForceTimestamp forced -> pure forced
    AdvanceTo previous_ts requested -> do
      -- GUARD (b) — G2 against the CHAIN.
      when (requested <= head_ts) $
        fail ("cheat_and_swap: requested block timestamp " ++ show requested
               ++ " does not advance past the chain head " ++ show head_ts
               ++ " (tick " ++ show tick ++ "). A non-advancing timestamp is a SILENT NO-OP in the"
               ++ " oracle, not an error: RealizedVolatilityStateLib compares"
               ++ " lastTimepointTimestamp to now for EQUALITY, so the swap would still succeed at"
               ++ " status 1, still emit E5 and still serve a fee, and simply write no timepoint."
               ++ " Nothing was sent.")
      -- GUARD (c) — G2 against the CALLER'S OWN SEQUENCE.
      when (requested <= previous_ts) $
        fail ("cheat_and_swap: requested block timestamp " ++ show requested
               ++ " does not advance past the previous step's " ++ show previous_ts
               ++ " (tick " ++ show tick ++ "). The oracle assumes a non-decreasing uint32 clock"
               ++ " and does NOT check it; a backwards step corrupts the window math with no"
               ++ " revert, no event and no symptom, so this guard is the only signal that exists."
               ++ " Nothing was sent.")
      pure requested

  let slot     = pool_state_slot (cst_pool_id target)
      slot_hex = fromString (hex32 slot) :: HexString

  word_before <- read_word (cst_pool_manager target) =<< liftIO (encode_extsload slot)
  pack_word   <- read_word (cst_price_hook target)   =<< liftIO (encode_pack_slot0_for tick)

  let composed = compose_slot0 word_before pack_word

  -- GUARD (d) — the shape of what is about to be written.
  when (composed .&. ((1 `shiftL` 160) - 1) == 0) $
    fail ("cheat_and_swap: the composed slot0 word has a ZERO sqrtPriceX96 for tick " ++ show tick
           ++ ". packSlot0For reverts InvalidTick outside [MIN_TICK, MAX_TICK], but a NotBound"
           ++ " revert on PriceSetterHook.readSlot0 returns 0x instead, which parses as the"
           ++ " perfectly well-formed word 0. Check that PriceSetterHook is bound to a pool on"
           ++ " PriceSetterPoolManager. Nothing was written and nothing was sent.")

  _ <- anvil_set_storage_at (cst_cheat_manager target) slot_hex (fromString (hex32 composed))

  case clock of
    LeaveClockAlone -> pure ()
    _               -> () <$ evm_set_next_block_timestamp ts

  calldata <-
    liftIO
      (encode_swap
         (cst_currency0 target)
         (cst_currency1 target)
         (cst_tick_spacing target)
         (address_hex (cst_fee_hook target)))

  tx_hash <-
    GlobalState.sendTransaction
      Call
        { callFrom     = Just (cst_deployer target)
        , callTo       = Just (cst_swap_router target)
        , callGas      = Nothing
        , callGasPrice = Nothing
        , callValue    = Nothing
        , callData     = Just calldata
        , callNonce    = Nothing
        }
  receipt <- wait_for_receipt tx_hash

  when (receiptStatus receipt /= Just 1) $
    fail ("cheat_and_swap: the swap REVERTED -- tx " ++ show (receiptTransactionHash receipt)
           ++ ", status " ++ show (receiptStatus receipt) ++ ", tick " ++ show tick
           ++ ", timestamp " ++ show ts
           ++ ". A revert unwinds the ENTIRE frame including the timepoint beforeSwap already"
           ++ " wrote, so nothing was recorded.")

  -- The emitter-address filter is MANDATORY, not defensive. RealizedVolatilityMod emits the SAME
  -- E3 topic0 with poolId = bytes32(0) (notes/DATA_CONTRACT.md section 2 -- the sentinel is
  -- permanent and first-class), so a topic0-only filter conflates two series the moment anything
  -- drives the module. The poolId topic guard inside the decoder does not close it either: the
  -- hook and the module both emit E3 with a real poolId, and only the log's emitting address
  -- separates them.
  let hook_logs = filter ((== cst_fee_hook target) . changeAddress) (receiptLogs receipt)
      e3s = mapMaybe (decode_timepoint_written (cst_topic_e3 target) (cst_pool_id target)) hook_logs
      e5s = mapMaybe (decode_fee_applied      (cst_topic_e5 target) (cst_pool_id target)) hook_logs

  pure CheatSwapStep
    { cs_tick          = tick
    , cs_timestamp     = ts
    , cs_state_slot    = slot_hex
    , cs_word_before   = word_before
    , cs_word_written  = composed
    , cs_swap_router   = cst_swap_router target
    , cs_swap_calldata = calldata
    , cs_tx_hash       = tx_hash
    , cs_status        = receiptStatus receipt
    , cs_e3            = listToMaybe e3s
    , cs_e5            = listToMaybe e5s
    , cs_e3_count      = length e3s
    , cs_e5_count      = length e5s
    }

-- ---------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------

read_word :: Address -> HexString -> Web3 Integer
read_word to calldata =
  hex_to_integer
    <$> GlobalState.call
          Call
            { callFrom     = Nothing
            , callTo       = Just to
            , callGas      = Nothing
            , callGasPrice = Nothing
            , callValue    = Nothing
            , callData     = Just calldata
            , callNonce    = Nothing
            }
          Latest

-- | An 'Address' as the @0x@-prefixed lowercase hex string @cast@ expects inside a tuple argument.
--
-- Rendered from the bytes rather than via 'show', so the output shape is this module's decision and
-- not a dependency's formatting choice — and so nothing here is a source literal the offchain purge
-- could match.
address_hex :: Address -> String
address_hex = ("0x" ++) . concatMap byte . BS.unpack . toBytes . toHexString
  where
    byte b = [nibble (b `shiftR` 4), nibble (b .&. 0x0f)]
    nibble = intToDigit . fromIntegral
