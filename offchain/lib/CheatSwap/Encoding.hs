-- | Calldata for the two calls the cheat-swap pattern makes: reading the target pool's slot0 out
-- of @PoolManager@, and the minimal swap that exists only to enter @DynamicFeeHook.beforeSwap@.
--
-- Both are built by shelling to @cast calldata@ with the SIGNATURE STRING, exactly as
-- @PriceSetter.Encoding@ already does, and for the same two reasons. First, @cast@ is the
-- independent encoder: a selector computed here would be this repo agreeing with itself. Second,
-- the offchain literal purge (@sc3_literal_purge@) greps @offchain\/**\/*.hs@ for
-- @0x[0-9a-fA-F]{8}\\b@, so writing either selector down is a suite failure by construction. For
-- the record and NOT in any source file, the two selectors @cast sig@ reports are the ones
-- @driv01_swap_calldata_shape@ recomputes from 'swap_signature' at test time.
module CheatSwap.Encoding
  ( encode_extsload
  , encode_swap
  , swap_signature
  , extsload_signature
  , hex32
  ) where

import Data.Bits (shiftR, (.&.))
import Data.ByteArray.HexString (HexString)
import Data.Char (intToDigit)
import Data.List (intercalate)
import Data.String (fromString)
import System.Process (readProcess)

-- | @IExtsload@'s single-argument overload. v4's @PoolManager@ also declares two-argument
-- @extsload@ overloads, so the arity here is load-bearing: the wrong overload has a different
-- selector and @staticcall@ to a missing selector on a contract with no fallback simply reverts.
extsload_signature :: String
extsload_signature = "extsload(bytes32)"

-- | @PoolSwapTest.swap@'s signature, in the canonical tuple form @cast@ expects
-- (@lib\/panoptic-v2-core\/lib\/v4-core\/src\/test\/PoolSwapTest.sol@): @PoolKey@,
-- @SwapParams@, @TestSettings@, @hookData@.
--
-- This string is the single source of the selector. @driv01_swap_calldata_shape@ parses it BACK
-- OUT of this file and recomputes @keccak256@ over it, so the selector in the emitted calldata is
-- DERIVED at test time and never transcribed — the same discipline as the RPIN-01 selector check.
swap_signature :: String
swap_signature =
  "swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)"

-- | @LPFeeLibrary.DYNAMIC_FEE_FLAG@, written in DECIMAL. Its hex form is a @0x@-prefixed six-digit
-- value, and writing it that way is a habit that ends in an eight-digit one; decimal has nothing
-- for the purge to match and nothing for a reader to mistake for a selector.
dynamic_fee_flag :: Integer
dynamic_fee_flag = 8388608

-- | @TickMath.MIN_SQRT_PRICE + 1@ — the EXACT literal @InitSwappableRig@'s own probe swap uses.
--
-- Used at EVERY cheated tick, not only at zero. v4's bound check for @zeroForOne@ is
-- @MIN_SQRT_PRICE < sqrtPriceLimitX96 < slot0.sqrtPriceX96@, and @getSqrtPriceAtTick(-887259)@ is
-- 4297706459 — about 2.5e6 units ABOVE this limit — so the inequality never inverts anywhere
-- inside the G4 domain @[-887259, +887259]@. That is what makes one fixed limit safe here and why
-- the direction does not need to be chosen per step.
--
-- Near the FLOOR of the range the position holds almost no token1, so the swap DEGENERATES to
-- @amount1 ~ 0@ rather than reverting: the vendored @PoolSwapTest@ declares @error
-- NoSwapOccurred()@ and never uses it. That is harmless for DRIV-01, because @beforeSwap@ — and
-- therefore @rv_write_timepoint@ and E3 — runs BEFORE any swap math. THIS DEGENERACY IS A
-- PREDICTION, not an established fact; plan 22-04 measures it at an extreme tick. Do not cite it
-- as measured.
min_sqrt_price_limit :: Integer
min_sqrt_price_limit = 4295128740

-- | Exact-input dust against the rig's @L = 1e21@ — the probe amount @InitSwappableRig@ itself
-- uses, i.e. the single swap configuration this rig has ever executed successfully.
--
-- NEVER 0: v4 reverts @SwapAmountCannotBeZero@, and that unwinds the ENTIRE frame including the
-- timepoint write @beforeSwap@ already performed. A zero-amount "no-op probe" is therefore not a
-- cheaper version of this call, it is a call that undoes itself.
probe_amount :: Integer
probe_amount = -1000000

-- | @PoolManager.extsload(bytes32)@ for one slot.
encode_extsload :: Integer -> IO HexString
encode_extsload slot = encode_call extsload_signature [hex32 slot]

-- | The minimal swap that exists only to enter @DynamicFeeHook.beforeSwap@.
--
-- Every argument except the @PoolKey@ fields is FIXED, taken straight from @InitSwappableRig@'s
-- probe. The four caller-supplied values all come from @rig-manifest.json@ and NONE of them has a
-- default here — in particular @tickSpacing@, because the @PoolKey@ must reconstruct to
-- @hook.poolId()@ or @beforeSwap@'s @require(pool_id == \@evm_sload(SLOT_HOOK_POOL_ID))@ reverts
-- the whole transaction with EMPTY reason data. @InitSwappableRig@ pre-registers exactly this
-- drift detector ("reconstructed PoolKey does not hash to the hook's bound poolId (key drift)"),
-- and a hardcoded tickSpacing is the most likely way to trip it, since the rig's own value moved
-- 10 -> 20 during Phase 22's upstream gate.
encode_swap
  :: String    -- ^ currency0, @0x@-prefixed, from the manifest
  -> String    -- ^ currency1, @0x@-prefixed, from the manifest
  -> Integer   -- ^ tickSpacing, from @.pool.tickSpacing@ — NEVER a constant
  -> String    -- ^ hook address, @0x@-prefixed, from the manifest
  -> IO HexString
encode_swap currency0 currency1 tick_spacing hook =
  encode_call swap_signature
    [ tuple [currency0, currency1, show dynamic_fee_flag, show tick_spacing, hook]
    , tuple ["true", show probe_amount, show min_sqrt_price_limit]
    , tuple ["false", "false"]
    , "0x"
    ]
  where
    tuple fields = "(" ++ intercalate "," fields ++ ")"

-- | A 32-byte @0x@-prefixed hex word. Rendered at RUNTIME from an 'Integer', so nothing here is a
-- source literal and the purge has nothing to match.
hex32 :: Integer -> String
hex32 n = "0x" ++ [nibble i | i <- [63, 62 .. 0]]
  where
    nibble i = intToDigit (fromIntegral ((n `shiftR` (4 * i)) .&. 15))

encode_call :: String -> [String] -> IO HexString
encode_call signature args = do
  raw <- readProcess "cast" ("calldata" : signature : args) ""
  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
