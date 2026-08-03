module VolOrder.Types
  ( VolOrder(..)
  ) where

import Network.Ethereum.Api.Types (Quantity)

data VolOrder = VolOrder
  { vol_target  :: Quantity
  , range_width :: Quantity
  , skew        :: Quantity
  , target_vega :: Quantity
    -- ^ @DeltaQ_v*@ in RAW LIQUIDITY units -- the Uniswap @L@ dimension (see
    -- @notes\/UNITS_AND_SCALES.md@ section 2). NOT X96, NOT WAD, NOT collateral. Admissible
    -- range is @[1, 2^96-1]@, the width of its packed field.
    --
    -- A unit slip here is INVISIBLE on-chain: any value that fits u96 stores fine, so a WAD-scaled
    -- or X96-scaled quantity is accepted and only surfaces as nonsense downstream. Nothing in the
    -- contract can catch it, which is why the dimension is stated here rather than assumed.
  }
  deriving (Eq, Show)
