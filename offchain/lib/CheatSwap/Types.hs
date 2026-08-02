-- | The pure slot0 arithmetic behind the cheat-swap pattern: derive the pool's state slot, compose
-- the word to write into it, and reject a cheat tick the rig cannot honour. No IO, no addresses,
-- no chain.
--
-- == THE BLOCKER THIS MODULE EXISTS TO FIX
--
-- It is invisible at the call site, so it is stated here first.
--
-- @PriceSetterHookScript@ stands up its OWN, SECOND @PoolManager@ — manifest key
-- @PriceSetterPoolManager@ — and binds @PriceSetterHook@ to a pool THERE: currencies
-- @(address(0), address(1))@, static fee 3000, tickSpacing 60, ZERO liquidity, hook flags
-- @BEFORE_INITIALIZE | AFTER_INITIALIZE@ and notably NO @BEFORE_SWAP@. @DynamicFeeHook@ is bound to
-- a pool on a DIFFERENT @PoolManager@, with @MinimalToken@ currencies, a dynamic fee and
-- tickSpacing 20.
--
-- So @PriceSetter.Rpc.write_price@ writes @PriceSetterPoolManager@'s slot0 while
-- @DynamicFeeHook.beforeSwap@ reads @PoolManager@'s. Cheating one and swapping the other records
-- the UN-CHEATED tick, permanently, and it fails SILENTLY: E3 still fires, the receipt is status 1,
-- the timepoint clock still advances — only the tick VALUE is wrong. There is no error to notice.
-- The cheat must therefore be composed from the TARGET pool's OWN current word,
-- @PoolManager.extsload(keccak(poolId || 6))@, and this module does that composition.
--
-- @write_price@ is NOT deleted and NOT re-pointed. Roadmap SC-1 and 22-CONTEXT both require the
-- existing @PriceSetterHook@ flow to stay available and unchanged; this capability is ADDED beside
-- it. What DOES change is @PriceSetterHook.packSlot0For@'s role: it is now also used as the audited
-- on-chain @tick -> sqrtPriceX96@ oracle, because it already calls @TickMath.getSqrtPriceAtTick@
-- and already writes the two consistently. Only its LOW 184 bits are consumed — its fee bits
-- describe the wrong pool.
module CheatSwap.Types
  ( pools_slot
  , pool_state_slot
  , compose_slot0
  , check_cheat_tick
  , word32be
  ) where

import Crypto.Ethereum.Utils (keccak256)
import Data.Bits (complement, shiftL, shiftR, (.&.), (.|.))
import qualified Data.ByteString as BS

import VolOrder.Decode (be_integer)

-- | v4-core's @StateLibrary.POOLS_SLOT@.
--
-- This is CONSUMED from the pinned constant at
-- @src\/modules\/protocol_integrations\/DynamicFeeHook.plk:75@ (@const POOLS_SLOT = 6;@), never
-- re-derived by counting storage slots in v4-core. The reason is that the hook and this module
-- must agree: the hook's @read_current_tick@ derives the slot with ITS value, and if the two ever
-- disagreed the cheat would land in a slot nothing reads, which — again — produces no error at all,
-- just an unchanged tick. Consuming the same pinned number makes disagreement impossible rather
-- than unlikely.
pools_slot :: Integer
pools_slot = 6

-- | A non-negative 'Integer' as a 32-byte big-endian word. Built by shifting rather than from a hex
-- string: the offchain literal purge greps this file.
word32be :: Integer -> BS.ByteString
word32be n = BS.pack [fromIntegral ((n `shiftR` (8 * i)) .&. 0xff) | i <- [31, 30 .. 0]]

-- | @keccak256( bytes32(poolId) || bytes32(uint256(POOLS_SLOT)) )@ — the slot holding the pool's
-- @Pool.State@, whose FIRST word is @slot0@.
--
-- The 64-byte preimage order is @poolId@ THEN the slot number, matching @read_current_tick@'s
-- @\@mstore32(pre, pool_id); \@mstore32(pre +% 32, POOLS_SLOT)@ exactly. Swapping the two halves
-- yields a different, perfectly valid-looking 32-byte slot; @extsload@ on it returns zero rather
-- than reverting, and a zero slot0 decodes to @tick = 0@, which is a legal tick. The check
-- @driv01_slot0_composition_behavior@ pins the output against a value MEASURED with @cast keccak@
-- for precisely that reason.
pool_state_slot :: Integer -> Integer
pool_state_slot pool_id =
  be_integer (keccak256 (word32be pool_id <> word32be pools_slot))

