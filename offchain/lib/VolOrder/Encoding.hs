module VolOrder.Encoding
  ( encode_create_order
  , pack_vol_order_input
  , encode_create_orders
  , encode_order_count
  , encode_get_order_packed
  ) where

import Data.Bits (shiftL, (.|.))
import Data.ByteArray.HexString (HexString)
import Data.List (intercalate)
import Data.String (fromString)
import System.Process (readProcess)

import VolOrder.Types (VolOrder (..))

-- V2, four arguments. The V1 3-arg create_order path is DELETED, not kept alongside: nothing was
-- ever deployed under its selector (rig-pins.json records it under `retired`), and a module that
-- dispatches only the 4-arg selector answers a 3-arg call with a revert. Its signature string is
-- not repeated here either -- the phase's own verification greps offchain/ for it.
encode_create_order :: VolOrder -> IO HexString
encode_create_order order =
  encode_call
    "create_order(uint88,uint24,uint16,uint96)"
    [ show (vol_target order)
    , show (range_width order)
    , show (skew order)
    , show (target_vega order)
    ]

-- Packs a VolOrder into the create_orders INPUT word. V2 layout, read off the EXECUTABLE code at
-- src/modules/pos_spec/VolOrderManagerMod.plk:229-235:
--
--   skew        bits   0..15    u16   masked on-chain
--   vol_target  bits  16..103   u88   masked on-chain
--   range_width bits 104..127   u24   masked on-chain -- INTERIOR in V2
--   target_vega bits 128..223   u96   UNMASKED on-chain -- the TOP field
--   bits >= 224                       MUST BE ZERO BY CONSTRUCTION on this side
--
-- DO NOT TAKE THIS LAYOUT FROM THAT FILE'S COMMENT BLOCK AT LINES 177-188. That block is stale V1
-- prose -- it still says "bits >=128 MUST BE ZERO" and "width IS DELIBERATELY UNMASKED. It is the
-- TOP field" -- and both sentences are false of the V2 code 50 lines below it. The plank track owns
-- that file; the discrepancy is REPORTED, not edited here.
--
-- What moved with the layout is the dirty-bit-rejection ROLE. In V1 it sat on range_width; in V2
-- range_width is interior and masked, and target_vega inherited it: any bit >= 224 inflates
-- target_vega past 2^96-1, where target_vega_fits_packed rejects the order.
--
-- AND THAT REJECTION IS ASYMMETRIC. The strict create_order path REVERTS on a dirty word. The
-- BATCH path SKIPS it, returning (false, 0) -- indistinguishable from an ordinary business
-- rejection, and the batch never reverts. So on the batch path there is no on-chain signal at all;
-- the in_range 96 guard below is the ONLY loud signal a client gets, which is why every field is
-- validated here rather than masked. Masking would relocate silent corruption from on-chain to
-- off-chain, not remove it.
--
-- This is NOT the contract's internal storage layout -- see
-- VolOrder.Decode.unpack_vol_order_storage for that (a third, distinct layout).
--
-- in_range 96 needs no new predicate: its `> 0` IS vega_target_is_complete's `self.vega > 0`, and
-- its `< 2^96` IS target_vega_fits_packed.
--
-- Deliberate seam: these are FIELD-WIDTH bounds (packing safety), not the
-- contract's business rules. They coincide for vol_target ([1, 2^88-1] both
-- sides), range_width ([1, 2^24-1] both sides) and target_vega ([1, 2^96-1]
-- both sides), but skew's business rule is one tighter:
-- spread_tick_assimetry_is_complete accepts [1, 65534], while
-- skew = 65535 passes here, packs cleanly, and comes back (False, 0) from the
-- batch's best-effort path. That is intentional -- it is the only
-- client-passing, contract-rejected input, kept as the test vector that
-- exercises best-effort semantics end-to-end (spec Testing step 4). Callers
-- wanting pre-flight business validation must bound skew <= 65534 themselves.
pack_vol_order_input :: VolOrder -> Either String Integer
pack_vol_order_input order
  | not (in_range 88 target) =
      Left ("vol_target out of range for its 88-bit field (must be > 0 and < 2^88): "
             ++ show target)
  | not (in_range 24 width) =
      Left ("range_width out of range for its 24-bit field (must be > 0 and < 2^24): "
             ++ show width)
  | not (in_range 16 sk) =
      Left ("skew out of range for its 16-bit field (must be > 0 and < 2^16): "
             ++ show sk)
  | not (in_range 96 vega) =
      Left ("target_vega out of range for its 96-bit field (must be > 0 and < 2^96): "
             ++ show vega)
  | otherwise =
      Right (sk .|. (target `shiftL` 16) .|. (width `shiftL` 104) .|. (vega `shiftL` 128))
  where
    target = toInteger (vol_target order)
    width  = toInteger (range_width order)
    sk     = toInteger (skew order)
    vega   = toInteger (target_vega order)
    in_range bits value = value > 0 && value < (1 `shiftL` bits)

encode_create_orders :: [VolOrder] -> IO HexString
encode_create_orders orders = do
  packed <- either fail pure (traverse pack_vol_order_input orders)
  encode_call
    "create_orders(uint256,uint256[])"
    [ show (length orders)
    , "[" ++ intercalate "," (map show packed) ++ "]"
    ]

encode_order_count :: IO HexString
encode_order_count = encode_call "orderCount()" []

encode_get_order_packed :: Integer -> IO HexString
encode_get_order_packed order_id = encode_call "getOrderPacked(uint256)" [show order_id]

encode_call :: String -> [String] -> IO HexString
encode_call signature args = do
  raw <- readProcess "cast" ("calldata" : signature : args) ""
  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
