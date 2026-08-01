module StochasticOrderGen.Types
  ( ArrivalProcess (..)
  , OrderShape (..)
  , StochasticOrderGen (..)
  , VegaDraw (..)
  ) where

import Network.Ethereum.Api.Types (Quantity)

data ArrivalProcess = Poisson
  { lambda :: Double
  }
  deriving (Eq, Show)

-- | The law the generator draws each order's @targetVega@ from.
--
-- ONE constructor, deliberately -- the same shape as 'ArrivalProcess' and
-- "StochasticPriceGen.Types"'s @ProcessType@. A second constructor is the extension path
-- (see THE HONEST LIMIT below); a bare @Integer@ field would not have been.
--
-- == DIMENSION
--
-- @targetVega@ is DeltaQ_v*, in RAW UNISWAP-L UNITS -- dimension (ii) of
-- @notes\/UNITS_AND_SCALES.md@ section 2. It is NOT X96, NOT WAD, and NOT collateral-denominated.
-- A unit slip here is INVISIBLE on chain: any value that fits u96 stores fine, packs fine and
-- round-trips fine, so nothing rejects it and the error only surfaces downstream as nonsense.
-- That is why the dimension is written down here rather than left to the reader.
--
-- == WHY THE BAND IS [1e18, 1e21], EXACTLY
--
-- Instantiate the standard v3 relation @amount1 = L * (sqrt(P) - sqrt(Pa))@ on THE RIG'S OWN
-- POOL: @initTick = 0@, so @P = 1@, and both @MinimalToken@s carry 18 decimals. Depositing one
-- whole token (10^18 wei) of token1 over a symmetric width of @w@ ticks about tick 0 gives
-- @L = amount1 \/ (1 - 1.0001 ** (-w\/4))@:
--
-- > full range (+/- 887272)  ->  L = 1.000e18
-- > w = 20 000               ->  L = 2.542e18
-- > w =  1 000               ->  L = 4.050e19
-- > w =     20               ->  L = 2.001e21
--
-- So @[1e18, 1e21]@ is exactly "one whole 18-decimal token, from full range down to a ~20-tick
-- concentrated band" -- the concentrated-liquidity regime this instrument exists to target.
--
-- HEADROOM: u96 max is 7.923e28, so 1e21 leaves a factor of 7.9e7. @UNITS_AND_SCALES.md@
-- section 2's claim of "realistic pool liquidity 1e18-1e21, >= 1e7x headroom" is thereby
-- GROUNDED in this pool's own numbers, not corrected.
--
-- BIT-LENGTHS: 1e18 is 2^59.8 and 1e21 is 2^69.8, so the band occupies bit-lengths 60..70 of a
-- 96-bit field.
--
-- == WHY THE SHAPE IS LOG-UNIFORM
--
-- Heimbach, Schertenleib and Wattenhofer, /Risks and Returns of Uniswap V3 Liquidity Providers/,
-- ACM AFT 2022, arXiv:2205.08904, measures REAL v3 positions and reports the mean position size
-- at around TEN TIMES the median (rising towards 100x in 2022). That is a strongly right-skewed,
-- log-scale quantity.
--
-- Both alternatives are therefore rejected on evidence, not taste:
--
--   * LINEAR-UNIFORM on @[1e18, 1e21]@ would put 90% of its mass in @[1e20, 1e21]@ and
--     essentially never sample the full-range end -- it would exercise the top decade only.
--   * A FIXED CONSTANT exercises exactly one bit-length, which is what the generator shipped
--     with before this law existed.
--
-- Log-uniform is the scale-invariant (maximum-entropy) law on a positive quantity whose only
-- established feature is its order-of-magnitude range, and it commits to no fitted parameter
-- that no source supplies for this pool.
--
-- == THE HONEST LIMIT
--
-- No source, local or academic, specifies a SAMPLING LAW for a variance-instrument target vega
-- in raw L units. The evidence pins the BAND exactly (the v3 relation above, on this pool) and
-- pins the QUANTITY as log-scale rather than linear-scale (arXiv:2205.08904). Log-uniform is the
-- most defensible default given both, and it is defensible precisely BECAUSE it adds nothing
-- beyond them.
--
-- If a later phase measures the rig pool's actual L distribution, 'VegaDraw' gains a second
-- constructor and nothing else in this module changes. That is the whole reason it is a
-- one-constructor sum type rather than two bare @Integer@ fields on 'StochasticOrderGen'.
data VegaDraw
  = LogUniform
      { vega_min :: Integer  -- ^ inclusive lower bound, raw L
      , vega_max :: Integer  -- ^ inclusive upper bound, raw L
      }
  deriving (Eq, Show)

-- | A vol order MINUS its @targetVega@ -- the part a caller supplies, as opposed to the part the
-- generator draws.
--
-- This type exists to remove a trap rather than to add structure. The alternative was to keep
-- @orders :: [VolOrder]@ and overwrite each @target_vega@ at generation time, which forces every
-- caller to supply a value that is SILENTLY DISCARDED: a number that looks meaningful, reads as
-- meaningful in a diff, and is not. That is the same defect class as a stale address literal --
-- a value with no way to announce that it never mattered.
--
-- The @shape_@ prefixes are not decoration: "Sample" imports both this module and
-- "VolOrder.Types", and unprefixed field names would collide.
data OrderShape = OrderShape
  { shape_vol_target  :: Quantity
  , shape_range_width :: Quantity
  , shape_skew        :: Quantity
  }
  deriving (Eq, Show)

data StochasticOrderGen = StochasticOrderGen
  { arrival_process :: ArrivalProcess
  , orders          :: [OrderShape]
  , vega_draw       :: VegaDraw
  }
  deriving (Eq, Show)