-- | Compose the word to write into the target pool's slot0: bits 0..183 from @packSlot0For@'s word,
-- bits 184..255 from the TARGET pool's own current word.
--
-- == WHY THE MASK IS AT 184
--
-- The Slot0 layout is
-- @sqrtPriceX96 [0,160) | tick [160,184) int24 | protocolFee [184,208) | lpFee [208,232) | empty@.
--
-- Bits 184..207 and 208..231 are @protocolFee@ and @lpFee@ FOR THE TARGET POOL. Masking at 184
-- preserves them BY CONSTRUCTION (G5b) rather than by remembering to. On today's rig both happen
-- to be zero — @protocolFee@ is unset and a dynamic-fee pool stores @lpFee = 0@ at initialize —
-- which is exactly what makes zeroing them a LATENT bug: it is unobservable until someone
-- configures a protocol fee, and then it silently un-configures it once per cheat step.
--
-- Masking at 160 instead would take @packSlot0For@'s @sqrtPriceX96@ while KEEPING the target's
-- @tick@. The word would then carry a price and a tick that disagree, violating G5a, and the hook
-- would record the tick that was already there — the same silent wrong-value failure the module
-- header describes, arriving by a second route.
--
-- Taking the whole of @packSlot0For@'s word (no mask at all) is the third wrong answer: its fee
-- bits are @PriceSetterPoolManager@'s pool's, not the target's.
compose_slot0 :: Integer -> Integer -> Integer
compose_slot0 current_word pack_slot0_for_word =
  (current_word .&. complement low184) .|. (pack_slot0_for_word .&. low184)
  where
    low184 = (1 `shiftL` 184) - 1

-- | G4: reject any cheat tick the rig's liquidity cannot honour, BEFORE any calldata is built.
--
-- The admissible domain is STRICTLY inside
-- @[minUsableTick(20), maxUsableTick(20)] = [-887260, +887260]@, i.e. @[-887259, +887259]@.
--
-- The rig holds exactly ONE full-range position spanning those two ticks with @L = 1e21@. Cheat
-- moves never CROSS a tick — they overwrite slot0 directly, leaving @liquidity@, @tickBitmap@,
-- @ticks@ and @feeGrowthGlobal@ untouched — so the global liquidity figure is only meaningful while
-- the imposed tick stays INSIDE the position. The TickMath-valid slivers out to +-887272 sit
-- OUTSIDE it, and there the pool claims 1e21 of liquidity that is not there: an accounting desync,
-- not a revert.
--
-- This is a CLIENT-SIDE domain guard in the same family as @pack_vol_order_input@'s field
-- validation and @StochasticPriceGen.Simulate@'s NaN guard — catch it where the cause is known,
-- rather than letting it become a silent on-chain no-op nothing can attribute later. The 'Left'
-- names both the bound and the guard so the message is greppable back to this reasoning.
check_cheat_tick :: Integer -> Either String Integer
check_cheat_tick tick
  | tick < negate cheat_tick_bound || tick > cheat_tick_bound =
      Left ("cheat tick " ++ show tick ++ " is outside the G4 domain [-"
              ++ show cheat_tick_bound ++ ", " ++ show cheat_tick_bound
              ++ "]. The rig holds ONE full-range position over"
              ++ " [minUsableTick(20), maxUsableTick(20)] = [-887260, +887260]; the"
              ++ " TickMath-valid slivers out to +-887272 sit OUTSIDE it, where global liquidity"
              ++ " claims 1e21 that is not there. Cheat moves never cross ticks, so this desync"
              ++ " is silent.")
  | otherwise = Right tick

-- | The G4 bound: strictly inside @maxUsableTick(20) = 887260@.
cheat_tick_bound :: Integer
cheat_tick_bound = 887259
