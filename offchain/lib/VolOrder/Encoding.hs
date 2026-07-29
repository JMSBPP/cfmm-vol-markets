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

encode_create_order :: VolOrder -> IO HexString
encode_create_order order =
  encode_call
    "create_order(uint88,uint24,uint16)"
    [ show (vol_target order)
    , show (range_width order)
    , show (skew order)
    ]

-- Packs a VolOrder into the create_orders INPUT word layout, verified against
-- test/pos_spec/VolOrderManagerBatch.t.sol's own packInput helper:
--   packed = skew | (vol_target << 16) | (range_width << 104)
-- This is NOT the contract's internal storage layout -- see
-- VolOrder.Decode.unpack_vol_order_storage for that (a third, distinct layout).
--
-- Each field is validated strictly in-range before combining. The contract's own
-- decode deliberately leaves range_width unmasked so overflow >= 2^104 is caught
-- on-chain by vol_range_width_is_complete -- but a vol_target in [2^88, 2^104)
-- shifts left by 16 and lands entirely inside range_width's own 24-bit slot,
-- OR-ing in as a plausible-looking width with ZERO on-chain signal (not a revert,
-- not (false, 0)). Masking each field before combining (like the contract's own
-- storage-side pack_vol_order does) would only relocate this silent-corruption
-- risk from on-chain to off-chain -- so this validates and fails clearly instead.
--
-- Deliberate seam: these are FIELD-WIDTH bounds (packing safety), not the
-- contract's business rules. They coincide for vol_target ([1, 2^88-1] both
-- sides) and range_width ([1, 2^24-1] both sides), but skew's business rule is
-- one tighter: spread_tick_assimetry_is_complete accepts [1, 65534], while
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
  | otherwise = Right (sk .|. (target `shiftL` 16) .|. (width `shiftL` 104))
  where
    target = toInteger (vol_target order)
    width  = toInteger (range_width order)
    sk     = toInteger (skew order)
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
